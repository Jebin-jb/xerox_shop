import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../widgets/glass.dart';
import '../../widgets/order_widgets.dart';
import 'order_receipt.dart';

class StudentOrders extends StatelessWidget {
  final DataService dataService;
  final String uid;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const StudentOrders({
    super.key,
    required this.dataService,
    required this.uid,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<PrintOrder>>(
      stream: dataService.studentOrders(uid),
      builder: (context, snap) {
        final orders = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'My Print Orders',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                    onPressed: onToggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign Out',
                    onPressed: onSignOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (orders.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Orders Yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your submitted print orders and receipts will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OrderCard(
                    order: o,
                    onDelete: () => _confirmDelete(context, o),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderReceipt(
                          orderId: o.id,
                          dataService: dataService,
                          onToggleTheme: onToggleTheme,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PrintOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Order #${o.code}?'),
        content: Text(
          'Are you sure you want to remove Order #${o.code} (${o.fileName}) from your orders list?\n\n'
          'Your payment and transaction history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dataService.softDeleteOrderForStudent(o.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${o.code} removed from your list.'),
            backgroundColor: Colors.blueGrey[800],
          ),
        );
      }
    }
  }
}
