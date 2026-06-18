import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/mockito.dart';

import 'security_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityService service;
  late MockFlutterSecureStorage storage;

  setUp(() {
    storage = MockFlutterSecureStorage();
    service = SecurityService.withStorage(storage);
  });

  // ─── 11.9* Parallel reads equivalence ────────────────────────────────────
  group('readKeysInParallel equivalence', () {
    test('returns the same values, in input order, as sequential reads', () async {
      // Make completion order differ from request order to prove ordering is by
      // input position, not by which read finishes first.
      when(storage.read(key: 'a')).thenAnswer(
          (_) => Future.delayed(const Duration(milliseconds: 40), () => 'va'));
      when(storage.read(key: 'b')).thenAnswer(
          (_) => Future.delayed(const Duration(milliseconds: 5), () => 'vb'));
      when(storage.read(key: 'c')).thenAnswer((_) async => null);

      final keys = ['a', 'b', 'c'];

      final sequential = <String?>[];
      for (final k in keys) {
        sequential.add(await storage.read(key: k));
      }

      final parallel = await service.readKeysInParallel(keys);

      expect(parallel, equals(sequential));
      expect(parallel, equals(['va', 'vb', null]));
    });

    test('empty key list yields empty result', () async {
      expect(await service.readKeysInParallel(const []), isEmpty);
    });
  });

  // ─── 11.10* Future.wait failure propagation ──────────────────────────────
  group('readKeysInParallel failure propagation', () {
    test('a single failing read causes the whole call to throw', () async {
      when(storage.read(key: 'ok')).thenAnswer((_) async => 'v');
      when(storage.read(key: 'bad'))
          .thenAnswer((_) async => throw Exception('boom'));

      expect(
        () => service.readKeysInParallel(['ok', 'bad']),
        throwsA(isA<Exception>()),
      );
    });

    test('verifyPin propagates a storage read failure rather than masking it',
        () async {
      // Lockout gate passes, then the parallel pin_hash/salt read fails.
      when(storage.read(key: 'lockout_until')).thenAnswer((_) async => null);
      when(storage.read(key: 'pin_hash'))
          .thenAnswer((_) async => throw Exception('storage down'));
      when(storage.read(key: 'security_salt')).thenAnswer((_) async => 'salt');

      await expectLater(
        () => service.verifyPin('1234'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
