import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'glass.dart';

String orderStatusLabel(OrderStatus s) => switch (s) {
  OrderStatus.pending => 'Pending',
  OrderStatus.accepted => 'Accepted',
  OrderStatus.printing => 'Printing',
  OrderStatus.ready => 'Ready to Pick',
  OrderStatus.completed => 'Completed',
  OrderStatus.cancelled => 'Cancelled',
  OrderStatus.rejected => 'Rejected',
};

String paymentLabel(PaymentMode p) =>
    p == PaymentMode.online ? 'Online Payment' : 'Pay at Counter';

Color statusColor(OrderStatus s) => switch (s) {
  OrderStatus.pending => const Color(0xFFE67E22),
  OrderStatus.accepted => const Color(0xFF3F51B5),
  OrderStatus.printing => const Color(0xFF0091EA),
  OrderStatus.ready => const Color(0xFF00C853),
  OrderStatus.completed => const Color(0xFF00897B),
  OrderStatus.cancelled => const Color(0xFFE53935),
  OrderStatus.rejected => const Color(0xFFD32F2F),
};

class OrderCard extends StatelessWidget {
  final PrintOrder order;
  final bool shopkeeper;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.shopkeeper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => FadeSlide(
    child: GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shopkeeper
                          ? '${order.studentName} • ${order.studentId}'
                          : 'Code: #${order.code}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: orderStatusLabel(order.status).toUpperCase(),
                color: statusColor(order.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  '₹${order.total.toStringAsFixed(0)}',
                  Icons.payments_outlined,
                ),
              ),
              Expanded(
                child: _Meta(
                  '${order.pages}p × ${order.copies}',
                  Icons.copy_all_rounded,
                ),
              ),
              Expanded(
                child: _Meta(
                  order.color ? 'Color' : 'B&W',
                  Icons.palette_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                order.paymentMode == PaymentMode.online
                    ? Icons.account_balance_wallet_outlined
                    : Icons.storefront_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                paymentLabel(order.paymentMode),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              StatusChip(
                label: switch (order.paymentStatus) {
                  PaymentStatus.paid => 'PAID',
                  PaymentStatus.payment_submitted ||
                  PaymentStatus.verification_pending => 'VERIFYING',
                  PaymentStatus.payment_initiated => 'INITIATED',
                  PaymentStatus.failed || PaymentStatus.payment_failed => 'FAILED',
                  PaymentStatus.cancelled => 'CANCELLED',
                  PaymentStatus.unpaid => 'UNPAID',
                  PaymentStatus.refund_initiated => 'REFUND INIT',
                  PaymentStatus.refunded => 'REFUNDED',
                },
                color: switch (order.paymentStatus) {
                  PaymentStatus.paid => Colors.green,
                  PaymentStatus.payment_submitted ||
                  PaymentStatus.verification_pending => Colors.orange,
                  PaymentStatus.payment_initiated => Colors.amber,
                  PaymentStatus.failed || PaymentStatus.payment_failed => Colors.red,
                  PaymentStatus.cancelled => Colors.redAccent,
                  PaymentStatus.unpaid => Colors.orange,
                  PaymentStatus.refund_initiated => Colors.blueGrey,
                  PaymentStatus.refunded => Colors.teal,
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Meta(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    ],
  );
}

class StatusTimeline extends StatelessWidget {
  final OrderStatus status;
  const StatusTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: statusColor(status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: statusColor(status)),
            const SizedBox(width: 8),
            Text(
              'Order ${orderStatusLabel(status)}',
              style: TextStyle(
                color: statusColor(status),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    const steps = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.printing,
      OrderStatus.ready,
      OrderStatus.completed,
    ];
    final current = steps.indexOf(status);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(steps.length, (i) {
            final isReached = i <= current;
            final isCurrent = i == current;
            final color = isReached
                ? statusColor(steps[i])
                : Theme.of(context).dividerColor.withValues(alpha: 0.3);

            return Expanded(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isReached ? Icons.check_rounded : Icons.circle,
                          color: Colors.white,
                          size: isReached ? 16 : 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        orderStatusLabel(steps[i]),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: isCurrent
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: isReached
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i < current
                              ? statusColor(steps[i])
                              : Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
