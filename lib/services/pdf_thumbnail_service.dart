import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

/// High-performance lazy-loading PDF thumbnail service with in-memory caching.
class PdfThumbnailService {
  static final PdfThumbnailService _instance = PdfThumbnailService._internal();
  factory PdfThumbnailService() => _instance;
  PdfThumbnailService._internal();

  final Map<String, PdfDocument> _openDocuments = {};
  final Map<String, Map<int, Uint8List>> _pageCache = {};
  final Set<String> _failedKeys = {};

  /// Prepares or retrieves an open [PdfDocument] from bytes.
  Future<PdfDocument?> _getDocument(String key, Uint8List bytes) async {
    if (_failedKeys.contains(key)) return null;
    if (_openDocuments.containsKey(key)) {
      return _openDocuments[key];
    }
    try {
      final doc = await PdfDocument.openData(bytes);
      _openDocuments[key] = doc;
      return doc;
    } catch (e) {
      debugPrint('PdfThumbnailService: Could not open PDF document ($key): $e');
      _failedKeys.add(key);
      return null;
    }
  }

  /// Renders and caches an individual page thumbnail (1-indexed pageNumber).
  Future<Uint8List?> getPageThumbnail({
    required String documentKey,
    required Uint8List bytes,
    required int pageNumber,
    double targetWidth = 180,
    double targetHeight = 240,
  }) async {
    final cachedDocMap = _pageCache[documentKey];
    if (cachedDocMap != null && cachedDocMap.containsKey(pageNumber)) {
      return cachedDocMap[pageNumber];
    }

    if (bytes.isEmpty) return null;

    try {
      final doc = await _getDocument(documentKey, bytes);
      if (doc == null) return null;

      if (pageNumber < 1 || pageNumber > doc.pagesCount) {
        return null;
      }

      final page = await doc.getPage(pageNumber);
      final renderWidth = targetWidth > 0 ? targetWidth : (page.width * 0.35);
      final renderHeight = targetHeight > 0
          ? targetHeight
          : (page.height * 0.35);

      final pageImage = await page.render(
        width: renderWidth.clamp(120, 400),
        height: renderHeight.clamp(160, 560),
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImage != null && pageImage.bytes.isNotEmpty) {
        _pageCache.putIfAbsent(documentKey, () => {})[pageNumber] =
            pageImage.bytes;
        return pageImage.bytes;
      }
    } catch (e) {
      debugPrint('PdfThumbnailService: Error rendering page $pageNumber: $e');
    }
    return null;
  }

  /// Check if a page thumbnail is already in cache
  Uint8List? getCachedThumbnail(String documentKey, int pageNumber) {
    return _pageCache[documentKey]?[pageNumber];
  }

  /// Clears cache for a given document or all documents
  void clearDocumentCache(String documentKey) {
    _openDocuments[documentKey]?.close();
    _openDocuments.remove(documentKey);
    _pageCache.remove(documentKey);
    _failedKeys.remove(documentKey);
  }

  void clearAll() {
    for (final doc in _openDocuments.values) {
      doc.close();
    }
    _openDocuments.clear();
    _pageCache.clear();
    _failedKeys.clear();
  }
}
