import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class ShopReports extends StatefulWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const ShopReports({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  State<ShopReports> createState() => _ShopReportsState();
}

class _ShopReportsState extends State<ShopReports> {
  DateTimeRange range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  final categoryController = TextEditingController(text: 'Paper Bundle');
  final amountController = TextEditingController();
  final descController = TextEditingController();
  bool _addingExpense = false;

  @override
  void dispose() {
    categoryController.dispose();
    amountController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => range = picked);
    }
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount.')),
      );
      return;
    }

    setState(() => _addingExpense = true);
    try {
      final desc = descController.text.trim().isEmpty
          ? categoryController.text.trim()
          : descController.text.trim();

      await widget.dataService.addExpense(
        desc,
        amount,
        categoryController.text.trim(),
        DateTime.now(),
      );

      amountController.clear();
      descController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Expense logged successfully!'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingExpense = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        PageIntro(
          title: 'Financial Reports & Profit',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
        const SizedBox(height: 18),

        // Date Range Selector
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTED PERIOD',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(range.start)} — ${DateFormat('dd MMM yyyy').format(range.end)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Metrics streams
        StreamBuilder<List<PrintOrder>>(
          stream: widget.dataService.allOrders(),
          builder: (context, orderSnap) {
            return StreamBuilder<List<ExpenseEntry>>(
              stream: widget.dataService.expenses(),
              builder: (context, expSnap) {
                final orders = (orderSnap.data ?? [])
                    .where(
                      (o) =>
                          o.paymentStatus == PaymentStatus.paid &&
                          o.createdAt.isAfter(
                            range.start.subtract(const Duration(days: 1)),
                          ) &&
                          o.createdAt.isBefore(
                            range.end.add(const Duration(days: 1)),
                          ),
                    )
                    .toList();

                final expenses = (expSnap.data ?? [])
                    .where(
                      (e) =>
                          e.createdAt.isAfter(
                            range.start.subtract(const Duration(days: 1)),
                          ) &&
                          e.createdAt.isBefore(
                            range.end.add(const Duration(days: 1)),
                          ),
                    )
                    .toList();

                final totalRevenue = orders.fold(
                  0.0,
                  (sum, o) => sum + o.total,
                );
                final totalExpense = expenses.fold(
                  0.0,
                  (sum, e) => sum + e.amount,
                );
                final netProfit = totalRevenue - totalExpense;

                return Column(
                  children: [
                    // Financial summary cards
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            'Gross Revenue',
                            '₹${totalRevenue.toStringAsFixed(0)}',
                            Colors.green,
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            'Total Expenses',
                            '₹${totalExpense.toStringAsFixed(0)}',
                            Colors.red,
                            Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      'Net Estimated Profit',
                      '₹${netProfit.toStringAsFixed(0)}',
                      netProfit >= 0 ? AppTheme.primary : Colors.red,
                      Icons.account_balance_wallet_rounded,
                      isHero: true,
                    ),

                    const SizedBox(height: 28),

                    // Add Expense Box
                    const PageIntro(
                      title: 'Log Shop Expense',
                    ),
                    const SizedBox(height: 12),

                    GlassPanel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: descController,
                            decoration: const InputDecoration(
                              labelText: 'Expense Description',
                              hintText: 'e.g. Paper reams, toner refill',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: categoryController.text,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    prefixIcon: Icon(Icons.category_rounded),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Paper Bundle',
                                      child: Text('Paper'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Toner / Ink',
                                      child: Text('Toner/Ink'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Binding / Spiral',
                                      child: Text('Binding'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Maintenance',
                                      child: Text('Repair'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Electricity',
                                      child: Text('Bills'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Other',
                                      child: Text('Other'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(
                                        () => categoryController.text = v,
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    prefixText: '₹ ',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00A2FF),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: _addingExpense ? null : _addExpense,
                              icon: _addingExpense
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_circle_outline_rounded,
                                    ),
                              label: const Text(
                                'Add Expense',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Recent Expenses List
                    if (expenses.isNotEmpty) ...[
                      const PageIntro(
                        title: 'Recent Expenses',
                      ),
                      const SizedBox(height: 12),
                      ...expenses.reversed
                          .take(6)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_outlined,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            '${e.category} • ${DateFormat('dd MMM, hh:mm a').format(e.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '-₹${e.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _metricCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool isHero = false,
  }) => GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isHero ? 13 : 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Icon(icon, size: isHero ? 22 : 18, color: color),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isHero ? 28 : 22,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );
}
