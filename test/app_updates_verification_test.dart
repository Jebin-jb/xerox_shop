import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/screens/student/student_home.dart';
import 'package:campus_xerox/screens/student/student_orders.dart';
import 'package:campus_xerox/services/auth_service.dart';
import 'package:campus_xerox/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AutomaticDetectionScreen.filePickerOverride = null;
  });

  tearDown(() {
    AutomaticDetectionScreen.filePickerOverride = null;
  });

  group('Four-Digit Collection Code Requirements', () {
    test(
      'newCode generates exactly 4 numerical digits and preserves leading zeros',
      () {
        final data = DataService();
        final regex = RegExp(r'^[0-9]{4}$');

        for (int i = 0; i < 50; i++) {
          final code = data.newCode();
          expect(
            code.length,
            equals(4),
            reason: 'Code $code must be 4 characters',
          );
          expect(
            regex.hasMatch(code),
            isTrue,
            reason: 'Code $code must be strictly 4 numeric digits',
          );
        }
      },
    );

    test('Collection code is kept separate from Order ID', () async {
      final data = DataService();
      await data.ensureInitialized();

      final orderId = await data.createOrder(
        studentId: 'st_123',
        studentName: 'Joel Student',
        fileName: 'Project_Report.pdf',
        fileUrl: 'https://cdn/doc.pdf',
        pages: 12,
        copies: 2,
        color: false,
        doubleSided: true,
        lamination: false,
        binding: false,
        total: 24.0,
        paymentMode: PaymentMode.counter,
      );

      final order = (await data.allOrders().first).firstWhere(
        (o) => o.id == orderId,
      );

      expect(order.id, isNotEmpty);
      expect(order.code, isNotEmpty);
      expect(order.id, isNot(equals(order.code)));
      expect(RegExp(r'^[0-9]{4}$').hasMatch(order.code), isTrue);
    });

    test('findByCode lookup is restricted to authorized shopkeepers', () async {
      final data = DataService();
      await data.ensureInitialized();

      final orderId = await data.createOrder(
        studentId: 'st_code_test',
        studentName: 'Alice',
        fileName: 'Syllabus.pdf',
        fileUrl: 'https://cdn/syllabus.pdf',
        pages: 4,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 4.0,
        paymentMode: PaymentMode.counter,
      );

      final order = (await data.allOrders().first).firstWhere(
        (o) => o.id == orderId,
      );

      // Unauthorized request returns null
      final unauthorizedResult = await data.findByCode(
        order.code,
        isShopkeeper: false,
      );
      expect(unauthorizedResult, isNull);

      // Authorized shopkeeper lookup returns the order
      final authorizedResult = await data.findByCode(
        order.code,
        isShopkeeper: true,
      );
      expect(authorizedResult, isNotNull);
      expect(authorizedResult?.id, equals(order.id));
      expect(authorizedResult?.code, equals(order.code));
    });
  });

  group('Student Soft Deletion Requirements', () {
    test(
      'Soft deletion hides order from student list while preserving it in shop records',
      () async {
        final data = DataService();
        await data.ensureInitialized();

        final orderId = await data.createOrder(
          studentId: 'student_soft_del',
          studentName: 'Bob Student',
          fileName: 'Assignment.pdf',
          fileUrl: 'https://cdn/assign.pdf',
          pages: 10,
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 50.0,
          paymentMode: PaymentMode.counter,
        );

        // Verify initial presence in student stream
        var studentList = await data.studentOrders('student_soft_del').first;
        expect(studentList.any((o) => o.id == orderId), isTrue);

        // Soft delete order
        await data.softDeleteOrderForStudent(orderId);

        // Verify removed from student stream
        studentList = await data.studentOrders('student_soft_del').first;
        expect(studentList.any((o) => o.id == orderId), isFalse);

        // Verify STILL present in allOrders (shop records)
        final allList = await data.allOrders().first;
        final preservedOrder = allList.firstWhere((o) => o.id == orderId);
        expect(preservedOrder.isDeletedByStudent, isTrue);
        expect(preservedOrder.total, equals(50.0));
        expect(preservedOrder.pages, equals(10));
      },
    );

    testWidgets(
      'StudentOrders UI renders Delete button and confirmation dialog',
      (tester) async {
        final data = DataService();
        await data.ensureInitialized();

        final orderId = await data.createOrder(
          studentId: 'st_ui_test',
          studentName: 'Charlie',
          fileName: 'Presentation.pdf',
          fileUrl: 'https://cdn/pres.pdf',
          pages: 5,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 5.0,
          paymentMode: PaymentMode.counter,
        );

        final order = (await data.allOrders().first).firstWhere(
          (o) => o.id == orderId,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentOrders(
                uid: 'st_ui_test',
                dataService: data,
                onToggleTheme: () {},
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Delete button on the order card
        final deleteBtnFinder = find.widgetWithText(TextButton, 'Delete');
        expect(deleteBtnFinder, findsOneWidget);

        // Tap Delete to open confirmation dialog
        await tester.tap(deleteBtnFinder);
        await tester.pumpAndSettle();

        expect(find.text('Delete Order #${order.code}?'), findsOneWidget);
        expect(
          find.textContaining(
            'Your payment and transaction history will be preserved.',
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);

        // Tap Cancel -> dialog closes, order remains
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Presentation.pdf'), findsOneWidget);

        // Tap Delete again and confirm
        await tester.tap(deleteBtnFinder);
        await tester.pumpAndSettle();
        final confirmDeleteFinder = find.widgetWithText(FilledButton, 'Delete');
        await tester.tap(confirmDeleteFinder);
        await tester.pumpAndSettle();

        // Verify order is now hidden from the student screen
        expect(find.text('Presentation.pdf'), findsNothing);
      },
    );
  });

  group('Student Portal Requirements', () {
    testWidgets(
      'StudentHome: Create Print Order with cancelled picker stays on StudentHome without intermediate Documents screen',
      (tester) async {
        final auth = AuthService();
        final data = DataService();
        await data.ensureInitialized();

        const profile = UserProfile(
          id: 'st_portal_test',
          name: 'Portal Test',
          email: 'test@portal.edu',
          role: 'student',
          studentId: 'COL101',
        );

        // Document picker cancelled (returns null)
        AutomaticDetectionScreen.filePickerOverride = () async => null;

        await tester.pumpWidget(
          MaterialApp(
            home: StudentHome(
              auth: auth,
              dataService: data,
              profile: profile,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. FAST TRACK PRINTING must NOT be present
        expect(find.text('FAST TRACK PRINTING'), findsNothing);

        // 2. Auto Detect button/card must NOT be present on Home Page
        expect(find.text('Auto Detect'), findsNothing);

        // 3. Create Print Order button is present
        final createOrderBtn = find.text('Create Print Order');
        expect(createOrderBtn, findsOneWidget);

        // 4. Tap Create Print Order with cancelled picker
        await tester.tap(createOrderBtn);
        await tester.pump();
        await tester.pumpAndSettle();

        // Verification: Student remains on StudentHome without crashing or opening intermediate screen
        expect(find.byType(AutomaticDetectionScreen), findsNothing);
        expect(find.text('Tap to Select Document'), findsNothing);
        expect(find.text('Documents'), findsNothing);
        expect(find.byType(StudentHome), findsOneWidget);
      },
    );

    testWidgets(
      'StudentHome: Create Print Order with picked file opens Per-Page Inspection directly without intermediate Documents screen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final auth = AuthService();
        final data = DataService();
        await data.ensureInitialized();

        const profile = UserProfile(
          id: 'st_portal_test2',
          name: 'Portal Test 2',
          email: 'test2@portal.edu',
          role: 'student',
          studentId: 'COL102',
        );

        // Mock native file picker returning a selected document
        AutomaticDetectionScreen.filePickerOverride = () async =>
            FilePickerResult([
              PlatformFile(
                name: 'Sample_Assignment.pdf',
                size: 2048,
                bytes: Uint8List.fromList([1, 2, 3, 4]),
              ),
            ]);

        await tester.pumpWidget(
          MaterialApp(
            home: StudentHome(
              auth: auth,
              dataService: data,
              profile: profile,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final createOrderBtn = find.text('Create Print Order');
        expect(createOrderBtn, findsOneWidget);

        // Tap Create Print Order
        await tester.tap(createOrderBtn);
        await tester.pump();
        // Pump through navigator transition and analysis delays
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // Verification: Navigated directly to AutomaticDetectionScreen in Per-Page Inspection mode
        expect(find.byType(AutomaticDetectionScreen), findsOneWidget);

        // Intermediate 'Documents' header and 'Tap to Select Document' card must NOT be present
        expect(find.text('Tap to Select Document'), findsNothing);
        expect(find.text('Browse'), findsNothing);

        // App bar displays Per-Page Inspection
        expect(find.text('Per-Page Inspection'), findsOneWidget);

        // Selected file name is present in inspection screen
        expect(find.text('Sample_Assignment.pdf'), findsOneWidget);
      },
    );
  });

  group('Shopkeeper Order Queue Requirements', () {
    testWidgets(
      'Order Queue displays complete Print Summary table with all 9 fields',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final data = DataService();
        await data.ensureInitialized();

        final orderId = await data.createOrder(
          studentId: 'st_queue_test',
          studentName: 'Divya Patel',
          fileName: 'Lab_Manual.pdf',
          fileUrl: 'https://cdn/lab.pdf',
          pages: 8,
          copies: 3,
          color: true,
          doubleSided: true,
          lamination: false,
          binding: false,
          total: 96.0,
          paymentMode: PaymentMode.counter,
          pageSettings: const [
            PagePrintSetting(
              pageNumber: 1,
              printType: PrintType.color,
              unitPrice: 5.0,
            ),
            PagePrintSetting(
              pageNumber: 2,
              printType: PrintType.bw,
              unitPrice: 2.0,
            ),
          ],
        );

        final order = (await data.allOrders().first).firstWhere(
          (o) => o.id == orderId,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShopOrders(
                dataService: data,
                onToggleTheme: () {},
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Print Summary title
        expect(find.text('Print Summary'), findsOneWidget);

        // Verify Original Pages and Selected Printable Pages are removed
        expect(find.text('Original Pages'), findsNothing);
        expect(find.text('Selected Printable Pages'), findsNothing);
        expect(find.text('B&W Pages'), findsOneWidget);
        expect(find.text('Colour Pages'), findsOneWidget);
        expect(find.text('Removed Pages'), findsOneWidget);
        expect(find.text('Copies'), findsOneWidget);
        expect(find.text('Print Sides'), findsOneWidget);
        expect(find.text('Paper Type'), findsOneWidget);
        expect(find.text('Total Amount'), findsOneWidget);

        // Verify action buttons exist
        expect(
          find.widgetWithText(FilledButton, 'Receive ₹96 & Accept'),
          findsOneWidget,
        );
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Download'), findsNothing);
        expect(find.text('View / Print'), findsOneWidget);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );

        // Collection code format
        expect(find.textContaining(order.code), findsOneWidget);
      },
    );
  });
}
