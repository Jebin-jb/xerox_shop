import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/order_widgets.dart';

class ShopDashboard extends StatelessWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const ShopDashboard({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PrintOrder>>(
        stream: dataService.allOrders(),
        builder: (context, snap) {
          final orders = snap.data ?? [];
          final today = DateTime.now();

          final todayOrders = orders.where((x) =>
              x.createdAt.year == today.year &&
              x.createdAt.month == today.month &&
              x.createdAt.day == today.day).toList();

          final todayRevenue = todayOrders
              .where((x) =>
                  x.paymentStatus == PaymentStatus.paid &&
                  x.status != OrderStatus.cancelled &&
                  x.status != OrderStatus.rejected)
              .fold(0.0, (sum, x) => sum + x.total);

          final pendingCount =
              orders.where((x) => x.status == OrderStatus.pending).length;
          final printingCount =
              orders.where((x) => x.status == OrderStatus.printing).length;

          final screenWidth = MediaQuery.sizeOf(context).width;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              PageIntro(
                title: 'Shop Dashboard',
                subtitle: 'Real-time Xerox campus queue & revenue metrics.',
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
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // KPI Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: screenWidth > 800 ? 4 : (screenWidth > 500 ? 2 : 2),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: screenWidth > 600 ? 1.6 : (screenWidth < 360 ? 1.15 : 1.35),
                children: [
                  _statCard(
                    title: 'Today Orders',
                    value: '${todayOrders.length}',
                    color: AppTheme.primary,
                    icon: Icons.receipt_long_rounded,
                  ),
                  _statCard(
                    title: 'Today Revenue',
                    value: '₹${todayRevenue.toStringAsFixed(0)}',
                    color: Colors.green,
                    icon: Icons.currency_rupee_rounded,
                  ),
                  _statCard(
                    title: 'Pending Queue',
                    value: '$pendingCount',
                    color: Colors.orange,
                    icon: Icons.hourglass_top_rounded,
                  ),
                  _statCard(
                    title: 'In Printing',
                    value: '$printingCount',
                    color: const Color(0xFF00A2FF),
                    icon: Icons.print_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 26),
              const PageIntro(
                title: 'Live Queue Summary',
                subtitle: 'Orders requiring immediate shopkeeper action.',
              ),
              const SizedBox(height: 14),

              if (orders.isEmpty)
                GlassPanel(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No orders in the system yet.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...orders.take(5).map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OrderCard(order: o),
                      ),
                    ),
            ],
          );
        },
      );

  Widget _statCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) =>
      GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
}
