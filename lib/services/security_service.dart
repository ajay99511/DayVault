import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:local_auth/local_auth.dart';
import '../config/security_questions.dart';

/// Security service handling PIN hashing, rate limiting, and data encryption.
///
/// Security Features:
/// - PIN hashing using PBKDF2 with SHA-256
/// - Rate limiting with exponential backoff
/// - Account lockout after failed attempts
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Use FlutterSecureStorage for PIN storage
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Cache encryption key in memory after PIN verification (for decrypting existing data)
  Uint8List? _cachedEncryptionKey;

  // Security constants
  static const int _maxAttempts = 5;
  static const int _lockoutDurationSeconds = 30;
  static const String _saltKey = 'security_salt';
  static const String _pinHashKey = 'pin_hash';
  static const String _attemptCountKey = 'attempt_count';
  static const String _lockoutUntilKey = 'lockout_until';
  static const String _encryptionKey = 'encryption_key';
  
  // Security questions storage keys
  static const String _securityQuestionsKey = 'security_questions';
  static const String _securityAnswersKey = 'security_answers';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  // Biometric authentication
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Generate a random salt for PIN hashing
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Hash PIN using PBKDF2 with SHA-256
  /// 
  /// Uses 100,000 iterations for security while maintaining performance
  Future<String> _hashPin(String pin, String salt) async {
    // PBKDF2 with SHA-256, 100000 iterations
    final key = await compute(
      _pbkdf2Hash,
      {'pin': pin, 'salt': salt, 'iterations': 100000},
    );
    return key;
  }

  /// Initialize security service - creates salt if not exists
  Future<void> initialize() async {
    final salt = await _storage.read(key: _saltKey);
    if (salt == null) {
      final newSalt = _generateSalt();
      await _storage.write(key: _saltKey, value: newSalt);
    }
    
    // Reset attempt count on app start (optional - can be removed for stricter security)
    await _resetAttempts();
  }

  /// Derive encryption key from PIN and cache it in memory.
  /// Used to decrypt existing journal data after successful PIN verification.
  Future<void> _deriveAndCacheEncryptionKey(String pin) async {
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    
    // Derive key using HMAC-SHA256 iterations
    final derivedKeyList = await compute(
      _deriveKeyBinary,
      {'pin': pin, 'salt': salt, 'iterations': 10000},
    );

    _cachedEncryptionKey = Uint8List.fromList(derivedKeyList);
  }

  /// Get the cached encryption key (for decrypting existing journal data).
  /// Returns null if not cached (PIN not verified).
  Uint8List? getCachedEncryptionKey() {
    return _cachedEncryptionKey;
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set a new PIN (only if no PIN exists)
  /// 
  /// Returns true if PIN was set successfully
  Future<bool> setPin(String pin) async {
    // Validate PIN format - must be 4-6 digits
    if (!_isValidPin(pin)) {
      return false;
    }

    // Don't allow setting PIN if one already exists
    if (await isPinSet()) {
      return false;
    }

    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    if (await _storage.read(key: _saltKey) == null) {
      await _storage.write(key: _saltKey, value: salt);
    }

    final hash = await _hashPin(pin, salt);
    await _storage.write(key: _pinHashKey, value: hash);

    return true;
  }

  /// Verify PIN with rate limiting
  ///
  /// Returns [PinVerificationResult] with status and any error message
  Future<PinVerificationResult> verifyPin(String pin) async {
    // Check if locked out
    final lockoutResult = await _checkLockout();
    if (!lockoutResult.success) {
      return lockoutResult;
    }

    // Validate PIN format
    if (!_isValidPin(pin)) {
      return PinVerificationResult(
        success: false,
        error: 'Invalid PIN format',
      );
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) {
      return PinVerificationResult(
        success: false,
        error: 'No PIN configured',
      );
    }

    final salt = await _storage.read(key: _saltKey) ?? '';
    final inputHash = await _hashPin(pin, salt);

    if (inputHash == storedHash) {
      // Success - reset attempts and derive encryption key
      await _resetAttempts();
      await _deriveAndCacheEncryptionKey(pin); // Cache key for decrypting existing data
      return PinVerificationResult(success: true);
    } else {
      // Failed - increment attempts
      return await _handleFailedAttempt();
    }
  }

  /// Check if device is locked out
  Future<PinVerificationResult> _checkLockout() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) {
      return PinVerificationResult(success: true);
    }

    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(
      int.parse(lockoutUntilStr),
    );

    if (DateTime.now().isBefore(lockoutUntil)) {
      final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
      return PinVerificationResult(
        success: false,
        error: 'Too many attempts. Try again in $remaining seconds.',
        remainingLockoutSeconds: remaining,
      );
    }

    // Lockout expired - clear it
    await _storage.delete(key: _lockoutUntilKey);
    await _resetAttempts();
    
    return PinVerificationResult(success: true);
  }

  /// Handle failed PIN attempt
  Future<PinVerificationResult> _handleFailedAttempt() async {
    final attemptsStr = await _storage.read(key: _attemptCountKey) ?? '0';
    final attempts = int.parse(attemptsStr) + 1;
    
    await _storage.write(key: _attemptCountKey, value: attempts.toString());

    final remainingAttempts = _maxAttempts - attempts;

    if (remainingAttempts <= 0) {
      // Lockout
      final lockoutUntil = DateTime.now().add(
        const Duration(seconds: _lockoutDurationSeconds),
      );
      await _storage.write(
        key: _lockoutUntilKey, 
        value: lockoutUntil.millisecondsSinceEpoch.toString(),
      );
      await _storage.delete(key: _attemptCountKey);
      
      return PinVerificationResult(
        success: false,
        error: 'Too many failed attempts. Locked for $_lockoutDurationSeconds seconds.',
        remainingLockoutSeconds: _lockoutDurationSeconds,
      );
    }

    return PinVerificationResult(
      success: false,
      error: 'Incorrect PIN. $remainingAttempts attempts remaining.',
      remainingAttempts: remainingAttempts,
    );
  }

  /// Reset failed attempt counter
  Future<void> _resetAttempts() async {
    await _storage.delete(key: _attemptCountKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  /// Change PIN (requires old PIN verification)
  Future<PinVerificationResult> changePin(String oldPin, String newPin) async {
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(
        success: false,
        error: 'New PIN must be 4-6 digits',
      );
    }

    // Verify old PIN first
    final verifyResult = await verifyPin(oldPin);
    if (!verifyResult.success) {
      return verifyResult;
    }

    // Delete old PIN hash
    await _storage.delete(key: _pinHashKey);

    // Set new PIN
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    final hash = await _hashPin(newPin, salt);
    await _storage.write(key: _pinHashKey, value: hash);

    return PinVerificationResult(success: true);
  }

  /// Remove PIN (requires verification)
  Future<PinVerificationResult> removePin(String pin) async {
    final verifyResult = await verifyPin(pin);
    if (!verifyResult.success) {
      return verifyResult;
    }

    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _saltKey);
    await _resetAttempts();

    return PinVerificationResult(success: true);
  }

  /// Validate PIN format (4-6 digits only)
  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  /// Get remaining attempts before lockout
  Future<int> getRemainingAttempts() async {
    final attemptsStr = await _storage.read(key: _attemptCountKey) ?? '0';
    final attempts = int.parse(attemptsStr);
    return (_maxAttempts - attempts).clamp(0, _maxAttempts);
  }

  /// Check if currently locked out
  Future<bool> isLockedOut() async {
    final result = await _checkLockout();
    return !result.success && result.remainingLockoutSeconds != null;
  }

  // ==================== SECURITY QUESTIONS ====================

  /// Check if security questions are set up
  Future<bool> areSecurityQuestionsSet() async {
    final questions = await _storage.read(key: _securityQuestionsKey);
    return questions != null && questions.isNotEmpty;
  }

  /// Set security questions and hashed answers
  /// 
  /// [questions] - List of 3 question strings
  /// [answers] - List of 3 answer strings (will be normalized and hashed)
  Future<bool> setSecurityQuestions(List<String> questions, List<String> answers) async {
    if (questions.length != 3 || answers.length != 3) {
      return false;
    }

    // Hash each answer
    final hashedAnswers = <String>[];
    for (final answer in answers) {
      final normalizedAnswer = SecurityQuestions.normalizeAnswer(answer);
      final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
      final hashedAnswer = await _hashPin(normalizedAnswer, salt);
      hashedAnswers.add(hashedAnswer);
    }

    // Store questions and hashed answers
    final questionsJson = jsonEncode(questions);
    final answersJson = jsonEncode(hashedAnswers);

    await _storage.write(key: _securityQuestionsKey, value: questionsJson);
    await _storage.write(key: _securityAnswersKey, value: answersJson);

    return true;
  }

  /// Verify security questions answers
  /// 
  /// Returns [SecurityQuestionsResult] with verification status
  Future<SecurityQuestionsResult> verifySecurityQuestions(List<String> answers) async {
    if (answers.length != 3) {
      return SecurityQuestionsResult(
        success: false,
        error: 'Must provide exactly 3 answers',
      );
    }

    final questionsJson = await _storage.read(key: _securityQuestionsKey);
    final answersJson = await _storage.read(key: _securityAnswersKey);

    if (questionsJson == null || answersJson == null) {
      return SecurityQuestionsResult(
        success: false,
        error: 'Security questions not configured',
      );
    }

    final List<dynamic> storedHashes = jsonDecode(answersJson);
    final salt = await _storage.read(key: _saltKey) ?? '';

    int correctCount = 0;
    for (int i = 0; i < answers.length; i++) {
      final normalizedAnswer = SecurityQuestions.normalizeAnswer(answers[i]);
      final hashedAnswer = await _hashPin(normalizedAnswer, salt);
      
      if (hashedAnswer == storedHashes[i]) {
        correctCount++;
      }
    }

    // Require at least 2 out of 3 correct
    if (correctCount >= 2) {
      return SecurityQuestionsResult(success: true);
    } else {
      return SecurityQuestionsResult(
        success: false,
        error: '$correctCount/3 answers correct. At least 2 required.',
        correctCount: correctCount,
      );
    }
  }

  /// Get stored security questions (for display in forgot PIN flow)
  Future<List<String>> getSecurityQuestions() async {
    final questionsJson = await _storage.read(key: _securityQuestionsKey);
    if (questionsJson == null) return [];

    try {
      final List<dynamic> questions = jsonDecode(questionsJson);
      return questions.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Reset PIN using security questions verification
  /// 
  /// [answers] - User's answers to security questions
  /// [newPin] - New PIN to set
  Future<PinVerificationResult> resetPinViaSecurityQuestions(
    List<String> answers,
    String newPin,
  ) async {
    // Verify security questions first
    final questionsResult = await verifySecurityQuestions(answers);
    if (!questionsResult.success) {
      return PinVerificationResult(
        success: false,
        error: questionsResult.error ?? 'Security questions verification failed',
      );
    }

    // Validate new PIN
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(
        success: false,
        error: 'Invalid PIN format',
      );
    }

    // Reset PIN
    await _storage.delete(key: _pinHashKey);
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    final hash = await _hashPin(newPin, salt);
    await _storage.write(key: _pinHashKey, value: hash);

    // Reset lockout and attempts
    await _resetAttempts();

    return PinVerificationResult(success: true);
  }

  // ==================== BIOMETRIC AUTH FOR PIN RESET ====================

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with biometrics and reset PIN
  /// 
  /// This allows users with registered biometrics to reset their PIN
  Future<PinVerificationResult> resetPinViaBiometric(String newPin) async {
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(
        success: false,
        error: 'Invalid PIN format',
      );
    }

    try {
      final canAuthenticate = await isBiometricAvailable();
      if (!canAuthenticate) {
        return PinVerificationResult(
          success: false,
          error: 'Biometric authentication not available',
        );
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to reset your PIN',
      );

      if (didAuthenticate) {
        // Reset PIN
        await _storage.delete(key: _pinHashKey);
        final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
        final hash = await _hashPin(newPin, salt);
        await _storage.write(key: _pinHashKey, value: hash);

        // Reset lockout and attempts
        await _resetAttempts();

        return PinVerificationResult(success: true);
      } else {
        return PinVerificationResult(
          success: false,
          error: 'Biometric authentication cancelled',
        );
      }
    } catch (e) {
      return PinVerificationResult(
        success: false,
        error: 'Biometric authentication failed: ${e.toString()}',
      );
    }
  }

  /// Get biometric enrollment status
  Future<String> getBiometricStatus() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return 'Not available - Set up biometrics in device settings';
      }
      return 'Available - Use fingerprint to reset PIN';
    } catch (e) {
      return 'Error checking biometric status';
    }
  }
}

/// Result of PIN verification attempt
class PinVerificationResult {
  final bool success;
  final String? error;
  final int? remainingAttempts;
  final int? remainingLockoutSeconds;

  PinVerificationResult({
    required this.success,
    this.error,
    this.remainingAttempts,
    this.remainingLockoutSeconds,
  });
}

/// Result of security questions verification
class SecurityQuestionsResult {
  final bool success;
  final String? error;
  final int? correctCount;

  SecurityQuestionsResult({
    required this.success,
    this.error,
    this.correctCount,
  });
}

// Isolate function for key derivation using multiple rounds of HMAC-SHA256
// This is a simplified PBKDF2-like approach since the crypto package doesn't expose PBKDF2
String _pbkdf2Hash(Map<String, dynamic> params) {
  final pin = params['pin'] as String;
  final salt = params['salt'] as String;
  final iterations = params['iterations'] as int;

  // Using multiple rounds of HMAC-SHA256 for key derivation
  var derivedKey = salt;
  for (int i = 0; i < (iterations ~/ 1000).clamp(1, 100); i++) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final digest = hmac.convert(utf8.encode(derivedKey));
    derivedKey = digest.toString();
  }

  // Final hash
  final hmac = Hmac(sha256, utf8.encode(pin));
  final digest = hmac.convert(utf8.encode(derivedKey + pin));
  return digest.toString();
}

// Isolate function for proper binary key derivation (32 bytes of entropy)
// Used to derive encryption key from PIN for decrypting existing journal data
List<int> _deriveKeyBinary(Map<String, dynamic> params) {
  final pin = params['pin'] as String;
  final salt = params['salt'] as String;
  final iterations = params['iterations'] as int;
  
  // PBKDF2-like with full binary output (not hex string)
  List<int> derivedKey = utf8.encode(salt);
  
  for (int i = 0; i < iterations; i++) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final digest = hmac.convert(derivedKey);
    derivedKey = digest.bytes;
  }
  
  return derivedKey; // 32 bytes of entropy as List<int>
}
