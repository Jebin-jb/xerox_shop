import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/supabase_config.dart';
import 'services/supabase_service.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Initialize Firebase Cloud Firestore
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully!');
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize Supabase if credentials are provided in SupabaseConfig
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabasePublishableKey,
      );
      debugPrint('Supabase initialized successfully!');
    } catch (e) {
      debugPrint('Supabase initialization warning: $e');
    }
  } else {
    debugPrint(
      'Supabase credentials not configured yet. Running in local persistent storage mode.',
    );
  }

  final auth = AuthService();
  await auth.isReady;
  final data = SupabaseService();

  runApp(
    CampusXeroxApp(
      initialDarkMode: prefs.getBool('darkMode') ?? false,
      auth: auth,
      data: data,
    ),
  );
}

class CampusXeroxApp extends StatefulWidget {
  final bool initialDarkMode;
  final AuthService auth;
  final DataService data;

  const CampusXeroxApp({
    super.key,
    required this.initialDarkMode,
    required this.auth,
    required this.data,
  });

  @override
  State<CampusXeroxApp> createState() => _CampusXeroxAppState();
}

class _CampusXeroxAppState extends State<CampusXeroxApp> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = widget.initialDarkMode;
  }

  Future<void> toggleTheme() async {
    setState(() => isDark = !isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Xerox',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: AuthGate(
        auth: widget.auth,
        dataService: widget.data,
        onToggleTheme: toggleTheme,
      ),
    );
  }

  @override
  void dispose() {
    widget.auth.dispose();
    widget.data.dispose();
    super.dispose();
  }
}
