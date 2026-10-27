import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/glass.dart';
import '../student/automatic_detection_screen.dart';
import 'shop_dashboard.dart';
import 'shop_orders.dart';
import 'price_management.dart';
import 'bank_payment_account_screen.dart';

class ShopkeeperShell extends StatefulWidget {
  final AuthService auth;
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final UserProfile? profile;

  const ShopkeeperShell({
    super.key,
    required this.auth,
    required this.dataService,
    required this.onToggleTheme,
    this.profile,
  });

  @override
  State<ShopkeeperShell> createState() => _ShopkeeperShellState();
}

class _ShopkeeperShellState extends State<ShopkeeperShell>
    with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dataService.refreshOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.dataService.refreshOrders();
    }
  }

  UserProfile get _adminProfile =>
      widget.profile ??
      const UserProfile(
        id: 'shopkeeper',
        name: 'Campus Xerox Shopkeeper',
        email: 'xeroxshop@college.ac.in',
        role: 'shopkeeper',
        studentId: '',
      );

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from Campus Xerox Shopkeeper?',
        ),
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
        onOpenPaymentAccount: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BankPaymentAccountScreen(
                dataService: widget.dataService,
                onToggleTheme: widget.onToggleTheme,
                onSignOut: _confirmSignOut,
              ),
            ),
          );
        },
      ),
      ShopOrders(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      AutomaticDetectionScreen(
        dataService: widget.dataService,
        profile: _adminProfile,
        onToggleTheme: widget.onToggleTheme,
        isShopkeeperMode: true,
      ),
      PriceManagement(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      BankPaymentAccountScreen(
        dataService: widget.dataService,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final activeIndex = (index >= 0 && index < pages.length)
                    ? index
                    : 0;
                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(width: 270, child: _rail()),
                      Expanded(child: pages[activeIndex]),
                    ],
                  );
                }
                return pages[activeIndex];
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomBar(theme),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _buildNavItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard_rounded,
                'Dashboard',
                theme,
              ),
              _buildNavItem(
                1,
                Icons.receipt_long_outlined,
                Icons.receipt_long_rounded,
                'Orders',
                theme,
              ),
              _buildNavItem(
                2,
                Icons.add_circle_outline_rounded,
                Icons.add_circle_rounded,
                'Create Print Order',
                theme,
              ),
              _buildNavItem(
                3,
                Icons.currency_rupee_rounded,
                Icons.currency_rupee_rounded,
                'Prices',
                theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int itemIndex,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
    ThemeData theme,
  ) {
    final isSelected = index == itemIndex;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = itemIndex),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 22,
                color: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
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
          _navItem(Icons.add_circle_rounded, 'Create Print Order', 2),
          const SizedBox(height: 6),
          _navItem(Icons.currency_rupee_rounded, 'Price Control', 3),
          const SizedBox(height: 6),
          _navItem(Icons.account_balance_rounded, 'Payment Account', 4),
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
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navItem(IconData icon, String label, int i) => ListTile(
    selected: index == i,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    selectedTileColor: Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.12),
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
