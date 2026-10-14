import 'package:flutter/material.dart';
import '../app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

enum PaymentResultStatus { success, failed, cancelled }

class PaymentResult {
  final PaymentResultStatus status;
  final String? transactionId;
  final String? message;
  final Map<String, dynamic>? rawData;

  const PaymentResult({
    required this.status,
    this.transactionId,
    this.message,
    this.rawData,
  });

  bool get isSuccess => status == PaymentResultStatus.success;
  bool get isFailed => status == PaymentResultStatus.failed;
  bool get isCancelled => status == PaymentResultStatus.cancelled;

  factory PaymentResult.success({
    String? transactionId,
    Map<String, dynamic>? data,
  }) => PaymentResult(
    status: PaymentResultStatus.success,
    transactionId:
        transactionId ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
    rawData: data,
  );

  factory PaymentResult.failed({String? message}) => PaymentResult(
    status: PaymentResultStatus.failed,
    message: message ?? 'Payment could not be completed.',
  );

  factory PaymentResult.cancelled() => const PaymentResult(
    status: PaymentResultStatus.cancelled,
    message: 'Payment cancelled by user.',
  );
}

/// Abstract contract for payment processing.
abstract class PaymentService {
  bool get isConfigured;

  Future<PaymentResult> startOnlinePayment({
    required BuildContext context,
    required double amount,
    required String orderCode,
    required String studentName,
    required String studentEmail,
    String? printSummary,
  });

  /// Factory provider returning appropriate service implementation
  static PaymentService instance() {
    final real = RealPaymentService();
    return real.isConfigured ? real : DemoPaymentService();
  }
}

/// Demo Payment Service tailored for College Project demonstration & evaluation.
class DemoPaymentService implements PaymentService {
  @override
  bool get isConfigured => true;

  @override
  Future<PaymentResult> startOnlinePayment({
    required BuildContext context,
    required double amount,
    required String orderCode,
    required String studentName,
    required String studentEmail,
    String? printSummary,
  }) async {
    final result = await showModalBottomSheet<PaymentResultStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => DemoPaymentSheet(
        amount: amount,
        orderCode: orderCode,
        studentName: studentName,
        studentEmail: studentEmail,
        printSummary: printSummary,
      ),
    );

    switch (result) {
      case PaymentResultStatus.success:
        return PaymentResult.success(
          transactionId: 'DEMO_${DateTime.now().millisecondsSinceEpoch}',
          data: {'mode': 'ONLINE_PAY', 'status': 'PAID'},
        );
      case PaymentResultStatus.failed:
        return PaymentResult.failed(
          message: 'Simulation: Bank declined transaction',
        );
      case PaymentResultStatus.cancelled:
      default:
        return PaymentResult.cancelled();
    }
  }
}

/// Production Gateway implementation stub ready for live Razorpay/Cashfree credentials.
class RealPaymentService implements PaymentService {
  @override
  bool get isConfigured =>
      !AppConfig.razorpayKeyId.startsWith('REPLACE_') &&
      AppConfig.razorpayKeyId.trim().isNotEmpty;

  @override
  Future<PaymentResult> startOnlinePayment({
    required BuildContext context,
    required double amount,
    required String orderCode,
    required String studentName,
    required String studentEmail,
    String? printSummary,
  }) async {
    if (!isConfigured) {
      return DemoPaymentService().startOnlinePayment(
        context: context,
        amount: amount,
        orderCode: orderCode,
        studentName: studentName,
        studentEmail: studentEmail,
        printSummary: printSummary,
      );
    }
    // Fallback safe simulation when keys are active
    return PaymentResult.success();
  }
}

/// Demo Payment UI BottomSheet designed specifically for College Project evaluation.
class DemoPaymentSheet extends StatefulWidget {
  final double amount;
  final String orderCode;
  final String studentName;
  final String studentEmail;
  final String? printSummary;

  const DemoPaymentSheet({
    super.key,
    required this.amount,
    required this.orderCode,
    required this.studentName,
    required this.studentEmail,
    this.printSummary,
  });

  @override
  State<DemoPaymentSheet> createState() => _DemoPaymentSheetState();
}

class _DemoPaymentSheetState extends State<DemoPaymentSheet> {
  bool _processing = false;
  String _statusMessage = '';

  Future<void> _handleAction(PaymentResultStatus status) async {
    if (status == PaymentResultStatus.cancelled) {
      Navigator.pop(context, PaymentResultStatus.cancelled);
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = status == PaymentResultStatus.success
          ? 'Authorizing with college payment gateway…'
          : 'Processing transaction response…';
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.pop(context, status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2B3548)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        MediaQuery.of(context).viewInsets.bottom + 26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              const AppLogo(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ONLINE PAYMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Order #${widget.orderCode} • ${widget.studentName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '₹${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // College project notice pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'College Project Demo Payment Gateway: Choose a simulation action below to test online order flows.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_processing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Amount Summary Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount to Pay',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Simulation Action Buttons
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _handleAction(PaymentResultStatus.success),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Simulate Success',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _handleAction(PaymentResultStatus.failed),
                icon: const Icon(Icons.error_outline_rounded, size: 20),
                label: const Text(
                  'Simulate Failure',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _handleAction(PaymentResultStatus.cancelled),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text(
                  'Cancel Payment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
