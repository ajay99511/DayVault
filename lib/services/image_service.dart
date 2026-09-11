import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../models/types.dart';

/// Hosts an image URL may be fetched from.
///
/// This is an allowlist, and deliberately the only way in. An earlier version
/// took a `trustedDomains` override and a `userApproved` escape hatch, and
/// documented that "users can add/remove domains from app settings" — but no
/// caller ever passed either, and no such setting exists. Both were removed
/// rather than left as decoration that implied a control the app did not have.
const List<String> defaultTrustedDomains = [
  'unsplash.com',
  'wikipedia.org',
  'wikimedia.org',
  'imgur.com',
  'flickr.com',
  'pexels.com',
  'pixabay.com',
  'giphy.com',
  'github.com',
  'githubusercontent.com',
];

/// Allowed image content types for URL validation.
const List<String> allowedContentTypes = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/svg+xml',
  'image/bmp',
  'image/tiff',
  'image/avif',
];

/// Maximum allowed image size (10MB) for URL validation.
const int maxImageSizeBytes = 10 * 1024 * 1024;

/// How long to wait for the validation request before giving up.
const Duration imageValidationTimeout = Duration(seconds: 10);

/// True when [host] names the local machine or a private/reserved network.
///
/// User-supplied URLs are a server-side-request-forgery vector: an app that
/// will fetch whatever address it is handed can be pointed at a loopback
/// service, a device on the user's LAN, or a cloud metadata endpoint such as
/// `169.254.169.254`. This check runs regardless of the allowlist so that a
/// hostile or mistaken entry cannot reach inward.
///
/// It inspects IP *literals* and obviously-local names. It deliberately does
/// not resolve DNS: `dart:io` is unavailable on web, and a resolve-then-fetch
/// check is racy anyway (the name can resolve differently the second time).
/// DNS names that resolve into private space are therefore not caught here —
/// the allowlist is what covers that case.
@visibleForTesting
bool isNonPublicHost(String host) {
  final normalized = host.toLowerCase().replaceAll('[', '').replaceAll(']', '');
  if (normalized.isEmpty) return true;

  const localSuffixes = ['.localhost', '.local', '.internal', '.home.arpa'];
  if (normalized == 'localhost' ||
      localSuffixes.any(normalized.endsWith)) {
    return true;
  }

  final ipv4 = _parseIpv4(normalized);
  if (ipv4 != null) return _isPrivateIpv4(ipv4);

  if (normalized.contains(':')) return _isNonPublicIpv6(normalized);

  return false;
}

List<int>? _parseIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return null;
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return null;
    octets.add(octet);
  }
  return octets;
}

bool _isPrivateIpv4(List<int> o) {
  final a = o[0], b = o[1];
  if (a == 0) return true; // "this network"
  if (a == 10) return true; // private
  if (a == 127) return true; // loopback
  if (a == 169 && b == 254) return true; // link-local, incl. cloud metadata
  if (a == 172 && b >= 16 && b <= 31) return true; // private
  if (a == 192 && b == 168) return true; // private
  if (a == 100 && b >= 64 && b <= 127) return true; // carrier-grade NAT
  if (a == 192 && b == 0) return true; // IETF protocol assignments
  if (a == 198 && (b == 18 || b == 19)) return true; // benchmarking
  if (a >= 224) return true; // multicast and reserved
  return false;
}

bool _isNonPublicIpv6(String value) {
  final address = value.split('%').first; // strip any zone index
  if (address == '::1' || address == '::') return true;

  // IPv4-mapped (::ffff:10.0.0.1) carries an embedded v4 address.
  final mapped = address.split(':').last;
  final embedded = _parseIpv4(mapped);
  if (embedded != null) return _isPrivateIpv4(embedded);

  // fc00::/7 unique-local, fe80::/10 link-local.
  return address.startsWith('fc') ||
      address.startsWith('fd') ||
      address.startsWith('fe8') ||
      address.startsWith('fe9') ||
      address.startsWith('fea') ||
      address.startsWith('feb');
}

/// Validates an image URL before it is stored as a reference.
///
/// Checks, in order: it parses; it is HTTPS; the host is not local or private;
/// the host is on [defaultTrustedDomains]; and a HEAD request reports an
/// allowed image content type within [maxImageSizeBytes].
///
/// Returns `(isValid, userFacingError)`. The error string is shown directly in
/// the UI, so it never contains exception text or internal detail.
Future<(bool, String?)> validateImageUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) {
    return (false, 'That does not look like a valid link.');
  }

  // HTTPS only. Plain http was previously accepted, which meant the image
  // could be swapped in transit and the URL is stored and re-fetched forever.
  if (!uri.isScheme('https')) {
    return (false, 'Images must be linked over https://');
  }

  if (isNonPublicHost(uri.host)) {
    return (false, 'That address cannot be reached.');
  }

  final host = uri.host.toLowerCase();
  final isTrusted = defaultTrustedDomains.any(
    (d) => host == d || host.endsWith('.$d'),
  );
  if (!isTrusted) {
    return (
      false,
      'Images can only be linked from trusted sites '
          '(${defaultTrustedDomains.take(3).join(', ')} and similar).'
    );
  }

  final client = http.Client();
  try {
    // followRedirects: false — otherwise an allowlisted host can bounce the
    // request to any address at all, which defeats every check above.
    final request = http.Request('HEAD', uri)..followRedirects = false;
    final response = await client.send(request).timeout(imageValidationTimeout);

    // Drain so the connection can be reused/closed cleanly.
    await response.stream.drain<void>();

    if (response.statusCode >= 300 && response.statusCode < 400) {
      return (false, 'That link redirects somewhere else — use the direct '
          'image address.');
    }
    if (response.statusCode != 200) {
      return (false, 'That image could not be loaded.');
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!allowedContentTypes.any(contentType.startsWith)) {
      return (false, 'That link does not point to an image.');
    }

    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxImageSizeBytes) {
      final sizeMb = (contentLength / (1024 * 1024)).toStringAsFixed(1);
      return (false, 'That image is too large (${sizeMb}MB, max 10MB).');
    }

    return (true, null);
  } catch (_) {
    // Deliberately generic: the exception can carry host and network detail
    // that does not belong in a user-facing message.
    return (false, 'Could not reach that image. Check the link and your '
        'connection.');
  } finally {
    client.close();
  }
}

/// Helper to create an ImageReference from a web URL.
ImageReference createUrlImageRef(String url, {String? displayName}) {
  return ImageReference(
    source: url,
    type: ImageSourceType.webUrl,
    displayName: displayName,
  );
}

/// Helper to create an ImageReference from a local file path.
ImageReference createFileImageRef(String path, {String? displayName}) {
  return ImageReference(
    source: path,
    type: ImageSourceType.filePath,
    displayName: displayName,
  );
}
