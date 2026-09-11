import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/config/constants.dart';
import 'package:memory_palace/services/pbkdf2.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<FlutterSecureStorage>()])
import 'security_envelope_test.mocks.dart';

/// Covers envelope encryption and the recovery rate limit.
///
/// These use a *stateful* storage fake rather than one-shot stubs: the whole
/// point of the envelope is that a value written by one call is read back by a
/// later one, and stubs that always return the same thing cannot show that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage storage;
  late Map<String, String> disk;
  late SecurityService service;

  setUp(() {
    disk = <String, String>{};
    storage = MockFlutterSecureStorage();

    when(storage.read(key: anyNamed('key'))).thenAnswer(
      (i) async => disk[i.namedArguments[#key] as String],
    );
    when(storage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((i) async {
      final value = i.namedArguments[#value] as String?;
      final key = i.namedArguments[#key] as String;
      if (value == null) {
        disk.remove(key);
      } else {
        disk[key] = value;
      }
    });
    when(storage.delete(key: anyNamed('key'))).thenAnswer((i) async {
      disk.remove(i.namedArguments[#key] as String);
    });

    service = SecurityService.withStorage(storage);
  });

  /// Re-derives the key from scratch, as a cold start would.
  Future<List<int>?> unlockAndReadKey(String pin) async {
    service.lockVault();
    final result = await service.verifyPin(pin);
    if (!result.success) return null;
    return service.getCachedEncryptionKey();
  }

  group('envelope encryption', () {
    test('changePin preserves the data-encryption key', () async {
      expect(await service.setPin('1234'), isTrue);

      final before = await unlockAndReadKey('1234');
      expect(before, isNotNull);

      final changed = await service.changePin('1234', '5678');
      expect(changed.success, isTrue);
      expect(changed.priorEncryptedDataLost, isFalse,
          reason: 'a normal PIN change re-wraps the key, it does not replace it');

      final after = await unlockAndReadKey('5678');

      // This is the defect the envelope exists to prevent: the key used to be
      // PBKDF2(pin, salt), so it changed with the PIN and every draft and
      // encrypted backup written under the old one became unreadable.
      expect(after, equals(before),
          reason: 'the DEK must survive a PIN change unchanged');
    });

    test('old PIN stops working after a change', () async {
      await service.setPin('1234');
      await service.verifyPin('1234');
      await service.changePin('1234', '5678');

      service.lockVault();
      final old = await service.verifyPin('1234');
      expect(old.success, isFalse);
    });

    test('a fresh install gets a random DEK, not a PIN-derived one', () async {
      await service.setPin('1234');
      final key = await unlockAndReadKey('1234');

      final pinDerived = pbkdf2Derive({
        'pin': '1234',
        'salt': disk['encryption_salt']!,
        'iterations': 100000,
        'keyLength': 32,
      });

      expect(key, isNot(equals(pinDerived)),
          reason: 'new installs must not tie the data key to the PIN at all');
    });

    test('an install predating the envelope keeps its existing key', () async {
      // Reconstruct a pre-envelope install by hand: salts and a PIN hash, but
      // no wrapped DEK. Its data is encrypted under PBKDF2(pin, encryptionSalt).
      const pin = '4321';
      final pinSalt = base64Encode(List.filled(16, 7));
      final encSalt = base64Encode(List.filled(16, 9));
      final legacyKey = pbkdf2Derive({
        'pin': pin,
        'salt': encSalt,
        'iterations': 100000,
        'keyLength': 32,
      });
      disk['security_salt'] = pinSalt;
      disk['encryption_salt'] = encSalt;
      disk['pin_hash'] = base64Encode(pbkdf2Derive({
        'pin': pin,
        'salt': pinSalt,
        'iterations': 100000,
        'keyLength': 32,
      }));

      final key = await unlockAndReadKey(pin);

      // Adopting the legacy key as the DEK is what makes the migration
      // lossless — nothing is re-encrypted and old drafts still open.
      expect(key, equals(legacyKey));
      expect(disk['wrapped_dek'], isNotNull,
          reason: 'the envelope should be created on first unlock');
    });

    test('migrated install then survives a PIN change', () async {
      const pin = '4321';
      final pinSalt = base64Encode(List.filled(16, 7));
      final encSalt = base64Encode(List.filled(16, 9));
      disk['security_salt'] = pinSalt;
      disk['encryption_salt'] = encSalt;
      disk['pin_hash'] = base64Encode(pbkdf2Derive({
        'pin': pin,
        'salt': pinSalt,
        'iterations': 100000,
        'keyLength': 32,
      }));

      final adopted = await unlockAndReadKey(pin);
      final changed = await service.changePin(pin, '1111');
      expect(changed.success, isTrue);

      expect(await unlockAndReadKey('1111'), equals(adopted),
          reason: 'legacy data must still open after the first PIN change');
    });
  });

  group('recovery reset', () {
    test('replaces the key and reports that prior data is unreadable',
        () async {
      await service.setPin('1234');
      final before = await unlockAndReadKey('1234');

      final reset = await service.resetPinDirectly('9999');
      expect(reset.success, isTrue);
      expect(reset.priorEncryptedDataLost, isTrue,
          reason: 'a reset without the old PIN cannot open the old envelope, '
              'and the user has to be told');

      expect(await unlockAndReadKey('9999'), isNot(equals(before)));
    });
  });

  group('interrupted re-key', () {
    test('is completed on the next initialize', () async {
      disk['security_salt'] = base64Encode(List.filled(16, 3));
      disk['pin_hash'] = 'stale-hash';
      disk['wrapped_dek'] = 'stale-envelope';
      disk['rekey_pending'] =
          jsonEncode({'hash': 'new-hash', 'wrappedDek': 'new-envelope'});

      await service.initialize();

      expect(disk['pin_hash'], 'new-hash');
      expect(disk['wrapped_dek'], 'new-envelope');
      expect(disk.containsKey('rekey_pending'), isFalse,
          reason: 'the journal must be cleared so it is not replayed forever');
    });

    test('an unreadable journal is discarded without touching credentials',
        () async {
      disk['security_salt'] = base64Encode(List.filled(16, 3));
      disk['pin_hash'] = 'good-hash';
      disk['wrapped_dek'] = 'good-envelope';
      disk['rekey_pending'] = 'not json at all';

      await service.initialize();

      expect(disk['pin_hash'], 'good-hash');
      expect(disk['wrapped_dek'], 'good-envelope');
      expect(disk.containsKey('rekey_pending'), isFalse);
    });

    test('a completed changePin leaves no journal behind', () async {
      await service.setPin('1234');
      await service.verifyPin('1234');
      await service.changePin('1234', '5678');

      expect(disk.containsKey('rekey_pending'), isFalse);
    });
  });

  group('security questions are rate limited', () {
    const questions = ['Q1', 'Q2', 'Q3'];
    const answers = ['alpha', 'beta', 'gamma'];

    test('wrong answers consume the shared attempt budget and lock out',
        () async {
      await service.setSecurityQuestions(questions, answers);

      SecurityQuestionsResult? last;
      for (var i = 0; i < SecurityConstants.maxAttempts; i++) {
        last = await service.verifySecurityQuestions(
          const ['no', 'nope', 'wrong'],
        );
        expect(last.success, isFalse);
      }

      // Before this fix there was no counter here at all: recovery was an
      // unlimited-attempt path around the PIN lockout.
      expect(disk.containsKey('lockout_until'), isTrue,
          reason: 'repeated wrong answers must escalate to a lockout');

      final locked = await service.verifySecurityQuestions(answers);
      expect(locked.success, isFalse,
          reason: 'even correct answers are refused while locked out');
      expect(locked.error, contains('Too many attempts'));
    });

    test('correct answers verify and clear the failure state', () async {
      await service.setSecurityQuestions(questions, answers);

      await service.verifySecurityQuestions(const ['x', 'y', 'z']);
      expect(disk['attempt_count'], isNotNull);

      final ok = await service.verifySecurityQuestions(answers);
      expect(ok.success, isTrue);
      expect(disk.containsKey('attempt_count'), isFalse);
    });

    test('two of three correct still passes', () async {
      await service.setSecurityQuestions(questions, answers);
      final result =
          await service.verifySecurityQuestions(const ['alpha', 'beta', 'no']);
      expect(result.success, isTrue);
    });

    test('identical answers do not produce identical stored hashes', () async {
      await service.setSecurityQuestions(
        questions,
        const ['same', 'same', 'different'],
      );

      final stored =
          (jsonDecode(disk['security_answers']!) as List).cast<String>();

      // Per-index salting: without it, two equal answers hashed to the same
      // value and leaked that fact to anyone reading the store.
      expect(stored[0], isNot(equals(stored[1])));
    });
  });

  group('constantTimeEquals', () {
    test('matches equality semantics', () {
      expect(SecurityService.constantTimeEquals('abc', 'abc'), isTrue);
      expect(SecurityService.constantTimeEquals('abc', 'abd'), isFalse);
      expect(SecurityService.constantTimeEquals('abc', 'ab'), isFalse);
      expect(SecurityService.constantTimeEquals('', ''), isTrue);
      expect(SecurityService.constantTimeEquals('a', ''), isFalse);
    });
  });
}
