import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'data_service.dart';
import 'supabase_config.dart';

/// Production-ready Supabase Database & Realtime Service for Campus Xerox.
///
/// Features lag-free asynchronous synchronization:
/// 1. Instant rendering from persistent local cache on startup/login.
/// 2. Non-blocking background sync with Supabase PostgreSQL.
/// 3. Realtime stream listeners for instant live updates across student & shopkeeper devices.
class SupabaseService extends DataService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  SupabaseService._internal() : super() {
    _startBackgroundSync();
  }

  bool get isSupabaseLive => SupabaseConfig.isConfigured;

  SupabaseClient? get _client {
    try {
      if (isSupabaseLive) {
        return Supabase.instance.client;
      }
    } catch (e) {
      debugPrint('Supabase client check: $e');
    }
    return null;
  }

  /// Non-blocking background synchronization to ensure zero lag on UI thread
  void _startBackgroundSync() {
    if (!isSupabaseLive) return;

    Future.microtask(() async {
      final client = _client;
      if (client == null) return;

      try {
        // 1. Sync live prices from Supabase in background
        final priceRes = await client.from('shop_prices').select().maybeSingle();
        if (priceRes != null) {
          final livePrices = ShopPrice.fromMap(priceRes);
          await super.updatePrices(livePrices);
        }

        // 2. Sync active print orders
        final ordersRes = await client.from('print_orders').select().order('created_at', ascending: false).limit(100);
        for (final row in ordersRes) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final order = PrintOrder.fromMap(id, row);
            // Update internal map without blocking UI
            updateOrderLocally(order);
          }
        }

        // 3. Listen to realtime changes from Supabase
        _subscribeToRealtimeChanges(client);
      } catch (e) {
        debugPrint('Background Supabase sync notice: $e');
      }
    });
  }

  void _subscribeToRealtimeChanges(SupabaseClient client) {
    try {
      // Listen to print_orders table changes in real-time
      client
          .channel('public:print_orders_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'print_orders',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                final id = record['id']?.toString() ?? '';
                if (id.isNotEmpty) {
                  final order = PrintOrder.fromMap(id, record);
                  updateOrderLocally(order);
                }
              }
            },
          )
          .subscribe();

      // Listen to shop_prices updates in real-time
      client
          .channel('public:shop_prices_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shop_prices',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                final livePrices = ShopPrice.fromMap(record);
                super.updatePrices(livePrices);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription setup notice: $e');
    }
  }

  /// Synchronize student or shopkeeper user profile with Supabase 'profiles' table
  Future<void> syncProfileToSupabase(UserProfile profile) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('profiles').upsert({
        'id': profile.id,
        'name': profile.name,
        'email': profile.email,
        'role': profile.role,
        'student_id': profile.studentId,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error syncing profile to Supabase: $e');
    }
  }

  /// Create a new print order in Supabase and notify real-time listeners
  @override
  Future<String> createOrder({
    required String studentId,
    required String studentName,
    String studentEmail = '',
    required String fileName,
    required String fileUrl,
    int fileSizeBytes = 0,
    required int pages,
    required int copies,
    required bool color,
    required bool doubleSided,
    required bool lamination,
    required bool binding,
    PaperType paperType = PaperType.standard75Gsm,
    BindingType bindingType = BindingType.none,
    required double total,
    required PaymentMode paymentMode,
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
  }) async {
    // 1. Create in local memory & persistent storage for immediate response
    final orderId = await super.createOrder(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      fileName: fileName,
      fileUrl: fileUrl,
      fileSizeBytes: fileSizeBytes,
      pages: pages,
      copies: copies,
      color: color,
      doubleSided: doubleSided,
      lamination: lamination,
      binding: binding,
      paperType: paperType,
      bindingType: bindingType,
      total: total,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
    );

    // 2. Sync to Supabase PostgreSQL table in background
    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          final ordersList = allOrdersDirect;
          final matching = ordersList.where((o) => o.id == orderId).firstOrNull;
          final code = matching?.code ?? orderId.substring(0, 6).toUpperCase();

          await client.from('print_orders').insert({
            'id': orderId,
            'code': code,
            'student_id': studentId,
            'student_name': studentName,
            'student_email': studentEmail,
            'file_name': fileName,
            'file_url': fileUrl,
            'file_size_bytes': fileSizeBytes,
            'pages': pages,
            'copies': copies,
            'color': color,
            'double_sided': doubleSided,
            'lamination': lamination,
            'binding': binding,
            'paper_type': paperType.name,
            'binding_type': bindingType.name,
            'total': total,
            'payment_mode': paymentMode.name,
            'payment_status': paymentStatus.name,
            'status': OrderStatus.pending.name,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Supabase order insert error (saved locally): $e');
        }
      });
    }

    return orderId;
  }

  /// Update print order status & purge flags in Supabase
  @override
  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    await super.updateOrder(orderId, updates);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          final pgUpdates = <String, dynamic>{};
          if (updates.containsKey('status')) pgUpdates['status'] = updates['status'];
          if (updates.containsKey('paymentStatus')) pgUpdates['payment_status'] = updates['paymentStatus'];
          if (updates.containsKey('isDownloaded')) pgUpdates['is_downloaded'] = updates['isDownloaded'];
          if (updates.containsKey('isPurged')) pgUpdates['is_purged'] = updates['isPurged'];
          if (updates.containsKey('completedAt')) {
            pgUpdates['completed_at'] = updates['completedAt'] is DateTime
                ? (updates['completedAt'] as DateTime).toIso8601String()
                : updates['completedAt'];
          }

          if (pgUpdates.isNotEmpty) {
            await client.from('print_orders').update(pgUpdates).eq('id', orderId);
          }
        } catch (e) {
          debugPrint('Supabase update order error: $e');
        }
      });
    }
  }

  /// Update shop prices in Supabase and notify all students in real time
  @override
  Future<void> updatePrices(ShopPrice newPrices) async {
    await super.updatePrices(newPrices);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          await client.from('shop_prices').upsert({
            'id': 'campus-xerox',
            'bw_single': newPrices.bwSingle,
            'bw_double': newPrices.bwDouble,
            'color_single': newPrices.colorSingle,
            'color_double': newPrices.colorDouble,
            'photocopy': newPrices.photocopy,
            'paper_75_gsm': newPrices.paper75Gsm,
            'paper_100_gsm': newPrices.paper100Gsm,
            'paper_glossy': newPrices.paperGlossy,
            'spiral_binding': newPrices.spiralBinding,
            'hard_binding': newPrices.hardBinding,
            'lamination': newPrices.lamination,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Supabase update prices error: $e');
        }
      });
    }
  }

  /// Add expense entry in Supabase
  @override
  Future<void> addExpense(String title, double amount, String category, [DateTime? date]) async {
    await super.addExpense(title, amount, category, date);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          await client.from('expenses').insert({
            'id': 'exp_${DateTime.now().millisecondsSinceEpoch}',
            'title': title,
            'amount': amount,
            'category': category,
            'date': (date ?? DateTime.now()).toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Supabase add expense error: $e');
        }
      });
    }
  }
}
