import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/order_widgets.dart';

class OrderReceipt extends StatelessWidget {
  final String orderId;
  final DataService dataService;
  final bool isNew;
  final VoidCallback? onToggleTheme;

  const OrderReceipt({
    super.key,
    required this.orderId,
    required this.dataService,
    this.isNew = false,
    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<PrintOrder?>(
    stream: dataService.order(orderId),
    builder: (context, snap) {
      final o = snap.data;
      if (o == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isNew ? 'Order Confirmation' : 'Order Receipt',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (onToggleTheme != null)
              IconButton(
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                onPressed: onToggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            const AmbientBackground(),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                children: [
                  PageIntro(
                    title: isNew ? 'Order Submitted 🎉' : 'Order Details',
                    subtitle:
                        'Show the collection code when you pick up your prints.',
                  ),
                  const SizedBox(height: 16),

                  GlassPanel(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppLogo(size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Student: ${o.studentName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: orderStatusLabel(o.status).toUpperCase(),
                              color: statusColor(o.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Pickup Code Display
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'COLLECTION CODE',
                                  style: TextStyle(
                                    letterSpacing: 1.5,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.code,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        _detailRow('Pages', '${o.pages} pages'),
                        _detailRow(
                          'Copies',
                          '${o.copies} ${o.copies == 1 ? "copy" : "copies"}',
                        ),
                        _detailRow(
                          'Color Mode',
                          o.color ? 'Color' : 'Black & White',
                        ),
                        _detailRow(
                          'Sides',
                          o.doubleSided ? 'Double-Sided' : 'Single-Sided',
                        ),
                        _detailRow(
                          'Paper Type',
                          o.paperTypeName.isNotEmpty
                              ? o.paperTypeName
                              : o.paperType.name,
                        ),
                        if (o.gsmName.isNotEmpty)
                          _detailRow('Paper GSM', o.gsmName),
                        _detailRow(
                          'Binding & Finishing',
                          o.bindingName.isNotEmpty
                              ? o.bindingName
                              : o.bindingType.name,
                        ),
                        _detailRow('Lamination', o.lamination ? 'Yes' : 'No'),
                        if (o.specialInstructions.trim().isNotEmpty)
                          _detailRow(
                            'Special Instructions',
                            o.specialInstructions.trim(),
                          ),
                        _detailRow(
                          'Payment Mode',
                          o.paymentMode == PaymentMode.online
                              ? 'Online (UPI / Card)'
                              : 'Pay at Counter',
                        ),
                        _detailRow(
                          'Payment Status',
                          o.paymentMode == PaymentMode.counter
                              ? (o.paymentStatus == PaymentStatus.paid
                                    ? 'PAID AT COUNTER'
                                    : 'PAY AT COUNTER (UNPAID)')
                              : o.paymentStatus.name.toUpperCase(),
                          highlight: o.paymentStatus == PaymentStatus.paid,
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        _detailRow(
                          'Total Amount',
                          '₹${o.total.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),

                  if (o.status == OrderStatus.cancelled ||
                      o.status == OrderStatus.rejected) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cancel_outlined,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Order ${orderStatusLabel(o.status)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          if (o.cancellationBy != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Cancelled by: ${o.cancellationBy == "SHOPKEEPER" ? "Xerox Shop" : "Student"}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (o.cancellationReason != null &&
                              o.cancellationReason!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${o.cancellationReason}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (o.refundStatus != null &&
                              o.refundStatus!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Refund Status: ${o.refundStatus == "REFUND_INITIATED" ? "Refund Initiated" : o.refundStatus}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (o.studentCanCancel) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Order?'),
                              content: Text(
                                o.paymentMode == PaymentMode.online &&
                                        o.paymentStatus == PaymentStatus.paid
                                    ? 'Are you sure you want to cancel this online paid order? A refund will be initiated to your original payment method.'
                                    : 'Are you sure you want to cancel this print order? The uploaded document will be purged from the server.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Keep Order'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Cancel Order'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await StorageService().deleteFile(o.fileUrl);

                            final isOnlinePaid =
                                o.paymentMode == PaymentMode.online &&
                                o.paymentStatus == PaymentStatus.paid;

                            await dataService.updateOrder(o.id, {
                              'status': 'cancelled',
                              'isPurged': true,
                              'cancellationBy': 'STUDENT',
                              'cancellationReason': 'Cancelled by student',
                              'refundStatus': isOnlinePaid
                                  ? 'REFUND_INITIATED'
                                  : 'NONE',
                              if (isOnlinePaid)
                                'paymentStatus': 'refundPending',
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isOnlinePaid
                                        ? 'Order cancelled. Refund initiated.'
                                        : 'Order cancelled & file deleted.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel Order'),
                      ),
                    ),
                  ] else if (o.status == OrderStatus.accepted ||
                      o.status == OrderStatus.printing ||
                      o.status == OrderStatus.ready) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_clock_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cancellation unavailable.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'This order has already been accepted by the Xerox shop.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _detailRow(
    String label,
    String value, {
    bool highlight = false,
    bool isTotal = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            fontSize: isTotal ? 16 : 13.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal || highlight
                ? FontWeight.w900
                : FontWeight.w700,
            fontSize: isTotal ? 18 : 13.5,
            color: isTotal
                ? AppTheme.primary
                : highlight
                ? Colors.green
                : null,
          ),
        ),
      ],
    ),
  );
}
