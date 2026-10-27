import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';

void main() {
  group('Per-Page Print Configuration & 111-Page PDF Tests', () {
    test(
      'Utility: formatPageRanges correctly formats single pages and consecutive sequences',
      () {
        expect(formatPageRanges([]), equals(''));
        expect(formatPageRanges([5]), equals('5'));
        expect(formatPageRanges([1, 2, 3, 4, 5]), equals('1-5'));
        expect(
          formatPageRanges([3, 18, 47, 78, 111]),
          equals('3, 18, 47, 78, 111'),
        );
        expect(
          formatPageRanges([3, 18, 19, 20, 21, 22, 47, 78, 79, 80, 81, 111]),
          equals('3, 18-22, 47, 78-81, 111'),
        );
      },
    );

    test(
      '111-Page PDF: Initial state is 100% B&W, independent per-page toggle behavior',
      () {
        // 1. Initial State: All 111 pages default to B&W
        final List<PageAnalysis> pages = List.generate(
          111,
          (i) => PageAnalysis(pageNumber: i + 1, printType: PrintType.bw),
        );

        final doc = DocumentAnalysisResult(
          fileName: 'Engineering_111_Pages.pdf',
          fileSizeBytes: 15000000,
          fileExtension: 'pdf',
          pages: pages,
          analyzedAt: DateTime.now(),
        );

        expect(doc.totalPages, equals(111));
        expect(doc.bwPagesCount, equals(111));
        expect(doc.colorPagesCount, equals(0));
        expect(doc.colorPageNumbers, isEmpty);

        // 2. Change ONLY Page 3 to Color
        // Index 2 corresponds to Page 3
        pages[2].isColor = true;

        expect(pages[2].isColor, isTrue);
        expect(pages[0].isColor, isFalse); // Page 1 remains B&W
        expect(pages[1].isColor, isFalse); // Page 2 remains B&W
        expect(pages[3].isColor, isFalse); // Page 4 remains B&W
        expect(doc.colorPagesCount, equals(1));
        expect(doc.bwPagesCount, equals(110));
        expect(doc.colorPageNumbers, equals([3]));

        // 3. Change Page 18, 47, 78, 111 to Color
        pages[17].isColor = true; // Page 18
        pages[46].isColor = true; // Page 47
        pages[77].isColor = true; // Page 78
        pages[110].isColor = true; // Page 111

        expect(doc.colorPagesCount, equals(5));
        expect(doc.bwPagesCount, equals(106));
        expect(doc.colorPageNumbers, equals([3, 18, 47, 78, 111]));
        expect(
          formatPageRanges(doc.colorPageNumbers),
          equals('3, 18, 47, 78, 111'),
        );

        // 4. Change Page 47 back to B&W
        pages[46].isColor = false; // Page 47 -> B&W

        expect(doc.colorPagesCount, equals(4));
        expect(doc.bwPagesCount, equals(107));
        expect(doc.colorPageNumbers, equals([3, 18, 78, 111]));

        // 5. Change Page 18 back to B&W
        pages[17].isColor = false; // Page 18 -> B&W

        expect(doc.colorPagesCount, equals(3));
        expect(doc.bwPagesCount, equals(108));
        expect(doc.colorPageNumbers, equals([3, 78, 111]));
      },
    );

    test('Exact Price Calculation: 111 pages (106 B&W @ ₹1, 5 Color @ ₹5)', () {
      final prices = ShopPrice(
        bwSingle: 1.0,
        bwDouble: 1.5,
        colorSingle: 5.0,
        colorDouble: 8.0,
        photocopy: 1.0,
        lamination: 10.0,
        updatedAt: DateTime.now(),
      );

      final pages = List.generate(
        111,
        (i) => PageAnalysis(pageNumber: i + 1, printType: PrintType.bw),
      );

      // Set pages 3, 18, 47, 78, 111 to Color
      for (final pNum in [3, 18, 47, 78, 111]) {
        pages[pNum - 1].isColor = true;
      }

      final doc = DocumentAnalysisResult(
        fileName: 'Campus_Project_111.pdf',
        fileSizeBytes: 12000000,
        fileExtension: 'pdf',
        pages: pages,
        analyzedAt: DateTime.now(),
      );

      expect(doc.bwPagesCount, equals(106));
      expect(doc.colorPagesCount, equals(5));

      // Single sided, 1 copy:
      // 106 B&W * ₹1 = ₹106
      // 5 Color * ₹5 = ₹25
      // Total = ₹131
      final costSingle1Copy = doc.calculateCost(
        prices: prices,
        doubleSided: false,
        paperType: PaperType.standard75Gsm,
        bindingType: BindingType.none,
        copies: 1,
        lamination: false,
      );
      expect(costSingle1Copy, equals(131.0));

      // Single sided, 2 copies:
      // ₹131 * 2 = ₹262
      final costSingle2Copies = doc.calculateCost(
        prices: prices,
        doubleSided: false,
        paperType: PaperType.standard75Gsm,
        bindingType: BindingType.none,
        copies: 2,
        lamination: false,
      );
      expect(costSingle2Copies, equals(262.0));
    });

    test(
      'Supabase Order Storage & Serialization: Stores per-page details & ranges',
      () {
        final colorPages = [3, 18, 47, 78, 111];
        final pageSettings = List.generate(
          111,
          (i) => PagePrintSetting(
            pageNumber: i + 1,
            printType: colorPages.contains(i + 1)
                ? PrintType.color
                : PrintType.bw,
            unitPrice: colorPages.contains(i + 1) ? 5.0 : 1.0,
          ),
        );

        final order = PrintOrder(
          id: 'order_test_111',
          code: 'CP-X683',
          studentId: 'STU101',
          studentName: 'Rahul Verma',
          fileName: 'Project_Report_111.pdf',
          fileUrl: 'https://vault.example.com/project.pdf',
          pages: 111,
          copies: 2,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 262.0,
          paymentMode: PaymentMode.online,
          paymentStatus: PaymentStatus.paid,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
          bwPageCount: 106,
          colorPageCount: 5,
          colorPageNumbers: colorPages,
          pageSettings: pageSettings,
        );

        final map = order.toMap();
        expect(map['bw_page_count'], equals(106));
        expect(map['color_page_count'], equals(5));
        expect(map['color_page_numbers'], equals([3, 18, 47, 78, 111]));
        expect((map['page_settings'] as List).length, equals(111));

        // Deserialize back from Map
        final deserialized = PrintOrder.fromMap(order.id, map);
        expect(deserialized.pages, equals(111));
        expect(deserialized.calculatedBwPages, equals(106));
        expect(deserialized.calculatedColorPages, equals(5));
        expect(deserialized.colorPageNumbers, equals([3, 18, 47, 78, 111]));
        expect(
          deserialized.formattedColorPageRanges,
          equals('3, 18, 47, 78, 111'),
        );
        expect(deserialized.pageSettings.length, equals(111));
        expect(
          deserialized.pageSettings[2].printType,
          equals(PrintType.color),
        ); // Page 3 is Color
        expect(
          deserialized.pageSettings[0].printType,
          equals(PrintType.bw),
        ); // Page 1 is B&W
      },
    );

    test(
      'Two-Device Sync: Shopkeeper receives identical page settings from Supabase JSON',
      () {
        // JSON payload exactly as received from Supabase PostgreSQL print_orders table
        final supabaseJson = {
          'id': 'order_sync_111',
          'code': 'CP-X683',
          'student_id': 'STU202',
          'student_name': 'Ananya Sharma',
          'student_email': 'ananya@college.edu',
          'file_name': 'Semester_Thesis_111p.pdf',
          'file_url': 'https://storage.supabase.co/orders/doc.pdf',
          'pages': 111,
          'copies': 1,
          'color': true,
          'double_sided': false,
          'total': 131.0,
          'payment_mode': 'counter',
          'payment_status': 'unpaid',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'bw_page_count': 106,
          'color_page_count': 5,
          'color_page_numbers': [3, 18, 47, 78, 111],
          'page_settings': [
            {'pageNumber': 1, 'printType': 'bw', 'unitPrice': 1.0},
            {'pageNumber': 2, 'printType': 'bw', 'unitPrice': 1.0},
            {'pageNumber': 3, 'printType': 'color', 'unitPrice': 5.0},
            {'pageNumber': 18, 'printType': 'color', 'unitPrice': 5.0},
            {'pageNumber': 47, 'printType': 'color', 'unitPrice': 5.0},
            {'pageNumber': 78, 'printType': 'color', 'unitPrice': 5.0},
            {'pageNumber': 111, 'printType': 'color', 'unitPrice': 5.0},
          ],
        };

        final shopkeeperOrder = PrintOrder.fromMap(
          supabaseJson['id'] as String,
          supabaseJson,
        );
        expect(shopkeeperOrder.pages, equals(111));
        expect(shopkeeperOrder.calculatedBwPages, equals(106));
        expect(shopkeeperOrder.calculatedColorPages, equals(5));
        expect(shopkeeperOrder.colorPageNumbers, equals([3, 18, 47, 78, 111]));
        expect(
          shopkeeperOrder.formattedColorPageRanges,
          equals('3, 18, 47, 78, 111'),
        );
        expect(shopkeeperOrder.total, equals(131.0));
      },
    );

    test(
      'Price Snapshot Rule: Old order keeps original snapshot price calculation after price update',
      () async {
        final dataService = DataService();

        // Original pricing: B&W = ₹1, Color = ₹5
        final originalSnapshot = {
          'total_pages': 111,
          'bw_page_count': 106,
          'color_page_count': 5,
          'color_page_numbers': [3, 18, 47, 78, 111],
          'price_breakdown': {
            'bw_rate': 1.0,
            'color_rate': 5.0,
            'total': 131.0,
          },
        };

        final orderId = await dataService.createOrder(
          studentId: 'STU505',
          studentName: 'Pooja Nair',
          fileName: 'Project_Report_111.pdf',
          fileUrl: 'https://example.com/report.pdf',
          pages: 111,
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 131.0,
          paymentMode: PaymentMode.counter,
          priceSnapshot: originalSnapshot,
          bwPageCount: 106,
          colorPageCount: 5,
          colorPageNumbers: [3, 18, 47, 78, 111],
        );

        final placedOrder = dataService.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(placedOrder.total, equals(131.0));
        expect(placedOrder.calculatedBwPages, equals(106));
        expect(placedOrder.calculatedColorPages, equals(5));

        // Now Shopkeeper raises prices in system: B&W = ₹2, Color = ₹7
        await dataService.updatePrices(
          ShopPrice(
            bwSingle: 2.0,
            bwDouble: 3.0,
            colorSingle: 7.0,
            colorDouble: 12.0,
            photocopy: 2.0,
            lamination: 15.0,
            updatedAt: DateTime.now(),
          ),
        );

        // Old order must retain its original total amount of ₹131 and original counts
        final oldOrderAfterPriceChange = dataService.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(oldOrderAfterPriceChange.total, equals(131.0));
        expect(oldOrderAfterPriceChange.calculatedBwPages, equals(106));
        expect(oldOrderAfterPriceChange.calculatedColorPages, equals(5));
        expect(
          oldOrderAfterPriceChange.colorPageNumbers,
          equals([3, 18, 47, 78, 111]),
        );
      },
    );

    testWidgets(
      'AutomaticDetectionScreen: 111-Page Inspection UI, per-page toggle independence & student summary',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataService = DataService();
        const profile = UserProfile(
          id: 'student-999',
          name: 'Arjun Das',
          email: 'arjun@college.edu',
          role: 'student',
          studentId: 'CS111-01',
        );

        final doc111 = DocumentAnalysisResult(
          fileName: 'Sample_111_Page_Project_Report.pdf',
          fileSizeBytes: 14200000,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: List.generate(
            111,
            (i) => PageAnalysis(
              pageNumber: i + 1,
              printType: PrintType.bw,
              isBlank: false,
              dimensions: 'A4 (210 × 297 mm)',
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AutomaticDetectionScreen(
              dataService: dataService,
              profile: profile,
              onToggleTheme: () {},
              initialAnalysis: doc111,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Verify 111-page Document loaded and all pages default to B&W
        expect(find.text('Per-Page Visual Inspection'), findsOneWidget);
        expect(find.text('111 Pages'), findsOneWidget);
        expect(find.text('Original Pages: 111'), findsOneWidget);
        // Summary bar chips removed per Requirement 2
        expect(find.text('B&W Pages: 111'), findsNothing);
        expect(find.text('Colour Pages: 0'), findsNothing);
        expect(find.text('Total Printable Pages: 111'), findsNothing);

        // Verify Page 1, Page 2, Page 3 are rendered
        expect(find.text('Page 1 of 111'), findsOneWidget);
        expect(find.text('Page 2 of 111'), findsOneWidget);
        expect(find.text('Page 3 of 111'), findsOneWidget);

        // 2. Tap ONLY Page 3 card to toggle it to Color
        final page3Card = find.text('Page 3 of 111');
        await tester.ensureVisible(page3Card);
        await tester.tap(page3Card);
        await tester.pump(const Duration(milliseconds: 300));

        // 3. Verify ONLY Page 3 changed to Color: Colour Pages breakdown appears
        expect(find.text('Colour Pages: '), findsOneWidget);
        expect(
          find.text('3'),
          findsWidgets,
        ); // Appears in student summary for page 3

        // 4. Toggle Page 3 back to B&W
        await tester.tap(page3Card);
        await tester.pump(const Duration(milliseconds: 300));

        // Verify back to 100% B&W (Colour Pages: indicator disappears)
        expect(find.text('Colour Pages: '), findsNothing);

        // Allow any snackbar timers to expire cleanly
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Shopkeeper: PerPageDetailsDialog displays 111-page summary, exact Color pages, and filter chips',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create 111-page order with color pages [3, 18, 47, 78, 111]
        final colorPages = [3, 18, 47, 78, 111];
        final pageSettings = List.generate(
          111,
          (i) => PagePrintSetting(
            pageNumber: i + 1,
            printType: colorPages.contains(i + 1)
                ? PrintType.color
                : PrintType.bw,
            unitPrice: colorPages.contains(i + 1) ? 5.0 : 1.0,
          ),
        );

        final order111 = PrintOrder(
          id: 'ord_shop_111',
          code: 'CP-X683',
          studentId: 'STU111',
          studentName: 'Sanjay Kumar',
          fileName: 'Final_Report_111p.pdf',
          fileUrl: 'https://storage.college.edu/report.pdf',
          pages: 111,
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 131.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.unpaid,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
          bwPageCount: 106,
          colorPageCount: 5,
          colorPageNumbers: colorPages,
          pageSettings: pageSettings,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PerPageDetailsDialog(order: order111)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Dialog Header and Counts
        expect(find.text('Order #CP-X683'), findsOneWidget);
        expect(find.text('Per-Page Print Configuration'), findsOneWidget);
        expect(find.text('Total: 111 Pages'), findsOneWidget);
        expect(find.text('B&W: 106'), findsOneWidget);
        expect(find.text('Color: 5'), findsOneWidget);
        expect(find.text('3, 18, 47, 78, 111'), findsOneWidget);

        // Verify Filter Chips
        expect(find.text('All (111)'), findsOneWidget);
        expect(find.text('Color (5)'), findsOneWidget);
        expect(find.text('B&W (106)'), findsOneWidget);

        // Verify Page 1 (B&W) and Page 3 (COLOR) in list
        expect(find.text('Page 1'), findsOneWidget);
        expect(find.text('Page 3'), findsOneWidget);

        // Tap 'Color (5)' filter chip
        await tester.tap(find.text('Color (5)'));
        await tester.pump(const Duration(milliseconds: 300));

        // Now only color pages are listed in dialog
        expect(find.text('Page 3'), findsOneWidget);
        expect(find.text('Page 18'), findsOneWidget);
        expect(find.text('Page 47'), findsOneWidget);
        expect(find.text('Page 78'), findsOneWidget);
        expect(find.text('Page 111'), findsOneWidget);
        expect(find.text('Page 1'), findsNothing); // Filtered out

        // Tap 'B&W (106)' filter chip
        await tester.tap(find.text('B&W (106)'));
        await tester.pump(const Duration(milliseconds: 300));

        // Page 1 is shown, Page 3 is filtered out
        expect(find.text('Page 1'), findsOneWidget);
        expect(find.text('Page 3'), findsNothing);
      },
    );
  });
}
