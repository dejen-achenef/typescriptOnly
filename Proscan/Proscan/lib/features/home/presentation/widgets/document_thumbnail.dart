// features/home/presentation/widgets/document_thumbnail.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/features/scan/core/services/preview_image_service.dart';

/// A widget that displays a downscaled preview image from an original image path.
/// 
/// This widget automatically generates and caches preview images to reduce memory pressure
/// in document lists and grids. Original images remain untouched for OCR, export, etc.
class DocumentThumbnail extends StatefulWidget {
  const DocumentThumbnail({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.width,
    this.height,
  });

  /// The original full-resolution image path
  final String imagePath;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final double? width;
  final double? height;

  @override
  State<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends State<DocumentThumbnail> {
  late Future<String> _previewFuture;
  String? _previewPath;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<String> _loadPreview() async {
    try {
      String localPath = widget.imagePath;

      // If path is a URL, download it first
      if (widget.imagePath.startsWith('http://') ||
          widget.imagePath.startsWith('https://')) {
        // Extract document ID from URL or use a hash
        final uri = Uri.parse(widget.imagePath);
        final pathSegments = uri.pathSegments;
        final documentId = pathSegments.isNotEmpty
            ? pathSegments.last.split('.').first
            : 'temp_${widget.imagePath.hashCode}';

        // Download thumbnail
        final downloadedPath = await DocumentDownloadService.instance
            .downloadThumbnail(
          url: widget.imagePath,
          documentId: documentId,
        );

        if (downloadedPath != null) {
          localPath = downloadedPath;
        } else {
          // Download failed, return original URL (will show placeholder)
          return widget.imagePath;
        }
      }

      // Check if file exists
      if (!File(localPath).existsSync()) {
        return localPath; // Fallback to original if file doesn't exist
      }

      final previewPath = await PreviewImageService.instance
          .getOrCreatePreviewPath(localPath);
      
      if (mounted) {
        setState(() => _previewPath = previewPath);
      }
      
      return previewPath;
    } catch (e) {
      // Fallback to original path on error
      return widget.imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePath.isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: _previewFuture,
      builder: (context, snapshot) {
        // Show placeholder while loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }

        // Show preview image once loaded
        if (snapshot.hasData && snapshot.data != null) {
          final path = snapshot.data!;
          
          // Verify preview file exists
          if (!File(path).existsSync()) {
            return _buildPlaceholder();
          }

          Widget image = Image.file(
            File(path),
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );

          if (widget.borderRadius != null) {
            image = ClipRRect(
              borderRadius: widget.borderRadius!,
              child: image,
            );
          }

          return image;
        }

        // Fallback to placeholder on error
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: (widget.width != null && widget.height != null)
            ? (widget.width! < widget.height! ? widget.width! * 0.3 : widget.height! * 0.3)
            : 24,
      ),
    );
  }
}

