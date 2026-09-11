import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/image_service.dart';

void main() {
  group('isNonPublicHost', () {
    test('blocks the cloud metadata endpoint', () {
      // The single most valuable address to block: on a hosted or rooted
      // device this returns credentials.
      expect(isNonPublicHost('169.254.169.254'), isTrue);
    });

    test('blocks loopback', () {
      expect(isNonPublicHost('127.0.0.1'), isTrue);
      expect(isNonPublicHost('127.1.2.3'), isTrue);
      expect(isNonPublicHost('localhost'), isTrue);
      expect(isNonPublicHost('LOCALHOST'), isTrue);
      expect(isNonPublicHost('::1'), isTrue);
      expect(isNonPublicHost('[::1]'), isTrue);
    });

    test('blocks RFC1918 private ranges', () {
      expect(isNonPublicHost('10.0.0.1'), isTrue);
      expect(isNonPublicHost('192.168.1.1'), isTrue);
      expect(isNonPublicHost('172.16.0.1'), isTrue);
      expect(isNonPublicHost('172.31.255.255'), isTrue);
    });

    test('allows public addresses adjacent to private ranges', () {
      // 172.15 and 172.32 sit just outside 172.16/12 — a range that is very
      // commonly mis-implemented as the whole of 172.
      expect(isNonPublicHost('172.15.0.1'), isFalse);
      expect(isNonPublicHost('172.32.0.1'), isFalse);
      expect(isNonPublicHost('11.0.0.1'), isFalse);
      expect(isNonPublicHost('126.0.0.1'), isFalse);
      expect(isNonPublicHost('128.0.0.1'), isFalse);
    });

    test('blocks other reserved space', () {
      expect(isNonPublicHost('0.0.0.0'), isTrue);
      expect(isNonPublicHost('100.64.0.1'), isTrue); // CGNAT
      expect(isNonPublicHost('198.18.0.1'), isTrue); // benchmarking
      expect(isNonPublicHost('224.0.0.1'), isTrue); // multicast
      expect(isNonPublicHost('255.255.255.255'), isTrue);
    });

    test('blocks local-only name suffixes', () {
      expect(isNonPublicHost('printer.local'), isTrue);
      expect(isNonPublicHost('db.internal'), isTrue);
      expect(isNonPublicHost('router.home.arpa'), isTrue);
    });

    test('blocks IPv6 unique-local and link-local', () {
      expect(isNonPublicHost('fd00::1'), isTrue);
      expect(isNonPublicHost('fc00::1'), isTrue);
      expect(isNonPublicHost('fe80::1'), isTrue);
      expect(isNonPublicHost('fe80::1%eth0'), isTrue);
    });

    test('blocks IPv4-mapped IPv6 pointing into private space', () {
      // A classic bypass: ::ffff:10.0.0.1 is 10.0.0.1 wearing a v6 costume.
      expect(isNonPublicHost('::ffff:10.0.0.1'), isTrue);
      expect(isNonPublicHost('::ffff:127.0.0.1'), isTrue);
    });

    test('allows ordinary public hosts', () {
      expect(isNonPublicHost('images.unsplash.com'), isFalse);
      expect(isNonPublicHost('upload.wikimedia.org'), isFalse);
      expect(isNonPublicHost('8.8.8.8'), isFalse);
    });

    test('treats an empty host as non-public', () {
      expect(isNonPublicHost(''), isTrue);
    });
  });

  group('validateImageUrl rejects before any network call', () {
    test('rejects non-https schemes', () async {
      final (ok, err) = await validateImageUrl('http://images.unsplash.com/a');
      expect(ok, isFalse);
      expect(err, contains('https'));
    });

    test('rejects unparseable input', () async {
      final (ok, _) = await validateImageUrl('not a url at all');
      expect(ok, isFalse);
    });

    test('rejects a private address even on an allowlisted-looking name',
        () async {
      final (ok, err) = await validateImageUrl('https://127.0.0.1/x.png');
      expect(ok, isFalse);
      expect(err, 'That address cannot be reached.');
    });

    test('rejects hosts outside the allowlist', () async {
      final (ok, err) = await validateImageUrl('https://example.com/a.png');
      expect(ok, isFalse);
      expect(err, contains('trusted sites'));
    });

    test('does not accept a lookalike domain suffix', () async {
      // "notunsplash.com" must not match "unsplash.com" via endsWith.
      final (ok, _) = await validateImageUrl('https://notunsplash.com/a.png');
      expect(ok, isFalse);
    });

    test('user-facing errors never leak internals', () async {
      final cases = [
        'http://images.unsplash.com/a',
        'https://127.0.0.1/x.png',
        'https://example.com/a.png',
        'not a url at all',
      ];
      for (final url in cases) {
        final (_, err) = await validateImageUrl(url);
        expect(err, isNotNull);
        expect(err, isNot(contains('Exception')));
        expect(err, isNot(contains('SocketException')));
        expect(err, isNot(contains('#0')));
      }
    });
  });
}
