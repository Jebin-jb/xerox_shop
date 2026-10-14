import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'data_service.dart';
import 'supabase_config.dart';

/// Production-ready Supabase Database & Realtime Service for Campus Xerox.
///
/// Supabase PostgreSQL is the single source of truth for:
/// 1. `payment_settings`: UPI ID, Payee Name, Payment App, Scannable QR Code URL.
/// 2. `shop_prices` & `services`: Live shop pricing synchronizing in real time across phones.
/// 3. `print_orders`: Orders, payment statuses, and verification.
class SupabaseService extends DataService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _paymentChannel;
  RealtimeChannel? _pricesChannel;
  RealtimeChannel? _servicesChannel;

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

  /// Non-blocking background synchronization with Supabase as single source of truth
  void _startBackgroundSync() {
    if (!isSupabaseLive) return;

    Future.microtask(() async {
      final client = _client;
      if (client == null) return;

      try {
        // 1. Fetch latest Payment Settings from Supabase
        await _fetchInitialPaymentSettings(client);

        // 2. Fetch latest Shop Prices & Services from Supabase
        await _fetchInitialPrices(client);

        // 3. Fetch active Print Orders from Supabase
        final ordersRes = await client
            .from('print_orders')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        for (final row in ordersRes) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final order = PrintOrder.fromMap(id, row);
            updateOrderLocally(order);
          }
        }

        // 4. Subscribe to Realtime updates on all tables
        _subscribeToRealtimeChanges(client);
      } catch (e) {
        debugPrint('Background Supabase sync notice: $e');
      }
    });
  }

  Future<void> _fetchInitialPaymentSettings(SupabaseClient client) async {
    try {
      final res = await client
          .from('payment_settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1);
      if (res.isNotEmpty) {
        final account = ShopPaymentAccount.fromMap(res.first);
        updatePaymentAccountLocally(account);
      }
    } catch (e) {
      debugPrint('Initial payment_settings fetch notice: $e');
    }
  }

  Future<void> _fetchInitialPrices(SupabaseClient client) async {
    try {
      final priceRes = await client
          .from('shop_prices')
          .select()
          .order('updated_at', ascending: false)
          .limit(1);
      if (priceRes.isNotEmpty) {
        _handleRemoteShopPrices(priceRes.first);
      }

      final srvRes = await client.from('services').select();
      for (final row in srvRes) {
        _handleRemoteServiceRow(row);
      }
    } catch (e) {
      debugPrint('Initial prices fetch notice: $e');
    }
  }

  void _subscribeToRealtimeChanges(SupabaseClient client) {
    try {
      // 1. Realtime subscription for print_orders
      _ordersChannel?.unsubscribe();
      _ordersChannel = client
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

      // 2. Realtime subscription for payment_settings (Instant QR & UPI sync to Student phone)
      _paymentChannel?.unsubscribe();
      _paymentChannel = client
          .channel('public:payment_settings_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'payment_settings',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                final account = ShopPaymentAccount.fromMap(record);
                updatePaymentAccountLocally(account);
              }
            },
          )
          .subscribe();

      // 3. Realtime subscription for shop_prices (Instant price sync to Student phone)
      _pricesChannel?.unsubscribe();
      _pricesChannel = client
          .channel('public:shop_prices_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shop_prices',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                _handleRemoteShopPrices(record);
              }
            },
          )
          .subscribe();

      // 4. Realtime subscription for granular services
      _servicesChannel?.unsubscribe();
      _servicesChannel = client
          .channel('public:services_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'services',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                _handleRemoteServiceRow(record);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscriptions setup notice: $e');
    }
  }

  void _handleRemoteShopPrices(Map<String, dynamic> row) {
    try {
      final bwSingle = double.tryParse('${row['bw_single']}') ?? 1.0;
      final bwDouble = double.tryParse('${row['bw_double']}') ?? 1.5;
      final colorSingle = double.tryParse('${row['color_single']}') ?? 5.0;
      final colorDouble = double.tryParse('${row['color_double']}') ?? 8.0;

      final spiral = double.tryParse('${row['spiral_binding']}') ?? 30.0;
      final hard = double.tryParse('${row['hard_binding']}') ?? 150.0;
      final lam = double.tryParse('${row['lamination']}') ?? 10.0;

      final current = currentLivePricing;
      final updatedPrinting = current.printingPrices.copyWith(
        bwSinglePerSheet: bwSingle,
        bwDoublePerSheet: bwDouble,
        colorSinglePerSheet: colorSingle,
        colorDoublePerSheet: colorDouble,
      );

      final updatedBinding = current.bindingTypes.map((b) {
        if (b.id == 'bind_spiral' || b.name.toLowerCase().contains('spiral')) return b.copyWith(price: spiral);
        if (b.id == 'bind_hard' || b.name.toLowerCase().contains('hard')) return b.copyWith(price: hard);
        return b;
      }).toList();

      final updatedLam = current.laminationTypes.map((l) {
        return l.copyWith(price: lam);
      }).toList();

      final updatedPricing = current.copyWith(
        printingPrices: updatedPrinting,
        bindingTypes: updatedBinding,
        laminationTypes: updatedLam,
        updatedAt: DateTime.tryParse('${row['updated_at']}') ?? DateTime.now(),
      );

      updateLivePricingLocally(updatedPricing);
    } catch (e) {
      debugPrint('Error handling remote shop prices: $e');
    }
  }

  void _handleRemoteServiceRow(Map<String, dynamic> row) {
    try {
      final name = (row['service_name'] ?? '').toString().toLowerCase();
      final price = (row['price'] is num)
          ? (row['price'] as num).toDouble()
          : double.tryParse('${row['price']}') ?? 0.0;

      final current = currentLivePricing;
      var printing = current.printingPrices;
      var bindings = current.bindingTypes;
      var laminations = current.laminationTypes;

      if (name.contains('b&w single') || name.contains('bw single')) {
        printing = printing.copyWith(bwSinglePerSheet: price);
      } else if (name.contains('b&w double') || name.contains('bw double')) {
        printing = printing.copyWith(bwDoublePerSheet: price);
      } else if (name.contains('color single')) {
        printing = printing.copyWith(colorSinglePerSheet: price);
      } else if (name.contains('color double')) {
        printing = printing.copyWith(colorDoublePerSheet: price);
      } else if (name.contains('spiral') || name == 'binding') {
        bindings = bindings.map((b) {
          if (b.id == 'bind_spiral' || b.name.toLowerCase().contains('spiral')) return b.copyWith(price: price);
          return b;
        }).toList();
      } else if (name.contains('lamination')) {
        laminations = laminations.map((l) => l.copyWith(price: price)).toList();
      }

      final updatedPricing = current.copyWith(
        printingPrices: printing,
        bindingTypes: bindings,
        laminationTypes: laminations,
        updatedAt: DateTime.tryParse('${row['updated_at']}') ?? DateTime.now(),
      );

      updateLivePricingLocally(updatedPricing);
    } catch (e) {
      debugPrint('Error handling remote service row: $e');
    }
  }

  /// Explicitly query the freshest payment settings directly from Supabase.
  /// Used when student loads payment screen, presses Retry, or before opening UPI app.
  Future<ShopPaymentAccount> getFreshPaymentSettings() async {
    final client = _client;
    if (client == null) return currentPaymentAccount;

    try {
      final res = await client
          .from('payment_settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 4));

      if (res.isNotEmpty) {
        final account = ShopPaymentAccount.fromMap(res.first);
        updatePaymentAccountLocally(account);
        return account;
      }
    } catch (e) {
      debugPrint('getFreshPaymentSettings notice: $e');
    }
    return currentPaymentAccount;
  }

  /// Explicitly query the freshest prices directly from Supabase.
  Future<LiveShopPricing> getFreshPrices() async {
    final client = _client;
    if (client == null) return currentLivePricing;

    try {
      final res = await client
          .from('shop_prices')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 4));

      if (res.isNotEmpty) {
        _handleRemoteShopPrices(res.first);
      }
    } catch (e) {
      debugPrint('getFreshPrices notice: $e');
    }
    return currentLivePricing;
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

  /// Update shop payment account in Supabase and notify all listening students instantly
  @override
  Future<void> updatePaymentAccount(ShopPaymentAccount newAccount) async {
    await super.updatePaymentAccount(newAccount);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          await client
              .from('payment_settings')
              .upsert(newAccount.toPaymentSettingsMap());
        } catch (e) {
          debugPrint('Supabase update payment_settings error: $e');
        }
      });
    }
  }

  /// Update shop prices in Supabase and notify all students in real time
  @override
  Future<void> updateLivePricing(LiveShopPricing newPricing) async {
    await super.updateLivePricing(newPricing);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          // 1. Update shop_prices table
          await client.from('shop_prices').upsert({
            'id': 'campus-xerox',
            'bw_single': newPricing.printingPrices.bwSinglePerSheet,
            'bw_double': newPricing.printingPrices.bwDoublePerSheet,
            'color_single': newPricing.printingPrices.colorSinglePerSheet,
            'color_double': newPricing.printingPrices.colorDoublePerSheet,
            'photocopy': newPricing.printingPrices.bwSinglePerSheet,
            'paper_75_gsm': 0.0,
            'paper_100_gsm': 1.5,
            'paper_glossy': 10.0,
            'spiral_binding': newPricing.bindingTypes
                .firstWhere(
                  (b) => b.id == 'bind_spiral' || b.name.toLowerCase().contains('spiral'),
                  orElse: () => const BindingTypeItem(
                    id: 'bind_spiral',
                    name: 'Spiral',
                    price: 30.0,
                  ),
                )
                .price,
            'hard_binding': newPricing.bindingTypes
                .firstWhere(
                  (b) => b.id == 'bind_hard' || b.name.toLowerCase().contains('hard'),
                  orElse: () => const BindingTypeItem(
                    id: 'bind_hard',
                    name: 'Hard',
                    price: 150.0,
                  ),
                )
                .price,
            'lamination': newPricing.laminationTypes.isNotEmpty
                ? newPricing.laminationTypes.first.price
                : 10.0,
            'updated_at': DateTime.now().toIso8601String(),
          });

          // 2. Also update services table for granular service catalog
          final servicesList = [
            {
              'id': 'srv_bw_single',
              'shop_id': 'campus-xerox',
              'service_name': 'B&W Single Side',
              'description': 'Black & white single side print',
              'price': newPricing.printingPrices.bwSinglePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'srv_bw_double',
              'shop_id': 'campus-xerox',
              'service_name': 'B&W Double Side',
              'description': 'Black & white double side print',
              'price': newPricing.printingPrices.bwDoublePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'srv_color_single',
              'shop_id': 'campus-xerox',
              'service_name': 'Color Single Side',
              'description': 'Full color single side print',
              'price': newPricing.printingPrices.colorSinglePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'srv_color_double',
              'shop_id': 'campus-xerox',
              'service_name': 'Color Double Side',
              'description': 'Full color double side print',
              'price': newPricing.printingPrices.colorDoublePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'srv_spiral_binding',
              'shop_id': 'campus-xerox',
              'service_name': 'Binding',
              'description': 'Spiral coil binding',
              'price': newPricing.bindingTypes
                  .firstWhere(
                    (b) => b.id == 'bind_spiral' || b.name.toLowerCase().contains('spiral'),
                    orElse: () => const BindingTypeItem(
                      id: 'bind_spiral',
                      name: 'Spiral',
                      price: 30.0,
                    ),
                  )
                  .price,
              'pricing_unit': 'per_item',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'srv_lamination',
              'shop_id': 'campus-xerox',
              'service_name': 'Lamination',
              'description': 'A4 hot pouch lamination',
              'price': newPricing.laminationTypes.isNotEmpty
                  ? newPricing.laminationTypes.first.price
                  : 10.0,
              'pricing_unit': 'per_item',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
          ];

          for (final srv in servicesList) {
            await client.from('services').upsert(srv);
          }
        } catch (e) {
          debugPrint('Supabase update live pricing error: $e');
        }
      });
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
    Map<String, dynamic>? priceSnapshot,
    String specialInstructions = '',
    String paperTypeName = '',
    String gsmName = '',
    String bindingName = '',
    int? bwPageCount,
    int? colorPageCount,
    List<int>? colorPageNumbers,
    List<PagePrintSetting>? pageSettings,
  }) async {
    // 1. Create in local memory & persistent storage for immediate UI response
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
      priceSnapshot: priceSnapshot,
      specialInstructions: specialInstructions,
      paperTypeName: paperTypeName,
      gsmName: gsmName,
      bindingName: bindingName,
      bwPageCount: bwPageCount,
      colorPageCount: colorPageCount,
      colorPageNumbers: colorPageNumbers,
      pageSettings: pageSettings,
    );

    // 2. Sync to Supabase PostgreSQL table
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
            'special_instructions': specialInstructions,
            'price_snapshot': priceSnapshot,
            'payment_method': '',
            'transaction_reference': '',
            'bw_page_count': bwPageCount ?? (color ? 0 : pages),
            'color_page_count': colorPageCount ?? (color ? pages : 0),
            'color_page_numbers': colorPageNumbers ??
                (color ? List.generate(pages, (i) => i + 1) : <int>[]),
            'page_settings':
                (pageSettings ?? const []).map((s) => s.toMap()).toList(),
          });
        } catch (e) {
          debugPrint('Supabase order insert error (saved locally): $e');
        }
      });
    }

    return orderId;
  }

  /// Update print order status, payment status & reference in Supabase
  @override
  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    await super.updateOrder(orderId, updates);

    final client = _client;
    if (client != null) {
      Future.microtask(() async {
        try {
          final pgUpdates = <String, dynamic>{};
          if (updates.containsKey('status')) {
            pgUpdates['status'] = updates['status'];
          }
          if (updates.containsKey('paymentStatus')) {
            pgUpdates['payment_status'] = updates['paymentStatus'];
          }
          if (updates.containsKey('paymentMode')) {
            pgUpdates['payment_mode'] = updates['paymentMode'];
          }
          if (updates.containsKey('paymentMethod')) {
            pgUpdates['payment_method'] = updates['paymentMethod'];
          }
          if (updates.containsKey('transactionReference')) {
            pgUpdates['transaction_reference'] = updates['transactionReference'];
          }
          if (updates.containsKey('paidAt')) {
            pgUpdates['paid_at'] = updates['paidAt'] is DateTime
                ? (updates['paidAt'] as DateTime).toIso8601String()
                : updates['paidAt'];
          }
          if (updates.containsKey('isDownloaded')) {
            pgUpdates['is_downloaded'] = updates['isDownloaded'];
          }
          if (updates.containsKey('isPurged')) {
            pgUpdates['is_purged'] = updates['isPurged'];
          }
          if (updates.containsKey('completedAt')) {
            pgUpdates['completed_at'] = updates['completedAt'] is DateTime
                ? (updates['completedAt'] as DateTime).toIso8601String()
                : updates['completedAt'];
          }

          if (pgUpdates.isNotEmpty) {
            await client
                .from('print_orders')
                .update(pgUpdates)
                .eq('id', orderId);
          }
        } catch (e) {
          debugPrint('Supabase update order error: $e');
        }
      });
    }
  }

  /// Add expense entry in Supabase
  @override
  Future<void> addExpense(
    String title,
    double amount,
    String category, [
    DateTime? date,
  ]) async {
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
