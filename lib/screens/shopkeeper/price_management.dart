import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class PriceManagement extends StatefulWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const PriceManagement({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  State<PriceManagement> createState() => _PriceManagementState();
}

class _PriceManagementState extends State<PriceManagement> {
  final bwSingle = TextEditingController();
  final bwDouble = TextEditingController();
  final colorSingle = TextEditingController();
  final colorDouble = TextEditingController();
  final photocopy = TextEditingController();
  final paper75Gsm = TextEditingController();
  final paper100Gsm = TextEditingController();
  final paperGlossy = TextEditingController();
  final spiralBinding = TextEditingController();
  final hardBinding = TextEditingController();
  final lamination = TextEditingController();

  bool _loaded = false;
  DateTime? _lastUpdated;
  bool _saving = false;

  @override
  void dispose() {
    bwSingle.dispose();
    bwDouble.dispose();
    colorSingle.dispose();
    colorDouble.dispose();
    photocopy.dispose();
    paper75Gsm.dispose();
    paper100Gsm.dispose();
    paperGlossy.dispose();
    spiralBinding.dispose();
    hardBinding.dispose();
    lamination.dispose();
    super.dispose();
  }

  void _populate(ShopPrice p) {
    if (_loaded) return;
    bwSingle.text = p.bwSingle.toStringAsFixed(2);
    bwDouble.text = p.bwDouble.toStringAsFixed(2);
    colorSingle.text = p.colorSingle.toStringAsFixed(2);
    colorDouble.text = p.colorDouble.toStringAsFixed(2);
    photocopy.text = p.photocopy.toStringAsFixed(2);
    paper75Gsm.text = p.paper75Gsm.toStringAsFixed(2);
    paper100Gsm.text = p.paper100Gsm.toStringAsFixed(2);
    paperGlossy.text = p.paperGlossy.toStringAsFixed(2);
    spiralBinding.text = p.spiralBinding.toStringAsFixed(2);
    hardBinding.text = p.hardBinding.toStringAsFixed(2);
    lamination.text = p.lamination.toStringAsFixed(2);
    _lastUpdated = p.updatedAt;
    _loaded = true;
  }

  void _applyPreset(String preset) {
    setState(() {
      if (preset == 'standard') {
        bwSingle.text = '1.0';
        bwDouble.text = '1.5';
        colorSingle.text = '5.0';
        colorDouble.text = '8.0';
        photocopy.text = '1.0';
        paper75Gsm.text = '0.0';
        paper100Gsm.text = '1.5';
        paperGlossy.text = '10.0';
        spiralBinding.text = '30.0';
        hardBinding.text = '150.0';
        lamination.text = '10.0';
      } else if (preset == 'discount') {
        bwSingle.text = '0.8';
        bwDouble.text = '1.2';
        colorSingle.text = '4.0';
        colorDouble.text = '6.5';
        photocopy.text = '0.8';
        paper75Gsm.text = '0.0';
        paper100Gsm.text = '1.0';
        paperGlossy.text = '8.0';
        spiralBinding.text = '25.0';
        hardBinding.text = '120.0';
        lamination.text = '8.0';
      } else if (preset == 'premium') {
        bwSingle.text = '1.5';
        bwDouble.text = '2.0';
        colorSingle.text = '7.0';
        colorDouble.text = '10.0';
        photocopy.text = '1.5';
        paper75Gsm.text = '0.0';
        paper100Gsm.text = '2.0';
        paperGlossy.text = '15.0';
        spiralBinding.text = '40.0';
        hardBinding.text = '180.0';
        lamination.text = '15.0';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset "$preset" applied. Click "Publish Live Prices" to save.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = ShopPrice(
        bwSingle: double.tryParse(bwSingle.text.trim()) ?? 1.0,
        bwDouble: double.tryParse(bwDouble.text.trim()) ?? 1.5,
        colorSingle: double.tryParse(colorSingle.text.trim()) ?? 5.0,
        colorDouble: double.tryParse(colorDouble.text.trim()) ?? 8.0,
        photocopy: double.tryParse(photocopy.text.trim()) ?? 1.0,
        paper75Gsm: double.tryParse(paper75Gsm.text.trim()) ?? 0.0,
        paper100Gsm: double.tryParse(paper100Gsm.text.trim()) ?? 1.5,
        paperGlossy: double.tryParse(paperGlossy.text.trim()) ?? 10.0,
        spiralBinding: double.tryParse(spiralBinding.text.trim()) ?? 30.0,
        hardBinding: double.tryParse(hardBinding.text.trim()) ?? 150.0,
        lamination: double.tryParse(lamination.text.trim()) ?? 10.0,
        updatedAt: DateTime.now(),
      );

      await widget.dataService.updatePrices(updated);
      _lastUpdated = updated.updatedAt;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Live shop prices updated & synchronized!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update prices: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<ShopPrice>(
      stream: widget.dataService.prices(),
      builder: (context, snap) {
        if (snap.hasData && !_loaded) {
          _populate(snap.data!);
        }

        final dateStr = _lastUpdated != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(_lastUpdated!)
            : 'Recently';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Live Price Control',
              subtitle: 'Manage paper types, printing & binding prices. Changes sync in real-time.',
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
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Presets Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Standard Rates'),
                    onPressed: () => _applyPreset('standard'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.local_offer_rounded, size: 16),
                    label: const Text('Exam Season Discount'),
                    onPressed: () => _applyPreset('discount'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.star_rounded, size: 16),
                    label: const Text('Premium Rates'),
                    onPressed: () => _applyPreset('premium'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Black & White Section
            _sectionCard(
              title: 'Black & White Printing',
              icon: Icons.filter_b_and_w_rounded,
              color: AppTheme.primary,
              children: [
                _priceField(bwSingle, 'B&W Single Sided', '/page'),
                _priceField(bwDouble, 'B&W Double Sided', '/page'),
                _priceField(photocopy, 'Photocopy / Xerox', '/page'),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Color Section
            _sectionCard(
              title: 'Color Printing',
              icon: Icons.palette_outlined,
              color: const Color(0xFF00A2FF),
              children: [
                _priceField(colorSingle, 'Color Single Sided', '/page'),
                _priceField(colorDouble, 'Color Double Sided', '/page'),
              ],
            ),

            const SizedBox(height: 16),

            // 3. Paper GSM & Material Section
            _sectionCard(
              title: 'Paper Quality & Types',
              icon: Icons.description_rounded,
              color: Colors.teal,
              children: [
                _priceField(paper75Gsm, '75 GSM Standard Paper', '/page extra'),
                _priceField(paper100Gsm, '100 GSM Executive Bond Paper', '/page extra'),
                _priceField(paperGlossy, 'Glossy Photo / Certificate Sheet', '/page extra'),
              ],
            ),

            const SizedBox(height: 16),

            // 4. Binding & Finishing Section
            _sectionCard(
              title: 'Binding & Finishing Services',
              icon: Icons.menu_book_rounded,
              color: Colors.amber[800] ?? Colors.amber,
              children: [
                _priceField(spiralBinding, 'Spiral / Soft Binding', '/book'),
                _priceField(hardBinding, 'Hard Cover / Thesis Binding', '/book'),
                _priceField(lamination, 'Document Lamination', '/sheet'),
              ],
            ),

            const SizedBox(height: 20),

            // Last updated timestamp & Save button
            Center(
              child: Text(
                'Last published: $dateStr',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _saving ? 'Publishing to Cloud…' : 'Publish Live Prices',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _priceField(TextEditingController controller, String label, String suffix) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            prefixText: '₹ ',
            suffixText: suffix,
            isDense: true,
          ),
        ),
      );
}
