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

  @override
  Future<void> refreshOrders() async {
    final client = _client;
    if (client == null) return;
    try {
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
      if (_ordersChannel == null) {
        _subscribeToRealtimeChanges(client);
      }
    } catch (e) {
      debugPrint('refreshOrders notice: $e');
    }
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
              } else if (payload.oldRecord.isNotEmpty) {
                final oldId = payload.oldRecord['id']?.toString() ?? '';
                if (oldId.isNotEmpty) {
                  removeOrderLocally(oldId);
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
        if (b.id == 'bind_spiral' || b.name.toLowerCase().contains('spiral')) {
          return b.copyWith(price: spiral);
        }
        if (b.id == 'bind_hard' || b.name.toLowerCase().contains('hard')) {
          return b.copyWith(price: hard);
        }
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
      final srvName = (row['service_name'] ?? '').toString().trim();
      if (srvName.isEmpty) return;

      final price = (row['price'] is num)
          ? (row['price'] as num).toDouble()
          : double.tryParse('${row['price']}') ?? 0.0;
      final isActive = row['is_active'] != false;
      final rawDesc = (row['description'] ?? '').toString().trim();
      final rawUnit = (row['pricing_unit'] ?? '').toString().trim();
      final rowTime = DateTime.tryParse('${row['updated_at']}');
      final rowId = row['id']?.toString() ?? '';

      final current = currentLivePricing;
      final nLower = srvName.toLowerCase();

      var printing = current.printingPrices;
      var bindings = current.bindingTypes;
      var laminations = current.laminationTypes;

      // 1. Core Printing Prices
      if (nLower == 'b&w single side' ||
          nLower == 'bw single' ||
          nLower == 'b&w single') {
        printing = printing.copyWith(bwSinglePerSheet: price);
      } else if (nLower == 'b&w double side' ||
          nLower == 'bw double' ||
          nLower == 'b&w double') {
        printing = printing.copyWith(bwDoublePerSheet: price);
      } else if (nLower == 'color single side' || nLower == 'color single') {
        printing = printing.copyWith(colorSinglePerSheet: price);
      } else if (nLower == 'color double side' || nLower == 'color double') {
        printing = printing.copyWith(colorDoublePerSheet: price);
      } else if (nLower == 'binding' ||
          nLower == 'spiral binding' ||
          nLower == 'spiral') {
        bindings = bindings.map((b) {
          if (b.id == 'bind_spiral' ||
              b.name.toLowerCase().contains('spiral')) {
            return b.copyWith(price: price);
          }
          return b;
        }).toList();
      } else if (nLower == 'lamination') {
        laminations = laminations.map((l) => l.copyWith(price: price)).toList();
      }

      // 2. Determine category
      String category = 'additionalService';
      if (rawDesc.isNotEmpty) {
        final dLower = rawDesc.toLowerCase();
        if (dLower == 'papertype' || dLower.contains('paper')) {
          category = 'paperType';
        } else if (dLower == 'gsm' || dLower.contains('gsm')) {
          category = 'gsm';
        } else if (dLower == 'binding') {
          category = 'binding';
        } else if (dLower == 'finishing') {
          category = 'finishing';
        } else if (dLower.contains('additional')) {
          category = 'additionalService';
        }
      } else {
        if (nLower.contains('binding') ||
            nLower.contains('spiral') ||
            nLower.contains('staple') ||
            nLower.contains('comb')) {
          category = 'binding';
        } else if (nLower.contains('lamination')) {
          category = 'finishing';
        } else if (nLower.contains('gsm')) {
          category = 'gsm';
        } else if (nLower.startsWith('a4') ||
            nLower.startsWith('a3') ||
            nLower.startsWith('legal') ||
            nLower.contains('photo paper')) {
          category = 'paperType';
        }
      }

      // 3. Update configItems
      final updatedConfig = List<PrintConfigItem>.from(current.configItems);
      final cfgIdx = updatedConfig.indexWhere(
        (i) => i.id == rowId || i.name.toLowerCase().trim() == nLower,
      );

      final isCorePrinting =
          nLower.contains('b&w single') ||
          nLower.contains('b&w double') ||
          nLower.contains('bw single') ||
          nLower.contains('bw double') ||
          nLower.contains('color single') ||
          nLower.contains('color double');

      if (cfgIdx != -1) {
        final old = updatedConfig[cfgIdx];
        updatedConfig[cfgIdx] = old.copyWith(
          price: price,
          enabled: isActive,
          updatedAt: rowTime ?? DateTime.now(),
        );
      } else if (!isCorePrinting) {
        updatedConfig.add(
          PrintConfigItem(
            id: rowId.isNotEmpty
                ? rowId
                : 'srv_${srvName.replaceAll(' ', '_')}',
            name: srvName,
            category: category,
            price: price,
            enabled: isActive,
            createdAt: rowTime ?? DateTime.now(),
            updatedAt: rowTime ?? DateTime.now(),
          ),
        );
      }

      // 4. Update additionalServices list if category is additionalService
      final updatedAdd = List<AdditionalServiceItem>.from(
        current.additionalServices,
      );
      if (category == 'additionalService') {
        final addIdx = updatedAdd.indexWhere(
          (a) => a.id == rowId || a.name.toLowerCase().trim() == nLower,
        );
        final addSrv = AdditionalServiceItem(
          id: rowId.isNotEmpty ? rowId : 'srv_${srvName.replaceAll(' ', '_')}',
          name: srvName,
          price: price,
          isEnabled: isActive,
          pricingUnit: AdditionalServiceUnit.fromString(rawUnit),
          description: rawDesc,
          createdAt: rowTime ?? DateTime.now(),
          updatedAt: rowTime ?? DateTime.now(),
        );
        if (addIdx != -1) {
          updatedAdd[addIdx] = addSrv;
        } else {
          updatedAdd.add(addSrv);
        }
      }

      final updatedPricing = current.copyWith(
        printingPrices: printing,
        bindingTypes: bindings,
        laminationTypes: laminations,
        configItems: updatedConfig,
        additionalServices: updatedAdd,
        updatedAt: rowTime ?? DateTime.now(),
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

      final srvRes = await client
          .from('services')
          .select()
          .timeout(const Duration(seconds: 4));
      for (final row in srvRes) {
        _handleRemoteServiceRow(row);
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
                  (b) =>
                      b.id == 'bind_spiral' ||
                      b.name.toLowerCase().contains('spiral'),
                  orElse: () => const BindingTypeItem(
                    id: 'bind_spiral',
                    name: 'Spiral',
                    price: 30.0,
                  ),
                )
                .price,
            'hard_binding': newPricing.bindingTypes
                .firstWhere(
                  (b) =>
                      b.id == 'bind_hard' ||
                      b.name.toLowerCase().contains('hard'),
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
          final List<Map<String, dynamic>> servicesList = [
            {
              'shop_id': 'campus-xerox',
              'service_name': 'B&W Single Side',
              'description': 'printing',
              'price': newPricing.printingPrices.bwSinglePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'shop_id': 'campus-xerox',
              'service_name': 'B&W Double Side',
              'description': 'printing',
              'price': newPricing.printingPrices.bwDoublePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'shop_id': 'campus-xerox',
              'service_name': 'Color Single Side',
              'description': 'printing',
              'price': newPricing.printingPrices.colorSinglePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'shop_id': 'campus-xerox',
              'service_name': 'Color Double Side',
              'description': 'printing',
              'price': newPricing.printingPrices.colorDoublePerSheet,
              'pricing_unit': 'per_page',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
          ];

          // Add all dynamic configItems (Paper Types, GSM, Binding, Finishing, Additional Services)
          for (final item in newPricing.configItems) {
            String unit = 'per_item';
            if (item.category == 'paperType' || item.category == 'gsm') {
              unit = 'per_sheet';
            } else if (item.category == 'additionalService') {
              unit = 'per_order';
            }
            servicesList.add({
              'shop_id': 'campus-xerox',
              'service_name': item.name,
              'description': item.category,
              'price': item.price,
              'pricing_unit': unit,
              'is_active': item.enabled,
              'updated_at': item.updatedAt.toIso8601String(),
            });
          }

          // Any additionalServices not already in configItems
          for (final add in newPricing.additionalServices) {
            if (!servicesList.any(
              (s) =>
                  s['service_name'].toString().toLowerCase().trim() ==
                  add.name.toLowerCase().trim(),
            )) {
              servicesList.add({
                'shop_id': 'campus-xerox',
                'service_name': add.name,
                'description': 'additionalService',
                'price': add.price,
                'pricing_unit': add.pricingUnit.name,
                'is_active': add.isEnabled,
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          }

          for (final srv in servicesList) {
            final srvName = srv['service_name'] as String;
            // 1. Try updating existing service by matching service_name (compatible with UUID primary key)
            final updateRes = await client
                .from('services')
                .update({
                  'price': srv['price'],
                  'description': srv['description'],
                  'pricing_unit': srv['pricing_unit'],
                  'is_active': srv['is_active'],
                  'updated_at': srv['updated_at'],
                })
                .ilike('service_name', srvName)
                .select();

            // 2. If no record was found, insert so PostgreSQL auto-generates UUID
            if (updateRes.isEmpty) {
              await client.from('services').insert(srv);
            }
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
    String? originalFileName,
    String? pageSelection,
    bool isDeletedFromQueue = false,
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
      originalFileName: originalFileName,
      pageSelection: pageSelection,
      isDeletedFromQueue: isDeletedFromQueue,
    );

    // 2. Sync to Supabase PostgreSQL table
    final client = _client;
    if (client != null) {
      final ordersList = allOrdersDirect;
      final matching = ordersList.where((o) => o.id == orderId).firstOrNull;
      var code = matching?.code ?? newCode();
      bool inserted = false;
      int attempts = 0;

      while (!inserted && attempts < 5) {
        attempts++;
        try {
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
            'paper_type_name': paperTypeName,
            'gsm_name': gsmName,
            'binding_name': bindingName,
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
            'color_page_numbers':
                colorPageNumbers ??
                (color ? List.generate(pages, (i) => i + 1) : <int>[]),
            'page_settings': (pageSettings ?? const [])
                .whereType<PagePrintSetting>()
                .map((s) => s.toMap())
                .toList(),
            'original_file_name': originalFileName,
            'page_selection': pageSelection,
            'is_deleted_from_queue': isDeletedFromQueue,
            'is_deleted_by_student': false,
          });
          inserted = true;
          debugPrint(
            'Print order $code ($orderId) successfully saved to Supabase!',
          );
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('23505') ||
              errStr.contains('unique') ||
              errStr.contains('active_code')) {
            debugPrint(
              'Order code $code collision detected, retrying with new 4-digit code...',
            );
            code = newCode();
            final current = allOrdersDirect
                .where((o) => o.id == orderId)
                .firstOrNull;
            if (current != null) {
              updateOrderLocally(current.copyWith(code: code));
            }
            continue;
          }
          debugPrint('Supabase order insert error: $e');
          if (isSupabaseLive) {
            throw Exception(
              'Failed to save order to Supabase cloud. Please verify your connection or database schema. Error: $e',
            );
          }
          break;
        }
      }
    }

    return orderId;
  }

  /// Update print order status, payment status & reference in Supabase
  @override
  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    final client = _client;
    if (client != null) {
      final pgUpdates = <String, dynamic>{};
      if (updates.containsKey('status')) {
        pgUpdates['status'] = updates['status'];
      }
      if (updates.containsKey('paymentStatus') ||
          updates.containsKey('payment_status')) {
        pgUpdates['payment_status'] =
            updates['paymentStatus'] ?? updates['payment_status'];
      }
      if (updates.containsKey('paymentMode') ||
          updates.containsKey('payment_mode')) {
        pgUpdates['payment_mode'] =
            updates['paymentMode'] ?? updates['payment_mode'];
      }
      if (updates.containsKey('paymentMethod') ||
          updates.containsKey('payment_method')) {
        pgUpdates['payment_method'] =
            updates['paymentMethod'] ?? updates['payment_method'];
      }
      if (updates.containsKey('transactionReference') ||
          updates.containsKey('transaction_reference')) {
        pgUpdates['transaction_reference'] =
            updates['transactionReference'] ?? updates['transaction_reference'];
      }
      if (updates.containsKey('paidAt') || updates.containsKey('paid_at')) {
        final val = updates['paidAt'] ?? updates['paid_at'];
        pgUpdates['paid_at'] = val is DateTime ? val.toIso8601String() : val;
      }
      if (updates.containsKey('isDownloaded') ||
          updates.containsKey('is_downloaded')) {
        pgUpdates['is_downloaded'] =
            updates['isDownloaded'] ?? updates['is_downloaded'];
      }
      if (updates.containsKey('isPurged') || updates.containsKey('is_purged')) {
        final purgedVal = updates['isPurged'] ?? updates['is_purged'];
        pgUpdates['is_purged'] = purgedVal;
        if (purgedVal == true) {
          pgUpdates['is_deleted_from_queue'] = true;
          pgUpdates['file_url'] = '';
        }
      }
      if (updates.containsKey('fileUrl') || updates.containsKey('file_url')) {
        pgUpdates['file_url'] = updates['fileUrl'] ?? updates['file_url'] ?? '';
      }
      if (updates.containsKey('completedAt') ||
          updates.containsKey('completed_at')) {
        final val = updates['completedAt'] ?? updates['completed_at'];
        pgUpdates['completed_at'] = val is DateTime
            ? val.toIso8601String()
            : val;
      }
      if (updates.containsKey('isDeletedFromQueue') ||
          updates.containsKey('is_deleted_from_queue')) {
        final delVal =
            updates['isDeletedFromQueue'] ?? updates['is_deleted_from_queue'];
        pgUpdates['is_deleted_from_queue'] = delVal;
        if (delVal == true) {
          pgUpdates['is_purged'] = true;
          pgUpdates['file_url'] = '';
        }
      }
      if (updates.containsKey('originalFileName') ||
          updates.containsKey('original_file_name')) {
        pgUpdates['original_file_name'] =
            updates['originalFileName'] ?? updates['original_file_name'];
      }
      if (updates.containsKey('pageSelection') ||
          updates.containsKey('page_selection')) {
        pgUpdates['page_selection'] =
            updates['pageSelection'] ?? updates['page_selection'];
      }
      if (updates.containsKey('isDeletedByStudent') ||
          updates.containsKey('is_deleted_by_student')) {
        pgUpdates['is_deleted_by_student'] =
            updates['isDeletedByStudent'] ?? updates['is_deleted_by_student'];
      }
      if (updates.containsKey('rejectionReason') ||
          updates.containsKey('rejection_reason') ||
          updates.containsKey('cancellationReason') ||
          updates.containsKey('cancellation_reason')) {
        final reason =
            updates['rejectionReason'] ??
            updates['rejection_reason'] ??
            updates['cancellationReason'] ??
            updates['cancellation_reason'];
        pgUpdates['rejection_reason'] = reason;
        pgUpdates['cancellation_reason'] = reason;
      }
      if (updates.containsKey('cancellationBy') ||
          updates.containsKey('cancellation_by')) {
        pgUpdates['cancellation_by'] =
            updates['cancellationBy'] ?? updates['cancellation_by'];
      }
      if (updates.containsKey('refundStatus') ||
          updates.containsKey('refund_status')) {
        pgUpdates['refund_status'] =
            updates['refundStatus'] ?? updates['refund_status'];
      }
      if (updates.containsKey('removalReason') ||
          updates.containsKey('removal_reason')) {
        pgUpdates['removal_reason'] =
            updates['removalReason'] ?? updates['removal_reason'];
      }
      if (updates.containsKey('removedAt') ||
          updates.containsKey('removed_at')) {
        final val = updates['removedAt'] ?? updates['removed_at'];
        pgUpdates['removed_at'] = val is DateTime ? val.toIso8601String() : val;
      }
      if (updates.containsKey('removedBy') ||
          updates.containsKey('removed_by')) {
        pgUpdates['removed_by'] = updates['removedBy'] ?? updates['removed_by'];
      }

      if (pgUpdates.isNotEmpty) {
        try {
          await client.from('print_orders').update(pgUpdates).eq('id', orderId);
        } catch (e) {
          debugPrint('Supabase update order error: $e');
          if (isSupabaseLive) {
            rethrow;
          }
        }
      }
    }

    // After Supabase remote persistence succeeds (or in offline mode), update local state & emit
    await super.updateOrder(orderId, updates);
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

  /// Lookup order by collection code strictly restricted to shopkeeper
  @override
  Future<PrintOrder?> findByCode(
    String code, {
    bool isShopkeeper = true,
  }) async {
    if (!isShopkeeper) return null;
    final needle = code.trim();
    final client = _client;
    if (client != null) {
      try {
        final res = await client.rpc(
          'lookup_order_by_code',
          params: {'p_code': needle},
        );
        if (res != null && (res as List).isNotEmpty) {
          final row = res.first as Map<String, dynamic>;
          final order = PrintOrder.fromMap(row['id'] as String, row);
          updateOrderLocally(order);
          return order;
        }
      } catch (e) {
        try {
          final res = await client
              .from('print_orders')
              .select()
              .eq('code', needle)
              .limit(1);
          if (res.isNotEmpty) {
            final row = res.first;
            final order = PrintOrder.fromMap(row['id'] as String, row);
            updateOrderLocally(order);
            return order;
          }
        } catch (_) {}
      }
    }
    return super.findByCode(code, isShopkeeper: isShopkeeper);
  }
}
