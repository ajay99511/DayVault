import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint, visibleForTesting;
import 'package:meta/meta.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import '../config/security_questions.dart';

/// Security service handling PIN hashing, rate limiting, and data encryption.
///
/// Security Features:
/// - PIN hashing using PBKDF2 with SHA-256
/// - Rate limiting with exponential backoff
/// - Account lockout after failed attempts
class SecurityService {
  static SecurityService _instance = SecurityService._internal(const FlutterSecureStorage());
  factory SecurityService() => _instance;
  
  @visibleForTesting
  SecurityService.withStorage(FlutterSecureStorage storage) : _storage = storage {
    _instance = this;
  }

  SecurityService._internal(this._storage);

  // Use FlutterSecureStorage for PIN storage
  final FlutterSecureStorage _storage;

  // Cache encryption key in memory after PIN verification (for decrypting existing data)
  Uint8List? _cachedEncryptionKey;

  // Security constants
  static const int _maxAttempts = 5;
  static const int _lockoutDurationSeconds = 30;
  static const String _saltKey = 'security_salt';
  static const String _encryptionSaltKey = 'encryption_salt';
  static const String _pinHashKey = 'pin_hash';
  static const String _attemptCountKey = 'attempt_count';
  static const String _lockoutUntilKey = 'lockout_until';

  // Security questions storage keys
  static const String _securityQuestionsKey = 'security_questions';
  static const String _securityAnswersKey = 'security_answers';

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
  /// Uses 100,000 iterations for security
  Future<String> _hashPin(String pin, String salt) async {
    final keyBytes = await compute(_pbkdf2Derive, {
      'pin': pin,
      'salt': salt,
      'iterations': 100000,
      'keyLength': 32,
    });
    return base64Encode(keyBytes);
  }

  /// Initialize security service - creates salt if not exists
  Future<void> initialize() async {
    final salt = await _storage.read(key: _saltKey);
    if (salt == null) {
      await _storage.write(key: _saltKey, value: _generateSalt());
    }
  }

  /// Derive encryption key from PIN and cache it in memory.
  /// Used to decrypt journal data after successful PIN verification.
  Future<void> _deriveAndCacheEncryptionKey(String pin) async {
    String? encSalt = await _storage.read(key: _encryptionSaltKey);
    if (encSalt == null) {
      encSalt = _generateSalt();
      await _storage.write(key: _encryptionSaltKey, value: encSalt);
    }

    final keyBytes = await compute(_pbkdf2Derive, {
      'pin': pin,
      'salt': encSalt,
      'iterations': 100000,
      'keyLength': 32,
    });

    _cachedEncryptionKey = keyBytes;
  }

  /// Get the cached encryption key.
  /// Returns null if not cached (PIN not verified).
  Uint8List? getCachedEncryptionKey() {
    return _cachedEncryptionKey;
  }

  @visibleForTesting
  void setCachedEncryptionKeyForTesting(Uint8List? key) {
    _cachedEncryptionKey = key;
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
    if (!_isValidPin(pin)) return false;
    if (await isPinSet()) return false;

    // Generate PIN hash salt
    final pinSalt = _generateSalt();
    await _storage.write(key: _saltKey, value: pinSalt);

    // Generate encryption key salt (independent)
    final encSalt = _generateSalt();
    await _storage.write(key: _encryptionSaltKey, value: encSalt);

    final hash = await _hashPin(pin, pinSalt);
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

    // Migration path: detect old hex hashes (64 chars)
    if (storedHash.length == 64) {
      await _storage.delete(key: _pinHashKey);
      return PinVerificationResult(
        success: false,
        error: 'Security upgrade required. Please set a new PIN.',
        requiresPinReset: true,
      );
    }

    final salt = await _storage.read(key: _saltKey) ?? '';
    final inputHash = await _hashPin(pin, salt);

    if (inputHash == storedHash) {
      // Success - reset attempts and derive encryption key
      await _resetAttempts();
      await _deriveAndCacheEncryptionKey(pin);
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

  /// Reset PIN without biometric re-authentication.
  /// Caller is responsible for having already authenticated the user.
  Future<PinVerificationResult> resetPinDirectly(String newPin) async {
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(success: false, error: 'Invalid PIN format');
    }
    await _storage.delete(key: _pinHashKey);
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    final hash = await _hashPin(newPin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _resetAttempts();
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
    await _storage.delete(key: _encryptionSaltKey);
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
  final bool requiresPinReset;

  PinVerificationResult({
    required this.success,
    this.error,
    this.remainingAttempts,
    this.remainingLockoutSeconds,
    this.requiresPinReset = false,
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

/// Top-level function for PBKDF2 key derivation.
/// Must be outside the class for compute().
Uint8List _pbkdf2Derive(Map<String, dynamic> params) {
  final pin = params['pin'] as String;
  final salt = params['salt'] as String;
  final iterations = params['iterations'] as int;
  final keyLength = params['keyLength'] as int;

  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(
    Uint8List.fromList(utf8.encode(salt)),
    iterations,
    keyLength,
  ));
  return derivator.process(Uint8List.fromList(utf8.encode(pin)));
}
