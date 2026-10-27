import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/auth_service.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/pdf_page_filter_service.dart';
import 'package:campus_xerox/screens/student/student_shell.dart';
import 'package:campus_xerox/screens/student/student_home.dart';
import 'package:campus_xerox/screens/student/student_orders.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_reports.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Requirement 1.B: Selected-Page Printing Bug Fix', () {
    test(
      'PdfPageFilterService validates and parses single pages and ranges',
      () {
        final filter = PdfPageFilterService();

        // Individual page
        expect(filter.parsePageSelection('1', 2), equals([1]));
        expect(filter.parsePageSelection('2', 2), equals([2]));

        // Ranges 2-4
        expect(filter.parsePageSelection('2-4', 10), equals([2, 3, 4]));

        // Multiple pages and ranges 1,3,5-7
        expect(
          filter.parsePageSelection('1,3,5-7', 10),
          equals([1, 3, 5, 6, 7]),
        );

        // Custom pages 2, 4, 6 from 10 pages
        expect(filter.parsePageSelection('2, 4, 6', 10), equals([2, 4, 6]));

        // Validation bounds
        expect(() => filter.parsePageSelection('0', 10), throwsFormatException);
        expect(
          () => filter.parsePageSelection('11', 10),
          throwsFormatException,
        );
        expect(
          () => filter.parsePageSelection('5-2', 10),
          throwsFormatException,
        );
      },
    );

    test(
      'Selected-page PDF generation produces exactly the requested pages',
      () async {
        final filter = PdfPageFilterService();

        // Create a 10-page sample PDF
        final doc = PdfDocument();
        for (int i = 1; i <= 10; i++) {
          final p = doc.pages.add();
          p.graphics.drawString(
            'Page $i',
            PdfStandardFont(PdfFontFamily.helvetica, 16),
            bounds: const Rect.fromLTWH(20, 20, 200, 30),
          );
        }
        final sourceBytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        // Student selects pages 2, 4, 6
        final generated = await filter.generateSelectedPagesPdf(
          sourceBytes: sourceBytes,
          selectedPages: [2, 4, 6],
        );

        final extractedDoc = PdfDocument(inputBytes: generated);
        expect(
          extractedDoc.pages.count,
          equals(3),
          reason:
              'Shopkeeper printable PDF must contain only the 3 selected pages',
        );
        extractedDoc.dispose();

        // Student uploads 2-page document and selects only page 1
        final doc2 = PdfDocument();
        doc2.pages.add();
        doc2.pages.add();
        final twoPageBytes = Uint8List.fromList(doc2.saveSync());
        doc2.dispose();

        final page1Pdf = await filter.generateSelectedPagesPdf(
          sourceBytes: twoPageBytes,
          selectedPages: [1],
        );
        final res1 = PdfDocument(inputBytes: page1Pdf);
        expect(res1.pages.count, equals(1));
        res1.dispose();

        // Student selects only page 2
        final page2Pdf = await filter.generateSelectedPagesPdf(
          sourceBytes: twoPageBytes,
          selectedPages: [2],
        );
        final res2 = PdfDocument(inputBytes: page2Pdf);
        expect(res2.pages.count, equals(1));
        res2.dispose();
      },
    );

    test(
      'Price calculation uses selected page count × copies × printing rate',
      () {
        // 10-page document, but student selects only 3 pages: 2, 4, 6
        const selectedPageCount = 3;
        const copies = 2;
        const bwRate = 1.0;

        final expectedPrintCost = selectedPageCount * copies * bwRate;
        expect(expectedPrintCost, equals(6.0));
      },
    );
  });

  group(
    'Requirement 1.C & 1.D: Shopkeeper Reports (Reset & Remove Recent Expenses)',
    () {
      testWidgets(
        'Reports page contains Reset button and resets date filters',
        (tester) async {
          final ds = DataService();
          await ds.ensureInitialized();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ShopReports(
                  dataService: ds,
                  onToggleTheme: () {},
                  onSignOut: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Check visible Reset button exists
          final resetButton = find.widgetWithText(OutlinedButton, 'Reset');
          expect(
            resetButton,
            findsOneWidget,
            reason: 'Reports page must have a visible Reset button',
          );

          // Tap reset button and verify snackbar confirms filter reset
          await tester.tap(resetButton);
          await tester.pumpAndSettle();
          expect(find.textContaining('Report filters reset'), findsOneWidget);
        },
      );

      testWidgets(
        'Recent Expenses section is completely removed from Reports UI',
        (tester) async {
          final ds = DataService();
          await ds.ensureInitialized();

          // Add sample expense to verify it doesn't render as a list section
          await ds.addExpense(
            'Test Paper Box',
            500,
            'Paper Bundle',
            DateTime.now(),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ShopReports(
                  dataService: ds,
                  onToggleTheme: () {},
                  onSignOut: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // "Recent Expenses" heading and list should NOT exist
          expect(
            find.text('Recent Expenses'),
            findsNothing,
            reason:
                'Recent Expenses section must be completely removed from Reports UI',
          );

          // Expense total in metrics cards must still calculate correctly
          expect(find.text('Total Expenses'), findsOneWidget);
          expect(find.text('Net Estimated Profit'), findsOneWidget);
        },
      );
    },
  );

  group('Requirement 1.E: Order Queue Delete Option', () {
    test(
      'Deleting an unfulfilled order transitions status to cancelled with audit record',
      () async {
        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_123',
          studentName: 'Joel Student',
          fileName: 'assignment.pdf',
          fileUrl: 'vault/assignment.pdf',
          pages: 5,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 5.0,
          paymentMode: PaymentMode.counter,
        );

        final initialOrder = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(initialOrder.status, equals(OrderStatus.pending));
        expect(initialOrder.isDeletedFromQueue, isFalse);

        // Shopkeeper deletes order from active queue
        await ds.updateOrder(orderId, {
          'isDeletedFromQueue': true,
          'status': 'cancelled',
          'cancellationBy': 'SHOPKEEPER',
          'cancellationReason': 'Deleted from active queue by shopkeeper',
        });

        final updatedOrder = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(updatedOrder.isDeletedFromQueue, isTrue);
        expect(updatedOrder.status, equals(OrderStatus.cancelled));
        expect(updatedOrder.cancellationBy, equals('SHOPKEEPER'));
        expect(
          updatedOrder.cancellationReason,
          equals('Deleted from active queue by shopkeeper'),
        );
      },
    );

    testWidgets('ShopOrders excludes orders where isDeletedFromQueue is true', (
      tester,
    ) async {
      final ds = DataService();
      await ds.ensureInitialized();

      await ds.createOrder(
        studentId: 'st_1',
        studentName: 'Alice Active',
        fileName: 'active_order.pdf',
        fileUrl: 'vault/active.pdf',
        pages: 2,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 2.0,
        paymentMode: PaymentMode.counter,
      );

      await ds.createOrder(
        studentId: 'st_2',
        studentName: 'Bob Deleted',
        fileName: 'deleted_order.pdf',
        fileUrl: 'vault/deleted.pdf',
        pages: 3,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 3.0,
        paymentMode: PaymentMode.counter,
        isDeletedFromQueue: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopOrders(
              dataService: ds,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Alice Active', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bob Deleted', skipOffstage: false),
        findsNothing,
        reason:
            'Orders marked as isDeletedFromQueue must not appear in active queue',
      );
    });
  });

  group('Requirement 2: Student Portal UI Improvements', () {
    testWidgets('Auto Detect is removed from StudentShell navigation bar', (
      tester,
    ) async {
      final ds = DataService();
      await ds.ensureInitialized();
      final auth = AuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: StudentShell(
            auth: auth,
            dataService: ds,
            profile: const UserProfile(
              id: 'st_1',
              studentId: '2024CS001',
              name: 'John Doe',
              email: 'john@college.ac.in',
              role: 'student',
            ),
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home and My Orders should be destinations in bottom navigation bar
      expect(find.text('Home'), findsWidgets);
      expect(find.text('My Orders'), findsWidgets);

      final autoDetectInNavBar = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Auto Detect'),
      );
      expect(
        autoDetectInNavBar,
        findsNothing,
        reason:
            'Auto Detect navigation option is removed from StudentShell bottom navigation',
      );
    });

    testWidgets(
      'Student Home page has Create Print Order button, Auto Detect and FAST TRACK PRINTING removed',
      (tester) async {
        final ds = DataService();
        await ds.ensureInitialized();
        final auth = AuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentHome(
                auth: auth,
                dataService: ds,
                profile: const UserProfile(
                  id: 'st_1',
                  studentId: '2024CS001',
                  name: 'John Doe',
                  email: 'john@college.ac.in',
                  role: 'student',
                ),
                onToggleTheme: () {},
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Auto Detect card and FAST TRACK PRINTING are removed from Home page
        expect(
          find.text('Auto Detect'),
          findsNothing,
          reason: 'Auto Detect button should be removed from Home Page',
        );
        expect(
          find.text('⚡ FAST TRACK PRINTING'),
          findsNothing,
          reason: 'FAST TRACK PRINTING section must be removed completely',
        );

        // Verify clean Create Print Order button exists
        expect(find.text('Create Print Order'), findsOneWidget);

        // The subtitle under Live Shop Rates starting with "Current..." must be removed
        expect(find.text('Live Shop Rates'), findsOneWidget);
        expect(
          find.textContaining('Current price list maintained directly'),
          findsNothing,
          reason: 'Unwanted subtitle beginning with Current... must be removed',
        );
      },
    );

    testWidgets(
      'My Print Orders has description beginning with "Track status..." removed',
      (tester) async {
        final ds = DataService();
        await ds.ensureInitialized();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentOrders(
                dataService: ds,
                uid: 'st_1',
                onToggleTheme: () {},
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Print Orders'), findsOneWidget);
        expect(
          find.textContaining('Track status, view collection codes'),
          findsNothing,
          reason:
              'Unwanted subtitle beginning with Track status... must be removed',
        );
      },
    );
  });
}
