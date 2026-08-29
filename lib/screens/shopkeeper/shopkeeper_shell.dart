import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/glass.dart';
import 'shop_dashboard.dart';
import 'shop_orders.dart';
import 'price_management.dart';
import 'shop_reports.dart';

class ShopkeeperShell extends StatefulWidget {
  final AuthService auth;
  final DataService dataService;
  final VoidCallback onToggleTheme;

  const ShopkeeperShell({
    super.key,
    required this.auth,
    required this.dataService,
    required this.onToggleTheme,
  });

  @override
  State<ShopkeeperShell> createState() => _ShopkeeperShellState();
}

class _ShopkeeperShellState extends State<ShopkeeperShell> {
  int index = 0;

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from Campus Xerox Admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ShopDashboard(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      ShopOrders(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      PriceManagement(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      ShopReports(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(width: 270, child: _rail()),
                      Expanded(child: pages[index]),
                    ],
                  );
                }
                return pages[index];
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.currency_rupee_rounded),
                  selectedIcon: Icon(Icons.currency_rupee_rounded),
                  label: 'Prices',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Reports',
                ),
              ],
            ),
    );
  }

  Widget _rail() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 10, 18),
        child: GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  AppLogo(size: 42),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Xerox',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          'Admin Console',
                          style: TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _navItem(Icons.dashboard_rounded, 'Dashboard', 0),
              const SizedBox(height: 6),
              _navItem(Icons.receipt_long_rounded, 'Orders Queue', 1),
              const SizedBox(height: 6),
              _navItem(Icons.currency_rupee_rounded, 'Price Control', 2),
              const SizedBox(height: 6),
              _navItem(Icons.bar_chart_rounded, 'Reports & Profit', 3),
              const Spacer(),
              IconButton(
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, int i) => ListTile(
        selected: index == i,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        leading: Icon(
          icon,
          color: index == i ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: index == i ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: () => setState(() => index = i),
      );
}
