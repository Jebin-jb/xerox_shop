import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';

void main() {
  group('DocumentAnalysisService Tests', () {
    final service = DocumentAnalysisService();
    final dummyPrices = ShopPrice(
      bwSingle: 1.0,
      bwDouble: 1.5,
      colorSingle: 5.0,
      colorDouble: 8.0,
      photocopy: 1.0,
      paper75Gsm: 0.0,
      paper100Gsm: 1.5,
      paperGlossy: 10.0,
      spiralBinding: 30.0,
      hardBinding: 150.0,
      lamination: 10.0,
      updatedAt: DateTime.now(),
    );

    test('Parses PDF with /Type /Pages /Count', () async {
      // Mock minimal PDF header with catalog and 5 pages
      const pdfText =
          '%PDF-1.4\n'
          '1 0 obj\n'
          '<< /Type /Catalog /Pages 2 0 R >>\n'
          'endobj\n'
          '2 0 obj\n'
          '<< /Type /Pages /Count 5 /Kids [3 0 R 4 0 R 5 0 R 6 0 R 7 0 R] >>\n'
          'endobj\n'
          'trailer\n'
          '<< /Root 1 0 R >>\n'
          '%%EOF';
      final bytes = Uint8List.fromList(ascii.encode(pdfText));

      final result = await service.analyzeDocument(
        fileName: 'test_assignment.pdf',
        bytes: bytes,
      );

      expect(result.totalPages, equals(5));
      expect(result.fileExtension, equals('pdf'));
      expect(result.pages.length, equals(5));
      expect(result.sheetsNeeded(doubleSided: false), equals(5));
      expect(result.sheetsNeeded(doubleSided: true), equals(3));
    });

    test('Calculates cost and mixed-color savings correctly', () {
      final pages = [
        PageAnalysis(pageNumber: 1, isColor: true), // color page: 5.0
        PageAnalysis(pageNumber: 2, isColor: false), // bw page: 1.0
        PageAnalysis(pageNumber: 3, isColor: false), // bw page: 1.0
        PageAnalysis(pageNumber: 4, isColor: false), // bw page: 1.0
      ];

      final result = DocumentAnalysisResult(
        fileName: 'report.pdf',
        fileSizeBytes: 100000,
        fileExtension: 'pdf',
        pages: pages,
        analyzedAt: DateTime.now(),
      );

      expect(result.totalPages, equals(4));
      expect(result.colorPagesCount, equals(1));
      expect(result.bwPagesCount, equals(3));

      // Single sided:
      // Mixed mode: 3 * 1.0 + 1 * 5.0 = 8.0
      final mixedCost = result.calculateCost(
        prices: dummyPrices,
        doubleSided: false,
        paperType: PaperType.standard75Gsm,
        bindingType: BindingType.none,
        copies: 1,
        lamination: false,
        mixedOptimization: true,
      );
      expect(mixedCost, equals(8.0));

      // All-Color mode: 4 * 5.0 = 20.0
      final allColorCost = result.calculateCost(
        prices: dummyPrices,
        doubleSided: false,
        paperType: PaperType.standard75Gsm,
        bindingType: BindingType.none,
        copies: 1,
        lamination: false,
        mixedOptimization: false,
      );
      expect(allColorCost, equals(20.0));

      // Potential savings = 20.0 - 8.0 = 12.0
      final savings = result.potentialSavings(
        prices: dummyPrices,
        doubleSided: false,
        paperType: PaperType.standard75Gsm,
        copies: 1,
      );
      expect(savings, equals(12.0));
    });

    test('Sample documents are removed for clean workflow', () {
      final samples = service.getSampleDocuments();
      expect(samples, isEmpty);
    });
  });
}
