import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'auth/auth_gate.dart';

class RoleGate extends StatelessWidget {
  final AuthService auth;
  final DataService dataService;
  final VoidCallback onToggleTheme;

  const RoleGate({
    super.key,
    required this.auth,
    required this.dataService,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      auth: auth,
      dataService: dataService,
      onToggleTheme: onToggleTheme,
    );
  }
}
