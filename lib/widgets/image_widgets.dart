import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/types.dart';
import '../config/constants.dart';

/// A reusable widget that renders an image thumbnail from any source type
/// (gallery asset, web URL, or local file) with loading spinner and error fallback.
class ImageThumbnailWidget extends StatefulWidget {
  final ImageReference imageRef;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showTapToZoom;
  final VoidCallback? onDelete;
  final BorderRadius? borderRadius;

  const ImageThumbnailWidget({
    super.key,
    required this.imageRef,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showTapToZoom = false,
    this.onDelete,
    this.borderRadius,
  });

  /// Resolve the physical-pixel dimension to decode an image to, so we never
  /// decode a multi-megapixel source just to paint a small thumbnail. Scales
  /// the on-screen logical size by [devicePixelRatio], falling back to
  /// [fallbackLogical] when the widget has no intrinsic size, and clamps to a
  /// sane range. Pure + exposed for unit testing.
  static int resolveCacheDimension(
    double? logicalSize,
    double devicePixelRatio, {
    double fallbackLogical = 400,
  }) {
    final logical = (logicalSize != null &&
            logicalSize.isFinite &&
            logicalSize > 0)
        ? logicalSize
        : fallbackLogical;
    final dpr = (devicePixelRatio.isFinite && devicePixelRatio > 0)
        ? devicePixelRatio
        : 1.0;
    return (logical * dpr).ceil().clamp(1, 4096);
  }

  @override
  State<ImageThumbnailWidget> createState() => _ImageThumbnailWidgetState();
}

class _ImageThumbnailWidgetState extends State<ImageThumbnailWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.showTapToZoom ? () => _openFullscreen(context) : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: widget.width != null && widget.height != null
                ? StackFit.expand
                : StackFit.passthrough,
            children: [
              _buildImage(),
              if (widget.onDelete != null) _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Physical-pixel decode bound for the current on-screen size.
  int _cacheDimension(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    // Prefer the larger declared dimension (cover fit fills the larger side).
    final logical = [widget.width, widget.height]
        .whereType<double>()
        .fold<double?>(null, (m, v) => m == null ? v : (v > m ? v : m));
    return ImageThumbnailWidget.resolveCacheDimension(logical, dpr);
  }

  Widget _buildImage() {
    switch (widget.imageRef.type) {
      case ImageSourceType.galleryAsset:
        return _buildGalleryImage();
      case ImageSourceType.webUrl:
        return _buildUrlImage();
      case ImageSourceType.filePath:
        return _buildFileImage();
    }
  }

  Widget _buildGalleryImage() {
    final cacheDim = _cacheDimension(context);
    return FutureBuilder<Uint8List?>(
      future: _loadGalleryThumbnail(cacheDim),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
            gaplessPlayback: true,
            // Downsize decode to the on-screen size.
            cacheWidth: cacheDim,
          );
        }
        return _buildErrorWidget();
      },
    );
  }

  Future<Uint8List?> _loadGalleryThumbnail(int cacheDim) async {
    try {
      final asset = await AssetEntity.fromId(widget.imageRef.source);
      if (asset == null) return null;
      // Thumbnail-first: request a thumbnail sized to the display, not the
      // full-resolution original.
      return await asset.thumbnailDataWithSize(
        ThumbnailSize.square(cacheDim),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildUrlImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageRef.source,
      fit: widget.fit,
      // Bound the in-memory decode to display size.
      memCacheWidth: _cacheDimension(context),
      placeholder: (context, url) => _buildLoadingIndicator(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildFileImage() {
    return Image.file(
      _toFile(widget.imageRef.source),
      fit: widget.fit,
      // Decode the (possibly large) original file down to display size.
      cacheWidth: _cacheDimension(context),
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }

  File _toFile(String path) => File(path);

  Widget _buildLoadingIndicator() {
    return Container(
      color: AppColors.slate900.withAlpha(128),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.indigo500,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: AppColors.slate900,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: AppColors.slate400,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      top: 4,
      right: 4,
      child: GestureDetector(
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppColors.rose500,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImagePage(imageRef: widget.imageRef),
      ),
    );
  }
}

/// Fullscreen image viewer with pinch-to-zoom.
class _FullscreenImagePage extends StatelessWidget {
  final ImageReference imageRef;

  const _FullscreenImagePage({required this.imageRef});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: _buildImage(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    switch (imageRef.type) {
      case ImageSourceType.galleryAsset:
        return _FullscreenGalleryImage(assetId: imageRef.source);
      case ImageSourceType.webUrl:
        return CachedNetworkImage(
          imageUrl: imageRef.source,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        );
      case ImageSourceType.filePath:
        return Image.file(
          File(imageRef.source),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        );
    }
  }
}

class _FullscreenGalleryImage extends StatefulWidget {
  final String assetId;
  const _FullscreenGalleryImage({required this.assetId});

  @override
  State<_FullscreenGalleryImage> createState() => _FullscreenGalleryImageState();
}

class _FullscreenGalleryImageState extends State<_FullscreenGalleryImage> {
  Uint8List? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    try {
      final asset = await AssetEntity.fromId(widget.assetId);
      if (asset == null) return;

      final file = await asset.originFile;
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageData = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }
    if (_imageData == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }
    return Image.memory(
      _imageData!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
