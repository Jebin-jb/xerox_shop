import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/auth_service.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';
import 'package:campus_xerox/services/payment/payment_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TEST 1 - 4: Online Payment Outcomes & Bug Fix Verification', () {
    test(
      'TEST 1: Confirmed Success results in paymentStatus = paid and can mark order as paid',
      () {
        final successResult = UpiPaymentResult.demoSuccess(
          method: PaymentAppMethod.googlePay,
          orderCode: 'CP-T101',
          amount: 70.0,
        );

        expect(successResult.isPaid, isTrue);
        expect(successResult.isFailed, isFalse);
        expect(successResult.isCancelled, isFalse);
        expect(successResult.isVerificationPending, isFalse);
        expect(successResult.status, equals(PaymentStatusState.paid));

        final paymentStatus = successResult.isPaid
            ? PaymentStatus.paid
            : PaymentStatus.unpaid;
        expect(paymentStatus, equals(PaymentStatus.paid));
      },
    );

    test(
      'TEST 2: Cancelled / Return from UPI app without proof must NEVER mark paid',
      () {
        final cancelledResult = UpiPaymentResult.cancelled(
          method: PaymentAppMethod.phonePe,
          amount: 70.0,
        );

        expect(cancelledResult.isPaid, isFalse);
        expect(cancelledResult.isCancelled, isTrue);
        expect(cancelledResult.isFailed, isFalse);
        expect(cancelledResult.isVerificationPending, isFalse);
        expect(cancelledResult.status, equals(PaymentStatusState.cancelled));

        // Verify paymentStatus must be cancelled, NEVER paid
        final paymentStatus = cancelledResult.isPaid
            ? PaymentStatus.paid
            : (cancelledResult.isCancelled
                  ? PaymentStatus.cancelled
                  : PaymentStatus.failed);
        expect(paymentStatus, equals(PaymentStatus.cancelled));
        expect(paymentStatus, isNot(equals(PaymentStatus.paid)));
      },
    );

    test(
      'TEST 3: Payment failure produces paymentStatus = failed and NEVER paid',
      () {
        final failedResult = UpiPaymentResult.failed(
          method: PaymentAppMethod.paytm,
          amount: 70.0,
          message: 'Transaction declined by issuing bank',
        );

        expect(failedResult.isPaid, isFalse);
        expect(failedResult.isFailed, isTrue);
        expect(failedResult.isCancelled, isFalse);
        expect(failedResult.status, equals(PaymentStatusState.failed));

        final paymentStatus = failedResult.isPaid
            ? PaymentStatus.paid
            : PaymentStatus.failed;
        expect(paymentStatus, equals(PaymentStatus.failed));
        expect(paymentStatus, isNot(equals(PaymentStatus.paid)));
      },
    );

    test(
      'TEST 4: Returning from UPI app without reliable bank receipt is VERIFICATION_PENDING, not paid',
      () {
        final pendingResult = UpiPaymentResult.verificationPending(
          method: PaymentAppMethod.otherUpi,
          amount: 70.0,
          orderCode: 'CP-T104',
        );

        expect(pendingResult.isPaid, isFalse);
        expect(pendingResult.isVerificationPending, isTrue);
        expect(
          pendingResult.status,
          equals(PaymentStatusState.verificationPending),
        );

        // Must be marked as verification_pending, NOT paid
        final paymentStatus = pendingResult.isPaid
            ? PaymentStatus.paid
            : (pendingResult.isVerificationPending
                  ? PaymentStatus.verification_pending
                  : PaymentStatus.failed);
        expect(paymentStatus, equals(PaymentStatus.verification_pending));
        expect(paymentStatus, isNot(equals(PaymentStatus.paid)));
      },
    );

    test('Generic online UPI payment config and account configuration', () {
      expect(CentralPaymentConfig.shopName, equals('Campus Xerox'));
      expect(CentralPaymentConfig.provider, equals('Generic UPI Payment'));

      // New ShopPaymentAccount model
      final emptyAcc = ShopPaymentAccount.empty();
      expect(emptyAcc.isConfigured, isFalse);
      expect(emptyAcc.maskedAccountNumber, isEmpty);

      final configuredAcc = ShopPaymentAccount(
        accountHolderName: 'Campus Xerox Shop',
        bankName: 'State Bank of India',
        accountNumber: '123456789012',
        ifsc: 'SBIN0001234',
        upiId: 'campusxerox@upi',
        paymentDisplayName: 'Campus Xerox Shop',
        isOnlinePaymentEnabled: true,
        updatedAt: DateTime.now(),
      );
      expect(configuredAcc.isConfigured, isTrue);
      expect(configuredAcc.maskedAccountNumber, equals('XXXXXXXX9012'));
      expect(
        configuredAcc.toSafeStudentMap().containsKey('accountNumber'),
        isFalse,
      );
      expect(configuredAcc.toSafeStudentMap().containsKey('ifsc'), isFalse);
      expect(
        configuredAcc.toSafeStudentMap()['upiId'],
        equals('campusxerox@upi'),
      );
    });

    test('TEST 4B: Correct Double-Side Calculation Formula', () {
      // For Single Side: Sheets = pageCount
      // For Double Side: Sheets = ceil(pageCount / 2)
      int calculateSheets({required int pages, required bool doubleSided}) {
        return doubleSided ? (pages / 2).ceil() : pages;
      }

      expect(calculateSheets(pages: 20, doubleSided: false), equals(20));
      expect(calculateSheets(pages: 20, doubleSided: true), equals(10));
      expect(calculateSheets(pages: 21, doubleSided: true), equals(11));

      // 20 pages Double Side, 10 sheets * ₹1.50 * 2 copies = ₹30
      final sheets20 = calculateSheets(pages: 20, doubleSided: true);
      const pricePerSheet = 1.50;
      const copies = 2;
      final printingCost = sheets20 * pricePerSheet * copies;
      expect(printingCost, equals(30.0));

      // 21 pages Double Side, 11 sheets * ₹1.50 * 2 copies = ₹33
      final sheets21 = calculateSheets(pages: 21, doubleSided: true);
      final printingCost21 = sheets21 * pricePerSheet * copies;
      expect(printingCost21, equals(33.0));
    });

    test(
      'TEST 4C: Price Snapshot preserves old order receipts against future price changes',
      () async {
        final ds = DataService();
        final orderId = await ds.createOrder(
          studentId: 'student_1',
          studentName: 'Aman Singh',
          fileName: 'Project.pdf',
          fileUrl: 'https://vault.local/proj.pdf',
          pages: 21,
          copies: 2,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: true,
          total: 63.0,
          paymentMode: PaymentMode.online,
          priceSnapshot: {
            'sheetsRequired': 11,
            'pricePerSheet': 1.50,
            'printingCost': 33.0,
            'bindingCost': 30.0,
            'total': 63.0,
          },
        );

        final order = (await ds.order(orderId).first)!;
        expect(order.priceSnapshot, isNotNull);
        expect(order.priceSnapshot!['sheetsRequired'], equals(11));
        expect(order.priceSnapshot!['pricePerSheet'], equals(1.50));
        expect(order.priceSnapshot!['total'], equals(63.0));

        // Shopkeeper changes live prices to ₹2.50 per sheet
        await ds.updatePrices(ds.currentPrices.copyWith(bwDouble: 2.50));

        // Existing order's priceSnapshot MUST NOT change
        final refreshedOrder = (await ds.order(orderId).first)!;
        expect(refreshedOrder.priceSnapshot!['pricePerSheet'], equals(1.50));
        expect(refreshedOrder.priceSnapshot!['total'], equals(63.0));
      },
    );
  });

  group('TEST 5 & 6: Pay at Counter Workflow', () {
    late DataService dataService;

    setUp(() {
      dataService = DataService();
    });

    test(
      'TEST 5: Choosing Pay at Counter creates order with paymentStatus = unpaid, orderStatus = pending',
      () async {
        final orderId = await dataService.createOrder(
          studentId: 'stud-1',
          studentName: 'Rahul Verma',
          studentEmail: 'rahul@college.ac.in',
          fileName: 'Lab_Report.pdf',
          fileUrl: 'https://vault.local/files/lab.pdf',
          fileSizeBytes: 2048,
          pages: 10,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 10.0,
          paymentMode: PaymentMode.counter,
        );

        final order = await dataService.order(orderId).first;
        expect(order, isNotNull);
        expect(order!.paymentMode, equals(PaymentMode.counter));
        expect(order.paymentStatus, equals(PaymentStatus.unpaid));
        expect(order.status, equals(OrderStatus.pending));
        expect(order.code, isNotEmpty);
        // Shopkeeper cannot print yet because status is pending and paymentStatus is unpaid
      },
    );

    test(
      'TEST 6: Shopkeeper searches collection code, receives money, marks paid, printing can start',
      () async {
        final orderId = await dataService.createOrder(
          studentId: 'stud-2',
          studentName: 'Sneha Patel',
          studentEmail: 'sneha@college.ac.in',
          fileName: 'Project_Design.pdf',
          fileUrl: 'https://vault.local/files/design.pdf',
          fileSizeBytes: 4096,
          pages: 5,
          copies: 2,
          color: true,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 50.0,
          paymentMode: PaymentMode.counter,
        );

        final created = (await dataService.order(orderId).first)!;
        final collectionCode = created.code;

        // Shopkeeper searches by code
        final searchResults = dataService.allOrdersDirect
            .where((o) => o.code == collectionCode)
            .toList();
        expect(searchResults, hasLength(1));
        expect(searchResults.first.id, equals(orderId));

        // Shopkeeper receives 50 INR and confirms payment at counter
        await dataService.updateOrder(orderId, {
          'paymentStatus': 'paid',
          'status': 'accepted',
        });

        final updated = (await dataService.order(orderId).first)!;
        expect(updated.paymentStatus, equals(PaymentStatus.paid));
        expect(updated.status, equals(OrderStatus.accepted));

        // Shopkeeper starts printing
        await dataService.updateOrder(orderId, {'status': 'printing'});
        final printing = (await dataService.order(orderId).first)!;
        expect(printing.status, equals(OrderStatus.printing));
      },
    );
  });

  group('TEST 7: Shopkeeper Login Credentials', () {
    test(
      'TEST 7: Login with xeroxshop@college.ac.in and 1234 returns role shopkeeper',
      () async {
        final auth = AuthService();
        await auth.isReady;

        await auth.signIn('xeroxshop@college.ac.in', '1234');

        expect(auth.currentUser, isNotNull);
        expect(auth.currentUser!.email, equals('xeroxshop@college.ac.in'));
        final profile = auth.profile(auth.currentUser!.uid);
        expect(profile, isNotNull);
        expect(profile!.role, equals('shopkeeper'));
        expect(profile.name, equals('Campus Xerox'));
      },
    );
  });

  group('TEST 8: Auto Detect Mixed-Color Price Calculation', () {
    test(
      'TEST 8: 2 B&W pages + 2 Color pages calculated as (2 × B&W) + (2 × Color)',
      () {
        final prices = ShopPrice(
          bwSingle: 1.0,
          bwDouble: 1.5,
          colorSingle: 5.0,
          colorDouble: 8.0,
          photocopy: 1.0,
          lamination: 10.0,
          updatedAt: DateTime.now(),
        );

        // Create a document analysis result with 2 B&W pages and 2 Color pages
        final result = DocumentAnalysisResult(
          fileName: 'mixed_document.pdf',
          fileSizeBytes: 10240,
          fileExtension: 'pdf',
          pages: [
            PageAnalysis(pageNumber: 1, isColor: false, isBlank: false),
            PageAnalysis(pageNumber: 2, isColor: true, isBlank: false),
            PageAnalysis(pageNumber: 3, isColor: false, isBlank: false),
            PageAnalysis(pageNumber: 4, isColor: true, isBlank: false),
          ],
          analyzedAt: DateTime.now(),
        );

        expect(result.bwPagesCount, equals(2));
        expect(result.colorPagesCount, equals(2));

        // Mixed calculation: (2 * 1.0) + (2 * 5.0) = 2.0 + 10.0 = 12.0
        final mixedCost = result.calculateCost(
          prices: prices,
          doubleSided: false,
          paperType: PaperType.standard75Gsm,
          bindingType: BindingType.none,
          copies: 1,
          lamination: false,
          mixedOptimization: true,
        );

        expect(mixedCost, equals(12.0));

        // Unoptimized/All-Color would have charged 4 * 5.0 = 20.0
        final allColorCost = result.calculateCost(
          prices: prices,
          doubleSided: false,
          paperType: PaperType.standard75Gsm,
          bindingType: BindingType.none,
          copies: 1,
          lamination: false,
          mixedOptimization: false,
        );

        expect(allColorCost, equals(20.0));
        expect(
          result.potentialSavings(
            prices: prices,
            doubleSided: false,
            paperType: PaperType.standard75Gsm,
            copies: 1,
          ),
          equals(8.0),
        );
      },
    );
  });
}
