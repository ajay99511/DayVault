import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../config/security_questions.dart';
import 'credential_gate.dart';
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

  /// Attempt counting and escalating lockout — the same implementation the
  /// app-lock PIN uses, namespaced so the two credentials' counters are
  /// completely independent.
  late final CredentialGate _gate = CredentialGate(
    storage: _storage,
    credentialLabel: 'passcode',
    namespace: 'vault_',
  );

  // Namespaced storage keys — must never overlap with SecurityService keys.
  static const String _pinHashKey = 'vault_pin_hash';
  static const String _saltKey = 'vault_salt';
  static const String _securityQuestionsKey = 'vault_security_questions';
  static const String _securityAnswersKey = 'vault_security_answers';

  /// Dedicated salt for recovery-answer hashes, so rotating the passcode salt
  /// can never invalidate recovery. Installs predating this key keep verifying
  /// under the old shared-salt scheme — see [verifySecurityQuestions].
  static const String _securityAnswersSaltKey = 'vault_security_answers_salt';

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
    final gate = await _gate.check();
    if (!gate.allowed) return _toPinResult(gate);

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

    if (SecurityService.constantTimeEquals(inputHash, storedHash)) {
      await _gate.recordSuccess();
      return PinVerificationResult(success: true);
    }
    return _toPinResult(await _gate.recordFailure());
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
    await _storage.delete(key: _securityAnswersSaltKey);
    await _gate.recordSuccess();
    return PinVerificationResult(success: true);
  }

  /// Adapt a [GateDecision] to the shared result type.
  static PinVerificationResult _toPinResult(GateDecision decision) =>
      PinVerificationResult(
        success: decision.allowed,
        error: decision.error,
        remainingAttempts: decision.remainingAttempts,
        remainingLockoutSeconds: decision.remainingLockoutSeconds,
      );

  /// Attempts left before the next lockout.
  Future<int> getRemainingAttempts() => _gate.remainingAttempts();

  /// Whether a lockout is currently in force.
  Future<bool> isLockedOut() => _gate.isLockedOut();

  Future<void> _writeNewPasscode(String newPin) async {
    await _storage.delete(key: _pinHashKey);
    final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    final hash = await _hash(newPin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  // ─── Security questions (forgot-passcode recovery) ────────────────────────

  Future<bool> areSecurityQuestionsSet() async {
    final questions = await _storage.read(key: _securityQuestionsKey);
    return questions != null && questions.isNotEmpty;
  }

  Future<bool> setSecurityQuestions(
      List<String> questions, List<String> answers) async {
    if (questions.length != 3 || answers.length != 3) return false;

    final answersSalt = _generateSalt();
    final hashedAnswers = <String>[];
    for (var i = 0; i < answers.length; i++) {
      hashedAnswers.add(await _hashAnswerAt(answers[i], answersSalt, i));
    }

    await _storage.write(key: _securityAnswersSaltKey, value: answersSalt);
    await _storage.write(
        key: _securityQuestionsKey, value: jsonEncode(questions));
    await _storage.write(
        key: _securityAnswersKey, value: jsonEncode(hashedAnswers));
    return true;
  }

  /// Hash the answer at [index] under a per-index salt derived from
  /// [answersSalt], so two identical answers do not hash identically.
  Future<String> _hashAnswerAt(String answer, String answersSalt, int index) =>
      _hash(SecurityQuestions.normalizeAnswer(answer), '$answersSalt:$index');

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
    // Recovery shares the passcode's lockout budget. Without this it was an
    // unlimited-attempt path *around* the vault lockout — the same hole that
    // existed in SecurityService, present here because this state machine was
    // copy-pasted rather than shared.
    final gate = await _gate.check();
    if (!gate.allowed) {
      return SecurityQuestionsResult(success: false, error: gate.error);
    }

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
    final answersSalt = await _storage.read(key: _securityAnswersSaltKey);
    final legacySalt = await _storage.read(key: _saltKey) ?? '';

    int correctCount = 0;
    for (int i = 0; i < answers.length && i < storedHashes.length; i++) {
      final hashed = answersSalt == null
          // Install predating the dedicated answers salt.
          ? await _hash(
              SecurityQuestions.normalizeAnswer(answers[i]), legacySalt)
          : await _hashAnswerAt(answers[i], answersSalt, i);

      if (SecurityService.constantTimeEquals(hashed, storedHashes[i] as String)) {
        correctCount++;
      }
    }

    if (correctCount >= 2) {
      await _gate.recordSuccess();
      return SecurityQuestionsResult(success: true);
    }

    await _gate.recordFailure();
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
    await _gate.recordSuccess();
    return PinVerificationResult(success: true);
  }

  /// Every key this service may write, including the ones its [CredentialGate]
  /// owns. Kept exhaustive so the "removePasscode clears all vault keys" test
  /// fails loudly whenever a new key is added without a matching cleanup —
  /// which is exactly how it caught [_securityAnswersSaltKey].
  @visibleForTesting
  List<String> get storageKeysForTesting => [
        _pinHashKey,
        _saltKey,
        _securityQuestionsKey,
        _securityAnswersKey,
        _securityAnswersSaltKey,
        ..._gate.storageKeys,
      ];
}
