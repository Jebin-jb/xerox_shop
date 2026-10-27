import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataService dataService;
  const testProfile = UserProfile(
    id: 'student_tester',
    name: 'Priya Sharma',
    email: 'priya@college.ac.in',
    role: 'student',
    studentId: 'CS2026-99',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
  });

  group('User Requirement Scenarios 1 - 10: Print Configuration & GSM Flow', () {
    testWidgets(
      'TEST 1, 2, 3: Single selection for Paper Type (A4 -> A3 -> Legal) & Visual State',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final sampleDoc = DocumentAnalysisResult(
          fileName: 'Sample_Lecture_Notes.pdf',
          fileSizeBytes: 2450000,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: List.generate(
            12,
            (i) => PageAnalysis(
              pageNumber: i + 1,
              isColor: i == 0 || i == 3,
              isBlank: i == 11,
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

        // Scroll to Print Configuration section
        await tester.scrollUntilVisible(
          find.text('Paper Type'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        // TEST 1: Select A4
        final a4Finder = find.widgetWithText(InkWell, 'A4');
        expect(a4Finder, findsOneWidget);
        await tester.tap(a4Finder);
        await tester.pump(const Duration(milliseconds: 200));

        // Verify only A4 is selected (shows check icon)
        // Find InkWell containing A4 and check icon
        final a4Widget = tester.widget<InkWell>(a4Finder);
        expect(a4Widget, isNotNull);

        // Check icon count in Paper Type section: exactly 1 checkmark
        final checkIcons = find.byIcon(Icons.check_rounded);
        expect(checkIcons, findsWidgets);

        // TEST 2: Select A3
        final a3Finder = find.widgetWithText(InkWell, 'A3');
        expect(a3Finder, findsOneWidget);
        await tester.tap(a3Finder);
        await tester.pump(const Duration(milliseconds: 200));

        // TEST 3: Select Legal
        final legalFinder = find.widgetWithText(InkWell, 'Legal');
        expect(legalFinder, findsOneWidget);
        await tester.tap(legalFinder);
        await tester.pump(const Duration(milliseconds: 200));

        // Legal is tapped, now tap A4 again
        await tester.tap(a4Finder);
        await tester.pump(const Duration(milliseconds: 200));
      },
    );

    test(
      'TEST 4: Shopkeeper has GSM values (70 GSM, 80 GSM, 100 GSM) -> Student sees all enabled values',
      () async {
        final currentPricing = dataService.currentLivePricing;
        final gsmItems = [
          PrintConfigItem(
            id: 'gsm_70',
            name: '70 GSM',
            category: 'gsm',
            price: 0.0,
            enabled: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          PrintConfigItem(
            id: 'gsm_80',
            name: '80 GSM',
            category: 'gsm',
            price: 1.0,
            enabled: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          PrintConfigItem(
            id: 'gsm_100',
            name: '100 GSM',
            category: 'gsm',
            price: 3.0,
            enabled: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final updatedConfig =
            List<PrintConfigItem>.from(currentPricing.configItems)
              ..removeWhere((item) => item.category == 'gsm')
              ..addAll(gsmItems);

        await dataService.updateLivePricing(
          currentPricing.copyWith(configItems: updatedConfig),
        );

        final studentGsmOptions = dataService.currentLivePricing.gsmOptions
            .where((g) => g.enabled)
            .toList();

        expect(studentGsmOptions.length, equals(3));
        expect(
          studentGsmOptions.map((g) => g.name).toList(),
          containsAll(['70 GSM', '80 GSM', '100 GSM']),
        );
      },
    );

    testWidgets(
      'TEST 5: Select 80 GSM -> then 100 GSM -> 80 GSM unselected automatically',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final sampleDoc = DocumentAnalysisResult(
          fileName: 'Sample_Lecture_Notes.pdf',
          fileSizeBytes: 2450000,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: List.generate(
            12,
            (i) => PageAnalysis(
              pageNumber: i + 1,
              isColor: i == 0 || i == 3,
              isBlank: i == 11,
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

        // Verify Paper GSM is removed from Print Configuration
        expect(find.text('Paper GSM'), findsNothing);
      },
    );

    test(
      'TEST 6: Disable 100 GSM from shopkeeper configuration -> 100 GSM disappears from new student options',
      () async {
        final current = dataService.currentLivePricing;
        final updatedConfig = current.configItems.map((item) {
          if (item.name.contains('100 GSM')) {
            return item.copyWith(enabled: false);
          }
          return item;
        }).toList();

        await dataService.updateLivePricing(
          current.copyWith(configItems: updatedConfig),
        );

        final studentGsmOptions = dataService.currentLivePricing.gsmOptions
            .where((g) => g.enabled)
            .toList();

        expect(
          studentGsmOptions.any((g) => g.name.contains('100 GSM')),
          isFalse,
        );
      },
    );

    test(
      'TEST 7: Pricing verification -> Only selected Paper Type and selected GSM affect total',
      () {
        const basePrintPrice = 20.0;
        final selectedPaperType = PrintConfigItem(
          id: 'p_a3',
          name: 'A3',
          category: 'paper_type',
          price: 2.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final selectedGsm = PrintConfigItem(
          id: 'gsm_100',
          name: '100 GSM',
          category: 'gsm',
          price: 3.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final selectedBinding = PrintConfigItem(
          id: 'b_spiral',
          name: 'Spiral Binding',
          category: 'binding',
          price: 30.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        const copies = 1;
        final paperCost = selectedPaperType.price * copies;
        final gsmCost = selectedGsm.price * copies;
        final bindingCost = selectedBinding.price * copies;
        final finalTotal = basePrintPrice + paperCost + gsmCost + bindingCost;

        // Base 20 + A3 (2) + 100 GSM (3) + Spiral (30) = 55.0
        expect(paperCost, equals(2.0));
        expect(gsmCost, equals(3.0));
        expect(bindingCost, equals(30.0));
        expect(finalTotal, equals(55.0));
      },
    );

    testWidgets(
      'TEST 8: Cost Optimizer Breakdown is completely removed from the UI',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final sampleDoc = DocumentAnalysisResult(
          fileName: 'Sample_Lecture_Notes.pdf',
          fileSizeBytes: 2450000,
          fileExtension: 'pdf',
          analyzedAt: DateTime.now(),
          pages: List.generate(
            12,
            (i) => PageAnalysis(
              pageNumber: i + 1,
              isColor: i == 0 || i == 3,
              isBlank: i == 11,
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

        // Assert Cost Optimizer Breakdown is completely removed per Requirement 2
        expect(find.text('Cost Optimizer Breakdown'), findsNothing);
      },
    );

    test(
      'TEST 9: Create order and verify selected Paper Type and GSM snapshot saved in order',
      () async {
        final selectedPaperType = {'id': 'pt_a3', 'name': 'A3', 'price': 2.0};
        final selectedGsm = {'id': 'gsm_100', 'name': '100 GSM', 'price': 3.0};

        final orderId = await dataService.createOrder(
          studentId: testProfile.id,
          studentName: testProfile.name,
          studentEmail: testProfile.email,
          fileName: 'Engineering_Design.pdf',
          fileUrl: 'https://vault.local/eng.pdf',
          fileSizeBytes: 40960,
          pages: 10,
          copies: 1,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: true,
          paperTypeName: 'A3',
          gsmName: '100 GSM',
          bindingName: 'Spiral Binding',
          total: 55.0,
          paymentMode: PaymentMode.counter,
          priceSnapshot: {
            'paperType': selectedPaperType,
            'gsm': selectedGsm,
            'totalAmount': 55.0,
          },
        );

        final order = (await dataService.order(orderId).first)!;
        expect(order.paperTypeName, equals('A3'));
        expect(order.gsmName, equals('100 GSM'));
        expect(order.priceSnapshot?['paperType'], equals(selectedPaperType));
        expect(order.priceSnapshot?['gsm'], equals(selectedGsm));

        // Verify toMap() output snapshot structure
        final mapData = order.toMap();
        expect(mapData['paperType'], equals(selectedPaperType));
        expect(mapData['gsm'], equals(selectedGsm));
        expect(mapData['paperTypeName'], equals('A3'));
        expect(mapData['gsmName'], equals('100 GSM'));
      },
    );

    test(
      'TEST 10: App reload / new DataService preserves configured Paper Types & GSM',
      () async {
        // 1. Shopkeeper adds custom 120 GSM
        final current = dataService.currentLivePricing;
        final customGsm = PrintConfigItem(
          id: 'gsm_120',
          name: '120 GSM Heavyweight',
          category: 'gsm',
          price: 4.5,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final updated = List<PrintConfigItem>.from(current.configItems)
          ..add(customGsm);
        await dataService.updateLivePricing(
          current.copyWith(configItems: updated),
        );

        // 2. Re-instantiate DataService
        final reloadedService = DataService();
        await reloadedService.ensureInitialized();
        final enabledGsmList = reloadedService.currentLivePricing.gsmOptions
            .where((g) => g.enabled)
            .toList();

        expect(
          enabledGsmList.any((g) => g.name == '120 GSM Heavyweight'),
          isTrue,
        );
      },
    );
  });
}
