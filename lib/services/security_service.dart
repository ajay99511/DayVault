import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'
    show compute, debugPrint, visibleForTesting;
import 'package:local_auth/local_auth.dart';
import '../config/security_questions.dart';
import '../config/constants.dart';
import 'pbkdf2.dart';

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
  static const int _maxAttempts = SecurityConstants.maxAttempts;
  static const String _saltKey = 'security_salt';

  /// Salt for the PIN-derived *key-encryption key* (KEK). Named for the role it
  /// played before envelope encryption; kept as-is so existing installs keep
  /// deriving the same value and their data stays readable.
  static const String _encryptionSaltKey = 'encryption_salt';
  static const String _pinHashKey = 'pin_hash';
  static const String _attemptCountKey = 'attempt_count';
  static const String _lockoutUntilKey = 'lockout_until';
  static const String _lockoutCycleCountKey = 'lockout_cycle_count';

  /// The data-encryption key (DEK), sealed under the PIN-derived KEK.
  ///
  /// Envelope encryption exists so a PIN change is a 32-byte re-wrap instead of
  /// a re-encryption of every draft and backup. Before this, the key that
  /// encrypted data *was* PBKDF2(pin, encryptionSalt), so changing the PIN
  /// silently changed the key and orphaned everything encrypted under the old
  /// one — with no warning and no way back.
  static const String _wrappedDekKey = 'wrapped_dek';

  /// Dedicated salt for security-answer hashes.
  ///
  /// Answers used to be hashed with [_saltKey] — the PIN salt — which coupled
  /// recovery to the PIN credential and meant two identical answers produced
  /// identical stored hashes. Installs predating this key keep verifying under
  /// the old scheme (see [_hashAnswerAt]) so nobody is locked out of recovery.
  static const String _securityAnswersSaltKey = 'security_answers_salt';

  /// AES-256 key length in bytes.
  static const int _keyLengthBytes = 32;

  /// IV length used when sealing the DEK. Matches [EncryptionService]'s layout.
  static const int _wrapIvLengthBytes = 16;

  /// Exponential backoff lockout duration for a given (1-based) lockout
  /// [cycleCount]: base * 2^(cycle-1), clamped to
  /// [SecurityConstants.maxLockoutDurationSeconds].
  ///
  /// Cycle 1 returns the base duration, preserving the previous fixed-lockout
  /// behavior for a first offense. Pure; shared with [VaultSecurityService]
  /// so both credential gates escalate identically.
  static int computeLockoutDurationSeconds(int cycleCount) {
    if (cycleCount <= 1) return SecurityConstants.lockoutDurationSeconds;
    final exponent = cycleCount - 1;
    // Guard the shift against overflow / runaway growth before computing.
    if (exponent >= 20) return SecurityConstants.maxLockoutDurationSeconds;
    final scaled = SecurityConstants.lockoutDurationSeconds * (1 << exponent);
    return scaled > SecurityConstants.maxLockoutDurationSeconds
        ? SecurityConstants.maxLockoutDurationSeconds
        : scaled;
  }

  // Security questions storage keys
  static const String _securityQuestionsKey = 'security_questions';
  static const String _securityAnswersKey = 'security_answers';

  // Crash-recovery guard for PIN change re-key operation
  static const String _rekeyPendingKey = 'rekey_pending';

  // Biometric authentication
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Get the overall status of the security vault
  Future<SecurityVaultStatus> getVaultStatus(bool settingsEnabled) async {
    final pinSet = await isPinSet();
    return SecurityVaultStatus(
      isConfigured: pinSet,
      isEnabled: settingsEnabled,
      isUnlocked: _cachedEncryptionKey != null,
    );
  }

  /// Clear the encryption key from memory
  void lockVault() {
    _cachedEncryptionKey = null;
  }

  /// Generate a random salt for PIN hashing
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Cryptographically secure random bytes, for key material.
  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256 derivation on a background isolate.
  Future<Uint8List> _deriveKey(String secret, String salt) => compute(
        pbkdf2Derive,
        {
          'pin': secret,
          'salt': salt,
          'iterations': 100000,
          'keyLength': _keyLengthBytes,
        },
      );

  /// Compare two hashes without leaking where they first differ.
  ///
  /// Dart's `==` on String short-circuits at the first differing code unit.
  /// The attack surface is local rather than remote here, but constant-time
  /// comparison of secrets costs nothing and removes the question entirely.
  ///
  /// Shared with [VaultSecurityService] so both credential gates compare the
  /// same way.
  static bool constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    // Fold the length difference into the result instead of returning early.
    var diff = aBytes.length ^ bBytes.length;
    final max = aBytes.length > bBytes.length ? aBytes.length : bBytes.length;
    for (var i = 0; i < max; i++) {
      final x = i < aBytes.length ? aBytes[i] : 0;
      final y = i < bBytes.length ? bBytes[i] : 0;
      diff |= x ^ y;
    }
    return diff == 0;
  }

  /// Seal [dek] under [kek] with AES-256-GCM.
  /// Layout: base64([16-byte IV][ciphertext + GCM tag]).
  static String _wrapKey(Uint8List dek, Uint8List kek) {
    final iv = encrypt_lib.IV.fromSecureRandom(_wrapIvLengthBytes);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(encrypt_lib.Key(kek), mode: encrypt_lib.AESMode.gcm),
    );
    final sealed = encrypter.encryptBytes(dek, iv: iv);
    return base64Encode(<int>[...iv.bytes, ...sealed.bytes]);
  }

  /// Open a [_wrapKey] envelope. Throws [StateError] when the GCM tag does not
  /// verify — that means the stored key material is corrupt, and silently
  /// continuing would hand callers a garbage key that encrypts unreadable data.
  static Uint8List _unwrapKey(String wrapped, Uint8List kek) {
    try {
      final raw = base64Decode(wrapped);
      if (raw.length <= _wrapIvLengthBytes) {
        throw const FormatException('wrapped key too short');
      }
      final iv = encrypt_lib.IV(
        Uint8List.fromList(raw.sublist(0, _wrapIvLengthBytes)),
      );
      final body = Uint8List.fromList(raw.sublist(_wrapIvLengthBytes));
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(encrypt_lib.Key(kek), mode: encrypt_lib.AESMode.gcm),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(encrypt_lib.Encrypted(body), iv: iv),
      );
    } catch (e) {
      throw StateError('Stored encryption key could not be opened: $e');
    }
  }

  /// Hash PIN using PBKDF2 with SHA-256
  ///
  /// Uses 100,000 iterations for security
  Future<String> _hashPin(String pin, String salt) async =>
      base64Encode(await _deriveKey(pin, salt));

  /// Initialize security service - creates salt if not exists
  Future<void> initialize() async {
    final salt = await _storage.read(key: _saltKey);
    if (salt == null) {
      await _storage.write(key: _saltKey, value: _generateSalt());
    }
    // A PIN change interrupted by process death must be finished before any
    // verification runs, or the stored hash and the wrapped key can disagree
    // and the vault becomes unopenable.
    await _completeInterruptedRekey();
  }

  /// Write a new (PIN hash, wrapped DEK) pair.
  ///
  /// The envelope is written first: if the process dies between the two, the
  /// old PIN still verifies and its KEK still opens the *old* envelope, so the
  /// user is never locked out — and [_completeInterruptedRekey] finishes the
  /// job on the next launch.
  Future<void> _applyRekey(String pinHash, String wrappedDek) async {
    await _storage.write(key: _wrappedDekKey, value: wrappedDek);
    await _storage.write(key: _pinHashKey, value: pinHash);
  }

  /// Finish a PIN change that was interrupted by process death.
  ///
  /// Rolls *forward*: the journal holds a self-consistent (hash, wrapped DEK)
  /// pair, so replaying it lands on the new PIN with the same DEK. Rolling back
  /// is impossible — the old values are deliberately not retained — and also
  /// unnecessary, because the DEK is identical either way, so no user data is
  /// at risk in either direction. Replaying a record that already applied
  /// writes the same bytes, so this is idempotent.
  Future<void> _completeInterruptedRekey() async {
    final pending = await _storage.read(key: _rekeyPendingKey);
    if (pending == null || pending.isEmpty) return;

    try {
      final record = jsonDecode(pending) as Map<String, dynamic>;
      final hash = record['hash'] as String?;
      final wrappedDek = record['wrappedDek'] as String?;
      if (hash != null && wrappedDek != null) {
        await _applyRekey(hash, wrappedDek);
      }
    } on FormatException catch (e) {
      // An unparseable journal cannot be replayed. The credentials on disk are
      // still internally consistent, so leave them alone and drop the record
      // rather than retrying it on every launch forever.
      debugPrint('Discarding unreadable re-key journal: $e');
    }
    await _storage.delete(key: _rekeyPendingKey);
  }

  /// Return the data-encryption key, creating the envelope on first use.
  ///
  /// Installs predating envelope encryption have no wrapped DEK, and for them
  /// the key already protecting their drafts and encrypted backups *is* the
  /// PIN-derived [kek]. Adopting that exact value as the DEK — rather than
  /// generating a fresh one — is what makes this migration lossless: nothing is
  /// re-encrypted, every existing artefact stays readable, and from here on a
  /// PIN change only re-wraps this key instead of replacing it.
  Future<Uint8List> _openOrAdoptDek(Uint8List kek) async {
    final wrapped = await _storage.read(key: _wrappedDekKey);
    if (wrapped != null && wrapped.isNotEmpty) {
      return _unwrapKey(wrapped, kek);
    }
    await _storage.write(key: _wrappedDekKey, value: _wrapKey(kek, kek));
    return kek;
  }

  /// Read the encryption-key salt, generating and persisting it on first use.
  /// The salt is random and independent of the PIN, so creating it eagerly is
  /// harmless.
  Future<String> _readOrCreateEncryptionSalt() async {
    final existing = await _storage.read(key: _encryptionSaltKey);
    if (existing != null) return existing;
    final encSalt = _generateSalt();
    await _storage.write(key: _encryptionSaltKey, value: encSalt);
    return encSalt;
  }

  /// Get the cached encryption key.
  /// Returns null if not cached (PIN not verified).
  Uint8List? getCachedEncryptionKey() {
    return _cachedEncryptionKey;
  }

  /// Read several secure-storage keys concurrently, returning values in the
  /// same order as [keys].
  ///
  /// Equivalent in result to reading the keys one-by-one, but issues the I/O in
  /// parallel via [Future.wait]. As with any [Future.wait], if any read throws,
  /// the returned future completes with that error.
  @visibleForTesting
  Future<List<String?>> readKeysInParallel(List<String> keys) {
    return Future.wait(keys.map((k) => _storage.read(key: k)));
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

    // Fresh install: the DEK is random and never derived, so it is independent
    // of the PIN from the very first write and a later PIN change is a re-wrap.
    final kek = await _deriveKey(pin, encSalt);
    await _storage.write(
      key: _wrappedDekKey,
      value: _wrapKey(_randomBytes(_keyLengthBytes), kek),
    );
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

    // The PIN hash and salt are independent reads — fetch them concurrently.
    // (Ordering vs. _checkLockout above is preserved: the lockout gate, which
    // has side effects, still runs first.)
    final reads = await readKeysInParallel([_pinHashKey, _saltKey]);
    final storedHash = reads[0];
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

    final salt = reads[1] ?? '';
    final encSalt = await _readOrCreateEncryptionSalt();

    // Verify the PIN and derive the (independent) data-encryption key in
    // parallel. They use different salts and don't depend on each other, so on
    // the common correct-PIN path this collapses two sequential ~100k-iteration
    // PBKDF2 passes — the dominant cost of unlocking — into roughly one,
    // noticeably tightening the unlock latency. On a wrong PIN the
    // speculatively derived key is simply discarded.
    final derived = await Future.wait([
      _deriveKey(pin, salt),
      _deriveKey(pin, encSalt),
    ]);
    final inputHash = base64Encode(derived[0]);
    final kek = derived[1];

    if (!constantTimeEquals(inputHash, storedHash)) {
      return await _handleFailedAttempt();
    }

    // Correct PIN. Open the envelope (or adopt one, for installs predating it)
    // before clearing the failure state, so a corrupt key store surfaces as an
    // error instead of a silent half-unlock with no usable key.
    _cachedEncryptionKey = await _openOrAdoptDek(kek);
    await _resetAttempts(clearBackoff: true);
    return PinVerificationResult(success: true);
  }

  /// Check if device is locked out
  Future<PinVerificationResult> _checkLockout() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) {
      return PinVerificationResult(success: true);
    }

    // Stored values are parsed defensively: an unparseable lockout stamp used
    // to throw straight out of verifyPin, which fails *open* by aborting the
    // check entirely. Treat corruption as "no active lockout" only after
    // clearing the bad value, so the counter starts from a known state.
    final lockoutMillis = int.tryParse(lockoutUntilStr);
    if (lockoutMillis == null) {
      await _storage.delete(key: _lockoutUntilKey);
      return PinVerificationResult(success: true);
    }

    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);

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
    // A corrupt counter must not crash the failure path — that would let an
    // attacker disable attempt counting by corrupting one value.
    final attempts = (int.tryParse(attemptsStr) ?? 0) + 1;

    await _storage.write(key: _attemptCountKey, value: attempts.toString());

    final remainingAttempts = _maxAttempts - attempts;

    if (remainingAttempts <= 0) {
      // Escalating lockout — bump the persisted cycle count so each successive
      // lockout (within the same failure streak) lasts longer. The cycle count
      // survives lockout expiry and is only cleared on a successful unlock.
      final cycleStr = await _storage.read(key: _lockoutCycleCountKey) ?? '0';
      final cycle = (int.tryParse(cycleStr) ?? 0) + 1;
      await _storage.write(key: _lockoutCycleCountKey, value: cycle.toString());

      final lockoutSeconds = computeLockoutDurationSeconds(cycle);
      final lockoutUntil = DateTime.now().add(
        Duration(seconds: lockoutSeconds),
      );
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
      error: 'Incorrect PIN. $remainingAttempts attempts remaining.',
      remainingAttempts: remainingAttempts,
    );
  }

  /// Reset failed attempt counter (and the active lockout).
  ///
  /// [clearBackoff] additionally resets the escalating lockout cycle count;
  /// pass `true` only when the user has successfully proven identity (correct
  /// PIN, biometric/security-question reset, or PIN removal). It must stay
  /// `false` on mere lockout expiry so repeated lock cycles keep escalating.
  Future<void> _resetAttempts({bool clearBackoff = false}) async {
    await _storage.delete(key: _attemptCountKey);
    await _storage.delete(key: _lockoutUntilKey);
    if (clearBackoff) {
      await _storage.delete(key: _lockoutCycleCountKey);
    }
  }

  /// Change PIN (requires old PIN verification)
  Future<PinVerificationResult> changePin(String oldPin, String newPin) async {
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(
        success: false,
        error: 'New PIN must be exactly ${SecurityConstants.pinLength} digits',
      );
    }

    // Verify old PIN first. This also unwraps the DEK into the cache.
    final verifyResult = await verifyPin(oldPin);
    if (!verifyResult.success) {
      return verifyResult;
    }

    final dek = _cachedEncryptionKey;
    if (dek == null) {
      return PinVerificationResult(
        success: false,
        error: 'Could not access the encryption key. Please try again.',
      );
    }

    // Both salts stay put. A salt exists to stop cross-account precomputation,
    // not to change per PIN, and rotating the PIN salt here would invalidate
    // the security-answer hashes of installs that still share it.
    final pinSalt = await _storage.read(key: _saltKey) ?? _generateSalt();
    await _storage.write(key: _saltKey, value: pinSalt);
    final encSalt = await _readOrCreateEncryptionSalt();

    final newHash = await _hashPin(newPin, pinSalt);
    final newKek = await _deriveKey(newPin, encSalt);

    // The DEK itself is unchanged — only its wrapping. This is the whole point
    // of the envelope: every draft and every encrypted backup stays readable
    // across a PIN change, where previously the derived key changed underneath
    // them and orphaned the lot without a word.
    final rewrapped = _wrapKey(dek, newKek);

    // Journal before writing. Losing power between the hash write and the
    // envelope write would leave a PIN that cannot open its own key; on the
    // next launch initialize() replays this record instead.
    await _storage.write(
      key: _rekeyPendingKey,
      value: jsonEncode({'hash': newHash, 'wrappedDek': rewrapped}),
    );
    await _applyRekey(newHash, rewrapped);
    await _storage.delete(key: _rekeyPendingKey);

    return PinVerificationResult(success: true);
  }

  /// Set [newPin] after an identity check that did **not** involve the old PIN
  /// (security questions or biometrics).
  ///
  /// Such a reset cannot open the existing envelope: the old KEK died with the
  /// forgotten PIN. The DEK is therefore replaced with a fresh random one so
  /// future encryption works. That loss is inherent to forgetting a PIN rather
  /// than a defect — but it must be *stated*, so the returned flag reports
  /// whether anything was encrypted under the old PIN, letting the caller warn
  /// the user instead of leaving them to discover it later.
  Future<bool> _writeNewPinAfterRecovery(String newPin) async {
    final pinSalt = await _storage.read(key: _saltKey) ?? _generateSalt();
    await _storage.write(key: _saltKey, value: pinSalt);
    final hash = await _hashPin(newPin, pinSalt);

    final hadEncryptedData =
        (await _storage.read(key: _wrappedDekKey))?.isNotEmpty ?? false;

    final encSalt = await _readOrCreateEncryptionSalt();
    final kek = await _deriveKey(newPin, encSalt);
    final freshDek = _randomBytes(_keyLengthBytes);

    await _storage.write(key: _wrappedDekKey, value: _wrapKey(freshDek, kek));
    await _storage.write(key: _pinHashKey, value: hash);
    // Any half-finished change from before the reset is now moot.
    await _storage.delete(key: _rekeyPendingKey);

    _cachedEncryptionKey = freshDek;
    await _resetAttempts(clearBackoff: true);
    return hadEncryptedData;
  }

  /// Reset PIN without biometric re-authentication.
  /// Caller is responsible for having already authenticated the user.
  Future<PinVerificationResult> resetPinDirectly(String newPin) async {
    if (!_isValidPin(newPin)) {
      return PinVerificationResult(success: false, error: 'Invalid PIN format');
    }
    final lostData = await _writeNewPinAfterRecovery(newPin);
    return PinVerificationResult(
      success: true,
      priorEncryptedDataLost: lostData,
    );
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
    // The envelope is meaningless without the salts that derive its KEK, and
    // leaving it behind would strand key material the user asked us to remove.
    await _storage.delete(key: _wrappedDekKey);
    await _storage.delete(key: _rekeyPendingKey);
    _cachedEncryptionKey = null;
    await _resetAttempts(clearBackoff: true);

    return PinVerificationResult(success: true);
  }

  /// Validate PIN format (strict length)
  bool _isValidPin(String pin) {
    return RegExp('^\\d{${SecurityConstants.pinLength}}\$').hasMatch(pin);
  }

  /// Get remaining attempts before lockout
  Future<int> getRemainingAttempts() async {
    final attemptsStr = await _storage.read(key: _attemptCountKey) ?? '0';
    final attempts = int.tryParse(attemptsStr) ?? 0;
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

    // A dedicated salt keeps recovery independent of the PIN credential, so
    // rotating one can never invalidate the other.
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

  /// Hash the answer at [index], deriving a per-index salt from [answersSalt].
  ///
  /// Per-index salting stops two identical answers from producing identical
  /// stored hashes, which previously leaked "these two answers are the same" to
  /// anyone reading the store.
  Future<String> _hashAnswerAt(String answer, String answersSalt, int index) =>
      _hashPin(SecurityQuestions.normalizeAnswer(answer), '$answersSalt:$index');

  /// Verify security questions answers
  /// 
  /// Returns [SecurityQuestionsResult] with verification status
  Future<SecurityQuestionsResult> verifySecurityQuestions(List<String> answers) async {
    // Recovery is a credential path and shares the PIN's lockout budget.
    // Without this gate it was an unlimited-attempt bypass *around* the PIN
    // lockout: two of three low-entropy answers, no counter, and a success then
    // cleared whatever backoff had been accrued on the PIN itself.
    final lockout = await _checkLockout();
    if (!lockout.success) {
      return SecurityQuestionsResult(
        success: false,
        error: lockout.error,
      );
    }

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
    final answersSalt = await _storage.read(key: _securityAnswersSaltKey);
    final legacySalt = await _storage.read(key: _saltKey) ?? '';

    int correctCount = 0;
    for (int i = 0; i < answers.length && i < storedHashes.length; i++) {
      final hashedAnswer = answersSalt == null
          // Install predating the dedicated answers salt: answers were hashed
          // with the shared PIN salt. Verify under the old scheme so existing
          // users are not locked out of their own recovery.
          ? await _hashPin(
              SecurityQuestions.normalizeAnswer(answers[i]), legacySalt)
          : await _hashAnswerAt(answers[i], answersSalt, i);

      if (constantTimeEquals(hashedAnswer, storedHashes[i] as String)) {
        correctCount++;
      }
    }

    // Require at least 2 out of 3 correct
    if (correctCount >= 2) {
      await _resetAttempts(clearBackoff: true);
      return SecurityQuestionsResult(success: true);
    }

    // A wrong answer set costs an attempt from the same budget as a wrong PIN,
    // so grinding recovery escalates into the same lockout.
    await _handleFailedAttempt();
    return SecurityQuestionsResult(
      success: false,
      error: '$correctCount/3 answers correct. At least 2 required.',
      correctCount: correctCount,
    );
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

    final lostData = await _writeNewPinAfterRecovery(newPin);
    return PinVerificationResult(
      success: true,
      priorEncryptedDataLost: lostData,
    );
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
        final lostData = await _writeNewPinAfterRecovery(newPin);
        return PinVerificationResult(
          success: true,
          priorEncryptedDataLost: lostData,
        );
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

}

/// High-level representation of the security vault state (OOD)
class SecurityVaultStatus {
  /// Whether a PIN and salts are configured in secure storage
  final bool isConfigured;
  /// Whether the user has enabled the security system in settings
  final bool isEnabled;
  /// Whether the encryption key is currently available in memory
  final bool isUnlocked;

  SecurityVaultStatus({
    required this.isConfigured,
    required this.isEnabled,
    required this.isUnlocked,
  });

  bool get needsSetup => !isConfigured;
  bool get canReactivate => isConfigured && !isEnabled;
}

/// Result of PIN verification attempt
class PinVerificationResult {
  final bool success;
  final String? error;
  final int? remainingAttempts;
  final int? remainingLockoutSeconds;
  final bool requiresPinReset;

  /// True when this operation replaced the data-encryption key, making anything
  /// encrypted under the previous PIN — saved drafts, encrypted backup files —
  /// permanently unreadable.
  ///
  /// Only a recovery reset (security questions or biometrics) can set this: it
  /// proves identity without proving knowledge of the old PIN, so the old key
  /// cannot be recovered. A normal PIN change never sets it, because the key is
  /// re-wrapped rather than replaced. Callers should tell the user.
  final bool priorEncryptedDataLost;

  PinVerificationResult({
    required this.success,
    this.error,
    this.remainingAttempts,
    this.remainingLockoutSeconds,
    this.requiresPinReset = false,
    this.priorEncryptedDataLost = false,
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
class ChangePinResult {
  final bool success;
  final String? error;

  const ChangePinResult({required this.success, this.error});

  factory ChangePinResult.fromVerification(PinVerificationResult r) =>
      ChangePinResult(success: false, error: r.error);
}

