import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';
import 'package:campus_xerox/screens/shopkeeper/price_management.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/screens/student/create_order.dart';
import 'package:campus_xerox/screens/shopkeeper/shop_orders.dart';
import 'package:campus_xerox/widgets/order_widgets.dart';
import 'package:campus_xerox/screens/student/order_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Campus Xerox Management System — Tasks 1, 2, and 3 Comprehensive Verification',
    () {
      late DataService ds;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        ds = DataService();
        await ds.ensureInitialized();
        ds.clearOrdersForTesting();
      });

      testWidgets(
        'Task 1A: Shopkeeper Live Price Control has NO Additional Service tab or section',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PriceManagement(
                  dataService: ds,
                  onToggleTheme: () {},
                  onSignOut: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify Additional Services tab and option are completely absent
          expect(find.text('Additional Services'), findsNothing);
          expect(find.text('Additional Service'), findsNothing);

          // Verify remaining price management tabs are present and functional
          expect(find.text('Paper Types'), findsOneWidget);
          expect(find.text('Printing'), findsOneWidget);
          expect(find.text('Finishing & Binding'), findsOneWidget);
        },
      );

      testWidgets(
        'Task 1B: Student Print Configuration screens have NO Additional Service option',
        (WidgetTester tester) async {
          final analysis = DocumentAnalysisResult(
            fileName: 'sample_notes.pdf',
            fileSizeBytes: 4096,
            fileExtension: 'pdf',
            analyzedAt: DateTime.now(),
            pages: [
              PageAnalysis(
                pageNumber: 1,
                isBlank: false,
                isColor: false,
                orientation: 'portrait',
              ),
              PageAnalysis(
                pageNumber: 2,
                isBlank: false,
                isColor: true,
                orientation: 'landscape',
              ),
              PageAnalysis(
                pageNumber: 3,
                isBlank: false,
                isColor: false,
                orientation: 'portrait',
              ),
              PageAnalysis(
                pageNumber: 4,
                isBlank: false,
                isColor: false,
                orientation: 'portrait',
              ),
            ],
          );

          // 1. Test AutomaticDetectionScreen
          await tester.pumpWidget(
            MaterialApp(
              home: AutomaticDetectionScreen(
                dataService: ds,
                profile: const UserProfile(
                  id: 'st_1',
                  studentId: 'STU001',
                  name: 'Aarav Sharma',
                  email: 'aarav@college.ac.in',
                  role: 'student',
                ),
                onToggleTheme: () {},
                initialAnalysis: analysis,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Additional Services'), findsNothing);
          expect(find.text('Additional Service'), findsNothing);

          // 2. Test CreateOrder screen
          await tester.pumpWidget(
            MaterialApp(
              home: CreateOrder(
                dataService: ds,
                profile: const UserProfile(
                  id: 'st_1',
                  studentId: 'STU001',
                  name: 'Aarav Sharma',
                  email: 'aarav@college.ac.in',
                  role: 'student',
                ),
                prices: ShopPrice(
                  bwSingle: 1.0,
                  bwDouble: 1.5,
                  colorSingle: 5.0,
                  colorDouble: 8.0,
                  photocopy: 1.0,
                  lamination: 10.0,
                  updatedAt: DateTime.now(),
                ),
                onToggleTheme: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Additional Services'), findsNothing);
          expect(find.text('Additional Service'), findsNothing);
        },
      );

      testWidgets(
        'Task 1C: Historical order with older additional services renders safely without crash',
        (WidgetTester tester) async {
          final historicalOrder = PrintOrder(
            id: 'hist_ord_001',
            code: '7788',
            studentId: 'STU001',
            studentName: 'Aarav Sharma',
            fileName: 'old_project_report.pdf',
            fileUrl: '',
            fileSizeBytes: 2048,
            pages: 10,
            copies: 1,
            color: false,
            doubleSided: false,
            paperType: PaperType.standard75Gsm,
            bindingType: BindingType.spiral,
            lamination: false,
            binding: true,
            total: 45.0,
            paymentMode: PaymentMode.counter,
            paymentStatus: PaymentStatus.paid,
            status: OrderStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
            priceSnapshot: {
              'additional_services': [
                {
                  'id': 'legacy_stapling',
                  'name': 'Corner Stapling',
                  'price': 5.0,
                },
              ],
            },
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: OrderCard(order: historicalOrder, onTap: () {}),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('old_project_report.pdf'), findsOneWidget);
          expect(find.text('₹45'), findsOneWidget);
        },
      );

      testWidgets(
        'Task 2: Per-Page Inspection has NO Landscape/Portrait or Colour/B&W status pills while page interaction remains intact',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final analysis = DocumentAnalysisResult(
            fileName: 'engineering_drawing.pdf',
            fileSizeBytes: 8192,
            fileExtension: 'pdf',
            analyzedAt: DateTime.now(),
            pages: [
              PageAnalysis(
                pageNumber: 1,
                isBlank: false,
                isColor: false,
                orientation: 'portrait',
              ),
              PageAnalysis(
                pageNumber: 2,
                isBlank: false,
                isColor: true,
                orientation: 'landscape',
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AutomaticDetectionScreen(
                dataService: ds,
                profile: const UserProfile(
                  id: 'st_1',
                  studentId: 'STU001',
                  name: 'Aarav Sharma',
                  email: 'aarav@college.ac.in',
                  role: 'student',
                ),
                onToggleTheme: () {},
                initialAnalysis: analysis,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // 1. Verify visible pills/badges for orientation and color are completely absent
          expect(find.text('Portrait'), findsNothing);
          expect(find.text('Landscape'), findsNothing);
          expect(find.text('B&W'), findsNothing);
          expect(find.text('Colour'), findsNothing);

          // 2. Underlying page metadata and previews are intact
          expect(find.text('Page 1 of 2'), findsOneWidget);
          expect(find.text('Page 2 of 2'), findsOneWidget);

          // 3. Page interaction: tap page 1 toggles its individual color selection
          await tester.tap(find.text('Page 1 of 2'));
          await tester.pump(const Duration(milliseconds: 300));

          // 4. Page exclusion: long press excludes page
          await tester.longPress(find.text('Page 1 of 2'));
          await tester.pump(const Duration(milliseconds: 300));

          // Icon for excluded page appears
          expect(find.byIcon(Icons.block_rounded), findsOneWidget);

          // Long press again restores the page
          await tester.longPress(find.text('Page 1 of 2'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byIcon(Icons.block_rounded), findsNothing);
        },
      );

      testWidgets(
        'Task 3: Bin click requires non-empty reason, validates input, deletes file, and displays reason in student orders',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // Create a completed order ready for Bin removal
          final orderId = await ds.createOrder(
            studentId: 'st_1',
            studentName: 'Aarav Sharma',
            fileName: 'remove_me_file.pdf',
            fileUrl: 'https://example.com/remove_me_file.pdf',
            pages: 5,
            copies: 2,
            color: false,
            doubleSided: false,
            lamination: false,
            binding: false,
            total: 10.0,
            paymentMode: PaymentMode.counter,
            paymentStatus: PaymentStatus.paid,
          );

          await ds.updateOrder(orderId, {
            'status': 'completed',
            'completedAt': DateTime.now(),
          });

          // 1. Open ShopOrders screen
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

          expect(find.text('remove_me_file.pdf'), findsOneWidget);

          // 2. Click Bin button
          final binBtn = find.byTooltip('Delete Document & Remove from Queue');
          expect(binBtn, findsOneWidget);
          await tester.tap(binBtn);
          await tester.pumpAndSettle();

          // Verify removal dialog is displayed
          expect(find.textContaining('from Queue?'), findsOneWidget);
          expect(find.text('Reason for removing this order'), findsOneWidget);
          expect(find.text('Confirm Removal'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);

          // 3. Test empty reason validation
          await tester.tap(find.text('Confirm Removal'));
          await tester.pumpAndSettle();
          expect(
            find.text('Please enter a reason for removing this order.'),
            findsOneWidget,
          );

          // 4. Test whitespace-only reason validation
          final dialogTextField = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(dialogTextField, '     \n   ');
          await tester.tap(find.text('Confirm Removal'));
          await tester.pumpAndSettle();
          expect(
            find.text('Please enter a reason for removing this order.'),
            findsOneWidget,
          );

          // 5. Enter valid removal reason and confirm
          await tester.enterText(
            dialogTextField,
            'Document collected and printed in person',
          );
          await tester.tap(find.text('Confirm Removal'));
          await tester.pump();
          await tester.pumpAndSettle();

          // 6. Verify order is removed from the active shopkeeper queue
          expect(find.text('remove_me_file.pdf'), findsNothing);

          // 7. Verify database record persisted the removal details
          final updatedOrder = ds.allOrdersDirect.firstWhere(
            (o) => o.id == orderId,
          );
          expect(updatedOrder.isDeletedFromQueue, isTrue);
          expect(updatedOrder.isPurged, isTrue);
          expect(updatedOrder.fileUrl, isEmpty);
          expect(
            updatedOrder.removalReason,
            equals('Document collected and printed in person'),
          );
          expect(updatedOrder.removedBy, equals('Shopkeeper'));
          expect(updatedOrder.removedAt, isNotNull);
          // Financial history is preserved
          expect(updatedOrder.total, equals(10.0));
          expect(updatedOrder.pages, equals(5));

          // 8. Verify Student Portal renders "REMOVED BY SHOPKEEPER" and shows reason
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: OrderCard(order: updatedOrder, onTap: () {}),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('REMOVED BY SHOPKEEPER'), findsOneWidget);
          expect(
            find.textContaining(
              'Reason: Document collected and printed in person',
            ),
            findsOneWidget,
          );
          expect(find.text('Removed by Shopkeeper'), findsWidgets);

          // 9. Verify OrderReceipt displays removal reason banner
          await tester.pumpWidget(
            MaterialApp(
              home: OrderReceipt(orderId: orderId, dataService: ds),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Removed by Shopkeeper'), findsWidgets);
          expect(
            find.textContaining('Document collected and printed in person'),
            findsWidgets,
          );
        },
      );
    },
  );
}
