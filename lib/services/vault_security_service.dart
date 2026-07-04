import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../config/security_questions.dart';
import 'pbkdf2.dart';
import 'security_service.dart'
    show
        PinVerificationResult,
        SecurityQuestionsResult,
        SecurityService;

final vaultSecurityServiceProvider = Provider<VaultSecurityService>((ref) {
  return VaultSecurityService();
});

/// Passcode gate for the Privacy Vault — a second, independent passcode from
/// the app-lock PIN in [SecurityService].
///
/// Deliberately much slimmer than [SecurityService]: the vault only ever
/// verifies a passcode hash (single PBKDF2 pass — no encryption-key
/// derivation, no biometrics, no legacy-hash migration). All secure-storage
/// keys are namespaced with `vault_` so the two credential sets can never
/// collide.
class VaultSecurityService {
  VaultSecurityService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const int _maxAttempts = SecurityConstants.maxAttempts;

  // Namespaced storage keys — must never overlap with SecurityService keys.
  static const String _pinHashKey = 'vault_pin_hash';
  static const String _saltKey = 'vault_salt';
  static const String _attemptCountKey = 'vault_attempt_count';
  static const String _lockoutUntilKey = 'vault_lockout_until';
  static const String _lockoutCycleCountKey = 'vault_lockout_cycle_count';
  static const String _securityQuestionsKey = 'vault_security_questions';
  static const String _securityAnswersKey = 'vault_security_answers';

  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  Future<String> _hash(String value, String salt) async {
    final keyBytes = await compute(pbkdf2Derive, {
      'pin': value,
      'salt': salt,
      'iterations': 100000,
      'keyLength': 32,
    });
    return base64Encode(keyBytes);
  }

  bool _isValidPasscode(String pin) {
    return RegExp('^\\d{${SecurityConstants.pinLength}}\$').hasMatch(pin);
  }

  // ─── Passcode lifecycle ───────────────────────────────────────────────────

  Future<bool> isPasscodeSet() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set the vault passcode for the first time. Fails if one already exists.
  Future<bool> setPasscode(String pin) async {
    if (!_isValidPasscode(pin)) return false;
    if (await isPasscodeSet()) return false;

    final salt = _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    final hash = await _hash(pin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
    return true;
  }

  /// Verify the vault passcode with rate limiting and escalating lockout.
  Future<PinVerificationResult> verifyPasscode(String pin) async {
    final lockoutResult = await _checkLockout();
    if (!lockoutResult.success) return lockoutResult;

    if (!_isValidPasscode(pin)) {
      return PinVerificationResult(
          success: false, error: 'Invalid passcode format');
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) {
      return PinVerificationResult(
          success: false, error: 'No vault passcode configured');
    }

    final salt = await _storage.read(key: _saltKey) ?? '';
    final inputHash = await _hash(pin, salt);

    if (inputHash == storedHash) {
      await _resetAttempts(clearBackoff: true);
      return PinVerificationResult(success: true);
    }
    return _handleFailedAttempt();
  }

  /// Change the vault passcode (requires the current one).
  Future<PinVerificationResult> changePasscode(
      String oldPin, String newPin) async {
    if (!_isValidPasscode(newPin)) {
      return PinVerificationResult(
        success: false,
        error:
            'New passcode must be exactly ${SecurityConstants.pinLength} digits',
      );
    }

    final verifyResult = await verifyPasscode(oldPin);
    if (!verifyResult.success) return verifyResult;

    await _writeNewPasscode(newPin);
    return PinVerificationResult(success: true);
  }

  /// Remove the vault passcode and all vault security data (requires the
  /// current passcode). The caller is responsible for un-vaulting any private
  /// entries first — never leave isPrivate rows behind with no vault.
  Future<PinVerificationResult> removePasscode(String pin) async {
    final verifyResult = await verifyPasscode(pin);
    if (!verifyResult.success) return verifyResult;

    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _securityQuestionsKey);
    await _storage.delete(key: _securityAnswersKey);
    await _resetAttempts(clearBackoff: true);
    return PinVerificationResult(success: true);
  }

  Future<void> _writeNewPasscode(String newPin) async {
    await _storage.delete(key: _pinHashKey);
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    final hash = await _hash(newPin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  // ─── Rate limiting (mirrors SecurityService semantics) ────────────────────

  Future<PinVerificationResult> _checkLockout() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) return PinVerificationResult(success: true);

    final lockoutUntil =
        DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutUntilStr));

    if (DateTime.now().isBefore(lockoutUntil)) {
      final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
      return PinVerificationResult(
        success: false,
        error: 'Too many attempts. Try again in $remaining seconds.',
        remainingLockoutSeconds: remaining,
      );
    }

    // Lockout expired — clear it but keep the escalation cycle count so
    // repeated lockouts keep getting longer until a successful unlock.
    await _storage.delete(key: _lockoutUntilKey);
    await _resetAttempts();
    return PinVerificationResult(success: true);
  }

  Future<PinVerificationResult> _handleFailedAttempt() async {
    final attemptsStr = await _storage.read(key: _attemptCountKey) ?? '0';
    final attempts = int.parse(attemptsStr) + 1;
    await _storage.write(key: _attemptCountKey, value: attempts.toString());

    final remainingAttempts = _maxAttempts - attempts;

    if (remainingAttempts <= 0) {
      final cycleStr = await _storage.read(key: _lockoutCycleCountKey) ?? '0';
      final cycle = (int.tryParse(cycleStr) ?? 0) + 1;
      await _storage.write(
          key: _lockoutCycleCountKey, value: cycle.toString());

      final lockoutSeconds =
          SecurityService.computeLockoutDurationSeconds(cycle);
      final lockoutUntil =
          DateTime.now().add(Duration(seconds: lockoutSeconds));
      await _storage.write(
        key: _lockoutUntilKey,
        value: lockoutUntil.millisecondsSinceEpoch.toString(),
      );
      await _storage.delete(key: _attemptCountKey);

      return PinVerificationResult(
        success: false,
        error: 'Too many failed attempts. Locked for $lockoutSeconds seconds.',
        remainingLockoutSeconds: lockoutSeconds,
      );
    }

    return PinVerificationResult(
      success: false,
      error: 'Incorrect passcode. $remainingAttempts attempts remaining.',
      remainingAttempts: remainingAttempts,
    );
  }

  Future<void> _resetAttempts({bool clearBackoff = false}) async {
    await _storage.delete(key: _attemptCountKey);
    await _storage.delete(key: _lockoutUntilKey);
    if (clearBackoff) {
      await _storage.delete(key: _lockoutCycleCountKey);
    }
  }

  Future<int> getRemainingAttempts() async {
    final attemptsStr = await _storage.read(key: _attemptCountKey) ?? '0';
    final attempts = int.parse(attemptsStr);
    return (_maxAttempts - attempts).clamp(0, _maxAttempts);
  }

  Future<bool> isLockedOut() async {
    final result = await _checkLockout();
    return !result.success && result.remainingLockoutSeconds != null;
  }

  // ─── Security questions (forgot-passcode recovery) ────────────────────────

  Future<bool> areSecurityQuestionsSet() async {
    final questions = await _storage.read(key: _securityQuestionsKey);
    return questions != null && questions.isNotEmpty;
  }

  Future<bool> setSecurityQuestions(
      List<String> questions, List<String> answers) async {
    if (questions.length != 3 || answers.length != 3) return false;

    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    await _storage.write(key: _saltKey, value: salt);

    final hashedAnswers = <String>[];
    for (final answer in answers) {
      final normalized = SecurityQuestions.normalizeAnswer(answer);
      hashedAnswers.add(await _hash(normalized, salt));
    }

    await _storage.write(
        key: _securityQuestionsKey, value: jsonEncode(questions));
    await _storage.write(
        key: _securityAnswersKey, value: jsonEncode(hashedAnswers));
    return true;
  }

  Future<List<String>> getSecurityQuestions() async {
    final questionsJson = await _storage.read(key: _securityQuestionsKey);
    if (questionsJson == null) return [];
    try {
      return (jsonDecode(questionsJson) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Verify recovery answers — at least 2 of 3 must match.
  Future<SecurityQuestionsResult> verifySecurityQuestions(
      List<String> answers) async {
    if (answers.length != 3) {
      return SecurityQuestionsResult(
          success: false, error: 'Must provide exactly 3 answers');
    }

    final questionsJson = await _storage.read(key: _securityQuestionsKey);
    final answersJson = await _storage.read(key: _securityAnswersKey);
    if (questionsJson == null || answersJson == null) {
      return SecurityQuestionsResult(
          success: false, error: 'Recovery questions not configured');
    }

    final List<dynamic> storedHashes = jsonDecode(answersJson);
    final salt = await _storage.read(key: _saltKey) ?? '';

    int correctCount = 0;
    for (int i = 0; i < answers.length; i++) {
      final normalized = SecurityQuestions.normalizeAnswer(answers[i]);
      if (await _hash(normalized, salt) == storedHashes[i]) {
        correctCount++;
      }
    }

    if (correctCount >= 2) return SecurityQuestionsResult(success: true);
    return SecurityQuestionsResult(
      success: false,
      error: '$correctCount/3 answers correct. At least 2 required.',
      correctCount: correctCount,
    );
  }

  /// Reset the passcode after successful recovery verification. Never touches
  /// journal entries — only the credential.
  Future<PinVerificationResult> resetPasscodeViaSecurityQuestions(
      List<String> answers, String newPin) async {
    final questionsResult = await verifySecurityQuestions(answers);
    if (!questionsResult.success) {
      return PinVerificationResult(
        success: false,
        error: questionsResult.error ?? 'Recovery verification failed',
      );
    }

    if (!_isValidPasscode(newPin)) {
      return PinVerificationResult(
          success: false, error: 'Invalid passcode format');
    }

    await _writeNewPasscode(newPin);
    await _resetAttempts(clearBackoff: true);
    return PinVerificationResult(success: true);
  }

  @visibleForTesting
  static const List<String> storageKeysForTesting = [
    _pinHashKey,
    _saltKey,
    _attemptCountKey,
    _lockoutUntilKey,
    _lockoutCycleCountKey,
    _securityQuestionsKey,
    _securityAnswersKey,
  ];
}
