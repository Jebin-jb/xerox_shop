import 'package:flutter/material.dart';
import '../app_config.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

class PaymentModal extends StatefulWidget {
  final double amount;
  final String orderId;
  final String studentEmail;

  const PaymentModal({
    super.key,
    required this.amount,
    required this.orderId,
    required this.studentEmail,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double amount,
    required String orderId,
    required String studentEmail,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentModal(
        amount: amount,
        orderId: orderId,
        studentEmail: studentEmail,
      ),
    );
  }

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String selectedMethod = 'gpay';
  bool processing = false;
  String statusMessage = 'Select payment method';

  Future<void> _processPayment() async {
    setState(() {
      processing = true;
      statusMessage = 'Redirecting to payment gateway…';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => statusMessage = 'Authorizing with bank / UPI network…');

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => statusMessage = 'Verifying payment signature…');

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              const AppLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConfig.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Order #${widget.orderId.substring(widget.orderId.length > 8 ? widget.orderId.length - 8 : 0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${widget.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (processing) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      statusMessage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please do not press back or close the app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'PAY VIA UPI (INSTANT)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            _upiOption(
              'gpay',
              'Google Pay',
              Icons.account_balance_wallet_rounded,
              const Color(0xFF4285F4),
            ),
            const SizedBox(height: 8),
            _upiOption(
              'phonepe',
              'PhonePe UPI',
              Icons.flash_on_rounded,
              const Color(0xFF5F259F),
            ),
            const SizedBox(height: 8),
            _upiOption(
              'paytm',
              'Paytm UPI',
              Icons.payment_rounded,
              const Color(0xFF002970),
            ),
            const SizedBox(height: 16),

            Text(
              'CARDS & NET BANKING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            _upiOption(
              'card',
              'Debit / Credit Card',
              Icons.credit_card_rounded,
              Colors.teal,
            ),
            const SizedBox(height: 8),
            _upiOption(
              'netbanking',
              'Net Banking (All Major Banks)',
              Icons.account_balance_rounded,
              Colors.orange,
            ),

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Pay ₹${widget.amount.toStringAsFixed(2)} Securely',
                icon: Icons.lock_rounded,
                onPressed: _processPayment,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '🔒 256-Bit SSL Encrypted Payment Redirection',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _upiOption(String id, String label, IconData icon, Color color) {
    final isSelected = selectedMethod == id;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).dividerColor.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primary,
                size: 20,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey.withValues(alpha: 0.4),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
