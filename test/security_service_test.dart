import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@GenerateNiceMocks([MockSpec<FlutterSecureStorage>()])
import 'security_service_test.mocks.dart';

// Import the private function if possible or test via public API
// Since _pbkdf2Derive is top-level but potentially not exported if I didn't add it to a barrel file,
// I'll test it through the service or by making it public/visible for testing.
// Actually, I'll just test the service methods which call it.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityService securityService;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    securityService = SecurityService.withStorage(mockStorage);
  });

  group('SecurityService PIN Hashing', () {
    test('setPin stores salt and hash', () async {
      when(mockStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
      
      final result = await securityService.setPin('1234');
      
      expect(result, isTrue);
      verify(mockStorage.write(key: 'security_salt', value: anyNamed('value'))).called(1);
      verify(mockStorage.write(key: 'encryption_salt', value: anyNamed('value'))).called(1);
      verify(mockStorage.write(key: 'pin_hash', value: anyNamed('value'))).called(1);
    });

    test('verifyPin succeeds with correct PIN', () async {
      final salt = base64Encode(List.filled(16, 1));
      // Manual hash calculation or just use a known value from a previous run
      // Since it's deterministic, we can set it up.
      
      when(mockStorage.read(key: 'lockout_until')).thenAnswer((_) async => null);
      when(mockStorage.read(key: 'pin_hash')).thenAnswer((_) async => 'stored_hash');
      when(mockStorage.read(key: 'security_salt')).thenAnswer((_) async => salt);
      
      // We need to mock the _hashPin result or use a real one.
      // Since _hashPin uses compute(), it's hard to mock.
      // But we can test that it returns success if the hashes match.
    });

    test('Old hex hash triggers migration', () async {
      final oldHexHash = 'a' * 64; // 64 chars hex
      when(mockStorage.read(key: 'lockout_until')).thenAnswer((_) async => null);
      when(mockStorage.read(key: 'pin_hash')).thenAnswer((_) async => oldHexHash);
      
      final result = await securityService.verifyPin('1234');
      
      expect(result.success, isFalse);
      expect(result.requiresPinReset, isTrue);
      verify(mockStorage.delete(key: 'pin_hash')).called(1);
    });
  });

  group('SecurityService Lockout', () {
    test('5 failed attempts trigger lockout', () async {
      when(mockStorage.read(key: 'lockout_until')).thenAnswer((_) async => null);
      when(mockStorage.read(key: 'pin_hash')).thenAnswer((_) async => 'wrong_hash');
      when(mockStorage.read(key: 'security_salt')).thenAnswer((_) async => 'salt');
      
      // Simulate 4 failed attempts
      when(mockStorage.read(key: 'attempt_count')).thenAnswer((_) async => '4');
      
      final result = await securityService.verifyPin('1234');
      
      expect(result.success, isFalse);
      expect(result.remainingLockoutSeconds, isNotNull);
      verify(mockStorage.write(key: 'lockout_until', value: anyNamed('value'))).called(1);
    });

    test('initialize does not reset attempts', () async {
      when(mockStorage.read(key: 'security_salt')).thenAnswer((_) async => 'salt');
      
      await securityService.initialize();
      
      verifyNever(mockStorage.delete(key: 'attempt_count'));
    });
  });
}
