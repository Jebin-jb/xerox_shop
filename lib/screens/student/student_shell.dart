import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/glass.dart';
import 'student_home.dart';
import 'student_orders.dart';

class StudentShell extends StatefulWidget {
  final AuthService auth;
  final DataService dataService;
  final UserProfile profile;
  final VoidCallback onToggleTheme;

  const StudentShell({
    super.key,
    required this.auth,
    required this.dataService,
    required this.profile,
    required this.onToggleTheme,
  });

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell>
    with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from Campus Xerox?',
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
      StudentHome(
        auth: widget.auth,
        dataService: widget.dataService,
        profile: widget.profile,
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _confirmSignOut,
      ),
      StudentOrders(
        dataService: widget.dataService,
        uid: widget.profile.id,
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
                final activeIndex = (index >= 0 && index < pages.length)
                    ? index
                    : 0;
                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(width: 260, child: _rail()),
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
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: (index >= 0 && index < pages.length) ? index : 0,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'My Orders',
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
                child: Text(
                  'Campus Xerox',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _navItem(Icons.home_rounded, 'Home', 0),
          const SizedBox(height: 6),
          _navItem(Icons.receipt_long_rounded, 'My Orders', 1),
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
