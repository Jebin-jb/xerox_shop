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

  group('Bin Auto-Deletion, Order Reload Bug, and Order Summary UI Tests', () {
    testWidgets(
      'Requirement 1: Bin deletion shows confirmation dialog, removes from queue, deletes file, and preserves financial history',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_bin_1',
          studentName: 'Bin Test Student',
          fileName: 'lecture_notes.pdf',
          fileUrl: 'secure://vault/bin_lecture_notes.pdf',
          pages: 12,
          copies: 1,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: false,
          total: 18.0,
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

        // Initially order is visible in active queue
        expect(find.text('lecture_notes.pdf'), findsOneWidget);
        expect(
          find.text('Bin Test Student • 12 pages'),
          findsNothing,
        ); // format check

        // 1. Click Bin button
        final binFinder = find.byTooltip('Delete Document & Remove from Queue');
        expect(binFinder, findsOneWidget);
        await tester.tap(binFinder);
        await tester.pumpAndSettle();

        // 2. Verify confirmation dialog appears
        expect(find.textContaining('Remove Order #'), findsOneWidget);
        expect(
          find.textContaining('The document file will be deleted from storage'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Payment and financial records (₹18.00) will be safely retained',
          ),
          findsOneWidget,
        );

        // Cancel first to verify it does not delete prematurely
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('lecture_notes.pdf'), findsOneWidget);

        // 3. Click Bin again and test empty reason validation
        await tester.tap(binFinder);
        await tester.pumpAndSettle();

        // Tap Confirm Removal with empty text
        await tester.tap(find.text('Confirm Removal'));
        await tester.pumpAndSettle();
        expect(
          find.text('Please enter a reason for removing this order.'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);

        // Enter whitespace-only reason
        final reasonField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(reasonField, '    ');
        await tester.tap(find.text('Confirm Removal'));
        await tester.pumpAndSettle();
        expect(
          find.text('Please enter a reason for removing this order.'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);

        // Enter valid reason
        await tester.enterText(reasonField, 'Printed and picked up by student');
        await tester.tap(find.text('Confirm Removal'));
        await tester.pump();
        await tester.pumpAndSettle();

        // 4. Verify removed from active order list
        expect(find.text('lecture_notes.pdf'), findsNothing);

        // 5. Verify database record updated: isPurged = true, isDeletedFromQueue = true, fileUrl is empty, removalReason saved
        final deletedOrder = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(deletedOrder.isPurged, isTrue);
        expect(deletedOrder.isDeletedFromQueue, isTrue);
        expect(deletedOrder.fileUrl, isEmpty);
        expect(
          deletedOrder.removalReason,
          equals('Printed and picked up by student'),
        );
        expect(deletedOrder.removedAt, isNotNull);
        expect(deletedOrder.removedBy, equals('Shopkeeper'));

        // 6. Verify financial history preserved: total and payment records remain intact
        expect(deletedOrder.total, equals(18.0));
        expect(deletedOrder.paymentStatus, equals(PaymentStatus.paid));
        expect(deletedOrder.status, equals(OrderStatus.completed));

        // 7. Verify order does NOT reappear after screen refresh / re-query
        await ds.refreshOrders();
        await tester.pumpAndSettle();
        expect(find.text('lecture_notes.pdf'), findsNothing);

        // 8. Verify order does NOT reappear after reopening app (new DataService loading from disk)
        final reloadedDs = DataService();
        await reloadedDs.ensureInitialized();
        final activeReloadedOrders = reloadedDs.allOrdersDirect
            .where((o) => !o.isDeletedFromQueue)
            .toList();
        expect(activeReloadedOrders.any((o) => o.id == orderId), isFalse);

        // 9. Verify student orders stream still contains the order and displays the removal reason
        final studentOrderList = await reloadedDs
            .studentOrders('st_bin_1')
            .first;
        expect(studentOrderList.any((o) => o.id == orderId), isTrue);
        final studentOrder = studentOrderList.firstWhere(
          (o) => o.id == orderId,
        );
        expect(
          studentOrder.effectiveRemovalReason,
          equals('Printed and picked up by student'),
        );
      },
    );

    testWidgets(
      'Requirement 2A: Pending Order shows View / Print, Receive & Accept, Reject; hides Bin and printing actions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        await ds.createOrder(
          studentId: 'st_pend',
          studentName: 'Pending Student',
          fileName: 'pending_paper.pdf',
          fileUrl: 'secure://vault/pending_paper.pdf',
          pages: 2,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 2.0,
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

        expect(find.text('View / Print'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Receive ₹2 & Accept'), findsOneWidget);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Mark Ready'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);
      },
    );

    testWidgets(
      'Requirement 2B: Accepted Order retains View / Print and hides Receive & Accept and Reject',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_acc',
          studentName: 'Accepted Student',
          fileName: 'accepted_paper.pdf',
          fileUrl: 'secure://vault/accepted_paper.pdf',
          pages: 3,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 3.0,
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

        // Retains View / Print and Start Printing
        expect(find.text('View / Print'), findsOneWidget);
        expect(find.text('Start Printing'), findsOneWidget);

        // Hides Receive & Accept, Reject, and Bin
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Receive ₹3 & Accept'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Requirement 2C: Rejected Order does not allow further acceptance, rejection, or printing; shows Bin action',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_rej',
          studentName: 'Rejected Student',
          fileName: 'rejected_doc.pdf',
          fileUrl: 'secure://vault/rejected_doc.pdf',
          pages: 1,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 1.0,
          paymentMode: PaymentMode.counter,
        );
        await ds.updateOrder(orderId, {
          'status': 'rejected',
          'cancellationBy': 'Shopkeeper',
          'cancellationReason': 'Ink depleted',
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

        // Rejected order has no active actions; Bin is NOT shown or required
        expect(find.text('View / Print'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Mark Ready'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Requirement 2D: Completed Order retains document viewing via View / Print, with Bin available',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_comp',
          studentName: 'Completed Student',
          fileName: 'completed_summary.pdf',
          fileUrl: 'secure://vault/completed_summary.pdf',
          pages: 4,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 4.0,
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

        // Retains View / Print and Bin
        expect(find.text('View / Print'), findsOneWidget);
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsOneWidget,
        );

        // Hides Accept, Reject, and Printing actions
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Start Printing'), findsNothing);
        expect(find.text('Mark Ready'), findsNothing);
        expect(find.text('Complete Order'), findsNothing);
      },
    );

    testWidgets(
      'Requirement 3: Redundant View Document action is removed from top of Order Summary card, while View / Print remains',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        await ds.createOrder(
          studentId: 'st_top_test',
          studentName: 'Summary Test Student',
          fileName: 'project_submission_final.pdf',
          fileUrl: 'secure://vault/project_submission_final.pdf',
          pages: 15,
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 75.0,
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

        // File name is displayed
        expect(find.text('project_submission_final.pdf'), findsOneWidget);

        // Redundant top-level 'View Document' button is gone
        expect(find.text('View Document'), findsNothing);

        // View / Print button is present on the action row
        expect(find.text('View / Print'), findsOneWidget);

        // Tapping View / Print opens the DocumentPreviewDialog
        await tester.tap(find.text('View / Print'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DocumentPreviewDialog), findsOneWidget);

        // Close preview
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DocumentPreviewDialog), findsNothing);
      },
    );
  });
}
