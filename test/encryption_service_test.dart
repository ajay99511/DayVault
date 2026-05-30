import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/encryption_service.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@GenerateNiceMocks([MockSpec<FlutterSecureStorage>()])
import 'encryption_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionService encryptionService;
  late MockFlutterSecureStorage mockStorage;
  late SecurityService securityService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    securityService = SecurityService.withStorage(mockStorage);
    encryptionService = EncryptionService();
    securityService.setCachedEncryptionKeyForTesting(null);
  });

  group('EncryptionService AES-GCM', () {
    test('Round-trip encrypt/decrypt', () async {
      final key = Uint8List.fromList(List.filled(32, 1));
      securityService.setCachedEncryptionKeyForTesting(key);
      
      const plaintext = 'Hello, World!';
      final encrypted = await encryptionService.encrypt(plaintext);
      
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(plaintext));
      
      final decrypted = await encryptionService.decrypt(encrypted);
      expect(decrypted, plaintext);
    });

    test('Encryption throws StateError if key not available', () async {
      securityService.setCachedEncryptionKeyForTesting(null);
      expect(() => encryptionService.encrypt('secret'), throwsA(isA<StateError>()));
    });

    test('Two encryptions of same plaintext differ (random IV)', () async {
      final key = Uint8List.fromList(List.filled(32, 1));
      securityService.setCachedEncryptionKeyForTesting(key);
      
      const plaintext = 'Same';
      final enc1 = await encryptionService.encrypt(plaintext);
      final enc2 = await encryptionService.encrypt(plaintext);
      
      expect(enc1, isNot(enc2));
    });

    test('Tampered ciphertext throws FormatException', () async {
      final key = Uint8List.fromList(List.filled(32, 1));
      securityService.setCachedEncryptionKeyForTesting(key);
      
      final encrypted = await encryptionService.encrypt('valid');
      final bytes = base64Decode(encrypted!);
      bytes[bytes.length - 1] ^= 0xFF; // Tamper with GCM tag
      
      final tampered = base64Encode(bytes);
      expect(() => encryptionService.decrypt(tampered), throwsA(isA<FormatException>()));
    });
  });
}
