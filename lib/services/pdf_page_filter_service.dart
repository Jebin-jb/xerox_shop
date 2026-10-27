import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service for validating page selections, parsing page range strings
/// (e.g. "1", "2-4", "1,3,5-7"), and generating a new PDF containing
/// only the requested pages for the Xerox shopkeeper.
class PdfPageFilterService {
  static final PdfPageFilterService _instance =
      PdfPageFilterService._internal();
  factory PdfPageFilterService() => _instance;
  PdfPageFilterService._internal();

  /// Parses a user-entered page selection string into a sorted, unique list of 1-indexed page numbers.
  ///
  /// Examples:
  /// - "1" -> [1]
  /// - "2" -> [2]
  /// - "2-4" -> [2, 3, 4]
  /// - "1,3,5-7" -> [1, 3, 5, 6, 7]
  /// - "2, 4, 6" -> [2, 4, 6]
  ///
  /// If [input] is empty or blank, and [totalPages] > 0, returns all pages `[1..totalPages]`.
  /// Throws [FormatException] if page numbers are invalid or exceed [totalPages].
  List<int> parsePageSelection(String input, int totalPages) {
    final clean = input.trim();
    if (clean.isEmpty) {
      if (totalPages > 0) {
        return List.generate(totalPages, (i) => i + 1);
      }
      return const [];
    }

    final parts = clean.split(',');
    final Set<int> result = {};

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length != 2) {
          throw FormatException(
            'Invalid range format: "$part". Use format like "2-4".',
          );
        }
        final start = int.tryParse(rangeParts[0].trim());
        final end = int.tryParse(rangeParts[1].trim());
        if (start == null || end == null) {
          throw FormatException('Invalid page numbers in range: "$part".');
        }
        if (start < 1) {
          throw const FormatException('Page numbers must be 1 or greater.');
        }
        if (start > end) {
          throw FormatException(
            'Invalid range "$start-$end": start page cannot be greater than end page.',
          );
        }
        if (totalPages > 0 && end > totalPages) {
          throw FormatException(
            'Page $end exceeds document total of $totalPages pages.',
          );
        }
        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      } else {
        final pageNum = int.tryParse(part);
        if (pageNum == null) {
          throw FormatException('Invalid page number: "$part".');
        }
        if (pageNum < 1) {
          throw const FormatException('Page numbers must be 1 or greater.');
        }
        if (totalPages > 0 && pageNum > totalPages) {
          throw FormatException(
            'Page $pageNum exceeds document total of $totalPages pages.',
          );
        }
        result.add(pageNum);
      }
    }

    if (result.isEmpty) {
      throw const FormatException('No valid pages entered in selection.');
    }

    final list = result.toList()..sort();
    return list;
  }

  /// Formats a list of page numbers into readable range string
  /// e.g. [2, 4, 6] -> "2, 4, 6", [1, 2, 3, 5] -> "1-3, 5"
  String formatPageRanges(List<int> pages) {
    if (pages.isEmpty) return '';
    final sorted = List<int>.from(pages.where((p) => p > 0)).toSet().toList()
      ..sort();
    if (sorted.isEmpty) return '';
    final List<String> ranges = [];
    int start = sorted[0];
    int end = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = sorted[i];
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return ranges.join(', ');
  }

  /// Generates a new PDF file containing ONLY the specified [selectedPages] from [sourceBytes].
  ///
  /// For instance:
  /// - Source PDF: 10 pages
  /// - Selected: [2, 4, 6]
  /// - Generated PDF: Exactly 3 pages
  Future<Uint8List> generateSelectedPagesPdf({
    required Uint8List sourceBytes,
    required List<int> selectedPages,
  }) async {
    if (sourceBytes.isEmpty || selectedPages.isEmpty) {
      return sourceBytes;
    }

    try {
      final sourceDoc = PdfDocument(inputBytes: sourceBytes);
      final newDoc = PdfDocument();
      newDoc.pageSettings.margins.all = 0;

      for (final pageNum in selectedPages) {
        final pageIndex = pageNum - 1;
        if (pageIndex >= 0 && pageIndex < sourceDoc.pages.count) {
          final sourcePage = sourceDoc.pages[pageIndex];
          newDoc.pageSettings.size = sourcePage.size;
          final template = sourcePage.createTemplate();
          final newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }

      final outputBytes = Uint8List.fromList(await newDoc.save());
      newDoc.dispose();
      sourceDoc.dispose();
      return outputBytes;
    } catch (e) {
      debugPrint('Error generating selected pages PDF: $e');
      return sourceBytes;
    }
  }
}
