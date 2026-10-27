import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

List<int> parsePageSelection(String input, int totalPages) {
  final clean = input.trim();
  if (clean.isEmpty) {
    return List.generate(totalPages, (i) => i + 1);
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
        throw FormatException('Invalid numbers in range: "$part".');
      }
      if (start < 1) {
        throw FormatException('Page numbers cannot be less than 1.');
      }
      if (totalPages > 0 && end > totalPages) {
        throw FormatException('Page $end exceeds total pages ($totalPages).');
      }
      if (start > end) {
        throw FormatException(
          'Invalid range: $start-$end (start must be <= end).',
        );
      }
      for (int i = start; i <= end; i++) {
        result.add(i);
      }
    } else {
      final num = int.tryParse(part);
      if (num == null) {
        throw FormatException('Invalid page number: "$part".');
      }
      if (num < 1) {
        throw FormatException('Page numbers cannot be less than 1.');
      }
      if (totalPages > 0 && num > totalPages) {
        throw FormatException('Page $num exceeds total pages ($totalPages).');
      }
      result.add(num);
    }
  }

  if (result.isEmpty) {
    throw const FormatException('No valid pages selected.');
  }

  final list = result.toList()..sort();
  return list;
}

Future<Uint8List> generateSelectedPagesPdf({
  required Uint8List sourceBytes,
  required List<int> selectedPages,
}) async {
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

  final bytes = Uint8List.fromList(await newDoc.save());
  newDoc.dispose();
  sourceDoc.dispose();
  return bytes;
}

Uint8List createSamplePdf(int pageCount) {
  final doc = PdfDocument();
  for (int i = 1; i <= pageCount; i++) {
    final page = doc.pages.add();
    page.graphics.drawString(
      'Page $i Content',
      PdfStandardFont(PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(50, 50, 400, 50),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

void main() {
  test('parsePageSelection handles single pages, ranges, and validation', () {
    expect(parsePageSelection('1', 2), equals([1]));
    expect(parsePageSelection('2', 2), equals([2]));
    expect(parsePageSelection('2-4', 10), equals([2, 3, 4]));
    expect(parsePageSelection('1,3,5-7', 10), equals([1, 3, 5, 6, 7]));
    expect(parsePageSelection('2, 4, 6', 10), equals([2, 4, 6]));

    expect(() => parsePageSelection('11', 10), throwsFormatException);
    expect(() => parsePageSelection('0', 10), throwsFormatException);
    expect(() => parsePageSelection('5-3', 10), throwsFormatException);
    expect(() => parsePageSelection('abc', 10), throwsFormatException);
  });

  test(
    'generateSelectedPagesPdf generates a new PDF with only selected pages',
    () async {
      // 10-page document
      final originalBytes = createSamplePdf(10);
      final originalDoc = PdfDocument(inputBytes: originalBytes);
      expect(originalDoc.pages.count, equals(10));
      originalDoc.dispose();

      // Select pages 2, 4, 6
      final selectedPages = [2, 4, 6];
      final selectedBytes = await generateSelectedPagesPdf(
        sourceBytes: originalBytes,
        selectedPages: selectedPages,
      );

      // Verify generated document has exactly 3 pages
      final extractedDoc = PdfDocument(inputBytes: selectedBytes);
      expect(extractedDoc.pages.count, equals(3));
      extractedDoc.dispose();

      // Select only page 1 from 2-page document
      final twoPageBytes = createSamplePdf(2);
      final page1Only = await generateSelectedPagesPdf(
        sourceBytes: twoPageBytes,
        selectedPages: [1],
      );
      final doc1 = PdfDocument(inputBytes: page1Only);
      expect(doc1.pages.count, equals(1));
      doc1.dispose();

      // Select only page 2 from 2-page document
      final page2Only = await generateSelectedPagesPdf(
        sourceBytes: twoPageBytes,
        selectedPages: [2],
      );
      final doc2 = PdfDocument(inputBytes: page2Only);
      expect(doc2.pages.count, equals(1));
      doc2.dispose();
    },
  );
}
