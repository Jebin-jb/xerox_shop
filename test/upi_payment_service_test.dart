import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/payment/payment_models.dart';
import 'package:campus_xerox/services/payment/upi_payment_service.dart';

void main() {
  group('UpiPaymentService & QR Security Tests', () {
    final service = UpiPaymentService.instance;
    final shopConfig = ShopPaymentConfig(
      merchantName: 'Campus Xerox Center',
      upiId: 'campusxerox@okaxis',
      updatedAt: DateTime.now(),
    );

    test(
      'buildUpiUri creates valid upi://pay URI with required parameters',
      () {
        final uri = service.buildUpiUri(
          shop: shopConfig,
          amount: 70.0,
          orderCode: 'CP-A105',
          note: 'Print Order CP-A105',
        );

        expect(uri.scheme, equals('upi'));
        expect(uri.host, equals('pay'));
        expect(uri.queryParameters['pa'], equals('campusxerox@okaxis'));
        expect(uri.queryParameters['pn'], equals('Campus Xerox Center'));
        expect(uri.queryParameters['am'], equals('70.00'));
        expect(uri.queryParameters['cu'], equals('INR'));
        expect(uri.queryParameters['tn'], equals('Print Order CP-A105'));
      },
    );

    test(
      'validateQrCode accepts authentic Xerox shop QR and enforces order.totalAmount',
      () {
        const qrRaw =
            'upi://pay?pa=campusxerox@okaxis&pn=Campus%20Xerox%20Center&cu=INR';

        final result = service.validateQrCode(
          scannedRaw: qrRaw,
          registeredShop: shopConfig,
          orderAmount: 85.50, // Real order amount
        );

        expect(result.isValid, isTrue);
        expect(result.upiId, equals('campusxerox@okaxis'));
        expect(result.enforcedAmount, equals(85.50));
        expect(result.errorMessage, isNull);
      },
    );

    test(
      'validateQrCode ignores any malicious am= in QR and strictly enforces orderAmount',
      () {
        // Attacker generated QR with am=1.00 trying to underpay
        const tamperedQr =
            'upi://pay?pa=campusxerox@okaxis&pn=Campus%20Xerox&am=1.00&cu=INR';

        final result = service.validateQrCode(
          scannedRaw: tamperedQr,
          registeredShop: shopConfig,
          orderAmount: 120.00, // True order price
        );

        expect(result.isValid, isTrue);
        // Strictly enforced from order.totalAmount, not the 1.00 in the QR!
        expect(result.enforcedAmount, equals(120.00));
      },
    );

    test('validateQrCode rejects fraudulent QR with mismatched UPI ID', () {
      // Imposter/fraudulent merchant QR
      const imposterQr = 'upi://pay?pa=scammer@oksbi&pn=Fake%20Shop&cu=INR';

      final result = service.validateQrCode(
        scannedRaw: imposterQr,
        registeredShop: shopConfig,
        orderAmount: 70.00,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        equals('This QR code does not belong to the registered Xerox shop.'),
      );
    });

    test('validateQrCode rejects empty or invalid QR strings', () {
      final emptyResult = service.validateQrCode(
        scannedRaw: '   ',
        registeredShop: shopConfig,
        orderAmount: 70.00,
      );
      expect(emptyResult.isValid, isFalse);

      final invalidResult = service.validateQrCode(
        scannedRaw: 'https://example.com/not-a-upi-qr',
        registeredShop: shopConfig,
        orderAmount: 70.00,
      );
      expect(invalidResult.isValid, isFalse);
    });

    test('ShopPaymentConfig serializes and deserializes correctly', () {
      final json = {
        'merchantName': 'Main Campus Xerox',
        'upiId': 'xeroxmain@oksbi',
        'updatedAt': '2026-10-09T10:00:00.000Z',
      };

      final config = ShopPaymentConfig.fromMap(json);
      expect(config.merchantName, equals('Main Campus Xerox'));
      expect(config.upiId, equals('xeroxmain@oksbi'));

      final backToJson = config.toMap();
      expect(backToJson['merchantName'], equals('Main Campus Xerox'));
      expect(backToJson['upiId'], equals('xeroxmain@oksbi'));
    });

    test('UpiPaymentResult marks demo confirmation explicitly', () {
      final result = UpiPaymentResult.demoSuccess(
        method: PaymentAppMethod.googlePay,
        amount: 70.0,
        orderCode: 'CP-A105',
      );

      expect(result.status, equals(PaymentStatusState.paid));
      expect(result.isDemoConfirmation, isTrue);
      expect(result.transactionReference, startsWith('TXN_'));
      expect(result.amount, equals(70.0));
      expect(result.method, equals(PaymentAppMethod.googlePay));
    });
  });
}
