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
  /// Process-wide instance, wired to the app-lock service's cached key.
  static final EncryptionService _instance = EncryptionService.withKeySource(
    () => SecurityService().getCachedEncryptionKey(),
  );

  factory EncryptionService() => _instance;

  /// Construct with an explicit key source.
  ///
  /// This service is stateless — it holds nothing but this function — so the
  /// only coupling worth breaking was the hard reference to the app-lock
  /// singleton that used to sit inside the two places a key is needed. Passing
  /// the key in means this class can be exercised on its own, and means the
  /// ciphers do not care where the key comes from.
  EncryptionService.withKeySource(this._keySource);

  /// Returns the current data-encryption key, or null when the vault is locked.
  final Uint8List? Function() _keySource;

  static const int _currentEncryptionVersion = 2;

  /// Minimum base64 length that could hold a `[version][iv][ct]` envelope.
  /// 17 raw bytes encode to 24 base64 characters.
  static const int _minEnvelopeChars = 24;

  /// Base64 alphabet, anchored. Ordinary prose fails this immediately (spaces
  /// and punctuation are not in the alphabet), which is the point.
  static final RegExp _base64Shaped = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

  /// Cheap test for "this might be one of our encryption envelopes".
  ///
  /// Journal content is stored as plain text by design, so the overwhelmingly
  /// common case is a value that is *not* encrypted. [decrypt] used to discover
  /// that by calling `base64Decode` and catching the resulting
  /// [FormatException] — an exception thrown per field, per entry, on every
  /// read. That is exception-as-control-flow on the hot path. This answers the
  /// same question with a length check and a regex, and only decodes when the
  /// shape is actually plausible.
  ///
  /// False positives are harmless: [decrypt] still falls back to the original
  /// text when the bytes turn out not to be a real envelope.
  static bool looksEncrypted(String value) {
    if (value.length < _minEnvelopeChars) return false;
    if (value.length % 4 != 0) return false; // base64 is always 4-char aligned
    if (!_base64Shaped.hasMatch(value)) return false;
    try {
      final bytes = base64Decode(value);
      if (bytes.length < 17) return false;
      final version = bytes[0];
      return version == 1 || version == _currentEncryptionVersion;
    } on FormatException {
      return false;
    }
  }

  /// Generate a derived key for encryption (32 bytes for AES-256)
  Future<Uint8List> _getDerivedKey() async {
    final key = _keySource();
    if (key == null) {
      throw StateError('Encryption key not available: PIN not verified');
    }
    return key;
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
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
      );

      final encrypted = encrypter.encryptBytes(
        Uint8List.fromList(utf8.encode(plainText)),
        iv: iv,
      );

      // Combine: version + IV + ciphertext (includes GCM tag at the end)
      final combined = Uint8List.fromList([
        _currentEncryptionVersion, // Version byte (2)
        ...iv.bytes, // 16 bytes IV
        ...encrypted.bytes, // Ciphertext + GCM tag
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
    if (!looksEncrypted(encryptedText)) return encryptedText;

    final combined = base64Decode(encryptedText);
    final version = combined[0];

    // AES needs async key derivation; the caller gets the original back and can
    // retry through [decrypt].
    if (version == _currentEncryptionVersion) return encryptedText;

    // XOR legacy — decryptable synchronously when the key is cached.
    return _decryptXorSync(combined.sublist(1));
  }

  /// Synchronous XOR decryption (for legacy data migration only).
  String _decryptXorSync(Uint8List data) {
    try {
      final key = _keySource();
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

    // Fast path: journal content is plain text by design, so most values are
    // not envelopes at all. Rejecting them without throwing keeps reads cheap.
    if (!looksEncrypted(encryptedText)) return encryptedText;

    final combined = base64Decode(encryptedText);
    final version = combined[0];

    // Step 3: Try AES-GCM (version 2)
    if (version == 2 && combined.length >= 34) {
      try {
        return await _decryptAes(combined.sublist(1));
      } on FormatException {
        rethrow; // Authenticated encryption failure must be fatal (R2.5)
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
    // data = [16 bytes IV][N bytes ciphertext + 16 bytes GCM tag]
    if (data.length < 17) {
      throw const FormatException('Encrypted data too short');
    }

    final ivBytes = data.sublist(0, 16);
    final cipherWithTag = data.sublist(16);

    final iv = encrypt_lib.IV(ivBytes);
    final keyBytes = await _getDerivedKey();
    final key = encrypt_lib.Key(keyBytes);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
    );

    try {
      return encrypter.decrypt(
        encrypt_lib.Encrypted(cipherWithTag),
        iv: iv,
      );
    } catch (e) {
      // pointycastle throws InvalidCipherTextException on GCM tag failure
      throw FormatException('GCM tag verification failed: $e');
    }
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
