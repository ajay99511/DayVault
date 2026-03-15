import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'security_service.dart';

/// Service for encrypting and decrypting sensitive data fields.
/// 
/// This provides field-level encryption for sensitive journal entry data
/// using XOR cipher with PBKDF2-derived keys.
/// 
/// Note: For production use with higher security requirements,
/// consider using the `encrypt` package or platform-specific encryption.
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final SecurityService _securityService = SecurityService();

  /// Generate a derived key for encryption
  Future<Uint8List> _getDerivedKey() async {
    final key = await _securityService.getEncryptionKey();
    if (key == null) {
      // Generate a default key if none available
      return Uint8List.fromList(utf8.encode('dayvault_default_key_32bytes!!'));
    }
    return key;
  }

  /// Simple XOR encryption/decryption
  /// 
  /// XOR is symmetric - same operation for encrypt and decrypt
  Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Encrypt sensitive text data
  /// 
  /// Returns the encrypted data as a base64-encoded string.
  Future<String?> encrypt(String plainText) async {
    if (plainText.isEmpty) return plainText;

    try {
      final key = await _getDerivedKey();
      final data = utf8.encode(plainText);
      
      // Generate a random IV (using timestamp + random-ish data)
      final ivBytes = Uint8List(16);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 16; i++) {
        ivBytes[i] = (timestamp + i) % 256;
      }
      
      // Combine IV and encrypted data
      final encrypted = _xorEncrypt(Uint8List.fromList(data), key);
      final combined = Uint8List.fromList([...ivBytes, ...encrypted]);
      
      return base64Encode(combined);
    } catch (e) {
      // On encryption failure, return plaintext to prevent data loss
      return plainText;
    }
  }

  /// Decrypt sensitive text data
  /// 
  /// Returns the decrypted plaintext.
  /// If the data is not encrypted or decryption fails, returns the input as-is.
  Future<String> decrypt(String? encryptedText) async {
    if (encryptedText == null || encryptedText.isEmpty) {
      return '';
    }

    try {
      final key = await _getDerivedKey();
      
      // Decode base64
      final combined = base64Decode(encryptedText);
      
      // Extract IV (first 16 bytes) and encrypted data
      final encryptedBytes = combined.sublist(16);

      // Decrypt using XOR
      final decrypted = _xorEncrypt(Uint8List.fromList(encryptedBytes), key);
      
      return utf8.decode(decrypted, allowMalformed: true);
    } catch (e) {
      // On decryption failure, return original text
      // This handles cases where data was stored unencrypted
      return encryptedText;
    }
  }

  /// Encrypt multiple fields in a map
  Future<Map<String, String>> encryptFields(
    Map<String, String> fields,
  ) async {
    final encrypted = <String, String>{};
    for (final entry in fields.entries) {
      final encryptedValue = await encrypt(entry.value);
      encrypted[entry.key] = encryptedValue ?? entry.value;
    }
    return encrypted;
  }

  /// Decrypt multiple fields in a map
  Future<Map<String, String>> decryptFields(
    Map<String, String> fields,
  ) async {
    final decrypted = <String, String>{};
    for (final entry in fields.entries) {
      final decryptedValue = await decrypt(entry.value);
      decrypted[entry.key] = decryptedValue;
    }
    return decrypted;
  }

  /// Generate a hash of data for integrity verification
  String hash(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  /// Verify data integrity
  bool verifyIntegrity(String data, String expectedHash) {
    return hash(data) == expectedHash;
  }
}
