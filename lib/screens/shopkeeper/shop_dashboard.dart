import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/order_widgets.dart';
import 'bank_payment_account_screen.dart';
import 'shop_settings_screen.dart';

class ShopDashboard extends StatelessWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;
  final VoidCallback? onOpenPaymentAccount;

  const ShopDashboard({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
    this.onOpenPaymentAccount,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PrintOrder>>(
    stream: dataService.allOrders(),
    initialData: dataService.allOrdersDirect,
    builder: (context, snap) {
      final allOrders = snap.data ?? dataService.allOrdersDirect;
      final activeOrders = allOrders
          .where((x) => !x.isDeletedFromQueue && !x.isPurged)
          .toList();
      final pendingOrders = allOrders
          .where(
            (x) =>
                !x.isDeletedFromQueue &&
                !x.isPurged &&
                x.status == OrderStatus.pending,
          )
          .toList();
      final today = DateTime.now();

      final todayOrders = allOrders
          .where(
            (x) =>
                x.createdAt.year == today.year &&
                x.createdAt.month == today.month &&
                x.createdAt.day == today.day,
          )
          .toList();

      final todayRevenue = todayOrders
          .where(
            (x) =>
                x.paymentStatus == PaymentStatus.paid &&
                x.status != OrderStatus.cancelled &&
                x.status != OrderStatus.rejected,
          )
          .fold(0.0, (sum, x) => sum + x.total);

      final pendingCount = activeOrders
          .where((x) => x.status == OrderStatus.pending)
          .length;
      final printingCount = activeOrders
          .where((x) => x.status == OrderStatus.printing)
          .length;

      final readyCount = activeOrders
          .where((x) => x.status == OrderStatus.ready)
          .length;
      final completedCount = activeOrders
          .where((x) => x.status == OrderStatus.completed)
          .length;
      final onlineCount = activeOrders
          .where((x) => x.paymentMode == PaymentMode.online)
          .length;
      final counterCount = activeOrders
          .where((x) => x.paymentMode == PaymentMode.counter)
          .length;

      final screenWidth = MediaQuery.sizeOf(context).width;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return RefreshIndicator(
        onRefresh: () => dataService.refreshOrders(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Shop Dashboard',
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
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopSettingsScreen(
                            dataService: dataService,
                            onToggleTheme: onToggleTheme,
                            onSignOut: onSignOut,
                          ),
                        ),
                      );
                    },
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
            const SizedBox(height: 20),

            // KPI Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: screenWidth > 800
                  ? 4
                  : (screenWidth > 500 ? 2 : 2),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: screenWidth > 600
                  ? 1.6
                  : (screenWidth < 360 ? 1.15 : 1.35),
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

            const SizedBox(height: 20),

            // Bank & Payment Account Direct Dashboard Card
            _buildPaymentAccountCard(context),

            const SizedBox(height: 24),
            const PageIntro(title: 'Live Queue Summary'),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _queuePill('Pending', '$pendingCount', Colors.orange),
                _queuePill(
                  'Printing',
                  '$printingCount',
                  const Color(0xFF00A2FF),
                ),
                _queuePill('Ready', '$readyCount', const Color(0xFF00C853)),
                _queuePill('Completed', '$completedCount', Colors.teal),
                _queuePill('Online', '$onlineCount', Colors.purple),
                _queuePill(
                  'Pay at Counter',
                  '$counterCount',
                  Colors.amber.shade800,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const PageIntro(title: 'Pending Orders'),
            const SizedBox(height: 12),

            if (pendingOrders.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No pending orders in the queue.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...pendingOrders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OrderCard(order: o),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildPaymentAccountCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.purple.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () {
          if (onOpenPaymentAccount != null) {
            onOpenPaymentAccount!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BankPaymentAccountScreen(
                  dataService: dataService,
                  onToggleTheme: onToggleTheme,
                  onSignOut: onSignOut,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.purple,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bank & Payment Account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Settings → Bank & Payment Settings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) => GlassPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 4),
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

  Widget _queuePill(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
