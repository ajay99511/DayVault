import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/encryption_service.dart';
import 'package:memory_palace/services/security_service.dart';

/// Covers the retirement of the legacy XOR path.
///
/// Journal content is stored as plain text by design — the Privacy Vault
/// separates entries behind a PIN rather than encrypting them — so the read
/// path should not be doing cryptography at all. These pin the two things that
/// make that safe: plain text is recognised cheaply and never mangled, and a
/// value that cannot be decrypted is returned unchanged rather than corrupted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Build a version-1 (XOR) envelope the way old builds wrote them:
  /// base64([version byte][IV][XOR-ciphertext]).
  String legacyXorEnvelope(String plain, Uint8List key) {
    final body = utf8.encode(plain);
    final iv = List<int>.filled(16, 0);
    final cipher = <int>[
      for (var i = 0; i < body.length; i++) body[i] ^ key[i % key.length],
    ];
    return base64Encode(<int>[1, ...iv, ...cipher]);
  }

  group('looksEncrypted', () {
    test('rejects ordinary prose without throwing', () {
      const samples = [
        'Had a great day at the park with friends.',
        'Coffee with Sam',
        '',
        'a',
        'Ran 5km this morning — felt good!',
        "Today's entry: shipped the release.",
      ];
      for (final text in samples) {
        expect(EncryptionService.looksEncrypted(text), isFalse,
            reason: 'plain text must not be mistaken for an envelope: $text');
      }
    });

    test('rejects base64-shaped text that is not one of our envelopes', () {
      // Valid base64, decodes fine, but the leading byte is not a version we
      // ever wrote — so it is data, not an envelope.
      final notOurs = base64Encode(List<int>.filled(40, 9));
      expect(EncryptionService.looksEncrypted(notOurs), isFalse);
    });

    test('accepts a real version-1 envelope', () {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final envelope = legacyXorEnvelope('a reasonably long secret', key);
      expect(EncryptionService.looksEncrypted(envelope), isTrue);
    });

    test('rejects anything too short to be an envelope', () {
      expect(EncryptionService.looksEncrypted(base64Encode([1, 2, 3])), isFalse);
    });
  });

  group('decrypt', () {
    test('returns plain text unchanged', () async {
      const plain = 'Had a great day at the park with friends.';
      expect(await EncryptionService().decrypt(plain), plain);
    });

    test('returns an undecryptable envelope unchanged rather than mangling it',
        () async {
      // No cached key: the value cannot be read. It must come back byte-for-byte
      // so the migration recognises "I could not decrypt this" and leaves the
      // row alone, instead of overwriting good data with garbage.
      SecurityService().lockVault();
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final envelope = legacyXorEnvelope('some private thoughts', key);

      expect(await EncryptionService().decrypt(envelope), envelope);
    });

    test('decrypts a legacy version-1 envelope when the key is available',
        () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 7));
      SecurityService().setCachedEncryptionKeyForTesting(key);
      addTearDown(() => SecurityService().lockVault());

      const plain = 'a reasonably long secret worth decrypting';
      final envelope = legacyXorEnvelope(plain, key);

      expect(await EncryptionService().decrypt(envelope), plain);
    });

    test('round-trips through the current AES envelope', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 3 + 1));
      SecurityService().setCachedEncryptionKeyForTesting(key);
      addTearDown(() => SecurityService().lockVault());

      const plain = 'drafts and encrypted backups still use this path';
      final sealed = await EncryptionService().encrypt(plain);
      expect(sealed, isNotNull);
      expect(EncryptionService.looksEncrypted(sealed!), isTrue);
      expect(await EncryptionService().decrypt(sealed), plain);
    });

    test('an empty value decrypts to empty', () async {
      expect(await EncryptionService().decrypt(''), '');
      expect(await EncryptionService().decrypt(null), '');
    });
  });

  group('key-source injection', () {
    test('works with no SecurityService involved at all', () async {
      // The point of the seam: this service is stateless apart from where its
      // key comes from, so it can be exercised standalone. Previously both key
      // lookups reached for the app-lock singleton, which meant testing any
      // cipher meant mutating global state first.
      final key = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      final service = EncryptionService.withKeySource(() => key);

      const plain = 'independent of any app-lock service';
      final sealed = await service.encrypt(plain);
      expect(await service.decrypt(sealed!), plain);
    });

    test('reports a locked vault rather than encrypting with a null key',
        () async {
      final locked = EncryptionService.withKeySource(() => null);
      expect(
        () => locked.encrypt('should not be silently written in the clear'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
