import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'automatic_detection_screen.dart';

class StudentHome extends StatefulWidget {
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
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  bool _isPicking = false;

  Future<void> _handleCreatePrintOrder() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final pickedResult = await AutomaticDetectionScreen.pickDocument(context);
      if (pickedResult != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AutomaticDetectionScreen(
              dataService: widget.dataService,
              profile: widget.profile,
              onToggleTheme: widget.onToggleTheme,
              initialFile: pickedResult.file,
              initialBytes: pickedResult.bytes,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      } else {
        _isPicking = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<LiveShopPricing>(
      stream: widget.dataService.livePricing(),
      initialData: widget.dataService.currentLivePricing,
      builder: (context, snap) {
        final pricing = snap.data ?? widget.dataService.currentLivePricing;
        final firstName = widget.profile.name.split(' ').first;

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
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign Out',
                    onPressed: widget.onSignOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Create Print Order Action
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.description_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'New Print Job',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Select documents, configure print settings, and pay',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isPicking ? null : _handleCreatePrintOrder,
                      icon: _isPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        _isPicking
                            ? 'Opening Document Picker…'
                            : 'Create Print Order',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            const PageIntro(title: 'Live Shop Rates'),
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
