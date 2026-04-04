import 'package:http/http.dart' as http;
import '../models/types.dart';

/// Trusted domain allowlist for URL image validation.
/// Users can add/remove domains from app settings.
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

/// Validates an image URL by checking:
/// 1. URL format is valid
/// 2. Domain is in trusted allowlist (or user-approved)
/// 3. Content-Type header indicates it's an image
/// 4. Content-Length is within acceptable range
///
/// Returns (isValid, errorMessage)
Future<(bool, String?)> validateImageUrl(
  String url, {
  bool userApproved = false,
  List<String>? trustedDomains,
}) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return (false, 'Invalid URL format');
    }

    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      return (false, 'URL must use http:// or https://');
    }

    // Check domain trust
    final domains = trustedDomains ?? defaultTrustedDomains;
    final host = uri.host.toLowerCase();
    final isTrusted = domains.any(
      (d) => host == d.toLowerCase() || host.endsWith('.${d.toLowerCase()}'),
    );

    if (!isTrusted && !userApproved) {
      return (
        false,
        'Domain "$host" is not in trusted list. Approve manually?'
      );
    }

    // HEAD request to validate content type and size
    final response = await http.head(uri).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode != 200) {
      return (false, 'URL returned HTTP ${response.statusCode}');
    }

    // Validate content type
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final isImage = allowedContentTypes.any((ct) => contentType.startsWith(ct));
    if (!isImage) {
      return (false, 'URL does not point to a valid image (Content-Type: $contentType)');
    }

    // Validate content size
    final contentLengthStr = response.headers['content-length'];
    if (contentLengthStr != null) {
      final contentLength = int.tryParse(contentLengthStr);
      if (contentLength != null && contentLength > maxImageSizeBytes) {
        final sizeMB = (contentLength / (1024 * 1024)).toStringAsFixed(1);
        return (false, 'Image too large: ${sizeMB}MB (max 10MB)');
      }
    }

    return (true, null);
  } catch (e) {
    return (false, 'Failed to validate URL: $e');
  }
}

/// Helper to create an ImageReference from a gallery asset ID.
ImageReference createGalleryImageRef(String assetId, {String? displayName}) {
  return ImageReference(
    source: assetId,
    type: ImageSourceType.galleryAsset,
    displayName: displayName,
  );
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
