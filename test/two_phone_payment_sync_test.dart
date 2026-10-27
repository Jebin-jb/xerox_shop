import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/payment/upi_payment_service.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Problem 1 & 2: Dynamic QR, UPI URI Encoding & Payment Status Workflow', () {
    final upiService = UpiPaymentService.instance;

    test(
      'UPI URI generates proper URI encoding with %20 (no +) and uses dynamic Supabase account',
      () {
        final account = ShopPaymentAccount(
          upiId: 'example@okaxis',
          paymentDisplayName: 'Campus Xerox',
          paymentApp: 'Google Pay',
          qrImageUrl:
              'https://rqhtabgmltxrrjkbdclv.supabase.co/storage/v1/object/public/payment_qr/qr_123.jpg',
          isOnlinePaymentEnabled: true,
          updatedAt: DateTime.now(),
        );

        final uri = upiService.buildUpiUri(
          account: account,
          amount: 30.0,
          orderCode: 'CP-X683',
          note: 'Campus Xerox Order CP-X683',
        );

        final uriString = uri.toString();

        // Ensure no '+' exists in the query parameters
        expect(uriString.contains('+'), isFalse);
        expect(uriString, contains('tn=Campus%20Xerox%20Order%20CP-X683'));
        expect(uriString, contains('pa=example%40okaxis'));
        expect(uriString, contains('pn=Campus%20Xerox'));
        expect(uriString, contains('am=30.00'));
        expect(uriString, contains('cu=INR'));
        expect(uri.queryParameters['tn'], equals('Campus Xerox Order CP-X683'));
        expect(uri.queryParameters['pa'], equals('example@okaxis'));
        expect(uri.queryParameters['pn'], equals('Campus Xerox'));
        expect(uri.queryParameters['am'], equals('30.00'));
        expect(uri.queryParameters['cu'], equals('INR'));
      },
    );

    test(
      'Payment Status Workflow: UNPAID -> PAYMENT_INITIATED -> PAYMENT_SUBMITTED (UTR) -> PAID',
      () async {
        final dataService = DataService();

        // 1. Create order
        final orderId = await dataService.createOrder(
          studentId: 'test_student',
          studentName: 'Test Student',
          fileName: 'assignment.pdf',
          fileUrl: 'https://local/assignment.pdf',
          pages: 20,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 20.0,
          paymentMode: PaymentMode.online,
        );

        var order = (await dataService.order(orderId).first)!;
        expect(order.paymentStatus, equals(PaymentStatus.unpaid));
        expect(order.paymentMode, equals(PaymentMode.online));

        // 2. Student opens UPI App -> paymentStatus becomes payment_initiated (DO NOT auto-mark PAID)
        await dataService.updateOrder(orderId, {
          'paymentStatus': PaymentStatus.payment_initiated.name,
        });
        order = (await dataService.order(orderId).first)!;
        expect(order.paymentStatus, equals(PaymentStatus.payment_initiated));

        // 3. Bank limit exceeded / UPI fails -> Student returns, enters UTR -> payment_submitted
        await dataService.updateOrder(orderId, {
          'paymentStatus': PaymentStatus.payment_submitted.name,
          'transactionReference': 'UTR987654321',
        });
        order = (await dataService.order(orderId).first)!;
        expect(order.paymentStatus, equals(PaymentStatus.payment_submitted));
        expect(order.transactionReference, equals('UTR987654321'));

        // 4. Shopkeeper verifies payment -> transitions to PAID
        await dataService.updateOrder(orderId, {
          'paymentStatus': PaymentStatus.paid.name,
        });
        order = (await dataService.order(orderId).first)!;
        expect(order.paymentStatus, equals(PaymentStatus.paid));
      },
    );

    test(
      'Switch Online Pay to Pay at Counter preserves existing order and updates mode/status',
      () async {
        final dataService = DataService();

        final orderId = await dataService.createOrder(
          studentId: 'test_student_counter',
          studentName: 'Counter Test',
          fileName: 'report.pdf',
          fileUrl: 'https://local/report.pdf',
          pages: 10,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: 10.0,
          paymentMode: PaymentMode.online,
        );

        // Student switches online order to Counter
        await dataService.updateOrder(orderId, {
          'paymentMode': PaymentMode.counter.name,
          'paymentStatus': PaymentStatus.unpaid.name,
          'status': OrderStatus.pending.name,
        });

        final updated = (await dataService.order(orderId).first)!;
        expect(updated.id, equals(orderId)); // Same order, no duplicates!
        expect(updated.paymentMode, equals(PaymentMode.counter));
        expect(updated.paymentStatus, equals(PaymentStatus.unpaid));
        expect(updated.code.isNotEmpty, isTrue);
      },
    );
  });

  group('Problem 3: Realtime Prices & Price Snapshot Rule', () {
    test(
      'Price Snapshot Rule: Modifying shop pricing does not alter past confirmed orders',
      () async {
        final dataService = DataService();

        // Order created when B&W = ₹1.00
        final originalPrice = 20.0;
        final orderId = await dataService.createOrder(
          studentId: 'student_snapshot',
          studentName: 'Snapshot Student',
          fileName: 'thesis.pdf',
          fileUrl: 'https://local/thesis.pdf',
          pages: 20,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          total: originalPrice,
          paymentMode: PaymentMode.online,
          priceSnapshot: {
            'unit_price': 1.0,
            'quantity': 20,
            'subtotal': 20.0,
            'total_amount': 20.0,
            'price_breakdown': {'bw_single': 1.0},
          },
        );

        final initialOrder = (await dataService.order(orderId).first)!;
        expect(initialOrder.total, equals(20.0));
        expect(initialOrder.priceSnapshot?['unit_price'], equals(1.0));

        // Now Shopkeeper doubles the price: B&W = ₹2.00
        final currentPrices = dataService.currentPrices;
        await dataService.updatePrices(currentPrices.copyWith(bwSingle: 2.0));

        // New pricing is now 2.0
        expect(dataService.currentPrices.bwSingle, equals(2.0));

        // But OLD order retains its original ₹20.0 total and unit price of 1.0!
        final fetchedOldOrder = (await dataService.order(orderId).first)!;
        expect(fetchedOldOrder.total, equals(originalPrice));
        expect(fetchedOldOrder.priceSnapshot?['unit_price'], equals(1.0));
        expect(fetchedOldOrder.priceSnapshot?['total_amount'], equals(20.0));
      },
    );

    test(
      'Realtime Stream: Student stream receives updated price immediately when Shopkeeper changes price',
      () async {
        final dataService = DataService();
        final stream = dataService.prices();

        final emittedPrices = <double>[];
        final subscription = stream.listen((prices) {
          emittedPrices.add(prices.bwSingle);
        });

        // Shopkeeper changes price on Phone B
        await dataService.updatePrices(
          dataService.currentPrices.copyWith(bwSingle: 2.50),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(emittedPrices.contains(2.50), isTrue);
        await subscription.cancel();
      },
    );

    test(
      'ShopPaymentAccount stream updates in realtime when new QR / UPI ID is uploaded',
      () async {
        final dataService = DataService();
        final stream = dataService.paymentAccount();

        final emittedUpiIds = <String>[];
        final subscription = stream.listen((account) {
          emittedUpiIds.add(account.upiId);
        });

        final newAccount = ShopPaymentAccount(
          upiId: 'new_gpay@okaxis',
          paymentDisplayName: 'Campus Xerox Modern',
          paymentApp: 'Google Pay',
          qrImageUrl:
              'https://rqhtabgmltxrrjkbdclv.supabase.co/storage/v1/object/public/payment_qr/qr_new.png',
          isOnlinePaymentEnabled: true,
          updatedAt: DateTime.now(),
        );

        await dataService.updatePaymentAccount(newAccount);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(emittedUpiIds.contains('new_gpay@okaxis'), isTrue);
        expect(
          dataService.currentPaymentAccount.qrImageUrl,
          equals(newAccount.qrImageUrl),
        );
        await subscription.cancel();
      },
    );
  });
}
