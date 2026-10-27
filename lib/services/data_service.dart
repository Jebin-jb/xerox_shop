import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import 'firebase_payment_config_service.dart';
import 'supabase_config.dart';

class DataService {
  final _pricesController = StreamController<ShopPrice>.broadcast();
  final _livePricingController = StreamController<LiveShopPricing>.broadcast();
  final _paymentAccountController =
      StreamController<ShopPaymentAccount>.broadcast();
  final _ordersController = StreamController<List<PrintOrder>>.broadcast();
  final _expensesController = StreamController<List<ExpenseEntry>>.broadcast();

  LiveShopPricing _livePricing = LiveShopPricing.defaultPricing();
  ShopPaymentAccount _paymentAccount = ShopPaymentAccount.empty();

  ShopPrice _prices = ShopPrice(
    bwSingle: 1.0,
    bwDouble: 1.5,
    colorSingle: 5.0,
    colorDouble: 8.0,
    photocopy: 1.0,
    paper75Gsm: 0.0,
    paper100Gsm: 1.5,
    paperGlossy: 10.0,
    spiralBinding: 30.0,
    hardBinding: 150.0,
    lamination: 10.0,
    updatedAt: DateTime.now(),
  );
  final Map<String, PrintOrder> _orders = {};
  final Map<String, ExpenseEntry> _expenses = {};
  StreamSubscription? _remotePricingSub;
  StreamSubscription? _remoteAccountSub;
  StreamSubscription? _remoteOrdersSub;
  StreamSubscription? _remoteExpensesSub;
  Future<void>? _initFuture;

  DataService() {
    _initFuture = _init();
  }

  Future<void> ensureInitialized() => _initFuture ??= _init();

  List<PrintOrder> get allOrdersDirect => _orders.values.toList();
  ShopPrice get currentPrices => _prices;
  LiveShopPricing get currentLivePricing => _livePricing;
  ShopPaymentAccount get currentPaymentAccount => _paymentAccount;

  Future<void> _init() async {
    await _loadFromDisk();
    // Clean out any legacy mock demo orders from previous sessions
    _orders.removeWhere((id, o) => id.startsWith('ord_'));
    _expenses.removeWhere((id, e) => id.startsWith('exp_'));

    _emitPrices();
    _emitLivePricing();
    _emitPaymentAccount();
    _emitOrders();
    _emitExpenses();

    // Sync with Firebase Firestore in real-time
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    try {
      _remotePricingSub = FirebasePaymentConfigService.instance
          .streamLivePricing()
          .listen(
            (remotePricing) {
              _livePricing = remotePricing;
              _prices = remotePricing.toShopPrice();
              _emitPrices();
              _emitLivePricing();
              _saveToDisk();
            },
            onError: (err) {
              debugPrint('Firestore remote pricing stream error: $err');
            },
          );

      _remoteAccountSub = FirebasePaymentConfigService.instance
          .streamPaymentAccount()
          .listen(
            (remoteAccount) {
              _paymentAccount = remoteAccount;
              _emitPaymentAccount();
              _saveToDisk();
            },
            onError: (err) {
              debugPrint('Firestore remote account stream error: $err');
            },
          );

      // Real-time synchronization for orders across all devices (fallback when Supabase is not active)
      _remoteOrdersSub = FirebasePaymentConfigService.instance
          .streamOrders()
          .listen(
            (remoteOrders) {
              if (SupabaseConfig.isConfigured) {
                // Supabase is the primary database; ignore stale Firestore order overwrites
                return;
              }
              // Replace orders map with real Cloud Firestore state
              _orders.clear();
              for (final o in remoteOrders) {
                _orders[o.id] = o;
              }
              _emitOrders();
              _saveToDisk();
            },
            onError: (err) {
              debugPrint('Firestore remote orders stream error: $err');
            },
          );

      // Real-time synchronization for shopkeeper expenses across devices
      _remoteExpensesSub = FirebasePaymentConfigService.instance
          .streamExpenses()
          .listen(
            (remoteExpenses) {
              _expenses.clear();
              for (final e in remoteExpenses) {
                _expenses[e.id] = e;
              }
              _emitExpenses();
              _saveToDisk();
            },
            onError: (err) {
              debugPrint('Firestore remote expenses stream error: $err');
            },
          );
    } catch (e) {
      debugPrint('Firestore sync initialization error: $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final livePricingJson = prefs.getString('shop_live_pricing');
      if (livePricingJson != null) {
        _livePricing = LiveShopPricing.fromMap(jsonDecode(livePricingJson));
        _prices = _livePricing.toShopPrice();
      } else {
        final pricesJson = prefs.getString('shop_prices');
        if (pricesJson != null) {
          _prices = ShopPrice.fromMap(jsonDecode(pricesJson));
        }
      }

      final accountJson = prefs.getString('shop_payment_account');
      if (accountJson != null) {
        _paymentAccount = ShopPaymentAccount.fromMap(jsonDecode(accountJson));
      }

      final ordersJson = prefs.getString('shop_orders');
      if (ordersJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(ordersJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _orders[key] = PrintOrder.fromMap(
              key,
              Map<String, dynamic>.from(value),
            );
          }
        });
      }

      final expensesJson = prefs.getString('shop_expenses');
      if (expensesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(expensesJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _expenses[key] = ExpenseEntry.fromMap(
              key,
              Map<String, dynamic>.from(value),
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'shop_live_pricing',
        jsonEncode(_livePricing.toMap()),
      );
      await prefs.setString('shop_prices', jsonEncode(_prices.toMap()));
      await prefs.setString(
        'shop_payment_account',
        jsonEncode(_paymentAccount.toMap()),
      );

      final ordersMap = <String, dynamic>{};
      _orders.forEach((key, val) => ordersMap[key] = val.toMap());
      await prefs.setString('shop_orders', jsonEncode(ordersMap));

      final expensesMap = <String, dynamic>{};
      _expenses.forEach((key, val) => expensesMap[key] = val.toMap());
      await prefs.setString('shop_expenses', jsonEncode(expensesMap));
    } catch (_) {}
  }

  void _emitPrices() => _pricesController.add(_prices);
  void _emitLivePricing() => _livePricingController.add(_livePricing);
  void _emitPaymentAccount() => _paymentAccountController.add(_paymentAccount);
  void _emitOrders() => _ordersController.add(
    List.unmodifiable(
      _orders.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    ),
  );
  void _emitExpenses() => _expensesController.add(
    List.unmodifiable(
      _expenses.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    ),
  );

  Stream<ShopPrice> prices() async* {
    yield _prices;
    yield* _pricesController.stream;
  }

  Stream<LiveShopPricing> livePricing() async* {
    yield _livePricing;
    yield* _livePricingController.stream;
  }

  Stream<ShopPaymentAccount> paymentAccount() async* {
    yield _paymentAccount;
    yield* _paymentAccountController.stream;
  }

  Stream<List<PrintOrder>> allOrders() async* {
    yield List.unmodifiable(
      _orders.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    yield* _ordersController.stream;
  }

  Stream<PrintOrder?> order(String orderId) {
    return allOrders().map((orders) {
      final matching = orders.where((o) => o.id == orderId);
      return matching.isEmpty ? null : matching.first;
    });
  }

  Stream<List<PrintOrder>> studentOrders(String studentId) {
    return allOrders().map(
      (orders) => orders
          .where((o) => o.studentId == studentId && !o.isDeletedByStudent)
          .toList(),
    );
  }

  Future<void> softDeleteOrderForStudent(String orderId) async {
    await updateOrder(orderId, {
      'isDeletedByStudent': true,
      'is_deleted_by_student': true,
    });
  }

  Stream<List<ExpenseEntry>> expenses() async* {
    yield List.unmodifiable(
      _expenses.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    yield* _expensesController.stream;
  }

  void updateOrderLocally(PrintOrder order) {
    _orders[order.id] = order;
    _emitOrders();
    _saveToDisk();
  }

  void removeOrderLocally(String id) {
    _orders.remove(id);
    _emitOrders();
    _saveToDisk();
  }

  void clearOrdersForTesting() {
    _orders.clear();
    _emitOrders();
  }

  Future<void> refreshOrders() async {}

  Future<LiveShopPricing> refreshPricingFromFirestore() async {
    try {
      final remote = await FirebasePaymentConfigService.instance
          .getLivePricing();
      if (remote != null) {
        _livePricing = remote;
        _prices = remote.toShopPrice();
        _emitPrices();
        _emitLivePricing();
        await _saveToDisk();
        return remote;
      }
    } catch (e) {
      debugPrint('refreshPricingFromFirestore notice: $e');
    }
    return _livePricing;
  }

  Future<void> updatePrices(ShopPrice newPrices) async {
    final updated = _livePricing.copyWith(
      printingPrices: _livePricing.printingPrices.copyWith(
        bwSinglePerSheet: newPrices.bwSingle,
        bwDoublePerSheet: newPrices.bwDouble,
        colorSinglePerSheet: newPrices.colorSingle,
        colorDoublePerSheet: newPrices.colorDouble,
      ),
      updatedAt: DateTime.now(),
    );
    await updateLivePricing(updated);
  }

  Future<void> updateLivePricing(LiveShopPricing newPricing) async {
    // 1. Immediately update memory and save to persistent local cache (Zero lag, instant UI feedback)
    _livePricing = newPricing;
    _prices = newPricing.toShopPrice();
    _emitPrices();
    _emitLivePricing();
    await _saveToDisk();

    // 2. Sync to Cloud Firestore safely in the background without blocking or hanging
    try {
      await FirebasePaymentConfigService.instance.updateLivePricing(newPricing);
    } catch (e) {
      debugPrint('Firestore updateLivePricing notice: $e');
    }
  }

  Future<void> updatePaymentAccount(ShopPaymentAccount newAccount) async {
    // 1. Immediately update memory and save to local persistent cache
    _paymentAccount = newAccount;
    _emitPaymentAccount();
    await _saveToDisk();

    // 2. Persist to Cloud Firestore safely
    try {
      await FirebasePaymentConfigService.instance.updatePaymentAccount(
        newAccount,
      );
    } catch (e) {
      debugPrint('Firestore updatePaymentAccount notice: $e');
    }
  }

  void updatePaymentAccountLocally(ShopPaymentAccount newAccount) {
    _paymentAccount = newAccount;
    _emitPaymentAccount();
    _saveToDisk();
  }

  void updateLivePricingLocally(LiveShopPricing newPricing) {
    _livePricing = newPricing;
    _prices = newPricing.toShopPrice();
    _emitLivePricing();
    _emitPrices();
    _saveToDisk();
  }

  String newCode() {
    final r = Random.secure();
    String code;
    final activeOrders = _orders.values.where(
      (o) =>
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled &&
          o.status != OrderStatus.rejected &&
          !o.isDeletedFromQueue,
    );
    do {
      final num = r.nextInt(10000);
      code = num.toString().padLeft(4, '0');
    } while (activeOrders.any((o) => o.code == code));
    return code;
  }

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
    final id = 'order_${DateTime.now().microsecondsSinceEpoch}';
    final order = PrintOrder(
      id: id,
      code: newCode(),
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
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      priceSnapshot: priceSnapshot,
      specialInstructions: specialInstructions,
      paperTypeName: paperTypeName,
      gsmName: gsmName,
      bindingName: bindingName,
      bwPageCount: bwPageCount,
      colorPageCount: colorPageCount,
      colorPageNumbers: colorPageNumbers ?? const [],
      pageSettings: pageSettings ?? const [],
      originalFileName: originalFileName,
      pageSelection: pageSelection,
      isDeletedFromQueue: isDeletedFromQueue,
    );
    _orders[id] = order;
    _emitOrders();
    await _saveToDisk();

    // Persist to Cloud Firestore
    try {
      await FirebasePaymentConfigService.instance.saveOrder(order);
    } catch (e) {
      debugPrint('Notice saving order to Firestore: $e');
    }

    return id;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> changes) async {
    final existing = _orders[id];
    if (existing == null) return;

    _orders[id] = existing.copyWith(
      fileUrl: changes.containsKey('fileUrl')
          ? changes['fileUrl']?.toString() ?? ''
          : (changes.containsKey('file_url')
                ? changes['file_url']?.toString() ?? ''
                : existing.fileUrl),
      paymentMode: changes.containsKey('paymentMode')
          ? _enum(
              changes['paymentMode'],
              PaymentMode.values,
              existing.paymentMode,
            )
          : existing.paymentMode,
      paymentStatus: changes.containsKey('paymentStatus')
          ? _enum(
              changes['paymentStatus'],
              PaymentStatus.values,
              existing.paymentStatus,
            )
          : existing.paymentStatus,
      paymentMethod: changes.containsKey('paymentMethod')
          ? changes['paymentMethod']?.toString()
          : existing.paymentMethod,
      transactionReference: changes.containsKey('transactionReference')
          ? changes['transactionReference']?.toString()
          : (changes.containsKey('transactionId')
                ? changes['transactionId']?.toString()
                : existing.transactionReference),
      paidAt: changes.containsKey('paidAt')
          ? (changes['paidAt'] != null
                ? DateTime.tryParse('${changes['paidAt']}')
                : null)
          : (changes.containsKey('paymentTime')
                ? (changes['paymentTime'] != null
                      ? DateTime.tryParse('${changes['paymentTime']}')
                      : null)
                : existing.paidAt),
      status: changes.containsKey('status')
          ? _enum(changes['status'], OrderStatus.values, existing.status)
          : existing.status,
      isDownloaded: changes.containsKey('isDownloaded')
          ? changes['isDownloaded'] == true
          : (changes.containsKey('is_downloaded')
                ? changes['is_downloaded'] == true
                : existing.isDownloaded),
      isPurged: changes.containsKey('isPurged')
          ? changes['isPurged'] == true
          : (changes.containsKey('is_purged')
                ? changes['is_purged'] == true
                : existing.isPurged),
      cancellationReason: changes.containsKey('cancellationReason')
          ? changes['cancellationReason']?.toString()
          : (changes.containsKey('cancellation_reason')
                ? changes['cancellation_reason']?.toString()
                : (changes.containsKey('rejectionReason')
                      ? changes['rejectionReason']?.toString()
                      : (changes.containsKey('rejection_reason')
                            ? changes['rejection_reason']?.toString()
                            : existing.cancellationReason))),
      cancellationBy: changes.containsKey('cancellationBy')
          ? changes['cancellationBy']?.toString()
          : (changes.containsKey('cancellation_by')
                ? changes['cancellation_by']?.toString()
                : existing.cancellationBy),
      refundStatus: changes.containsKey('refundStatus')
          ? changes['refundStatus']?.toString()
          : (changes.containsKey('refund_status')
                ? changes['refund_status']?.toString()
                : existing.refundStatus),
      isDeletedFromQueue: changes.containsKey('isDeletedFromQueue')
          ? changes['isDeletedFromQueue'] == true
          : (changes.containsKey('is_deleted_from_queue')
                ? changes['is_deleted_from_queue'] == true
                : existing.isDeletedFromQueue),
      isDeletedByStudent: changes.containsKey('isDeletedByStudent')
          ? changes['isDeletedByStudent'] == true
          : (changes.containsKey('is_deleted_by_student')
                ? changes['is_deleted_by_student'] == true
                : existing.isDeletedByStudent),
      originalFileName: changes.containsKey('originalFileName')
          ? changes['originalFileName']?.toString()
          : existing.originalFileName,
      pageSelection: changes.containsKey('pageSelection')
          ? changes['pageSelection']?.toString()
          : existing.pageSelection,
      removalReason: changes.containsKey('removalReason')
          ? changes['removalReason']?.toString()
          : (changes.containsKey('removal_reason')
                ? changes['removal_reason']?.toString()
                : existing.removalReason),
      removedAt: changes.containsKey('removedAt')
          ? (changes['removedAt'] is DateTime
                ? changes['removedAt'] as DateTime
                : DateTime.tryParse('${changes['removedAt']}'))
          : (changes.containsKey('removed_at')
                ? (changes['removed_at'] is DateTime
                      ? changes['removed_at'] as DateTime
                      : DateTime.tryParse('${changes['removed_at']}'))
                : existing.removedAt),
      removedBy: changes.containsKey('removedBy')
          ? changes['removedBy']?.toString()
          : (changes.containsKey('removed_by')
                ? changes['removed_by']?.toString()
                : existing.removedBy),
    );
    _emitOrders();
    await _saveToDisk();

    // Update in Cloud Firestore
    try {
      await FirebasePaymentConfigService.instance.updateFirestoreOrder(
        id,
        changes,
      );
    } catch (_) {}
  }

  Future<PrintOrder?> findByCode(
    String code, {
    bool isShopkeeper = true,
  }) async {
    if (!isShopkeeper) return null;
    final needle = code.trim().toUpperCase();
    for (final order in _orders.values) {
      if (order.code.toUpperCase() == needle) return order;
    }
    // Search directly in Cloud Firestore across devices
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('code', isEqualTo: needle)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final order = PrintOrder.fromMap(doc.id, doc.data());
        _orders[order.id] = order;
        _emitOrders();
        return order;
      }
    } catch (e) {
      debugPrint('Firestore findByCode notice: $e');
    }
    return null;
  }

  Future<void> addExpense(
    String title,
    double amount,
    String category, [
    DateTime? date,
  ]) async {
    final id = 'exp_${DateTime.now().microsecondsSinceEpoch}';
    final entry = ExpenseEntry(
      id: id,
      title: title,
      amount: amount,
      category: category,
      createdAt: date ?? DateTime.now(),
    );
    _expenses[id] = entry;
    _emitExpenses();
    await _saveToDisk();

    try {
      await FirebasePaymentConfigService.instance.saveExpense(entry);
    } catch (e) {
      debugPrint('Firestore saveExpense notice: $e');
    }
  }

  static T _enum<T extends Enum>(dynamic val, List<T> values, T fallback) {
    if (val == null) return fallback;
    if (val is T && values.contains(val)) return val;
    final rawStr = val.toString().trim();
    if (rawStr.isEmpty) return fallback;
    final clean = rawStr.contains('.') ? rawStr.split('.').last : rawStr;
    final strLower = clean.toLowerCase();
    for (final item in values) {
      if (item.name.toLowerCase() == strLower) return item;
    }
    if (T == PaymentStatus) {
      final s = strLower.replaceAll('_', '').replaceAll('-', '');
      if (s == 'unpaid') return PaymentStatus.unpaid as T;
      if (s == 'refundpending' || s == 'refundinitiated') {
        return PaymentStatus.refund_initiated as T;
      }
      if (s == 'verificationpending' || s == 'submitted') {
        return PaymentStatus.payment_submitted as T;
      }
      if (s == 'paid') {
        return PaymentStatus.paid as T;
      }
      if (s == 'canceled' || s == 'cancelled') {
        return PaymentStatus.cancelled as T;
      }
    }
    return fallback;
  }

  void dispose() {
    _remotePricingSub?.cancel();
    _remoteAccountSub?.cancel();
    _remoteOrdersSub?.cancel();
    _remoteExpensesSub?.cancel();
    _pricesController.close();
    _livePricingController.close();
    _paymentAccountController.close();
    _ordersController.close();
    _expensesController.close();
  }
}
