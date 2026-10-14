import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'automatic_detection_screen.dart';
import 'create_order.dart';

class StudentHome extends StatelessWidget {
  final AuthService auth;
  final DataService dataService;
  final UserProfile profile;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;
  final VoidCallback? onNavigateToAutoDetect;

  const StudentHome({
    super.key,
    required this.auth,
    required this.dataService,
    required this.profile,
    required this.onToggleTheme,
    required this.onSignOut,
    this.onNavigateToAutoDetect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<LiveShopPricing>(
      stream: dataService.livePricing(),
      initialData: dataService.currentLivePricing,
      builder: (context, snap) {
        final pricing = snap.data ?? dataService.currentLivePricing;
        final p = pricing.toShopPrice();
        final firstName = profile.name.split(' ').first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Hello, $firstName 👋',
              subtitle:
                  'Submit your print jobs online before you walk to the shop.',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
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
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              onNavigateToAutoDetect ??
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AutomaticDetectionScreen(
                                    dataService: dataService,
                                    profile: profile,
                                    onToggleTheme: onToggleTheme,
                                  ),
                                ),
                              ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Auto Detect',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white70,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Auto Detection Feature Card
            GlassPanel(
              padding: const EdgeInsets.all(16),
              onTap:
                  onNavigateToAutoDetect ??
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AutomaticDetectionScreen(
                        dataService: dataService,
                        profile: profile,
                        onToggleTheme: onToggleTheme,
                      ),
                    ),
                  ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6750F4), Color(0xFF00A2FF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Auto Detect',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Detect pages, color distribution & optimize print cost.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),

            const SizedBox(height: 26),
            const PageIntro(
              title: 'Live Shop Rates',
              subtitle:
                  'Current price list maintained directly by the campus Xerox shop (view only).',
            ),
            const SizedBox(height: 14),

            // 1. PRINTING (PER SHEET)
            _buildCategorySection(
              title: 'PRINTING (PRICE PER SHEET)',
              icon: Icons.print_rounded,
              items: [
                _RateItem(
                  name: 'B&W Single Side',
                  price: pricing.printingPrices.bwSinglePerSheet,
                  unit: '/ sheet',
                ),
                _RateItem(
                  name: 'B&W Double Side',
                  price: pricing.printingPrices.bwDoublePerSheet,
                  unit: '/ sheet',
                ),
                _RateItem(
                  name: 'Color Single Side',
                  price: pricing.printingPrices.colorSinglePerSheet,
                  unit: '/ sheet',
                ),
                _RateItem(
                  name: 'Color Double Side',
                  price: pricing.printingPrices.colorDoublePerSheet,
                  unit: '/ sheet',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. PAPER TYPES
            _buildCategorySection(
              title: 'PAPER TYPES',
              icon: Icons.description_rounded,
              items: pricing.paperTypes
                  .where((p) => p.isEnabled)
                  .map(
                    (p) => _RateItem(
                      name: '${p.name} (${p.size}, ${p.gsm})',
                      price: p.basePrice,
                      unit: p.basePrice == 0 ? 'Standard' : '/ sheet extra',
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // 3. BINDING
            _buildCategorySection(
              title: 'BINDING OPTIONS',
              icon: Icons.book_rounded,
              items: pricing.bindingTypes
                  .where((b) => b.isEnabled && b.price > 0)
                  .map(
                    (b) =>
                        _RateItem(name: b.name, price: b.price, unit: '/ book'),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // 4. LAMINATION
            _buildCategorySection(
              title: 'LAMINATION',
              icon: Icons.layers_rounded,
              items: pricing.laminationTypes
                  .where((l) => l.isEnabled)
                  .map(
                    (l) => _RateItem(
                      name: l.name,
                      price: l.price,
                      unit: '/ sheet',
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // 5. ADDITIONAL SERVICES
            if (pricing.additionalServices.any((s) => s.isEnabled)) ...[
              _buildCategorySection(
                title: 'ADDITIONAL SERVICES',
                icon: Icons.miscellaneous_services_rounded,
                items: pricing.additionalServices
                    .where((s) => s.isEnabled)
                    .map(
                      (s) => _RateItem(
                        name: s.name,
                        price: s.price,
                        unit: ' (${s.pricingUnit.label})',
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required List<_RateItem> items,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items[i].name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    items[i].price == 0 && items[i].unit == 'Standard'
                        ? 'Base Price'
                        : '₹${items[i].price.toStringAsFixed(items[i].price == items[i].price.roundToDouble() ? 0 : 2)} ${items[i].unit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateItem {
  final String name;
  final double price;
  final String unit;
  const _RateItem({
    required this.name,
    required this.price,
    required this.unit,
  });
}
