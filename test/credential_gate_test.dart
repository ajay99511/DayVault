import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/config/constants.dart';
import 'package:memory_palace/services/credential_gate.dart';
import 'package:mockito/mockito.dart';

import 'security_service_test.mocks.dart';

/// Tests the attempt-counting and lockout state machine directly.
///
/// This used to be exercised only through the two services, which meant every
/// assertion cost a 100,000-iteration PBKDF2 derivation — fifteen of them for a
/// single lockout test. That was slow enough to blow the 30-second per-test
/// timeout under full-suite concurrency and show up as a flake. The state
/// machine has no cryptography in it, so it is tested here, with no crypto, in
/// milliseconds; the service tests now only need to prove they are wired to it.
void main() {
  late MockFlutterSecureStorage storage;
  late Map<String, String> disk;

  CredentialGate gateFor(String namespace) => CredentialGate(
        storage: storage,
        credentialLabel: namespace.isEmpty ? 'PIN' : 'passcode',
        namespace: namespace,
      );

  setUp(() {
    disk = <String, String>{};
    storage = MockFlutterSecureStorage();
    when(storage.read(key: anyNamed('key')))
        .thenAnswer((i) async => disk[i.namedArguments[#key] as String]);
    when(storage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((i) async {
      disk[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(storage.delete(key: anyNamed('key'))).thenAnswer(
        (i) async => disk.remove(i.namedArguments[#key] as String));
  });

  group('attempt budget', () {
    test('allows attempts until the budget is spent, then locks out', () async {
      final gate = gateFor('');

      for (var i = 1; i < SecurityConstants.maxAttempts; i++) {
        final decision = await gate.recordFailure();
        expect(decision.allowed, isFalse);
        expect(decision.remainingAttempts, SecurityConstants.maxAttempts - i);
        expect(decision.remainingLockoutSeconds, isNull);
      }

      final last = await gate.recordFailure();
      expect(last.remainingLockoutSeconds,
          SecurityConstants.lockoutDurationSeconds);
      expect(disk.containsKey('lockout_until'), isTrue);
      expect(disk.containsKey('attempt_count'), isFalse,
          reason: 'the counter resets once the lockout takes over');
    });

    test('blocks while a lockout is active', () async {
      final gate = gateFor('');
      for (var i = 0; i < SecurityConstants.maxAttempts; i++) {
        await gate.recordFailure();
      }

      final decision = await gate.check();
      expect(decision.allowed, isFalse);
      expect(decision.error, contains('Too many attempts'));
      expect(await gate.isLockedOut(), isTrue);
    });

    test('allows again once the lockout has expired', () async {
      final gate = gateFor('');
      disk['lockout_until'] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch
          .toString();

      expect((await gate.check()).allowed, isTrue);
      expect(disk.containsKey('lockout_until'), isFalse);
    });

    test('a success clears the counter and the escalation', () async {
      final gate = gateFor('');
      await gate.recordFailure();
      await gate.recordSuccess();

      expect(disk.containsKey('attempt_count'), isFalse);
      expect(disk.containsKey('lockout_until'), isFalse);
      expect(disk.containsKey('lockout_cycle_count'), isFalse);
      expect(await gate.remainingAttempts(), SecurityConstants.maxAttempts);
    });
  });

  group('escalation', () {
    test('each lockout cycle lasts longer than the last', () async {
      final gate = gateFor('');
      final durations = <int>[];

      for (var cycle = 0; cycle < 3; cycle++) {
        for (var i = 0; i < SecurityConstants.maxAttempts; i++) {
          final decision = await gate.recordFailure();
          if (decision.remainingLockoutSeconds != null) {
            durations.add(decision.remainingLockoutSeconds!);
          }
        }
        // Expire the lockout without proving identity, so the cycle count
        // survives — this is what makes repeated lock cycles escalate.
        disk['lockout_until'] = DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch
            .toString();
        await gate.check();
      }

      expect(durations, [30, 60, 120]);
    });

    test('lockout expiry alone does not reset the escalation', () async {
      final gate = gateFor('');
      for (var i = 0; i < SecurityConstants.maxAttempts; i++) {
        await gate.recordFailure();
      }
      disk['lockout_until'] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch
          .toString();
      await gate.check();

      expect(disk['lockout_cycle_count'], '1',
          reason: 'only a proven identity may clear the escalation');
    });
  });

  group('corrupt persisted state fails closed, not open', () {
    test('an unparseable lockout stamp is cleared rather than thrown', () async {
      final gate = gateFor('');
      disk['lockout_until'] = 'not-a-number';

      // Previously this threw straight out of the verification path, which
      // skips the check entirely — failing *open*.
      final decision = await gate.check();
      expect(decision.allowed, isTrue);
      expect(disk.containsKey('lockout_until'), isFalse);
    });

    test('an unparseable attempt counter restarts from zero', () async {
      final gate = gateFor('');
      disk['attempt_count'] = 'garbage';

      final decision = await gate.recordFailure();
      expect(decision.remainingAttempts, SecurityConstants.maxAttempts - 1);
    });
  });

  group('namespacing', () {
    test('two credentials keep entirely separate counters', () async {
      final appLock = gateFor('');
      final vault = gateFor('vault_');

      for (var i = 0; i < SecurityConstants.maxAttempts; i++) {
        await appLock.recordFailure();
      }

      expect(await appLock.isLockedOut(), isTrue);
      expect(await vault.isLockedOut(), isFalse,
          reason: 'locking the app must not lock the vault');
      expect(await vault.remainingAttempts(), SecurityConstants.maxAttempts);
    });

    test('reports every key it owns, prefixed', () {
      expect(gateFor('vault_').storageKeys, [
        'vault_attempt_count',
        'vault_lockout_until',
        'vault_lockout_cycle_count',
      ]);
    });
  });
}
