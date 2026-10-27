import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../app_config.dart';
import '../models/app_models.dart';
import 'supabase_config.dart';
import 'supabase_service.dart';

class AppUser {
  final String uid;
  final String email;
  const AppUser({required this.uid, required this.email});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _init();
  }

  final _authController = StreamController<AppUser?>.broadcast();
  final _profileController =
      StreamController<Map<String, UserProfile>>.broadcast();
  final _initCompleter = Completer<void>();

  AppUser? _currentUser;
  final Map<String, Map<String, String>> _accounts = {};
  final Map<String, UserProfile> _profiles = {};
  bool _initialized = false;

  Future<void> get isReady => _initCompleter.future;
  Stream<AppUser?> get authState => _authController.stream;
  AppUser? get currentUser => _currentUser;

  bool isCollegeEmail(String email) {
    final clean = email.trim().toLowerCase();
    return clean.endsWith('@${AppConfig.collegeEmailDomain}') ||
        clean.contains('mock') ||
        clean.contains('college.ac.in');
  }

  Future<void> _init() async {
    try {
      await _loadAccountsAndProfiles();
      await ensureDemoShopkeeper();
      await ensureDemoStudent();
      await ensureMockAccounts();
      await _restoreSession();
    } finally {
      _initialized = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> _loadAccountsAndProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString('saved_accounts');
      if (accountsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(accountsJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _accounts[key] = Map<String, String>.from(value);
          }
        });
      }

      final profilesJson = prefs.getString('saved_profiles');
      if (profilesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(profilesJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _profiles[key] = UserProfile.fromMap(
              key,
              Map<String, dynamic>.from(value),
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAccountsAndProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_accounts', jsonEncode(_accounts));
      final profilesMap = <String, dynamic>{};
      _profiles.forEach((key, val) => profilesMap[key] = val.toMap());
      await prefs.setString('saved_profiles', jsonEncode(profilesMap));
      _profileController.add(Map.unmodifiable(_profiles));
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    // 1. If Supabase is connected, check for active Supabase session
    if (SupabaseConfig.isConfigured) {
      try {
        final sbUser = sb.Supabase.instance.client.auth.currentUser;
        if (sbUser != null) {
          final uid = sbUser.id;
          final email = sbUser.email ?? '';
          if (!_profiles.containsKey(uid)) {
            _profiles[uid] = UserProfile(
              id: uid,
              name: sbUser.userMetadata?['name'] ?? 'College Student',
              email: email,
              role: sbUser.userMetadata?['role'] ?? 'student',
              studentId: sbUser.userMetadata?['student_id'] ?? '',
            );
          }
          _currentUser = AppUser(uid: uid, email: email);
          _authController.add(_currentUser);
          return;
        }
      } catch (_) {}
    }

    // 2. Check local persistent session in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('session_email');
    final uid = prefs.getString('session_uid');
    if (email != null && uid != null) {
      final isShop =
          uid.contains('shopkeeper') ||
          uid.contains('admin') ||
          email.contains('shopkeeper') ||
          email.contains('xeroxshop') ||
          email.contains('admin');

      if (!_profiles.containsKey(uid)) {
        _profiles[uid] = UserProfile(
          id: uid,
          name: isShop ? 'Campus Xerox' : 'Mock Student',
          email: email,
          role: isShop ? 'shopkeeper' : 'student',
          studentId: isShop ? '' : 'MOCK2026',
        );
      } else if (_profiles[uid]!.role == 'admin') {
        _profiles[uid] = _profiles[uid]!.copyWith(role: 'shopkeeper');
      }
      _currentUser = AppUser(uid: uid, email: email);
      _authController.add(_currentUser);
      final prof = _profiles[uid];
      if (prof != null) {
        _syncFirebaseAuth(email, '1234', prof.role, prof.name, prof.studentId);
      }
    } else {
      _currentUser = null;
      _authController.add(null);
    }
  }

  Future<void> _syncFirebaseAuth(
    String email,
    String password,
    String role,
    String name,
    String studentId,
  ) async {
    try {
      fb_auth.UserCredential? cred;
      try {
        cred = await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        try {
          cred = await fb_auth.FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
        } catch (_) {
          try {
            cred = await fb_auth.FirebaseAuth.instance.signInAnonymously();
          } catch (_) {}
        }
      }

      final fbUser = cred?.user ?? fb_auth.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        await cf.FirebaseFirestore.instance
            .collection('users')
            .doc(fbUser.uid)
            .set({
              'role': role,
              'email': email,
              'name': name,
              'studentId': studentId,
              'updatedAt': cf.FieldValue.serverTimestamp(),
            }, cf.SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Firebase Auth sync notice: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!_initialized) await isReady;
    final normalized = email.trim().toLowerCase();
    if (!isCollegeEmail(normalized)) {
      throw AuthException(
        'Use your official college email ending in @${AppConfig.collegeEmailDomain}.',
      );
    }

    // Direct match for mock & demo accounts
    final account = _accounts[normalized];
    if (account != null && account['password'] == password) {
      final uid = account['uid']!;
      _currentUser = AppUser(uid: uid, email: normalized);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_email', normalized);
      await prefs.setString('session_uid', uid);
      _authController.add(_currentUser);
      final prof = _profiles[uid];
      if (prof != null) {
        _syncFirebaseAuth(
          normalized,
          password,
          prof.role,
          prof.name,
          prof.studentId,
        );
        if (SupabaseConfig.isConfigured) {
          try {
            await sb.Supabase.instance.client.auth.signInWithPassword(
              email: normalized,
              password: password,
            );
          } catch (_) {
            try {
              await sb.Supabase.instance.client.auth.signUp(
                email: normalized,
                password: password,
                data: {
                  'name': prof.name,
                  'role': prof.role,
                  'student_id': prof.studentId,
                },
              );
            } catch (_) {}
          }
        }
      }
      return;
    }

    // Try Supabase Auth if configured
    if (SupabaseConfig.isConfigured) {
      try {
        final res = await sb.Supabase.instance.client.auth.signInWithPassword(
          email: normalized,
          password: password,
        );
        if (res.user != null) {
          final uid = res.user!.id;
          final userProfile =
              _profiles[uid] ??
              UserProfile(
                id: uid,
                name: res.user!.userMetadata?['name'] ?? 'College Student',
                email: normalized,
                role: res.user!.userMetadata?['role'] ?? 'student',
                studentId: res.user!.userMetadata?['student_id'] ?? '',
              );
          _profiles[uid] = userProfile;
          _currentUser = AppUser(uid: uid, email: normalized);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_email', normalized);
          await prefs.setString('session_uid', uid);
          _authController.add(_currentUser);
          await _saveAccountsAndProfiles();
          return;
        }
      } catch (e) {
        debugPrint('Supabase Auth attempt notice: $e');
      }
    }

    if (account == null || account['password'] != password) {
      throw AuthException(
        'Invalid email or password. Please check your credentials.',
      );
    }
  }

  Future<void> registerStudent({
    required String name,
    required String studentId,
    required String email,
    required String password,
  }) async {
    if (!_initialized) await isReady;
    final normalized = email.trim().toLowerCase();
    if (!isCollegeEmail(normalized)) {
      throw AuthException(
        'Registration is restricted to official @${AppConfig.collegeEmailDomain} emails.',
      );
    }
    if (_accounts.containsKey(normalized)) {
      throw AuthException('An account already exists for this college email.');
    }

    String uid = 'student_${DateTime.now().millisecondsSinceEpoch}';

    // Register with Supabase Auth if configured
    if (SupabaseConfig.isConfigured) {
      try {
        final res = await sb.Supabase.instance.client.auth.signUp(
          email: normalized,
          password: password,
          data: {
            'name': name.trim(),
            'role': 'student',
            'student_id': studentId.trim(),
          },
        );
        if (res.user != null) {
          uid = res.user!.id;
        }
      } catch (e) {
        debugPrint('Supabase sign up warning: $e');
      }
    }

    _accounts[normalized] = {'uid': uid, 'password': password};
    final profile = UserProfile(
      id: uid,
      name: name.trim(),
      email: normalized,
      role: UserRole.student.name,
      studentId: studentId.trim(),
    );
    _profiles[uid] = profile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_email', normalized);
    await prefs.setString('session_uid', uid);
    _currentUser = AppUser(uid: uid, email: normalized);
    _authController.add(_currentUser);

    await _saveAccountsAndProfiles();

    // Sync profile to Firebase Auth & Firestore
    _syncFirebaseAuth(
      normalized,
      password,
      'student',
      name.trim(),
      studentId.trim(),
    );

    // Sync profile to Supabase 'profiles' table
    await SupabaseService().syncProfileToSupabase(profile);
  }

  Future<void> ensureMockAccounts() async {
    // 1. Mock Student
    const mockStudentEmail = 'mock@college.ac.in';
    const mockStudentUid = 'mock_student_1';
    _accounts[mockStudentEmail] = {'uid': mockStudentUid, 'password': 'mock'};
    _profiles[mockStudentUid] = const UserProfile(
      id: mockStudentUid,
      name: 'Mock Student',
      email: mockStudentEmail,
      role: 'student',
      studentId: 'MOCK2026',
    );

    // 2. Mock Shopkeeper
    const mockAdminEmail = 'xeroxshop@college.ac.in';
    const mockAdminUid = 'shopkeeper_1';
    _accounts[mockAdminEmail] = {'uid': mockAdminUid, 'password': '1234'};
    _profiles[mockAdminUid] = const UserProfile(
      id: mockAdminUid,
      name: 'Campus Xerox',
      email: mockAdminEmail,
      role: 'shopkeeper',
      studentId: '',
    );

    const mockAdminEmail2 = 'shopkeeper@college.ac.in';
    _accounts[mockAdminEmail2] = {'uid': mockAdminUid, 'password': '1234'};

    await _saveAccountsAndProfiles();
  }

  Future<void> ensureDemoShopkeeper() async {
    const email = 'xeroxshop@college.ac.in';
    const uid = 'shopkeeper_1';
    _accounts[email] = {'uid': uid, 'password': '1234'};
    _profiles[uid] = const UserProfile(
      id: uid,
      name: 'Campus Xerox',
      email: email,
      role: 'shopkeeper',
      studentId: '',
    );
    // Backward compatibility for old demo email
    _accounts['shopkeeper@college.ac.in'] = {'uid': uid, 'password': '1234'};
    await _saveAccountsAndProfiles();
  }

  Future<void> ensureDemoStudent() async {
    const email = 'student@college.ac.in';
    const uid = 'student_demo_1';
    if (!_accounts.containsKey(email)) {
      _accounts[email] = {'uid': uid, 'password': 'Student@12345'};
      _profiles[uid] = const UserProfile(
        id: uid,
        name: 'Krishna Sharma',
        email: email,
        role: 'student',
        studentId: 'CSE26A001',
      );
      await _saveAccountsAndProfiles();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!isCollegeEmail(normalized)) {
      throw AuthException(
        'Enter a valid @${AppConfig.collegeEmailDomain} college email.',
      );
    }

    if (SupabaseConfig.isConfigured) {
      try {
        await sb.Supabase.instance.client.auth.resetPasswordForEmail(
          normalized,
        );
        return;
      } catch (_) {}
    }

    if (!_accounts.containsKey(normalized)) {
      throw AuthException('No account found for $normalized.');
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  UserProfile? profile(String uid) => _profiles[uid];

  Stream<UserProfile?> profileStream(String uid) {
    if (_profiles.containsKey(uid)) {
      return Stream.value(_profiles[uid]).asBroadcastStream();
    }
    return _profileController.stream.map((profiles) => profiles[uid]);
  }

  Future<void> signOut() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (SupabaseConfig.isConfigured) {
      try {
        await sb.Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_email');
    await prefs.remove('session_uid');
    _authController.add(null);
  }

  void dispose() {
    _authController.close();
    _profileController.close();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
