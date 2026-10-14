enum PaymentAppMethod {
  googlePay,
  phonePe,
  paytm,
  otherUpi,
  counter;

  String get displayName {
    switch (this) {
      case PaymentAppMethod.googlePay:
        return 'Google Pay';
      case PaymentAppMethod.phonePe:
        return 'PhonePe';
      case PaymentAppMethod.paytm:
        return 'Paytm';
      case PaymentAppMethod.otherUpi:
        return 'Other UPI Apps';
      case PaymentAppMethod.counter:
        return 'Pay at Counter';
    }
  }

  String get dbCode {
    switch (this) {
      case PaymentAppMethod.googlePay:
        return 'GOOGLE_PAY';
      case PaymentAppMethod.phonePe:
        return 'PHONEPE';
      case PaymentAppMethod.paytm:
        return 'PAYTM';
      case PaymentAppMethod.otherUpi:
        return 'OTHER_UPI';
      case PaymentAppMethod.counter:
        return 'COUNTER';
    }
  }

  static PaymentAppMethod fromDbCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'GOOGLE_PAY':
        return PaymentAppMethod.googlePay;
      case 'PHONEPE':
        return PaymentAppMethod.phonePe;
      case 'PAYTM':
        return PaymentAppMethod.paytm;
      case 'FAMPAY_UPI':
      case 'OTHER_UPI':
      case 'QR_UPI':
        return PaymentAppMethod.otherUpi;
      default:
        return PaymentAppMethod.counter;
    }
  }
}

class CentralPaymentConfig {
  static const String shopName = 'Campus Xerox';
  static const String upiId = '';
  static const String provider = 'Generic UPI Payment';
}

enum PaymentStatusState {
  pending,
  initiated,
  submitted,
  paid,
  failed,
  cancelled,
  verificationPending,
}

class UpiPaymentResult {
  final PaymentStatusState status;
  final PaymentAppMethod method;
  final String transactionReference;
  final double amount;
  final DateTime paidAt;
  final bool isDemoConfirmation;
  final String? errorMessage;
  final String? screenshotUrl;

  const UpiPaymentResult({
    required this.status,
    required this.method,
    required this.transactionReference,
    required this.amount,
    required this.paidAt,
    this.isDemoConfirmation = false,
    this.errorMessage,
    this.screenshotUrl,
  });

  bool get isPaid => status == PaymentStatusState.paid;
  bool get isFailed => status == PaymentStatusState.failed;
  bool get isCancelled => status == PaymentStatusState.cancelled;
  bool get isVerificationPending =>
      status == PaymentStatusState.verificationPending ||
      status == PaymentStatusState.submitted;

  factory UpiPaymentResult.submitted({
    required PaymentAppMethod method,
    required double amount,
    required String orderCode,
    required String transactionReference,
    String? screenshotUrl,
  }) {
    return UpiPaymentResult(
      status: PaymentStatusState.submitted,
      method: method,
      transactionReference: transactionReference,
      amount: amount,
      paidAt: DateTime.now(),
      screenshotUrl: screenshotUrl,
    );
  }

  factory UpiPaymentResult.demoSuccess({
    required PaymentAppMethod method,
    required double amount,
    required String orderCode,
    String? transactionReference,
  }) {
    return UpiPaymentResult(
      status: PaymentStatusState.paid,
      method: method,
      transactionReference:
          transactionReference ??
          'TXN_${DateTime.now().millisecondsSinceEpoch}_$orderCode',
      amount: amount,
      paidAt: DateTime.now(),
      isDemoConfirmation: true,
    );
  }

  factory UpiPaymentResult.failed({
    required PaymentAppMethod method,
    required double amount,
    required String message,
  }) {
    return UpiPaymentResult(
      status: PaymentStatusState.failed,
      method: method,
      transactionReference: '',
      amount: amount,
      paidAt: DateTime.now(),
      errorMessage: message,
    );
  }

  factory UpiPaymentResult.cancelled({
    required PaymentAppMethod method,
    required double amount,
    String? message,
  }) {
    return UpiPaymentResult(
      status: PaymentStatusState.cancelled,
      method: method,
      transactionReference: '',
      amount: amount,
      paidAt: DateTime.now(),
      errorMessage: message ?? 'Payment cancelled by user.',
    );
  }

  factory UpiPaymentResult.verificationPending({
    required PaymentAppMethod method,
    required double amount,
    required String orderCode,
    String? transactionReference,
    String? message,
  }) {
    return UpiPaymentResult(
      status: PaymentStatusState.verificationPending,
      method: method,
      transactionReference:
          transactionReference ??
          'PENDING_${DateTime.now().millisecondsSinceEpoch}_$orderCode',
      amount: amount,
      paidAt: DateTime.now(),
      errorMessage: message ?? 'Payment verification is pending.',
    );
  }
}

class QrValidationResult {
  final bool isValid;
  final String merchantName;
  final String upiId;
  final double enforcedAmount;
  final String? errorMessage;

  const QrValidationResult({
    required this.isValid,
    this.merchantName = '',
    this.upiId = '',
    this.enforcedAmount = 0.0,
    this.errorMessage,
  });
}
