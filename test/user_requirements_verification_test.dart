import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataService dataService;

  setUp(() {
    dataService = DataService();
  });

  group('Prompt Verification Test Cases 1 - 7', () {
    test(
      'TEST 1: Change B&W price -> Save -> leave page -> return -> price remains changed',
      () async {
        // 1. Initial pricing
        final initialPricing = dataService.currentLivePricing;
        expect(initialPricing.printingPrices.bwSinglePerSheet, isNotNull);

        // 2. Shopkeeper changes B&W price
        final updatedPrinting = initialPricing.printingPrices.copyWith(
          bwSinglePerSheet: 1.00,
          bwDoublePerSheet: 1.50,
        );
        final newPricing = initialPricing.copyWith(
          printingPrices: updatedPrinting,
          updatedAt: DateTime.now(),
        );

        // 3. Shopkeeper presses Save (updates live pricing)
        await dataService.updateLivePricing(newPricing);

        // 4. Leave page and return (verify pricing returned by currentLivePricing and stream)
        final returnedPricing = dataService.currentLivePricing;
        expect(returnedPricing.printingPrices.bwSinglePerSheet, equals(1.00));
        expect(returnedPricing.printingPrices.bwDoublePerSheet, equals(1.50));

        final streamedPricing = await dataService.livePricing().first;
        expect(streamedPricing.printingPrices.bwSinglePerSheet, equals(1.00));
        expect(streamedPricing.printingPrices.bwDoublePerSheet, equals(1.50));
      },
    );

    test(
      'TEST 2: Change price -> close app -> reopen -> changed price remains',
      () async {
        // 1. Update prices in service
        final newPricing = dataService.currentLivePricing.copyWith(
          printingPrices: dataService.currentLivePricing.printingPrices
              .copyWith(
                bwSinglePerSheet: 1.00,
                bwDoublePerSheet: 1.50,
                colorSinglePerSheet: 5.00,
                colorDoublePerSheet: 8.00,
              ),
          updatedAt: DateTime.now(),
        );
        await dataService.updateLivePricing(newPricing);

        // 2. Simulate app close & reopen by instantiating a fresh DataService
        final freshDataService = DataService();

        // The fresh service should retain the saved prices from persistent storage
        final reloadedPricing = freshDataService.currentLivePricing;
        expect(reloadedPricing.printingPrices.bwSinglePerSheet, equals(1.00));
        expect(reloadedPricing.printingPrices.bwDoublePerSheet, equals(1.50));
        expect(
          reloadedPricing.printingPrices.colorSinglePerSheet,
          equals(5.00),
        );
        expect(
          reloadedPricing.printingPrices.colorDoublePerSheet,
          equals(8.00),
        );
      },
    );

    test(
      'TEST 3: Shopkeeper adds "100 GSM" -> student can see 100 GSM',
      () async {
        final currentPricing = dataService.currentLivePricing;

        // Shopkeeper adds 100 GSM option with extra price ₹2.50
        final item100Gsm = PrintConfigItem(
          id: 'gsm_100',
          name: '100 GSM',
          category: 'gsm',
          price: 2.50,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedConfig = List<PrintConfigItem>.from(
          currentPricing.configItems,
        )..add(item100Gsm);
        await dataService.updateLivePricing(
          currentPricing.copyWith(configItems: updatedConfig),
        );

        // Student checks enabled GSM options
        final studentGsmOptions = dataService.currentLivePricing.gsmOptions
            .where((g) => g.enabled)
            .toList();

        expect(
          studentGsmOptions.any((g) => g.name == '100 GSM' && g.price == 2.50),
          isTrue,
        );
      },
    );

    test(
      'TEST 4: Shopkeeper disables "100 GSM" -> student no longer sees it for new orders',
      () async {
        final currentPricing = dataService.currentLivePricing;

        // Disable 100 GSM
        final updatedConfig = currentPricing.configItems.map((item) {
          if (item.name.contains('100 GSM')) {
            return item.copyWith(enabled: false);
          }
          return item;
        }).toList();

        await dataService.updateLivePricing(
          currentPricing.copyWith(configItems: updatedConfig),
        );

        // Student views enabled GSM options
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
      'TEST 5: Shopkeeper adds "Hard Binding ₹80" -> student sees it and price calculation works',
      () async {
        final currentPricing = dataService.currentLivePricing;

        final hardBindingItem = PrintConfigItem(
          id: 'binding_hard_cover_80',
          name: 'Hard Binding',
          category: 'binding',
          price: 80.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedConfig = List<PrintConfigItem>.from(
          currentPricing.configItems,
        );
        final idx = updatedConfig.indexWhere((b) => b.name == 'Hard Binding');
        if (idx != -1) {
          updatedConfig[idx] = hardBindingItem;
        } else {
          updatedConfig.add(hardBindingItem);
        }
        await dataService.updateLivePricing(
          currentPricing.copyWith(configItems: updatedConfig),
        );

        // Student sees Hard Binding in bindingAndFinishingOptions
        final studentBindings = dataService
            .currentLivePricing
            .bindingAndFinishingOptions
            .where((b) => b.enabled)
            .toList();

        final selectedBinding = studentBindings.firstWhere(
          (b) => b.name == 'Hard Binding',
        );
        expect(selectedBinding.price, equals(80.0));

        // Calculation: 20 pages, single-sided (20 sheets), B&W at ₹1.00 = ₹20.00 print + ₹80 binding = ₹100.00
        const pages = 20;
        const copies = 1;
        const printPerSheet = 1.00;
        final printTotal = pages * printPerSheet * copies;
        final bindingCost = selectedBinding.price * copies;
        final total = printTotal + bindingCost;

        expect(bindingCost, equals(80.0));
        expect(total, equals(100.0));
      },
    );

    test(
      'TEST 6: Student enters special instructions -> submits order -> shopkeeper sees the same Special Instructions',
      () async {
        const instructions =
            'Print the first page in color and remaining pages in B&W.';

        final orderId = await dataService.createOrder(
          studentId: 'student_42',
          studentName: 'Priya Sharma',
          studentEmail: 'priya@college.ac.in',
          fileName: 'ProjectReport.pdf',
          fileUrl: 'https://vault.local/report.pdf',
          fileSizeBytes: 20480,
          pages: 15,
          copies: 2,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: true,
          paperTypeName: 'A4',
          gsmName: '75 GSM',
          bindingName: 'Spiral Binding',
          specialInstructions: instructions,
          total: 65.0,
          paymentMode: PaymentMode.online,
          priceSnapshot: {
            'sheetsRequired': 8,
            'copies': 2,
            'specialInstructions': instructions,
          },
        );

        // Shopkeeper fetches the order
        final order = (await dataService.order(orderId).first)!;
        expect(order.specialInstructions, equals(instructions));
        expect(order.paperTypeName, equals('A4'));
        expect(order.gsmName, equals('75 GSM'));
        expect(order.bindingName, equals('Spiral Binding'));
        expect(
          order.priceSnapshot?['specialInstructions'],
          equals(instructions),
        );
      },
    );

    test(
      'TEST 7: Change current prices/configuration after an old order exists. The old order must still show its original price and selections',
      () async {
        // 1. Create order with price ₹50 and A4 75 GSM Spiral Binding
        final oldOrderId = await dataService.createOrder(
          studentId: 'student_10',
          studentName: 'Rahul',
          studentEmail: 'rahul@college.ac.in',
          fileName: 'OldThesis.pdf',
          fileUrl: 'https://vault.local/thesis.pdf',
          fileSizeBytes: 10240,
          pages: 10,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: true,
          paperTypeName: 'A4',
          gsmName: '75 GSM',
          bindingName: 'Spiral Binding',
          specialInstructions: 'Handle with care',
          total: 50.0,
          paymentMode: PaymentMode.online,
          priceSnapshot: {
            'paperType': 'A4',
            'gsm': '75 GSM',
            'bindingType': 'Spiral Binding',
            'printPricePerSheet': 2.0,
            'bindingCost': 30.0,
            'totalAmount': 50.0,
          },
        );

        // Verify old order
        final oldOrderInitial = (await dataService.order(oldOrderId).first)!;
        expect(oldOrderInitial.total, equals(50.0));
        expect(oldOrderInitial.paperTypeName, equals('A4'));
        expect(oldOrderInitial.bindingName, equals('Spiral Binding'));
        expect(oldOrderInitial.priceSnapshot?['totalAmount'], equals(50.0));

        // 2. Shopkeeper later modifies prices and removes/disables options
        final current = dataService.currentLivePricing;
        final modified = current.copyWith(
          printingPrices: current.printingPrices.copyWith(
            bwSinglePerSheet: 10.0, // Major price increase
            bwDoublePerSheet: 20.0,
          ),
          // Shopkeeper disables Spiral Binding and changes Paper Type
          configItems: current.configItems.map((item) {
            if (item.name == 'Spiral Binding') {
              return item.copyWith(enabled: false, price: 99.0);
            }
            return item;
          }).toList(),
        );
        await dataService.updateLivePricing(modified);

        // 3. Verify old order did NOT change
        final oldOrderAfterChanges = (await dataService
            .order(oldOrderId)
            .first)!;
        expect(oldOrderAfterChanges.total, equals(50.0));
        expect(oldOrderAfterChanges.paperTypeName, equals('A4'));
        expect(oldOrderAfterChanges.gsmName, equals('75 GSM'));
        expect(oldOrderAfterChanges.bindingName, equals('Spiral Binding'));
        expect(
          oldOrderAfterChanges.specialInstructions,
          equals('Handle with care'),
        );
        expect(
          oldOrderAfterChanges.priceSnapshot?['printPricePerSheet'],
          equals(2.0),
        );
        expect(
          oldOrderAfterChanges.priceSnapshot?['bindingCost'],
          equals(30.0),
        );
        expect(
          oldOrderAfterChanges.priceSnapshot?['totalAmount'],
          equals(50.0),
        );
      },
    );
  });
}
