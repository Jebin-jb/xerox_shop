import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/splash_screen.dart';
import '../shopkeeper/shopkeeper_shell.dart';
import '../student/student_shell.dart';
import 'portal_selection_screen.dart';

class AuthGate extends StatelessWidget {
  final AuthService auth;
  final DataService dataService;
  final VoidCallback onToggleTheme;

  const AuthGate({
    super.key,
    required this.auth,
    required this.dataService,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
        stream: auth.authState,
        initialData: auth.currentUser,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;
          if (user == null) {
            return PortalSelectionScreen(
              auth: auth,
              onToggleTheme: onToggleTheme,
            );
          }

          return StreamBuilder<UserProfile?>(
            stream: auth.profileStream(user.uid),
            initialData: auth.profile(user.uid),
            builder: (context, profileSnapshot) {
              final p = profileSnapshot.data ?? auth.profile(user.uid);
              if (p == null) {
                return const CampusSplashScreen(
                  statusText: 'Synchronizing profile…',
                );
              }

              if (p.role == UserRole.shopkeeper.name) {
                return ShopkeeperShell(
                  auth: auth,
                  dataService: dataService,
                  onToggleTheme: onToggleTheme,
                );
              }

              return StudentShell(
                auth: auth,
                dataService: dataService,
                profile: p,
                onToggleTheme: onToggleTheme,
              );
            },
          );
        },
      );
}
