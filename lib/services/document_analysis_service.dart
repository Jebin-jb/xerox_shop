import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/app_models.dart';

class PageAnalysis {
  final int pageNumber;
  PrintType printType;
  bool isBlank;
  bool isRemoved;
  PrintType? previousPrintType;
  String orientation; // 'Portrait' or 'Landscape'
  final double estimatedCoverage; // 0.0 to 1.0 (ink coverage)
  final String dimensions; // e.g. "A4 (210 x 297 mm)"

  bool get isColor => printType == PrintType.color;
  set isColor(bool value) {
    printType = value ? PrintType.color : PrintType.bw;
  }

  PageAnalysis({
    required this.pageNumber,
    PrintType? printType,
    bool? isColor,
    this.isBlank = false,
    this.isRemoved = false,
    this.previousPrintType,
    this.orientation = 'Portrait',
    this.estimatedCoverage = 0.12,
    this.dimensions = 'A4 (210 × 297 mm)',
  }) : printType =
           printType ?? ((isColor ?? false) ? PrintType.color : PrintType.bw);

  PageAnalysis copyWith({
    int? pageNumber,
    PrintType? printType,
    bool? isColor,
    bool? isBlank,
    bool? isRemoved,
    PrintType? previousPrintType,
    String? orientation,
    double? estimatedCoverage,
    String? dimensions,
  }) {
    return PageAnalysis(
      pageNumber: pageNumber ?? this.pageNumber,
      printType:
          printType ??
          (isColor != null
              ? (isColor ? PrintType.color : PrintType.bw)
              : this.printType),
      isBlank: isBlank ?? this.isBlank,
      isRemoved: isRemoved ?? this.isRemoved,
      previousPrintType: previousPrintType ?? this.previousPrintType,
      orientation: orientation ?? this.orientation,
      estimatedCoverage: estimatedCoverage ?? this.estimatedCoverage,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  PagePrintSetting toPrintSetting({double? unitPrice}) => PagePrintSetting(
    pageNumber: pageNumber,
    printType: printType,
    unitPrice: unitPrice ?? 0.0,
    orientation: orientation,
    isRemoved: isRemoved,
  );
}

class DocumentAnalysisResult {
  final String fileName;
  final int fileSizeBytes;
  final String fileExtension;
  final List<PageAnalysis> pages;
  final DateTime analyzedAt;
  final bool isAccuratePdf;

  DocumentAnalysisResult({
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileExtension,
    required this.pages,
    required this.analyzedAt,
    this.isAccuratePdf = true,
  });

  int get totalPages => pages.length;

  int get colorPagesCount =>
      pages.where((p) => !p.isRemoved && p.isColor && !p.isBlank).length;

  int get bwPagesCount =>
      pages.where((p) => !p.isRemoved && !p.isColor && !p.isBlank).length;

  int get removedPagesCount => pages.where((p) => p.isRemoved).length;

  int get blankPagesCount => pages.where((p) => p.isBlank).length;

  int get activePrintablePages =>
      pages.where((p) => !p.isRemoved && !p.isBlank).length;

  List<int> get colorPageNumbers => pages
      .where((p) => !p.isRemoved && p.isColor && !p.isBlank)
      .map((p) => p.pageNumber)
      .toList();

  List<PagePrintSetting> toPagePrintSettings({
    ShopPrice? prices,
    bool doubleSided = false,
  }) {
    return pages.where((p) => !p.isRemoved).map((p) {
      final double? unitPrice = prices != null
          ? (p.isColor
                ? (doubleSided ? prices.colorDouble : prices.colorSingle)
                : (doubleSided ? prices.bwDouble : prices.bwSingle))
          : null;
      return PagePrintSetting(
        pageNumber: p.pageNumber,
        printType: p.printType,
        unitPrice: unitPrice ?? 0.0,
        orientation: p.orientation,
        isRemoved: p.isRemoved,
      );
    }).toList();
  }

  int sheetsNeeded({required bool doubleSided, bool skipBlankPages = false}) {
    final effectivePages = pages
        .where((p) => !p.isRemoved && (!skipBlankPages || !p.isBlank))
        .length;
    if (effectivePages <= 0) return 0;
    if (doubleSided) {
      return (effectivePages / 2).ceil();
    }
    return effectivePages;
  }

  /// Calculates cost with live ShopPrice rates:
  /// Compares pure All-Color mode vs Smart Mixed-Color optimization.
  double calculateCost({
    required ShopPrice prices,
    required bool doubleSided,
    required PaperType paperType,
    required BindingType bindingType,
    required int copies,
    required bool lamination,
    bool mixedOptimization = true,
    bool skipBlankPages = false,
  }) {
    final effectivePages = pages
        .where((p) => !p.isRemoved && (!skipBlankPages || !p.isBlank))
        .toList();
    if (effectivePages.isEmpty) return 0.0;

    final paperExtra = prices.paperExtra(paperType);
    final bindingExtra = prices.bindingPrice(bindingType) * copies;
    final laminationExtra = (lamination ? prices.lamination * copies : 0.0);

    double printTotal = 0.0;

    if (!mixedOptimization) {
      // If user chooses standard all-color or all-bw
      final anyColor = effectivePages.any((p) => p.isColor);
      final rate =
          prices.printRate(color: anyColor, doubleSided: doubleSided) +
          paperExtra;
      printTotal = effectivePages.length * rate * copies;
    } else {
      // Smart Mixed Optimization: Color pages billed at color rate, B&W pages billed at B&W rate
      final bwRate =
          prices.printRate(color: false, doubleSided: doubleSided) + paperExtra;
      final colorRate =
          prices.printRate(color: true, doubleSided: doubleSided) + paperExtra;

      int colorCount = 0;
      int bwCount = 0;

      for (final p in effectivePages) {
        if (p.isColor) {
          colorCount++;
        } else {
          bwCount++;
        }
      }

      printTotal = ((bwCount * bwRate) + (colorCount * colorRate)) * copies;
    }

    return printTotal + bindingExtra + laminationExtra;
  }

  /// Savings realized by detecting and printing monochrome pages as B&W instead of full color.
  double potentialSavings({
    required ShopPrice prices,
    required bool doubleSided,
    required PaperType paperType,
    required int copies,
  }) {
    if (colorPagesCount == 0 || bwPagesCount == 0) return 0.0;

    final fullColorCost = calculateCost(
      prices: prices,
      doubleSided: doubleSided,
      paperType: paperType,
      bindingType: BindingType.none,
      copies: copies,
      lamination: false,
      mixedOptimization: false,
    );

    final optimizedCost = calculateCost(
      prices: prices,
      doubleSided: doubleSided,
      paperType: paperType,
      bindingType: BindingType.none,
      copies: copies,
      lamination: false,
      mixedOptimization: true,
    );

    return max(0.0, fullColorCost - optimizedCost);
  }
}

class DocumentAnalysisService {
  static final DocumentAnalysisService _instance =
      DocumentAnalysisService._internal();
  factory DocumentAnalysisService() => _instance;
  DocumentAnalysisService._internal();

  /// Analyzes a document given its file name and byte content
  Future<DocumentAnalysisResult> analyzeDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();

    if (ext == 'pdf' && bytes.isNotEmpty) {
      return _analyzePdfBytes(fileName, bytes);
    } else if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
      return _analyzeImageBytes(fileName, bytes, ext);
    } else {
      // Word (doc/docx), PPT (ppt/pptx), or other text files
      return _analyzeGenericDocument(fileName, bytes, ext);
    }
  }

  /// Fast and robust pure-Dart PDF structure analyzer
  DocumentAnalysisResult _analyzePdfBytes(String fileName, Uint8List bytes) {
    int detectedPages = 0;
    final List<PageAnalysis> pageList = [];

    // 1. Try high-fidelity geometry and orientation extraction with syncfusion_flutter_pdf
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      if (count > 0) {
        for (int i = 0; i < count; i++) {
          final page = doc.pages[i];
          double w = page.size.width;
          double h = page.size.height;
          final rot = page.rotation;
          if (rot == sf.PdfPageRotateAngle.rotateAngle90 ||
              rot == sf.PdfPageRotateAngle.rotateAngle270) {
            final t = w;
            w = h;
            h = t;
          }
          final isLandscape = w > h;
          final orientation = isLandscape ? 'Landscape' : 'Portrait';
          final dimStr = isLandscape
              ? 'Landscape (${w.toInt()} × ${h.toInt()} pt)'
              : 'Portrait (${w.toInt()} × ${h.toInt()} pt)';

          pageList.add(
            PageAnalysis(
              pageNumber: i + 1,
              printType: PrintType.bw,
              isBlank: false,
              orientation: orientation,
              estimatedCoverage: 0.11,
              dimensions: dimStr,
            ),
          );
        }
        doc.dispose();

        return DocumentAnalysisResult(
          fileName: fileName,
          fileSizeBytes: bytes.length,
          fileExtension: 'pdf',
          pages: pageList,
          analyzedAt: DateTime.now(),
          isAccuratePdf: true,
        );
      }
      doc.dispose();
    } catch (e) {
      debugPrint('Syncfusion PDF analysis fallback: $e');
    }

    try {
      final length = bytes.length;
      final sampleString = _extractScanString(bytes, length);

      // Strategy 1: Look for /Count in /Pages catalog
      final countRegex = RegExp(
        r'/Type\s*/Pages[^\>]*?/Count\s+(\d+)',
        caseSensitive: false,
      );
      final countMatch = countRegex.firstMatch(sampleString);
      if (countMatch != null && countMatch.group(1) != null) {
        final parsed = int.tryParse(countMatch.group(1)!);
        if (parsed != null && parsed > 0 && parsed < 2000) {
          detectedPages = parsed;
        }
      }

      // Strategy 2: If strategy 1 was not conclusive, scan for /Type /Page occurrences
      if (detectedPages <= 0) {
        final pageObjectRegex = RegExp(
          r'/Type\s*/Page\b(?!s)',
          caseSensitive: false,
        );
        final matches = pageObjectRegex.allMatches(sampleString);
        if (matches.isNotEmpty) {
          detectedPages = matches.length;
        }
      }

      // Strategy 3: General fallback search for /Count (\d+) anywhere in trailer/catalog
      if (detectedPages <= 0) {
        final countFallback = RegExp(r'/Count\s+(\d+)', caseSensitive: false);
        for (final m in countFallback.allMatches(sampleString)) {
          final c = int.tryParse(m.group(1) ?? '');
          if (c != null && c > detectedPages && c < 2000) {
            detectedPages = c;
          }
        }
      }

      // If still not found, estimate based on standard PDF size (approx 45 KB per page)
      if (detectedPages <= 0) {
        detectedPages = max(1, (length / 45000).round());
      }

      // Build per-page details: Every page defaults to B&W as requested,
      // so the student starts with all B&W pages and can independently toggle pages.
      for (int i = 1; i <= detectedPages; i++) {
        pageList.add(
          PageAnalysis(
            pageNumber: i,
            printType: PrintType.bw,
            isBlank: false,
            orientation: 'Portrait',
            estimatedCoverage: 0.11,
            dimensions: 'A4 (210 × 297 mm)',
          ),
        );
      }

      return DocumentAnalysisResult(
        fileName: fileName,
        fileSizeBytes: bytes.length,
        fileExtension: 'pdf',
        pages: pageList,
        analyzedAt: DateTime.now(),
        isAccuratePdf: true,
      );
    } catch (_) {
      return _generateFallbackResult(
        fileName,
        bytes.length,
        'pdf',
        max(1, (bytes.length / 50000).round()),
      );
    }
  }

  /// Analyzes image files (JPG, PNG, etc.)
  DocumentAnalysisResult _analyzeImageBytes(
    String fileName,
    Uint8List bytes,
    String ext,
  ) {
    bool isColor = true;

    if (bytes.length > 30) {
      if (ext == 'png' && bytes[0] == 0x89 && bytes[1] == 0x50) {
        final colorType = bytes[25];
        if (colorType == 0 || colorType == 4) {
          isColor = false;
        }
      }
    }

    final pages = [
      PageAnalysis(
        pageNumber: 1,
        isColor: isColor,
        isBlank: false,
        orientation: 'Portrait',
        estimatedCoverage: 0.45,
        dimensions: 'Photo / A4 High-Res',
      ),
    ];

    return DocumentAnalysisResult(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      fileExtension: ext,
      pages: pages,
      analyzedAt: DateTime.now(),
      isAccuratePdf: false,
    );
  }

  /// Analyzes Word / PPT / generic documents
  DocumentAnalysisResult _analyzeGenericDocument(
    String fileName,
    Uint8List bytes,
    String ext,
  ) {
    int estimatedPages = 1;
    final sizeKb = bytes.length / 1024;

    if (ext.contains('ppt')) {
      estimatedPages = max(1, (sizeKb / 120).round());
    } else if (ext.contains('doc')) {
      estimatedPages = max(1, (sizeKb / 45).round());
    } else {
      estimatedPages = max(1, (sizeKb / 30).round());
    }

    return _generateFallbackResult(
      fileName,
      bytes.length,
      ext,
      min(50, estimatedPages),
    );
  }

  DocumentAnalysisResult _generateFallbackResult(
    String fileName,
    int fileSizeBytes,
    String ext,
    int pageCount,
  ) {
    final List<PageAnalysis> list = [];
    final safePages = max(1, pageCount);

    for (int i = 1; i <= safePages; i++) {
      list.add(
        PageAnalysis(
          pageNumber: i,
          printType: PrintType.bw,
          isBlank: false,
          orientation: 'Portrait',
          estimatedCoverage: 0.12,
          dimensions: 'A4 (210 × 297 mm)',
        ),
      );
    }

    return DocumentAnalysisResult(
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      fileExtension: ext,
      pages: list,
      analyzedAt: DateTime.now(),
      isAccuratePdf: ext == 'pdf',
    );
  }

  String _extractScanString(Uint8List bytes, int length) {
    final scanLen = min(length, 2 * 1024 * 1024);
    final buffer = StringBuffer();
    for (int i = 0; i < scanLen; i++) {
      final b = bytes[i];
      if (b >= 32 && b <= 126) {
        buffer.writeCharCode(b);
      } else if (b == 10 || b == 13 || b == 9) {
        buffer.writeCharCode(b);
      }
    }
    return buffer.toString();
  }

  // Pre-loaded sample documents removed to keep only real document workflow
  List<DocumentAnalysisResult> getSampleDocuments() => const [];
}
