import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ThumbnailCacheService {
  ThumbnailCacheService._();
  static final ThumbnailCacheService instance = ThumbnailCacheService._();

  final _cache = LinkedHashMap<String, Uint8List>();
  final int _maxEntries = 100;

  Future<Uint8List?> load(String path, {int maxDimension = 256}) async {
    if (path.isEmpty) return null;

    if (_cache.containsKey(path)) {
      final data = _cache.remove(path)!;
      _cache[path] = data; // refresh LRU order
      return data;
    }

    if (!await File(path).exists()) return null;

    final bytes = await compute<_ThumbnailParams, Uint8List?>(
      _generateThumbnail,
      _ThumbnailParams(path, maxDimension),
    );

    if (bytes != null) {
      _cache[path] = bytes;
      if (_cache.length > _maxEntries) {
        _cache.remove(_cache.keys.first);
      }
    }

    return bytes;
  }

  void evict(String path) {
    _cache.remove(path);
  }

  void clear() => _cache.clear();
}

class _ThumbnailParams {
  const _ThumbnailParams(this.path, this.maxDimension);

  final String path;
  final int maxDimension;
}

Future<Uint8List?> _generateThumbnail(_ThumbnailParams params) async {
  try {
    final file = File(params.path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? params.maxDimension : null,
      height: decoded.height >= decoded.width ? params.maxDimension : null,
    );

    final encoded = img.encodeJpg(resized, quality: 70);
    return Uint8List.fromList(encoded);
  } catch (_) {
    return null;
  }
}
