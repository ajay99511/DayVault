import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/security_service.dart'
    show PinVerificationResult;
import 'package:memory_palace/services/vault_security_service.dart';
import 'package:mockito/mockito.dart';

// Reuse the generated FlutterSecureStorage mock from the app-lock tests.
import 'security_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage mockStorage;
  late Map<String, String> store;
  late VaultSecurityService vault;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    store = <String, String>{};

    // Back the mock with a real in-memory map so full credential lifecycles
    // (set → verify → change → recover) run end-to-end.
    when(mockStorage.read(key: anyNamed('key'))).thenAnswer(
        (inv) async => store[inv.namedArguments[#key] as String]);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((inv) async {
      store[inv.namedArguments[#key] as String] =
          inv.namedArguments[#value] as String;
    });
    when(mockStorage.delete(key: anyNamed('key'))).thenAnswer((inv) async {
      store.remove(inv.namedArguments[#key] as String);
    });

    vault = VaultSecurityService(storage: mockStorage);
  });

  group('VaultSecurityService passcode lifecycle', () {
    test('setPasscode stores namespaced hash and salt', () async {
      expect(await vault.isPasscodeSet(), isFalse);
      expect(await vault.setPasscode('1234'), isTrue);
      expect(await vault.isPasscodeSet(), isTrue);
      expect(store.containsKey('vault_pin_hash'), isTrue);
      expect(store.containsKey('vault_salt'), isTrue);
    });

    test('setPasscode rejects invalid formats and duplicates', () async {
      expect(await vault.setPasscode('12'), isFalse);
      expect(await vault.setPasscode('abcd'), isFalse);
      expect(await vault.setPasscode('1234'), isTrue);
      expect(await vault.setPasscode('5678'), isFalse); // already set
    });

    test('verifyPasscode succeeds with correct and fails with wrong code',
        () async {
      await vault.setPasscode('1234');
      expect((await vault.verifyPasscode('1234')).success, isTrue);

      final wrong = await vault.verifyPasscode('9999');
      expect(wrong.success, isFalse);
      expect(wrong.remainingAttempts, isNotNull);
    });

    test('changePasscode requires the old passcode', () async {
      await vault.setPasscode('1234');

      final bad = await vault.changePasscode('0000', '5678');
      expect(bad.success, isFalse);
      expect((await vault.verifyPasscode('1234')).success, isTrue);

      final good = await vault.changePasscode('1234', '5678');
      expect(good.success, isTrue);
      expect((await vault.verifyPasscode('5678')).success, isTrue);
      expect((await vault.verifyPasscode('1234')).success, isFalse);
    });

    test('removePasscode verifies and clears all vault keys', () async {
      await vault.setPasscode('1234');
      await vault.setSecurityQuestions(
          ['q1', 'q2', 'q3'], ['a1', 'a2', 'a3']);

      expect((await vault.removePasscode('0000')).success, isFalse);
      expect((await vault.removePasscode('1234')).success, isTrue);
      expect(await vault.isPasscodeSet(), isFalse);
      expect(await vault.areSecurityQuestionsSet(), isFalse);
      final vaultKeys =
          store.keys.where((k) => k.startsWith('vault_')).toList();
      expect(vaultKeys, isEmpty);
    });
  });

  group('VaultSecurityService lockout', () {
    test('5 failed attempts trigger a lockout that blocks verification',
        () async {
      await vault.setPasscode('1234');

      PinVerificationResult? last;
      for (int i = 0; i < 5; i++) {
        last = await vault.verifyPasscode('0000');
      }
      expect(last!.success, isFalse);
      expect(last.remainingLockoutSeconds, isNotNull);

      // Even the correct passcode is rejected while locked out.
      final duringLockout = await vault.verifyPasscode('1234');
      expect(duringLockout.success, isFalse);
      expect(duringLockout.remainingLockoutSeconds, isNotNull);
      expect(await vault.isLockedOut(), isTrue);
    });
  });

  group('VaultSecurityService security questions', () {
    test('2 of 3 correct answers pass, fewer fail', () async {
      await vault.setPasscode('1234');
      await vault.setSecurityQuestions(
          ['q1', 'q2', 'q3'], ['Rex', 'Paris', 'Blue']);

      // Answers are normalized (trimmed, lowercased).
      final twoRight =
          await vault.verifySecurityQuestions(['  REX ', 'paris', 'wrong']);
      expect(twoRight.success, isTrue);

      final oneRight =
          await vault.verifySecurityQuestions(['Rex', 'nope', 'wrong']);
      expect(oneRight.success, isFalse);
      expect(oneRight.correctCount, 1);
    });

    test('resetPasscodeViaSecurityQuestions replaces the passcode', () async {
      await vault.setPasscode('1234');
      await vault.setSecurityQuestions(
          ['q1', 'q2', 'q3'], ['a1', 'a2', 'a3']);

      final reset = await vault
          .resetPasscodeViaSecurityQuestions(['a1', 'a2', 'wrong'], '9876');
      expect(reset.success, isTrue);
      expect((await vault.verifyPasscode('9876')).success, isTrue);
      expect((await vault.verifyPasscode('1234')).success, isFalse);
    });
  });

  group('VaultSecurityService key-namespace isolation', () {
    test('vault operations never write app-lock storage keys', () async {
      await vault.setPasscode('1234');
      await vault.setSecurityQuestions(
          ['q1', 'q2', 'q3'], ['a1', 'a2', 'a3']);
      await vault.verifyPasscode('0000'); // failed attempt bookkeeping
      await vault.verifyPasscode('1234');

      // Every key ever written must be vault-namespaced; in particular the
      // app-lock keys must be untouched.
      expect(store.keys.every((k) => k.startsWith('vault_')), isTrue,
          reason: 'non-namespaced keys written: '
              '${store.keys.where((k) => !k.startsWith('vault_'))}');
      expect(store.containsKey('pin_hash'), isFalse);
      expect(store.containsKey('security_salt'), isFalse);
      expect(store.containsKey('encryption_salt'), isFalse);
    });
  });
}
