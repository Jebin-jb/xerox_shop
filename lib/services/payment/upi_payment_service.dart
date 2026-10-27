import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_models.dart';
import 'payment_models.dart';

/// Service managing UPI Deep-Linking, Android Package Targeting, and QR Validation.
class UpiPaymentService {
  static final UpiPaymentService instance = UpiPaymentService._internal();
  UpiPaymentService._internal();

  static const String packageGooglePay =
      'com.google.android.apps.nbu.paisa.user';
  static const String packagePhonePe = 'com.phonepe.app';
  static const String packagePaytm = 'net.one97.paytm';

  /// Builds standard UPI URI.
  Uri buildUpiUri({
    ShopPaymentConfig? shop,
    ShopPaymentAccount? account,
    required double amount,
    required String orderCode,
    String? note,
  }) {
    final upiId = (account != null && account.upiId.trim().isNotEmpty)
        ? account.upiId.trim()
        : (shop?.upiId.trim() ?? '');
    final merchantName =
        (account != null && account.payeeName.trim().isNotEmpty)
        ? account.payeeName.trim()
        : (shop?.merchantName.trim().isNotEmpty == true
              ? shop!.merchantName.trim()
              : 'Campus Xerox');

    final txnNote = note ?? 'Campus Xerox Order $orderCode';
    final query = <String>[
      'pa=${Uri.encodeComponent(upiId)}',
      'pn=${Uri.encodeComponent(merchantName)}',
      'am=${amount.toStringAsFixed(2)}',
      'cu=INR',
      'tn=${Uri.encodeComponent(txnNote)}',
      'tr=${Uri.encodeComponent(orderCode)}',
    ].join('&');

    return Uri.parse('upi://pay?$query');
  }

  /// Checks if the target payment application can be launched on this device.
  Future<bool> isAppInstalled(PaymentAppMethod method) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    final dummyUri = Uri.parse('upi://pay?pa=test@upi&pn=Test&am=1.00&cu=INR');
    try {
      return await canLaunchUrl(dummyUri);
    } catch (e) {
      debugPrint('Error checking UPI app availability: $e');
      return false;
    }
  }

  /// Initiates payment via the selected UPI App.
  Future<UpiPaymentResult> payWithUpiApp({
    required PaymentAppMethod method,
    ShopPaymentConfig? shop,
    ShopPaymentAccount? account,
    required double amount,
    required String orderCode,
  }) async {
    final uri = buildUpiUri(
      shop: shop,
      account: account,
      amount: amount,
      orderCode: orderCode,
    );

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch && !kIsWeb && Platform.isAndroid) {
        return UpiPaymentResult.failed(
          method: method,
          amount: amount,
          message: '${method.displayName} is not installed on this device.',
        );
      }

      // Launch UPI intent via external application handler
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        // Security fix: Returning from an external UPI app intent must NEVER
        // be automatically treated as successful payment.
        return UpiPaymentResult.verificationPending(
          method: method,
          amount: amount,
          orderCode: orderCode,
          message:
              'Returned from ${method.displayName}. Awaiting confirmation.',
        );
      } else {
        return UpiPaymentResult.failed(
          method: method,
          amount: amount,
          message:
              'Could not open ${method.displayName}. Please choose another payment method.',
        );
      }
    } catch (e) {
      debugPrint('UpiPaymentService error launching ${method.displayName}: $e');
      return UpiPaymentResult.failed(
        method: method,
        amount: amount,
        message: 'Could not open ${method.displayName}: $e',
      );
    }
  }

  /// Validates a scanned QR string against the registered Xerox Shop UPI ID.
  ///
  /// Security Rules:
  /// 1. Scanned `pa` must strictly match the registered Xerox Shop UPI ID.
  /// 2. Any amount in the QR string is completely ignored — `orderAmount` (order.totalAmount)
  ///    is strictly enforced so students cannot tamper with the price.
  QrValidationResult validateQrCode({
    required String scannedRaw,
    required ShopPaymentConfig registeredShop,
    required double orderAmount,
  }) {
    if (scannedRaw.trim().isEmpty) {
      return const QrValidationResult(
        isValid: false,
        errorMessage:
            'Empty QR code detected. Please scan a valid Xerox Shop QR.',
      );
    }

    String? scannedPa;
    String? scannedPn;

    try {
      final uri = Uri.tryParse(scannedRaw.trim());
      if (uri != null && uri.scheme == 'upi' && uri.host == 'pay') {
        scannedPa = uri.queryParameters['pa'];
        scannedPn = uri.queryParameters['pn'];
      } else {
        // Fallback query parsing for raw query strings
        final regexPa = RegExp(r'[?&]pa=([^&]+)');
        final match = regexPa.firstMatch(scannedRaw);
        if (match != null) {
          scannedPa = Uri.decodeComponent(match.group(1)!);
        }
      }
    } catch (e) {
      debugPrint('Error parsing QR raw string: $e');
    }

    if (scannedPa == null || scannedPa.isEmpty) {
      return const QrValidationResult(
        isValid: false,
        errorMessage:
            'Invalid UPI QR format. Please scan the official Xerox Shop QR code.',
      );
    }

    final cleanScanned = scannedPa.trim().toLowerCase();
    final cleanRegistered = registeredShop.upiId.trim().toLowerCase();

    // Strict security check: must match registered shop
    if (cleanScanned != cleanRegistered) {
      return const QrValidationResult(
        isValid: false,
        errorMessage:
            'This QR code does not belong to the registered Xerox shop.',
      );
    }

    return QrValidationResult(
      isValid: true,
      merchantName: (scannedPn != null && scannedPn.isNotEmpty)
          ? scannedPn
          : registeredShop.merchantName,
      upiId: registeredShop.upiId,
      enforcedAmount: orderAmount, // Strictly enforced from order.totalAmount
    );
  }
}
