import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'admin_login_screen.dart';
import 'student_login_screen.dart';

class PortalSelectionScreen extends StatelessWidget {
  final AuthService auth;
  final VoidCallback onToggleTheme;

  const PortalSelectionScreen({
    super.key,
    required this.auth,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top bar with Theme toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppLogo(size: 42),
                          IconButton(
                            onPressed: onToggleTheme,
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Welcome Title
                      FadeSlide(
                        offset: const Offset(0, -0.04),
                        child: Column(
                          children: [
                            Text(
                              'Welcome to Campus Xerox',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select your portal to sign in',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 1. Student Portal Card
                      _portalCard(
                        context: context,
                        title: 'Student Portal',
                        subtitle:
                            'Upload documents up to 50MB, check live rates & pickup orders.',
                        icon: Icons.school_rounded,
                        color: AppTheme.primary,
                        buttonLabel: 'Enter Student Portal',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentLoginScreen(
                              auth: auth,
                              onToggleTheme: onToggleTheme,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Shopkeeper Portal Card
                      _portalCard(
                        context: context,
                        title: 'Shopkeeper Portal',
                        subtitle:
                            'Manage live print queue, download documents & update prices.',
                        icon: Icons.storefront_rounded,
                        color: const Color(0xFF00A2FF),
                        buttonLabel: 'Enter Shopkeeper Portal',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminLoginScreen(
                              auth: auth,
                              onToggleTheme: onToggleTheme,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required VoidCallback onTap,
  }) => FadeSlide(
    child: GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
