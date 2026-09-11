import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';

/// The outcome of consulting a [CredentialGate].
class GateDecision {
  /// Whether the caller may proceed to check the credential.
  final bool allowed;

  /// User-facing reason when [allowed] is false.
  final String? error;

  /// Attempts left before a lockout starts, when that is what stopped us.
  final int? remainingAttempts;

  /// Seconds until the active lockout expires, when one is active.
  final int? remainingLockoutSeconds;

  const GateDecision.allow()
      : allowed = true,
        error = null,
        remainingAttempts = null,
        remainingLockoutSeconds = null;

  const GateDecision.deny({
    required this.error,
    this.remainingAttempts,
    this.remainingLockoutSeconds,
  }) : allowed = false;
}

/// Attempt counting and escalating lockout for one credential.
///
/// The app has two credentials — the app-lock PIN and the Privacy Vault
/// passcode — with identical rate-limiting semantics and different storage key
/// prefixes. They previously carried two line-for-line copies of this state
/// machine, which is not a harmless duplication: when recovery questions were
/// found to bypass the lockout entirely, the fix had to be made twice, and the
/// second copy was nearly missed. They vary for the same reason, so they share
/// one implementation.
///
/// All persisted counters are parsed defensively. A corrupt value must not
/// throw out of a verification path, because that fails *open* — it skips the
/// check rather than enforcing it.
class CredentialGate {
  CredentialGate({
    required FlutterSecureStorage storage,
    required String credentialLabel,
    String namespace = '',
  })  : _storage = storage,
        _credentialLabel = credentialLabel,
        _namespace = namespace;

  final FlutterSecureStorage _storage;

  /// How the credential is named to the user ("PIN", "passcode"). The two
  /// services word their failure message differently and that wording is
  /// user-visible, so it is a parameter rather than something to flatten away.
  final String _credentialLabel;

  /// Key prefix isolating one credential's counters from the other's.
  final String _namespace;

  static const int _maxAttempts = SecurityConstants.maxAttempts;

  String get attemptCountKey => '${_namespace}attempt_count';
  String get lockoutUntilKey => '${_namespace}lockout_until';
  String get lockoutCycleCountKey => '${_namespace}lockout_cycle_count';

  /// Every key this gate may write, for cleanup and for tests that assert a
  /// credential was fully removed.
  List<String> get storageKeys =>
      [attemptCountKey, lockoutUntilKey, lockoutCycleCountKey];

  /// Exponential backoff for a given (1-based) lockout [cycleCount]:
  /// `base * 2^(cycle-1)`, clamped to
  /// [SecurityConstants.maxLockoutDurationSeconds].
  ///
  /// Cycle 1 returns the base duration, preserving plain fixed-lockout
  /// behaviour for a first offence.
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

  /// Whether a verification attempt may proceed right now.
  ///
  /// Call this *first* on every path that checks the credential — including
  /// recovery flows, which are an alternative route to the same privilege and
  /// must not be an unmetered way around the lockout.
  Future<GateDecision> check() async {
    final lockoutUntilStr = await _storage.read(key: lockoutUntilKey);
    if (lockoutUntilStr == null) return const GateDecision.allow();

    final lockoutMillis = int.tryParse(lockoutUntilStr);
    if (lockoutMillis == null) {
      // Corrupt stamp: clear it so the counter restarts from a known state.
      await _storage.delete(key: lockoutUntilKey);
      return const GateDecision.allow();
    }

    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
    final now = DateTime.now();
    if (now.isBefore(lockoutUntil)) {
      final remaining = lockoutUntil.difference(now).inSeconds;
      return GateDecision.deny(
        error: 'Too many attempts. Try again in $remaining seconds.',
        remainingLockoutSeconds: remaining,
      );
    }

    // Expired. Clear the lockout and the attempt counter, but deliberately keep
    // the escalation cycle so repeated lock cycles keep getting longer until
    // the user actually proves identity.
    await _storage.delete(key: lockoutUntilKey);
    await reset();
    return const GateDecision.allow();
  }

  /// Record a failed attempt, starting or escalating a lockout if the budget
  /// is exhausted.
  Future<GateDecision> recordFailure() async {
    final attemptsStr = await _storage.read(key: attemptCountKey) ?? '0';
    final attempts = (int.tryParse(attemptsStr) ?? 0) + 1;
    await _storage.write(key: attemptCountKey, value: attempts.toString());

    final remainingAttempts = _maxAttempts - attempts;
    if (remainingAttempts > 0) {
      return GateDecision.deny(
        error: 'Incorrect $_credentialLabel. '
            '$remainingAttempts attempts remaining.',
        remainingAttempts: remainingAttempts,
      );
    }

    // Budget exhausted. The cycle count survives lockout expiry and is only
    // cleared by a success, so each successive lockout lasts longer.
    final cycleStr = await _storage.read(key: lockoutCycleCountKey) ?? '0';
    final cycle = (int.tryParse(cycleStr) ?? 0) + 1;
    await _storage.write(key: lockoutCycleCountKey, value: cycle.toString());

    final lockoutSeconds = computeLockoutDurationSeconds(cycle);
    final lockoutUntil = DateTime.now().add(Duration(seconds: lockoutSeconds));
    await _storage.write(
      key: lockoutUntilKey,
      value: lockoutUntil.millisecondsSinceEpoch.toString(),
    );
    await _storage.delete(key: attemptCountKey);

    return GateDecision.deny(
      error: 'Too many failed attempts. Locked for $lockoutSeconds seconds.',
      remainingLockoutSeconds: lockoutSeconds,
    );
  }

  /// Record a successful verification: clears the counter and the escalation.
  Future<void> recordSuccess() => reset(clearBackoff: true);

  /// Clear the attempt counter and any active lockout.
  ///
  /// [clearBackoff] additionally resets the escalation cycle; pass it only when
  /// the user has actually proven identity. It must stay false on mere lockout
  /// expiry, or repeated lock cycles would never escalate.
  Future<void> reset({bool clearBackoff = false}) async {
    await _storage.delete(key: attemptCountKey);
    await _storage.delete(key: lockoutUntilKey);
    if (clearBackoff) {
      await _storage.delete(key: lockoutCycleCountKey);
    }
  }

  /// Attempts left before the next lockout.
  Future<int> remainingAttempts() async {
    final attemptsStr = await _storage.read(key: attemptCountKey) ?? '0';
    final attempts = int.tryParse(attemptsStr) ?? 0;
    return (_maxAttempts - attempts).clamp(0, _maxAttempts);
  }

  /// Whether a lockout is currently in force.
  Future<bool> isLockedOut() async {
    final decision = await check();
    return !decision.allowed && decision.remainingLockoutSeconds != null;
  }
}
