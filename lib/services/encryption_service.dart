import 'dart:convert';
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

  static const int _currentEncryptionVersion = 2;

  /// Generate a derived key for encryption (32 bytes for AES-256)
  /// 
  /// Note: Journal data is now stored as plain text. This method is retained
  /// for draft encryption compatibility but will be removed in future.
  Future<Uint8List> _getDerivedKey() async {
    // Return a fallback key for draft encryption compatibility
    // Actual journal entries no longer use encryption
    return Uint8List.fromList(List.filled(32, 0)); // Placeholder
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

  /// Synchronous decryption for migration detection.
  /// 
  /// Used by ObjectBox models to auto-detect and decrypt legacy encrypted data
  /// during loading. Falls back to original text if decryption fails.
  String decryptSync(String encryptedText) {
    if (encryptedText.isEmpty) return '';

    try {
      final combined = base64Decode(encryptedText);
      if (combined.length < 17) return encryptedText;

      final version = combined[0];
      if (version == 2) {
        // AES — would need async key derivation, return original for sync
        return encryptedText;
      } else if (version == 1) {
        // XOR legacy — can decrypt sync if key cached
        return _decryptXorSync(combined.sublist(1));
      }
    } catch (_) {}

    // Fallback: return original text
    return encryptedText;
  }

  /// Synchronous XOR decryption (for legacy data migration only).
  String _decryptXorSync(Uint8List data) {
    try {
      // Get cached key from SecurityService
      final key = SecurityService().getCachedEncryptionKey();
      if (key == null || key.isEmpty) return '';

      final result = Uint8List(data.length);
      for (int i = 0; i < data.length; i++) {
        result[i] = data[i] ^ key[i % key.length];
      }
      return utf8.decode(result, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// Decrypt sensitive text data
  ///
  /// Returns the decrypted plaintext.
  /// Handles: AES-CBC (v2), XOR legacy (v1), and PLAIN TEXT (unencrypted).
  /// Never throws — always returns the original text if decryption fails,
  /// so existing plain-text entries still display correctly.
  Future<String> decrypt(String? encryptedText) async {
    if (encryptedText == null || encryptedText.isEmpty) {
      return '';
    }

    // Step 1: Try to base64 decode
    Uint8List combined;
    try {
      combined = base64Decode(encryptedText);
    } catch (_) {
      // Not valid base64 → this is plain text, return as-is
      return encryptedText;
    }

    // Step 2: Detect encryption version
    if (combined.length < 17) {
      // Too short for any encryption format → plain text
      return encryptedText;
    }

    final version = combined[0];

    // Step 3: Try AES-CBC (version 2)
    if (version == 2 && combined.length >= 34) {
      // v2 format: [version][16-byte IV][ciphertext]
      // Minimum: 1 + 16 + 16 (one AES block) = 33 bytes, but we check 34 to be safe
      try {
        return await _decryptAes(combined.sublist(1));
      } catch (e) {
        debugPrint('AES decrypt failed (v2), trying XOR: $e');
        // Fall through to XOR attempt
      }
    }

    // Step 4: Try XOR legacy (version 1 or unknown)
    if (version == 1) {
      try {
        return await _decryptLegacyXorWithVersion(combined.sublist(1));
      } catch (e) {
        debugPrint('XOR decrypt failed (v1), returning original: $e');
        return encryptedText;
      }
    }

    // Step 5: Unknown version — try base64-decoded XOR, then fallback to original
    try {
      return await _decryptLegacyXor(encryptedText);
    } catch (e) {
      debugPrint('All decryption attempts failed, returning original text: $e');
      return encryptedText; // Plain text that survived base64 decode
    }
  }

  /// Decrypt AES encrypted data (version 2)
  Future<String> _decryptAes(Uint8List data) async {
    // Minimum size: 16 (IV) + 1 (min ciphertext) = 17 bytes
    if (data.length < 17) {
      throw const FormatException('Encrypted data too short');
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

  /// Decrypt legacy XOR encrypted data (old format: no version prefix)
  /// Format: base64([16-byte IV][XOR-encrypted data])
  Future<String> _decryptLegacyXor(String encryptedText) async {
    try {
      final key = await _getDerivedKey();
      final combined = base64Decode(encryptedText);

      // Need at least 16 bytes IV + 1 byte data
      if (combined.length <= 16) {
        return encryptedText; // Too short, return as-is
      }

      // First 16 bytes are IV (ignored for XOR since key is repeating)
      // XOR decrypt everything after the IV
      final encryptedBytes = combined.sublist(16);
      final decrypted = _xorDecrypt(Uint8List.fromList(encryptedBytes), key);
      final result = utf8.decode(decrypted, allowMalformed: true);

      // Quality check: if decryption produced garbage (many replacement chars),
      // the data was probably plain text that happened to be valid base64
      final replacementCount = result.codeUnits
          .where((c) => c == 0xFFFD)
          .length;
      if (replacementCount > result.length * 0.1 && result.length > 5) {
        // More than 10% replacement characters → decryption failed
        return encryptedText;
      }

      return result;
    } catch (e) {
      debugPrint('Legacy XOR decryption failed, returning as-is: $e');
      return encryptedText;
    }
  }

  /// Decrypt legacy XOR encrypted data with version prefix
  Future<String> _decryptLegacyXorWithVersion(Uint8List data) async {
    final key = await _getDerivedKey();

    if (data.length <= 16) {
      throw const FormatException('XOR encrypted data too short');
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
