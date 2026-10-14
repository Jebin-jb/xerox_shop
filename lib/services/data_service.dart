import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import 'firebase_payment_config_service.dart';

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
    if (_orders.isEmpty) {
      _seedSampleData();
      await _saveToDisk();
    }
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
      (orders) => orders.where((o) => o.studentId == studentId).toList(),
    );
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
  }

  void _seedSampleData() {
    final now = DateTime.now();
    final sampleOrders = [
      PrintOrder(
        id: 'ord_1',
        code: 'A9K7M2',
        studentId: 'student_demo_1',
        studentName: 'Krishna Sharma',
        studentEmail: 'student@college.ac.in',
        fileName: 'Compiler_Design_Notes.pdf',
        fileUrl: 'secure://vault/sample1/Compiler_Design_Notes.pdf',
        fileSizeBytes: 4200000,
        pages: 32,
        copies: 1,
        color: false,
        doubleSided: true,
        lamination: false,
        binding: true,
        total: 54.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      PrintOrder(
        id: 'ord_2',
        code: 'P4X9L1',
        studentId: 'student_2',
        studentName: 'Aarav Kumar',
        studentEmail: 'aarav.kumar@college.ac.in',
        fileName: 'Project_Report_Final.pdf',
        fileUrl: 'secure://vault/sample2/Project_Report_Final.pdf',
        fileSizeBytes: 18500000,
        pages: 45,
        copies: 2,
        color: true,
        doubleSided: false,
        lamination: true,
        binding: true,
        total: 520.0,
        paymentMode: PaymentMode.counter,
        paymentStatus: PaymentStatus.unpaid,
        status: OrderStatus.printing,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      PrintOrder(
        id: 'ord_3',
        code: 'H2W8N5',
        studentId: 'student_3',
        studentName: 'Priya Patel',
        studentEmail: 'priya.patel@college.ac.in',
        fileName: 'Lab_Manual_EE204.pdf',
        fileUrl: 'secure://vault/sample3/Lab_Manual_EE204.pdf',
        fileSizeBytes: 2400000,
        pages: 14,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 14.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      PrintOrder(
        id: 'ord_4',
        code: 'C7V3B9',
        studentId: 'student_demo_1',
        studentName: 'Krishna Sharma',
        studentEmail: 'student@college.ac.in',
        fileName: 'ID_Card_Govt_Form.jpg',
        fileUrl: 'secure://vault/sample4/ID_Card_Govt_Form.jpg',
        fileSizeBytes: 1200000,
        pages: 1,
        copies: 3,
        color: true,
        doubleSided: false,
        lamination: true,
        binding: false,
        total: 45.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    for (final o in sampleOrders) {
      _orders[o.id] = o;
    }

    final sampleExpenses = [
      ExpenseEntry(
        id: 'exp_1',
        title: 'JK Copier A4 Paper 75 GSM (10 Bundles)',
        amount: 2800.0,
        category: 'Paper',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ExpenseEntry(
        id: 'exp_2',
        title: 'HP 88A Black Toner Cartridge Refill',
        amount: 650.0,
        category: 'Toner',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      ExpenseEntry(
        id: 'exp_3',
        title: 'Spiral Binding Coils (Box of 100)',
        amount: 420.0,
        category: 'Binding Material',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    ];

    for (final e in sampleExpenses) {
      _expenses[e.id] = e;
    }
  }

  Future<LiveShopPricing> refreshPricingFromFirestore() async {
    try {
      final remote =
          await FirebasePaymentConfigService.instance.getLivePricing();
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
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final r = Random.secure();
    String code;
    do {
      final letter = letters[r.nextInt(letters.length)];
      final num = 100 + r.nextInt(900);
      code = 'CP-$letter$num';
    } while (_orders.values.any((o) => o.code == code));
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
          : existing.isDownloaded,
      isPurged: changes.containsKey('isPurged')
          ? changes['isPurged'] == true
          : existing.isPurged,
      cancellationReason: changes.containsKey('cancellationReason')
          ? changes['cancellationReason']?.toString()
          : existing.cancellationReason,
      cancellationBy: changes.containsKey('cancellationBy')
          ? changes['cancellationBy']?.toString()
          : existing.cancellationBy,
      refundStatus: changes.containsKey('refundStatus')
          ? changes['refundStatus']?.toString()
          : existing.refundStatus,
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

  Future<PrintOrder?> findByCode(String code) async {
    final needle = code.trim().toUpperCase();
    for (final order in _orders.values) {
      if (order.code == needle) return order;
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
  }

  static T _enum<T extends Enum>(dynamic val, List<T> values, T fallback) {
    if (val == null) return fallback;
    final str = val.toString();
    for (final item in values) {
      if (item.name == str) return item;
    }
    if (T == PaymentStatus) {
      if (str == 'refundPending') return PaymentStatus.refund_initiated as T;
      if (str == 'verificationPending') {
        return PaymentStatus.verification_pending as T;
      }
      if (str == 'canceled') return PaymentStatus.cancelled as T;
    }
    return fallback;
  }

  void dispose() {
    _remotePricingSub?.cancel();
    _remoteAccountSub?.cancel();
    _pricesController.close();
    _livePricingController.close();
    _paymentAccountController.close();
    _ordersController.close();
    _expensesController.close();
  }
}
