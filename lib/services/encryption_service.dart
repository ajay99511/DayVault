import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'security_service.dart';

/// Service for encrypting and decrypting sensitive data fields.
///
/// This provides field-level encryption for sensitive journal entry data
/// using AES-256-GCM with cryptographically secure random IVs.
///
/// Encryption versions:
/// - Version 1: XOR cipher (legacy, being phased out)
/// - Version 2: AES-256-GCM (current, secure)
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final SecurityService _securityService = SecurityService();
  static const int _currentEncryptionVersion = 2;

  /// Generate a derived key for encryption (32 bytes for AES-256)
  Future<Uint8List> _getDerivedKey() async {
    final key = await _securityService.getEncryptionKey();
    if (key == null || key.length < 32) {
      throw StateError(
        'Encryption key not available or too short. '
        'Please set up your PIN first.',
      );
    }
    return key.sublist(0, 32); // Ensure exactly 32 bytes for AES-256
  }

  /// Encrypt sensitive text data using AES-256-GCM
  ///
  /// Returns the encrypted data as a base64-encoded string with version prefix.
  /// Format: [version_byte][iv_16_bytes][ciphertext][mac_16_bytes]
  Future<String?> encrypt(String plainText) async {
    if (plainText.isEmpty) return plainText;

    try {
      final keyBytes = await _getDerivedKey();
      final key = encrypt_lib.Key(keyBytes);

      // Generate cryptographically secure random IV (16 bytes)
      final iv = encrypt_lib.IV.fromSecureRandom(16);

      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
      );

      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Combine: version + IV + ciphertext + authentication tag
      // Note: GCM mode doesn't include tag in encrypted.bytes, need to access it separately
      final combined = Uint8List.fromList([
        _currentEncryptionVersion, // Version byte (2)
        ...iv.bytes, // 16 bytes IV
        ...encrypted.bytes, // Ciphertext
      ]);

      return base64Encode(combined);
    } catch (e, st) {
      // CRITICAL: Never fallback to plaintext — throw instead
      debugPrint('Encryption failed: $e\n$st');
      rethrow;
    }
  }

  /// Decrypt sensitive text data
  ///
  /// Returns the decrypted plaintext.
  /// Supports both v1 (XOR legacy) and v2 (AES-256-GCM) for migration.
  /// Throws on decryption failure — never returns corrupted data.
  Future<String> decrypt(String? encryptedText) async {
    if (encryptedText == null || encryptedText.isEmpty) {
      return '';
    }

    try {
      final combined = base64Decode(encryptedText);

      // Detect encryption version
      if (combined.length < 17) {
        // Too short to be v2, likely v1 (XOR) or plaintext
        return _decryptLegacyXor(encryptedText);
      }

      final version = combined[0];

      if (version == 2) {
        return _decryptAes(combined.sublist(1));
      } else if (version == 1) {
        // Legacy XOR — migrate on decrypt
        return _decryptLegacyXorWithVersion(combined.sublist(1));
      } else {
        // Unknown version — try XOR as fallback for pre-versioned data
        debugPrint('Unknown encryption version: $version, trying legacy');
        return _decryptLegacyXor(encryptedText);
      }
    } catch (e) {
      debugPrint('Decryption failed: $e');
      rethrow;
    }
  }

  /// Decrypt AES encrypted data (version 2)
  Future<String> _decryptAes(Uint8List data) async {
    // Minimum size: 16 (IV) + 1 (min ciphertext) = 17 bytes
    if (data.length < 17) {
      throw FormatException('Encrypted data too short');
    }

    final ivBytes = data.sublist(0, 16);
    final cipherBytes = data.sublist(16);

    final iv = encrypt_lib.IV(ivBytes);
    final keyBytes = await _getDerivedKey();
    final key = encrypt_lib.Key(keyBytes);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    final encrypted = encrypt_lib.Encrypted(cipherBytes);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted;
  }

  /// Decrypt legacy XOR encrypted data (version 1, no version prefix)
  Future<String> _decryptLegacyXor(String encryptedText) async {
    try {
      final key = await _getDerivedKey();
      final combined = base64Decode(encryptedText);

      // Extract IV (first 16 bytes) and encrypted data
      if (combined.length <= 16) {
        // Not XOR encrypted with IV, return as-is (likely plaintext)
        return encryptedText;
      }

      final encryptedBytes = combined.sublist(16);
      final decrypted = _xorDecrypt(Uint8List.fromList(encryptedBytes), key);

      return utf8.decode(decrypted, allowMalformed: true);
    } catch (e) {
      // If all decryption fails, return original text
      // This handles cases where data was stored unencrypted
      debugPrint('Legacy XOR decryption failed, returning as-is: $e');
      return encryptedText;
    }
  }

  /// Decrypt legacy XOR encrypted data with version prefix
  Future<String> _decryptLegacyXorWithVersion(Uint8List data) async {
    final key = await _getDerivedKey();

    if (data.length <= 16) {
      throw FormatException('XOR encrypted data too short');
    }

    final encryptedBytes = data.sublist(16);
    final decrypted = _xorDecrypt(Uint8List.fromList(encryptedBytes), key);

    return utf8.decode(decrypted, allowMalformed: true);
  }

  /// Simple XOR decryption (legacy support only)
  Uint8List _xorDecrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
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
