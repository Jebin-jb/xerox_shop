import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'create_order.dart';

class StudentHome extends StatelessWidget {
  final AuthService auth;
  final DataService dataService;
  final UserProfile profile;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const StudentHome({
    super.key,
    required this.auth,
    required this.dataService,
    required this.profile,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<ShopPrice>(
      stream: dataService.prices(),
      builder: (context, snap) {
        final p = snap.data;
        final firstName = profile.name.split(' ').first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Hello, $firstName 👋',
              subtitle: 'Submit your print jobs online before you walk to the shop.',
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

            // Hero Action Banner
            GlassPanel(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6750F4), Color(0xFF00A2FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6750F4).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '⚡ FAST TRACK PRINTING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Skip the Xerox queue.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Upload document • choose paper & binding • calculate price • pickup directly!',
                      style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: p == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateOrder(
                                    dataService: dataService,
                                    profile: profile,
                                    prices: p,
                                    onToggleTheme: onToggleTheme,
                                  ),
                                ),
                              ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Print Order'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        elevation: 3,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 26),
            const PageIntro(
              title: 'Live Shop Rates',
              subtitle: 'Current price list maintained directly by the campus Xerox shop.',
            ),
            const SizedBox(height: 14),

            if (p == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    _priceRow('B&W • Single Sided', p.bwSingle, '/page', Icons.filter_b_and_w_rounded),
                    const Divider(height: 1),
                    _priceRow('B&W • Double Sided', p.bwDouble, '/page', Icons.auto_stories_rounded),
                    const Divider(height: 1),
                    _priceRow('Color • Single Sided', p.colorSingle, '/page', Icons.palette_outlined),
                    const Divider(height: 1),
                    _priceRow('Color • Double Sided', p.colorDouble, '/page', Icons.color_lens_rounded),
                    const Divider(height: 1),
                    _priceRow('Photocopy / Duplicate', p.photocopy, '/page', Icons.content_copy_rounded),
                    const Divider(height: 1),
                    _priceRow('100 GSM Executive Paper', p.paper100Gsm, '/page extra', Icons.description_rounded),
                    const Divider(height: 1),
                    _priceRow('Glossy Photo / Certificate Sheet', p.paperGlossy, '/page extra', Icons.image_rounded),
                    const Divider(height: 1),
                    _priceRow('Spiral / Soft Binding', p.spiralBinding, '/book', Icons.menu_book_rounded),
                    const Divider(height: 1),
                    _priceRow('Hard Cover / Thesis Binding', p.hardBinding, '/book', Icons.auto_stories_rounded),
                    const Divider(height: 1),
                    _priceRow('Document Lamination', p.lamination, '/sheet', Icons.layers_outlined),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _priceRow(String label, double price, String suffix, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
            Text(
              '₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
            ),
          ],
        ),
      );
}
