import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';
import 'package:campus_xerox/screens/shopkeeper/price_management.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Live Price Control & Print Configuration Integration Tests', () {
    test(
      '1. Add service -> Saved to data service -> Available in additionalServiceOptions',
      () async {
        final ds = DataService();
        await ds.ensureInitialized();

        final now = DateTime.now();
        final newService = PrintConfigItem(
          id: 'srv_glossy_cover',
          name: 'Glossy Laminated Cover',
          category: 'additionalService',
          price: 15.0,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        );

        final current = ds.currentLivePricing;
        final updatedList = List<PrintConfigItem>.from(current.configItems)
          ..add(newService);

        final updatedPricing = current.copyWith(
          configItems: updatedList,
          updatedAt: now,
        );

        await ds.updateLivePricing(updatedPricing);

        // Verify available in live pricing
        final freshPricing = ds.currentLivePricing;
        final match = freshPricing.additionalServiceOptions
            .where((s) => s.id == 'srv_glossy_cover')
            .firstOrNull;

        expect(match, isNotNull);
        expect(match!.name, equals('Glossy Laminated Cover'));
        expect(match.price, equals(15.0));
        expect(match.enabled, isTrue);
      },
    );

    test(
      '2. Edit service price -> Reflects immediately in live pricing',
      () async {
        final ds = DataService();
        await ds.ensureInitialized();

        final now = DateTime.now();
        final initialService = PrintConfigItem(
          id: 'srv_folding',
          name: 'Brochure Folding',
          category: 'additionalService',
          price: 5.0,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        );

        var current = ds.currentLivePricing;
        var updatedList = List<PrintConfigItem>.from(current.configItems)
          ..add(initialService);
        await ds.updateLivePricing(
          current.copyWith(configItems: updatedList, updatedAt: now),
        );

        // Edit price from 5.0 to 12.0
        current = ds.currentLivePricing;
        final editedList = current.configItems.map((item) {
          if (item.id == 'srv_folding') {
            return item.copyWith(price: 12.0, updatedAt: DateTime.now());
          }
          return item;
        }).toList();

        await ds.updateLivePricing(
          current.copyWith(configItems: editedList, updatedAt: DateTime.now()),
        );

        final updatedPricing = ds.currentLivePricing;
        final match = updatedPricing.additionalServiceOptions
            .where((s) => s.id == 'srv_folding')
            .firstOrNull;

        expect(match, isNotNull);
        expect(match!.price, equals(12.0));
      },
    );

    test(
      '3. Disable service -> Excluded from active student options while historical data is preserved',
      () async {
        final ds = DataService();
        await ds.ensureInitialized();

        final now = DateTime.now();
        final testService = PrintConfigItem(
          id: 'srv_hole_punch',
          name: 'Hole Punching',
          category: 'additionalService',
          price: 3.0,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        );

        var current = ds.currentLivePricing;
        var updatedList = List<PrintConfigItem>.from(current.configItems)
          ..add(testService);
        await ds.updateLivePricing(
          current.copyWith(configItems: updatedList, updatedAt: now),
        );

        // Order placed while service is active
        final orderId = await ds.createOrder(
          studentId: 'st_101',
          studentName: 'Rohan Sharma',
          fileName: 'project.pdf',
          fileUrl: 'vault/project.pdf',
          pages: 10,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 13.0, // 10 pages * 1.0 + 3.0 hole punch
          paymentMode: PaymentMode.counter,
          priceSnapshot: {
            'additionalServices': [
              {'id': testService.id, 'name': testService.name, 'price': 3.0},
            ],
            'additionalServicesCost': 3.0,
          },
        );

        // Shopkeeper disables the service
        current = ds.currentLivePricing;
        final disabledList = current.configItems.map((item) {
          if (item.id == 'srv_hole_punch') {
            return item.copyWith(enabled: false, updatedAt: DateTime.now());
          }
          return item;
        }).toList();

        await ds.updateLivePricing(
          current.copyWith(
            configItems: disabledList,
            updatedAt: DateTime.now(),
          ),
        );

        // Active student options must exclude the disabled service
        final activeServices = ds.currentLivePricing.additionalServiceOptions
            .where((s) => s.enabled)
            .toList();
        expect(
          activeServices.any((s) => s.id == 'srv_hole_punch'),
          isFalse,
          reason: 'Disabled service must not appear in active student options',
        );

        // Historical order must retain its original snapshot
        final placedOrder = ds.allOrdersDirect.firstWhere(
          (o) => o.id == orderId,
        );
        expect(placedOrder.priceSnapshot, isNotNull);
        final recordedServices =
            placedOrder.priceSnapshot!['additionalServices'] as List;
        expect(recordedServices.length, equals(1));
        expect(recordedServices.first['name'], equals('Hole Punching'));
      },
    );

    test(
      '4. App restart / new DataService preserves custom services',
      () async {
        final ds = DataService();
        await ds.ensureInitialized();

        final now = DateTime.now();
        final customService = PrintConfigItem(
          id: 'srv_staple_corner',
          name: 'Corner Staple Service',
          category: 'additionalService',
          price: 2.0,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        );

        final current = ds.currentLivePricing;
        final updatedList = List<PrintConfigItem>.from(current.configItems)
          ..add(customService);
        await ds.updateLivePricing(
          current.copyWith(configItems: updatedList, updatedAt: now),
        );

        // Simulate app restart by instantiating fresh DataService
        final freshDs = DataService();
        await freshDs.ensureInitialized();

        final loadedPricing = freshDs.currentLivePricing;
        final match = loadedPricing.additionalServiceOptions
            .where((s) => s.id == 'srv_staple_corner')
            .firstOrNull;

        expect(match, isNotNull);
        expect(match!.name, equals('Corner Staple Service'));
        expect(match.price, equals(2.0));
        expect(match.enabled, isTrue);
      },
    );

    testWidgets(
      '5. Live Price Control UI: Additional Services tab is completely removed',
      (tester) async {
        final ds = DataService();
        await ds.ensureInitialized();

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

        // Verify remaining 3 tabs exist
        expect(find.text('Paper Types'), findsOneWidget);
        expect(find.text('Printing'), findsOneWidget);
        expect(find.text('Finishing & Binding'), findsOneWidget);

        // Verify "Additional Services" tab and controls are completely removed
        expect(find.text('Additional Services'), findsNothing);
        expect(find.text('+ Add First Additional Service'), findsNothing);
        expect(find.text('Add First Additional Service'), findsNothing);
      },
    );

    testWidgets(
      '6. Print Configuration screen does NOT render Additional Services option',
      (tester) async {
        final ds = DataService();
        await ds.ensureInitialized();

        // Create sample analysis
        final analysis = DocumentAnalysisResult(
          fileName: 'assignment.pdf',
          fileSizeBytes: 2048,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: [
            PageAnalysis(pageNumber: 1, isBlank: false, isColor: false),
            PageAnalysis(pageNumber: 2, isBlank: false, isColor: false),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AutomaticDetectionScreen(
              dataService: ds,
              profile: const UserProfile(
                id: 'st_101',
                studentId: 'CS2026',
                name: 'Kavita Patel',
                email: 'kavita@college.ac.in',
                role: 'student',
              ),
              onToggleTheme: () {},
              initialAnalysis: analysis,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Verify "Additional Services" section is completely removed from Print Configuration
        expect(find.text('Additional Services'), findsNothing);

        // Verify standard print options like Paper Type, Binding, Lamination are present
        await tester.drag(find.byType(ListView).first, const Offset(0, -800));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Paper Type'), findsOneWidget);
        expect(find.text('Finishing & Binding'), findsOneWidget);
        expect(find.text('Document Lamination'), findsOneWidget);
      },
    );
  });
}
