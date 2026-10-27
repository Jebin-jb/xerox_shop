import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_dashboard.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';
import 'package:campus_xerox/screens/student/order_receipt.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/widgets/document_preview_dialog.dart';
import 'package:campus_xerox/widgets/order_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DataService().clearOrdersForTesting();
  });

  group('Campus Xerox Tasks 1-4 Verification', () {
    testWidgets('Task 1: Shopkeeper Dashboard displays Pending orders ONLY', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ds = DataService();
      await ds.ensureInitialized();

      // 1. Create orders with different statuses
      final pendingId = await ds.createOrder(
        studentId: 'st_pend_1',
        studentName: 'Alice Pending',
        fileName: 'pending_notes.pdf',
        fileUrl: 'secure://vault/pending_notes.pdf',
        pages: 5,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 5.0,
        paymentMode: PaymentMode.counter,
        paymentStatus: PaymentStatus.unpaid,
      );

      final acceptedId = await ds.createOrder(
        studentId: 'st_acc_2',
        studentName: 'Bob Accepted',
        fileName: 'accepted_notes.pdf',
        fileUrl: 'secure://vault/accepted_notes.pdf',
        pages: 10,
        copies: 1,
        color: false,
        doubleSided: true,
        lamination: false,
        binding: false,
        total: 15.0,
        paymentMode: PaymentMode.counter,
        paymentStatus: PaymentStatus.paid,
      );
      await ds.updateOrder(acceptedId, {'status': 'accepted'});

      final completedId = await ds.createOrder(
        studentId: 'st_comp_3',
        studentName: 'Charlie Completed',
        fileName: 'completed_project.pdf',
        fileUrl: 'secure://vault/completed_project.pdf',
        pages: 20,
        copies: 1,
        color: true,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 100.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
      );
      await ds.updateOrder(completedId, {
        'status': 'completed',
        'completedAt': DateTime.now(),
      });

      final rejectedId = await ds.createOrder(
        studentId: 'st_rej_4',
        studentName: 'David Rejected',
        fileName: 'rejected_file.pdf',
        fileUrl: 'secure://vault/rejected_file.pdf',
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
      await ds.updateOrder(rejectedId, {
        'status': 'rejected',
        'rejectionReason': 'Printer offline',
      });

      // 2. Render ShopDashboard
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopDashboard(
              dataService: ds,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3. Verify ONLY pending order appears in the Pending Orders section
      final pendingOrder =
          ds.allOrdersDirect.firstWhere((o) => o.id == pendingId);
      expect(find.text('pending_notes.pdf'), findsOneWidget);
      expect(find.text('Code: #${pendingOrder.code}'), findsOneWidget);

      // Non-pending orders must NOT be displayed in the list
      expect(find.text('accepted_notes.pdf'), findsNothing);
      expect(find.text('completed_project.pdf'), findsNothing);
      expect(find.text('rejected_file.pdf'), findsNothing);

      // 4. Update the pending order to accepted and verify it immediately disappears from pending list
      await ds.updateOrder(pendingId, {'status': 'accepted'});
      await tester.pumpAndSettle();

      expect(find.text('pending_notes.pdf'), findsNothing);
      expect(find.text('No pending orders in the queue.'), findsOneWidget);

      // 5. Verify completed and other orders remain safely in DataService history
      final all = ds.allOrdersDirect;
      expect(all.length, 4);
      expect(
        all.any(
          (o) => o.id == completedId && o.status == OrderStatus.completed,
        ),
        isTrue,
      );
    });

    testWidgets(
      'Task 2: Order rejection requires reason dialog, no Bin action, and displays reason in student portal',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_task2',
          studentName: 'Emma Watson',
          studentEmail: 'emma@college.ac.in',
          fileName: 'assignment_to_reject.pdf',
          fileUrl: 'secure://vault/assignment_to_reject.pdf',
          pages: 8,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 8.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.unpaid,
        );

        // 1. Render ShopOrders
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

        expect(find.text('assignment_to_reject.pdf'), findsOneWidget);
        final rejectButton = find.widgetWithText(OutlinedButton, 'Reject');
        expect(rejectButton, findsOneWidget);

        // 2. Click Reject -> Dialog appears with "Reason for Rejection" text field
        await tester.tap(rejectButton);
        await tester.pumpAndSettle();

        expect(find.textContaining('Reject Order #'), findsOneWidget);
        expect(find.text('Reason for Rejection'), findsOneWidget);
        expect(find.text('Confirm Rejection'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // 3. Test empty reason validation
        await tester.tap(find.text('Confirm Rejection'));
        await tester.pumpAndSettle();
        expect(
          find.text('Reason for Rejection cannot be empty.'),
          findsOneWidget,
        );

        // Test whitespace-only reason
        final dialogTextField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogTextField, '     ');
        await tester.tap(find.text('Confirm Rejection'));
        await tester.pumpAndSettle();
        expect(
          find.text('Reason for Rejection cannot be empty.'),
          findsOneWidget,
        );

        // 4. Test Cancel leaves order unchanged
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        var currentOrder = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(currentOrder.status, OrderStatus.pending);

        // 5. Click Reject again, enter valid reason, and confirm
        await tester.tap(rejectButton);
        await tester.pumpAndSettle();

        final rejectDialogTextField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(
          rejectDialogTextField,
          'Font corruption on page 3 and missing margins',
        );
        await tester.tap(find.text('Confirm Rejection'));
        await tester.pumpAndSettle();

        // 6. Verify database update
        currentOrder = ds.allOrdersDirect.firstWhere((o) => o.id == orderId);
        expect(currentOrder.status, OrderStatus.rejected);
        expect(
          currentOrder.effectiveRejectionReason,
          'Font corruption on page 3 and missing margins',
        );

        // 7. Verify Bin button is NOT shown for rejected order
        expect(
          find.byTooltip('Delete Document & Remove from Queue'),
          findsNothing,
        );
        expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Start Printing'), findsNothing);

        // 8. Verify Student Portal: OrderCard displays REJECTED chip & Reason for Rejection
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OrderCard(order: currentOrder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('REJECTED'), findsOneWidget);
        expect(find.text('Order Rejected by Xerox Shop'), findsOneWidget);
        expect(
          find.text(
            'Reason for Rejection: Font corruption on page 3 and missing margins',
          ),
          findsOneWidget,
        );

        // 9. Verify Student Portal: OrderReceipt displays Rejected by Xerox Shop and Reason for Rejection
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderReceipt(
                orderId: orderId,
                dataService: ds,
                onToggleTheme: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Order Rejected'), findsOneWidget);
        expect(find.text('Rejected by: Xerox Shop'), findsOneWidget);
        expect(
          find.text(
            'Reason for Rejection: Font corruption on page 3 and missing margins',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Task 3: Shopkeeper Order Summary omits Original Pages and Selected Printable Pages',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        await ds.createOrder(
          studentId: 'st_task3',
          studentName: 'Frank Summary',
          fileName: 'thesis_document.pdf',
          fileUrl: 'secure://vault/thesis_document.pdf',
          pages: 50,
          copies: 2,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: true,
          total: 80.0,
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

        expect(find.text('Print Summary'), findsOneWidget);

        // Required by Task 3: These two rows must NOT appear
        expect(find.text('Original Pages'), findsNothing);
        expect(find.text('Selected Printable Pages'), findsNothing);

        // Other summary info remains intact
        expect(find.text('B&W Pages'), findsOneWidget);
        expect(find.text('Colour Pages'), findsOneWidget);
        expect(find.text('Removed Pages'), findsOneWidget);
        expect(find.text('Copies'), findsOneWidget);
        expect(find.text('Print Sides'), findsOneWidget);
        expect(find.text('Paper Type'), findsOneWidget);
      },
    );

    testWidgets(
      'Task 4: Bin deletion removes file, marks isPurged, and prevents reloading',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ds = DataService();
        await ds.ensureInitialized();

        final orderId = await ds.createOrder(
          studentId: 'st_task4',
          studentName: 'Grace Completed',
          fileName: 'completed_lab.pdf',
          fileUrl: 'secure://vault/completed_lab.pdf',
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

        // 1. Bin is visible for completed order
        final binFinder = find.byTooltip('Delete Document & Remove from Queue');
        expect(binFinder, findsOneWidget);

        // 2. Click Bin -> Confirmation dialog appears
        await tester.tap(binFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('Remove Order #'), findsOneWidget);
        expect(find.text('Reason for removing this order'), findsOneWidget);

        // 3. Confirm deletion with reason
        final binDialogTextField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(
          binDialogTextField,
          'Printed, collected, and customer confirmed',
        );
        await tester.tap(find.text('Confirm Removal'));
        await tester.pumpAndSettle();

        // 4. Verify order is removed from the active queue in UI
        expect(find.text('completed_lab.pdf'), findsNothing);

        // 5. Verify database record state: fileUrl is empty, isPurged is true, isDeletedFromQueue is true
        final orderAfterBin = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(orderAfterBin.isPurged, isTrue);
        expect(orderAfterBin.fileUrl, isEmpty);
        expect(orderAfterBin.isDeletedFromQueue, isTrue);
        expect(
          orderAfterBin.effectiveRemovalReason,
          'Printed, collected, and customer confirmed',
        );

        // Financial records remain safe
        expect(orderAfterBin.total, 6.0);
        expect(orderAfterBin.status, OrderStatus.completed);

        // 6. Verify DocumentPreviewDialog gracefully detects purged status
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DocumentPreviewDialog(order: orderAfterBin)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This document has been removed and securely purged from storage.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
