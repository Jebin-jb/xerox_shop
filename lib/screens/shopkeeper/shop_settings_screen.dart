import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'bank_payment_account_screen.dart';
import 'price_management.dart';

class ShopSettingsScreen extends StatelessWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const ShopSettingsScreen({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                const PageIntro(
                  title: 'Shop Settings',
                  subtitle:
                      'Manage receiving payment accounts, pricing, and shop configuration.',
                ),
                const SizedBox(height: 16),

                // 1. Bank & Payment Settings Section
                _sectionHeader('PAYMENTS & BANK ACCOUNTS', theme),
                const SizedBox(height: 8),
                StreamBuilder<ShopPaymentAccount>(
                  stream: dataService.paymentAccount(),
                  initialData: dataService.currentPaymentAccount,
                  builder: (context, snapshot) {
                    final acc =
                        snapshot.data ?? dataService.currentPaymentAccount;
                    final isConfigured = acc.isConfigured;

                    return GlassPanel(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            title: const Text(
                              'Bank & Payment Settings',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              acc.upiId.isNotEmpty
                                  ? 'UPI: ${acc.upiId} • ${acc.bankName.isNotEmpty ? acc.bankName : "Active"}'
                                  : 'Update bank details, receiving UPI ID & payment QR',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isConfigured
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isConfigured
                                          ? Colors.green
                                          : Colors.orange,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    isConfigured ? 'ACTIVE ✓' : 'NEEDS SETUP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isConfigured
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: () {
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
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                color: Colors.teal,
                                size: 24,
                              ),
                            ),
                            title: const Text(
                              'Payment Verification & Security',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Sensitive credential masking & verified payout routing enabled',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.verified_rounded,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 2. Printing & Pricing Section
                _sectionHeader('PRINTING RATES & CATALOG', theme),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.currency_rupee_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Live Price Management',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Manage per-page pricing, paper types, GSM, and finishing services',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PriceManagement(
                            dataService: dataService,
                            onToggleTheme: onToggleTheme,
                            onSignOut: onSignOut,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 3. App Preferences
                _sectionHeader('PREFERENCES', theme),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: Colors.purple,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          isDark ? 'Dark Theme' : 'Light Theme',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Switch(
                          value: isDark,
                          onChanged: (_) => onToggleTheme(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Account & Sign Out
                _sectionHeader('ACCOUNT', theme),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: Text(
                      'End session on this shopkeeper device',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: onSignOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
