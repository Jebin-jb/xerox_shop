import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/supabase_service.dart';

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

class _PriceManagementState extends State<PriceManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LiveShopPricing _pricing;
  bool _initialized = false;
  bool _saving = false;

  // Printing price controllers & focus nodes
  final bwSingleController = TextEditingController();
  final bwDoubleController = TextEditingController();
  final colorSingleController = TextEditingController();
  final colorDoubleController = TextEditingController();

  final bwSingleFocus = FocusNode();
  final bwDoubleFocus = FocusNode();
  final colorSingleFocus = FocusNode();
  final colorDoubleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pricing = widget.dataService.currentLivePricing;
    _syncPrintingControllers();
    _initialized = true;
    _loadLatestFromFirestore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    bwSingleController.dispose();
    bwDoubleController.dispose();
    colorSingleController.dispose();
    colorDoubleController.dispose();
    bwSingleFocus.dispose();
    bwDoubleFocus.dispose();
    colorSingleFocus.dispose();
    colorDoubleFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLatestFromFirestore() async {
    try {
      if (widget.dataService is SupabaseService) {
        final latest = await (widget.dataService as SupabaseService).getFreshPrices();
        if (mounted) {
          setState(() {
            _pricing = latest;
            _syncPrintingControllers();
          });
          return;
        }
      }
      final latest = await widget.dataService.refreshPricingFromFirestore();
      if (mounted) {
        setState(() {
          _pricing = latest;
          _syncPrintingControllers();
        });
      }
    } catch (_) {}
  }

  void _syncPrintingControllers() {
    bwSingleController.text =
        _pricing.printingPrices.bwSinglePerSheet.toStringAsFixed(2);
    bwDoubleController.text =
        _pricing.printingPrices.bwDoublePerSheet.toStringAsFixed(2);
    colorSingleController.text =
        _pricing.printingPrices.colorSinglePerSheet.toStringAsFixed(2);
    colorDoubleController.text =
        _pricing.printingPrices.colorDoublePerSheet.toStringAsFixed(2);
  }

  Future<void> _persistChanges({String? message}) async {
    setState(() => _saving = true);
    try {
      final updated = _pricing.copyWith(
        printingPrices: _pricing.printingPrices.copyWith(
          bwSinglePerSheet:
              double.tryParse(bwSingleController.text.trim()) ??
              _pricing.printingPrices.bwSinglePerSheet,
          bwDoublePerSheet:
              double.tryParse(bwDoubleController.text.trim()) ??
              _pricing.printingPrices.bwDoublePerSheet,
          colorSinglePerSheet:
              double.tryParse(colorSingleController.text.trim()) ??
              _pricing.printingPrices.colorSinglePerSheet,
          colorDoublePerSheet:
              double.tryParse(colorDoubleController.text.trim()) ??
              _pricing.printingPrices.colorDoublePerSheet,
        ),
        updatedAt: DateTime.now(),
      );
      _pricing = updated;
      await widget.dataService.updateLivePricing(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Price updated successfully',
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update price: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleDeleteOrDisableItem(PrintConfigItem item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Manage "${item.name}"',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Prefer disabling an option instead of deleting it if it has already been used in past orders.\n\n'
          '• Disabling hides this option from new student orders while safely preserving historical order records.\n'
          '• Deleting will remove it completely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, 'disable'),
            child: const Text('Disable Instead (Recommended)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (action == 'disable') {
      final updatedList = List<PrintConfigItem>.from(_pricing.configItems);
      final idx = updatedList.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        updatedList[idx] = item.copyWith(
          enabled: false,
          updatedAt: DateTime.now(),
        );
        setState(() {
          _pricing = _pricing.copyWith(
            configItems: updatedList,
            updatedAt: DateTime.now(),
          );
        });
        await _persistChanges(message: '"${item.name}" disabled.');
      }
    } else if (action == 'delete') {
      final updatedList = List<PrintConfigItem>.from(_pricing.configItems)
        ..removeWhere((i) => i.id == item.id);
      setState(() {
        _pricing = _pricing.copyWith(
          configItems: updatedList,
          updatedAt: DateTime.now(),
        );
      });
      await _persistChanges(message: '"${item.name}" removed.');
    }
  }

  void _openConfigItemDialog({
    PrintConfigItem? existing,
    required String defaultCategory,
    required String categoryTitle,
    bool allowCategorySelection = false,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '0.00',
    );
    String selectedCategory = existing?.category ?? defaultCategory;
    bool isEnabled = existing?.enabled ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            existing == null ? 'Add $categoryTitle' : 'Edit $categoryTitle',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: '$categoryTitle Name',
                    hintText: 'e.g. A3, Glossy, Hard Binding',
                  ),
                ),
                const SizedBox(height: 12),
                if (allowCategorySelection) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(
                        value: 'binding',
                        child: Text('Binding Service'),
                      ),
                      DropdownMenuItem(
                        value: 'finishing',
                        child: Text('Finishing Service'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price / Extra Charge (₹)',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enabled for Students',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  value: isEnabled,
                  onChanged: (v) => setDlgState(() => isEnabled = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final now = DateTime.now();
                final id =
                    existing?.id ??
                    '${selectedCategory}_${now.millisecondsSinceEpoch}';

                final item = PrintConfigItem(
                  id: id,
                  name: name,
                  category: selectedCategory,
                  price: price,
                  enabled: isEnabled,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );

                final updatedList = List<PrintConfigItem>.from(
                  _pricing.configItems,
                );
                if (existing != null) {
                  final idx = updatedList.indexWhere((x) => x.id == existing.id);
                  if (idx != -1) {
                    updatedList[idx] = item;
                  } else {
                    updatedList.add(item);
                  }
                } else {
                  updatedList.add(item);
                }

                setState(() {
                  _pricing = _pricing.copyWith(
                    configItems: updatedList,
                    updatedAt: now,
                  );
                });
                Navigator.pop(ctx);
                _persistChanges(message: '$name updated.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<LiveShopPricing>(
      stream: widget.dataService.livePricing(),
      initialData: _pricing,
      builder: (context, snapshot) {
        if (snapshot.hasData && !_saving && _initialized) {
          _pricing = snapshot.data!;
          if (!bwSingleFocus.hasFocus &&
              !bwDoubleFocus.hasFocus &&
              !colorSingleFocus.hasFocus &&
              !colorDoubleFocus.hasFocus) {
            _syncPrintingControllers();
          }
        }

        return Scaffold(
          body: Column(
            children: [
              _buildHeader(theme, isDark),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.description_outlined),
                    text: 'Paper Types',
                  ),
                  Tab(icon: Icon(Icons.print_outlined), text: 'Printing'),
                  Tab(
                    icon: Icon(Icons.book_outlined),
                    text: 'Finishing & Binding',
                  ),
                  Tab(
                    icon: Icon(Icons.add_box_outlined),
                    text: 'Additional Services',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConfigCategoryTab(
                      theme: theme,
                      category: 'paperType',
                      categoryTitle: 'Paper Type',
                      items: _pricing.paperTypeOptions,
                      icon: Icons.description_outlined,
                      fabTag: 'add_paper_fab',
                    ),
                    _buildPrintingTab(theme),
                    _buildConfigCategoryTab(
                      theme: theme,
                      category: 'binding',
                      categoryTitle: 'Service',
                      items: _pricing.bindingAndFinishingOptions,
                      icon: Icons.book_outlined,
                      fabTag: 'add_binding_finishing_fab',
                      allowCategorySelection: true,
                    ),
                    _buildConfigCategoryTab(
                      theme: theme,
                      category: 'additionalService',
                      categoryTitle: 'Additional Service',
                      items: _pricing.additionalServiceOptions,
                      icon: Icons.miscellaneous_services_rounded,
                      fabTag: 'add_additional_fab',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Live Price Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 12,
                            color: Colors.teal,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'LIVE SYNC',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _loadLatestFromFirestore,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh prices',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 20,
                    ),
                    tooltip: 'Toggle Theme',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: widget.onSignOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    tooltip: 'Sign Out',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Last updated: ${DateFormat('dd/MM/yyyy hh:mm a').format(_pricing.updatedAt)}',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // PRINTING TAB (Price Per Sheet)
  Widget _buildPrintingTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Black & White Printing Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.monochrome_photos_rounded,
                        color: Colors.black87,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Black & White Printing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 280;
                      if (isNarrow) {
                        return Column(
                          children: [
                            TextField(
                              controller: bwSingleController,
                              focusNode: bwSingleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Single Side',
                                hintText: '1.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: bwDoubleController,
                              focusNode: bwDoubleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Double Side',
                                hintText: '1.50',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bwSingleController,
                              focusNode: bwSingleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Single Side',
                                hintText: '1.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: bwDoubleController,
                              focusNode: bwDoubleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Double Side',
                                hintText: '1.50',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Color Printing Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.color_lens_rounded, color: Colors.deepPurple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Color Printing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 280;
                      if (isNarrow) {
                        return Column(
                          children: [
                            TextField(
                              controller: colorSingleController,
                              focusNode: colorSingleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Single Side',
                                hintText: '5.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: colorDoubleController,
                              focusNode: colorDoubleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Double Side',
                                hintText: '8.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: colorSingleController,
                              focusNode: colorSingleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Single Side',
                                hintText: '5.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: colorDoubleController,
                              focusNode: colorDoubleFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Double Side',
                                hintText: '8.00',
                                prefixText: '₹ ',
                                suffixText: '/ sheet',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _saving
                  ? null
                  : () => _persistChanges(
                        message: 'Printing prices saved.',
                      ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _saving ? 'Saving…' : 'Save Printing Prices',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dynamic Category Tab Builder (Paper Types, Finishing & Binding, Additional Services)
  Widget _buildConfigCategoryTab({
    required ThemeData theme,
    required String category,
    required String categoryTitle,
    required List<PrintConfigItem> items,
    required IconData icon,
    required String fabTag,
    bool allowCategorySelection = false,
  }) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: fabTag,
        onPressed: () => _openConfigItemDialog(
          defaultCategory: category,
          categoryTitle: categoryTitle,
          allowCategorySelection: allowCategorySelection,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add $categoryTitle'),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 44,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No $categoryTitle options configured yet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _openConfigItemDialog(
                        defaultCategory: category,
                        categoryTitle: categoryTitle,
                        allowCategorySelection: allowCategorySelection,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add First $categoryTitle'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 110),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: item.enabled
                          ? theme.colorScheme.outline.withValues(alpha: 0.25)
                          : theme.disabledColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: item.enabled
                              ? theme.colorScheme.primary.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.15),
                          child: Icon(
                            icon,
                            color: item.enabled
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: item.enabled
                                          ? null
                                          : theme.colorScheme.onSurfaceVariant,
                                      decoration: item.enabled
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  if (!item.enabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DISABLED',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  if (allowCategorySelection)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.price == 0.0
                                    ? 'Base / Included (+₹0.00)'
                                    : '+₹${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: item.enabled
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 0.78,
                              child: Switch(
                                value: item.enabled,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  final updatedList =
                                      List<PrintConfigItem>.from(
                                        _pricing.configItems,
                                      );
                                  final idx = updatedList.indexWhere(
                                    (x) => x.id == item.id,
                                  );
                                  if (idx != -1) {
                                    updatedList[idx] = item.copyWith(
                                      enabled: val,
                                      updatedAt: DateTime.now(),
                                    );
                                    setState(() {
                                      _pricing = _pricing.copyWith(
                                        configItems: updatedList,
                                        updatedAt: DateTime.now(),
                                      );
                                    });
                                    _persistChanges(
                                      message:
                                          '${item.name} is now ${val ? "enabled" : "disabled"}.',
                                    );
                                  }
                                },
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Actions',
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _openConfigItemDialog(
                                    existing: item,
                                    defaultCategory: category,
                                    categoryTitle: categoryTitle,
                                    allowCategorySelection:
                                        allowCategorySelection,
                                  );
                                } else if (val == 'delete') {
                                  _handleDeleteOrDisableItem(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit Price & Name'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete / Disable',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
