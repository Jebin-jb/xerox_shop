import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/widgets/document_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DataService().clearOrdersForTesting();
  });

  group('Shopkeeper Orders Workflow — Steps 1 to 5', () {
    testWidgets(
      'Step 1: Pending Order card has View / Print, Accept, Reject; NO Download button, NO Bin button, NO print/complete',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        await ds.createOrder(
          studentId: 'st_step1',
          studentName: 'Alice Step1',
          fileName: 'assignment_step1.pdf',
          fileUrl: 'secure://vault/assignment_step1.pdf',
          pages: 4,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 4.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.unpaid,
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

        // Download button permanently removed from card
        expect(find.text('Download'), findsNothing);
        expect(find.byIcon(Icons.cloud_download_rounded), findsNothing);

        // Permitted actions for pending
        expect(find.text('View / Print'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Receive ₹4 & Accept'), findsOneWidget);

        // Bin button is hidden while pending
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
        expect(find.byTooltip('Delete from Queue'), findsNothing);

        // Printing/completion not permitted before acceptance
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Mark Ready'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);
      },
    );

    testWidgets(
      'Step 1 & DocumentPreviewDialog: Download button kept in dialog header; Delete After Print permanently removed',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final order = PrintOrder(
          id: 'preview_1',
          code: '1234',
          studentId: 'st_prev',
          studentName: 'Preview Student',
          fileName: 'sample_file.txt',
          fileUrl: 'secure://vault/sample_file.txt',
          pages: 2,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 2.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.unpaid,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => DocumentPreviewDialog(order: order),
                  ),
                  child: const Text('Open Preview'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Preview'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Download (down-arrow) button is kept inside View / Print dialog
        expect(find.byIcon(Icons.download_rounded), findsOneWidget);
        expect(find.byTooltip('Download Document'), findsOneWidget);

        // Can tap download button even while order is Pending
        await tester.tap(find.byTooltip('Download Document'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Delete After Print button is permanently removed from dialog
        expect(find.text('Delete After Print'), findsNothing);
        expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);

        // Done button is present
        expect(find.text('Done'), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'Step 2: Accepted Order card has View / Print and Start Printing; Reject, Accept, Bin, and Card Download are HIDDEN',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_step2_acc',
          studentName: 'Accepted Student',
          fileName: 'accepted_doc.pdf',
          fileUrl: 'secure://vault/accepted_doc.pdf',
          pages: 5,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 5.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.paid,
        );

        await ds.updateOrder(orderId, {'status': 'accepted'});

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

        // Order card download button is hidden
        expect(find.text('Download'), findsNothing);

        // Reject button is hidden after acceptance
        expect(find.text('Reject'), findsNothing);

        // View / Print and Start Printing are available
        expect(find.text('View / Print'), findsOneWidget);
        expect(find.text('Start Printing'), findsOneWidget);

        // Bin button is hidden while accepted
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Step 2: Rejected Order card hides View / Print, Accept, Reject, Download; Shows ONLY the Bin button',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_step2_rej',
          studentName: 'Rejected Student',
          fileName: 'rejected_doc.pdf',
          fileUrl: 'secure://vault/rejected_doc.pdf',
          pages: 3,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 3.0,
          paymentMode: PaymentMode.counter,
        );

        await ds.updateOrder(orderId, {
          'status': 'rejected',
          'cancellationBy': 'SHOPKEEPER',
          'cancellationReason': 'Printer unavailable',
        });

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

        // Hidden from rejected order card
        expect(find.text('View / Print'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Download'), findsNothing);
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);

        // Rejected orders do NOT require or show Bin button
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Step 3: Printing & Ready stages only permit eligible printing actions and View / Print; NO Bin button',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_step3',
          studentName: 'Printing Student',
          fileName: 'printing_doc.pdf',
          fileUrl: 'secure://vault/printing_doc.pdf',
          pages: 6,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 6.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.paid,
        );

        // Move to printing
        await ds.updateOrder(orderId, {'status': 'printing'});

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

        expect(find.text('View / Print'), findsOneWidget);
        expect(find.text('Mark Ready'), findsOneWidget);
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );

        // Move to ready
        await ds.updateOrder(orderId, {'status': 'ready'});
        await tester.pumpAndSettle();

        expect(find.text('Complete Order'), findsOneWidget);
        expect(find.text('View / Print'), findsOneWidget);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Step 4: Completed Order shows View / Print and Bin as action buttons; redundant top View Document is removed',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_step4',
          studentName: 'Completed Student',
          fileName: 'completed_doc.txt',
          fileUrl: 'secure://vault/completed_doc.txt',
          pages: 8,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 8.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.paid,
        );

        await ds.updateOrder(orderId, {
          'status': 'completed',
          'completedAt': DateTime.now(),
        });

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

        // Outside Download, Accept, Reject, Printing buttons not shown
        expect(find.text('Download'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Mark Ready'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);

        // Bin button is available as order-card action
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsOneWidget,
        );

        // Redundant top-level View Document button is removed
        expect(find.text('View Document'), findsNothing);

        // Document viewing retained via View / Print workflow
        expect(find.text('View / Print'), findsOneWidget);

        // Tapping View / Print opens preview dialog
        await tester.tap(find.text('View / Print'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DocumentPreviewDialog), findsOneWidget);

        // Close preview
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'Step 5: Bin Click shows confirmation dialog, deletes file, clears fileUrl, sets isPurged and isDeletedFromQueue, and preserves financial history',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_step5',
          studentName: 'Purge Student',
          fileName: 'purge_me.pdf',
          fileUrl: 'secure://vault/purge_me.pdf',
          pages: 10,
          copies: 2,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: false,
          total: 20.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.paid,
        );

        await ds.updateOrder(orderId, {
          'status': 'completed',
          'completedAt': DateTime.now(),
        });

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

        // Tap Bin button
        await tester.tap(find.byTooltip('Delete Document & Remove from Queue'));
        await tester.pumpAndSettle();

        // 1. Verify confirmation dialog appears explaining removal without reason text field (Task 1)
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Delete Order #'), findsOneWidget);
        expect(
          find.textContaining('Delete document "purge_me.pdf"'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'The associated document will be permanently deleted from storage',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Order history and payment records (₹20.00)'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );

        // Tap Confirm Delete
        await tester.tap(find.text('Confirm Delete'));
        await tester.pumpAndSettle();

        // 2. Order is removed from active queue
        expect(find.textContaining('Purge Student'), findsNothing);

        // 3. Database record preserves financial history while fileUrl is cleared and isPurged is true
        final orderRecord = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(orderRecord.isDeletedFromQueue, isTrue);
        expect(orderRecord.isPurged, isTrue);
        expect(orderRecord.fileUrl, isEmpty);
        expect(orderRecord.total, equals(20.0));
        expect(orderRecord.pages, equals(10));
        expect(orderRecord.copies, equals(2));
        expect(orderRecord.paymentMode, equals(PaymentMode.counter));
        expect(orderRecord.paymentStatus, equals(PaymentStatus.paid));
      },
    );
  });
}
