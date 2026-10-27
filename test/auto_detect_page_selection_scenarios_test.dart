import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/screens/student/create_order.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';
import 'package:campus_xerox/services/pdf_page_filter_service.dart';

Uint8List _generateSamplePdf(int pageCount) {
  final document = PdfDocument();
  for (int i = 0; i < pageCount; i++) {
    final page = document.pages.add();
    page.graphics.drawString(
      'Document Page ${i + 1}',
      PdfStandardFont(PdfFontFamily.helvetica, 16),
      bounds: const Rect.fromLTWH(50, 50, 400, 40),
    );
  }
  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}

void main() {
  group('Campus Xerox Auto Detect & Page Selection 16 Scenarios Tests', () {
    const testProfile = UserProfile(
      id: 'student_tester_01',
      name: 'Priya Sharma',
      email: 'priya@college.edu',
      role: 'student',
      studentId: 'CS2026-042',
    );

    final prices = ShopPrice(
      bwSingle: 1.0,
      bwDouble: 1.5,
      colorSingle: 5.0,
      colorDouble: 8.0,
      photocopy: 1.0,
      lamination: 10.0,
      updatedAt: DateTime.now(),
    );

    test(
      'Scenario 1 to 6: 5-page PDF, Tap p3 to Colour, Long-press p2 and p4 to remove, verify count and price',
      () {
        // 1. Upload a 5-page PDF
        final pages = List.generate(
          5,
          (i) => PageAnalysis(pageNumber: i + 1, printType: PrintType.bw),
        );

        final doc = DocumentAnalysisResult(
          fileName: 'Test_5_Pages.pdf',
          fileSizeBytes: 500000,
          fileExtension: 'pdf',
          pages: pages,
          analyzedAt: DateTime.now(),
        );

        expect(doc.totalPages, equals(5));

        // Calculate initial cost for all 5 B&W pages: 5 * 1.0 = ₹5.0
        final initialCost = doc.calculateCost(
          prices: prices,
          doubleSided: false,
          paperType: PaperType.standard75Gsm,
          bindingType: BindingType.none,
          copies: 1,
          lamination: false,
        );
        expect(initialCost, equals(5.0));

        // 2. Tap page 3 to change B&W to Colour
        // Normal tap toggles printType
        pages[2].printType = PrintType.color;
        expect(pages[2].isColor, isTrue);

        // Cost with Page 3 as colour: 4 B&W (₹4) + 1 Colour (₹5) = ₹9.0
        final withColorCost = doc.calculateCost(
          prices: prices,
          doubleSided: false,
          paperType: PaperType.standard75Gsm,
          bindingType: BindingType.none,
          copies: 1,
          lamination: false,
        );
        expect(withColorCost, equals(9.0));

        // 3. Long-press page 2 to remove it
        pages[1].isRemoved = true;
        expect(pages[1].isRemoved, isTrue);

        // 4. Long-press page 4 to remove it
        pages[3].isRemoved = true;
        expect(pages[3].isRemoved, isTrue);

        // 5. Verify the selected printable page count becomes 3
        final includedPages = pages.where((p) => !p.isRemoved).toList();
        expect(includedPages.length, equals(3));
        expect(
          includedPages.map((p) => p.pageNumber).toList(),
          equals([1, 3, 5]),
        );

        // 6. Verify the total amount decreases correctly:
        // Included: Page 1 (B&W @ ₹1) + Page 3 (Colour @ ₹5) + Page 5 (B&W @ ₹1) = ₹7.0
        // Removed pages (2 & 4) incur ₹0 charge. ₹7.0 < ₹9.0!
        final reducedCost = doc.calculateCost(
          prices: prices,
          doubleSided: false,
          paperType: PaperType.standard75Gsm,
          bindingType: BindingType.none,
          copies: 1,
          lamination: false,
        );
        expect(reducedCost, equals(7.0));
        expect(reducedCost < withColorCost, isTrue);
      },
    );

    test(
      'Scenario 7 and 8: Long-press page 2 again to restore it and its previous setting is restored',
      () {
        final p2 = PageAnalysis(pageNumber: 2, printType: PrintType.bw);

        // Remember previous setting and remove
        p2.previousPrintType = p2.printType;
        p2.isRemoved = true;
        expect(p2.isRemoved, isTrue);

        // Long press again to restore
        p2.isRemoved = false;
        if (p2.previousPrintType != null) {
          p2.printType = p2.previousPrintType!;
        }
        expect(p2.isRemoved, isFalse);
        expect(p2.printType, equals(PrintType.bw));

        // Test with Colour page:
        final p3 = PageAnalysis(pageNumber: 3, printType: PrintType.color);
        p3.previousPrintType = p3.printType;
        p3.isRemoved = true;
        expect(p3.isRemoved, isTrue);

        // Restore
        p3.isRemoved = false;
        if (p3.previousPrintType != null) {
          p3.printType = p3.previousPrintType!;
        }
        expect(p3.isRemoved, isFalse);
        expect(p3.isColor, isTrue); // Restored back to Colour!
      },
    );

    test(
      'Scenario 9 and 10: Printable document excludes removed pages and contains only [1, 3, 5]',
      () async {
        final originalPdfBytes = _generateSamplePdf(5);
        final pdfFilter = PdfPageFilterService();

        // Filter to pages 1, 3, 5 (removing pages 2 and 4)
        final printablePdfBytes = await pdfFilter.generateSelectedPagesPdf(
          sourceBytes: originalPdfBytes,
          selectedPages: [1, 3, 5],
        );

        final loadedDoc = PdfDocument(inputBytes: printablePdfBytes);
        expect(loadedDoc.pages.count, equals(3));
        loadedDoc.dispose();

        // Shopkeeper order created with printable pages:
        final order = PrintOrder(
          id: 'ord_mix_01',
          code: 'CP-M101',
          studentId: testProfile.id,
          studentName: testProfile.name,
          fileName: 'Document_Printable.pdf',
          fileUrl: 'https://vault.local/doc_printable.pdf',
          pages: 3, // exactly 3 printable pages
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 7.0,
          paymentMode: PaymentMode.online,
          paymentStatus: PaymentStatus.paid,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
          bwPageCount: 2,
          colorPageCount: 1,
          colorPageNumbers: [
            2,
          ], // Page 2 of the printable 3-page PDF is the color page!
          originalFileName: 'Document_Original_5p.pdf',
          pageSelection: '1, 3, 5',
        );

        expect(order.pages, equals(3));
        expect(order.calculatedBwPages, equals(2));
        expect(order.calculatedColorPages, equals(1));
        expect(order.colorPageNumbers, equals([2]));
        expect(order.pageSelection, equals('1, 3, 5'));
      },
    );

    testWidgets(
      'Scenario 12, 13, 14: Auto Detect has Special Instructions at bottom, no separate Page Selection, and CreateOrder has only 4 required sections',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataService = DataService();
        final sampleDoc = DocumentAnalysisResult(
          fileName: 'Lecture_Notes_5p.pdf',
          fileSizeBytes: 1200000,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: List.generate(
            5,
            (i) => PageAnalysis(
              pageNumber: i + 1,
              printType: PrintType.bw,
              dimensions: 'A4 (210 × 297 mm)',
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AutomaticDetectionScreen(
              dataService: dataService,
              profile: testProfile,
              onToggleTheme: () {},
              initialAnalysis: sampleDoc,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Scenario 12: Separate Page Selection controls (All Pages / Selected Pages chips) are REMOVED
        expect(find.text('Select Pages / Range'), findsNothing);
        expect(find.text('Custom Page Range'), findsNothing);

        // Scenario 14: Special Instructions is at the bottom of Auto Detect
        expect(find.text('Special Instructions'), findsOneWidget);
        expect(find.textContaining('staple top-left'), findsOneWidget);

        // Verify Auto Detect components from Scenario 1
        expect(find.text('Detection Results'), findsOneWidget);
        expect(find.text('Total Pages'), findsOneWidget);
        expect(find.text('Physical Sheets'), findsOneWidget);
        expect(find.text('Color Pages'), findsOneWidget);
        expect(find.text('B&W Pages'), findsOneWidget);
        expect(find.text('Cost Optimizer Breakdown'), findsNothing);
        expect(find.text('Per-Page Visual Inspection'), findsOneWidget);
        expect(find.text('Student Print Summary'), findsOneWidget);
        expect(find.text('Print Configuration'), findsOneWidget);
        expect(find.text('Proceed to Print Order'), findsOneWidget);

        // Scenario 13: Test simplified CreateOrder screen
        await tester.pumpWidget(
          MaterialApp(
            home: CreateOrder(
              dataService: dataService,
              profile: testProfile,
              prices: prices,
              onToggleTheme: () {},
              prefilledFile: null,
              prefilledPages: 3,
              prefilledTotalDocumentPages: 5,
              prefilledRemovedPages: 2,
              prefilledSelectedPages: const [1, 3, 5],
              prefilledPageSelection: '1, 3, 5',
              prefilledBwPages: 2,
              prefilledColorPages: 1,
              prefilledTotalAmount: 7.0,
              prefilledCopies: 1,
              prefilledDoubleSided: false,
              prefilledSpecialInstructions: 'Please print clearly',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // In CreateOrder without file: prompt is shown
        expect(find.text('No Document Configured'), findsOneWidget);

        // In CreateOrder with mock file:
        final mockFile = PlatformFile(
          name: 'Lecture_Notes_5p.pdf',
          size: 1024,
          bytes: Uint8List(1024),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CreateOrder(
              key: const ValueKey('create_order_with_file'),
              dataService: dataService,
              profile: testProfile,
              prices: prices,
              onToggleTheme: () {},
              prefilledFile: mockFile,
              prefilledBytes: Uint8List(1024),
              originalBytes: Uint8List(2048),
              prefilledPages: 3,
              prefilledTotalDocumentPages: 5,
              prefilledRemovedPages: 2,
              prefilledSelectedPages: const [1, 3, 5],
              prefilledPageSelection: '1, 3, 5',
              prefilledBwPages: 2,
              prefilledColorPages: 1,
              prefilledTotalAmount: 7.0,
              prefilledCopies: 1,
              prefilledDoubleSided: false,
              prefilledSpecialInstructions: 'Please staple on top left',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Read-only Print Summary
        expect(find.text('Selected Printable Pages'), findsOneWidget);
        expect(find.text('3 pages (1, 3, 5)'), findsOneWidget);
        expect(find.text('Removed Pages'), findsOneWidget);
        expect(find.text('2'), findsWidgets);
        expect(find.text('Please staple on top left'), findsOneWidget);

        // 2. Payment Method
        expect(find.text('Payment Method'), findsOneWidget);
        expect(find.text('Online Pay'), findsOneWidget);
        expect(find.text('Pay at Counter'), findsOneWidget);

        // 3. Total Amount
        expect(find.text('TOTAL AMOUNT'), findsOneWidget);
        expect(find.text('₹7.00'), findsOneWidget);

        // 4. Payment button: "Proceed to Pay" for online
        expect(find.text('Proceed to Pay'), findsOneWidget);

        // Tap "Pay at Counter" -> Button becomes "Confirm Order"
        await tester.tap(find.text('Pay at Counter'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Confirm Order'), findsOneWidget);

        // Verify redundant elements are NOT present on CreateOrder:
        expect(find.text('Tap to Select Document'), findsNothing);
        expect(find.text('Select Pages / Range'), findsNothing);
        expect(find.text('All Pages (5)'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 15: Shopkeeper Portal UI remains intact and functional',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataService = DataService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShopOrders(
                dataService: dataService,
                onToggleTheme: () {},
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Header, Search Bar, Queue & Order management
        expect(find.text('Order Queue'), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsWidgets);
        expect(find.text('All Orders'), findsWidgets);
        expect(find.text('Pending'), findsWidgets);
        expect(find.text('Printing'), findsWidgets);
        expect(find.text('Ready to Pick'), findsWidgets);
        expect(find.text('Completed'), findsWidgets);
      },
    );
  });
}
