import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class DataService {
  final _pricesController = StreamController<ShopPrice>.broadcast();
  final _ordersController = StreamController<List<PrintOrder>>.broadcast();
  final _expensesController = StreamController<List<ExpenseEntry>>.broadcast();

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

  DataService() {
    _init();
  }

  List<PrintOrder> get allOrdersDirect => _orders.values.toList();
  ShopPrice get currentPrices => _prices;

  Future<void> _init() async {
    await _loadFromDisk();
    if (_orders.isEmpty) {
      _seedSampleData();
      await _saveToDisk();
    }
    _emitPrices();
    _emitOrders();
    _emitExpenses();
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pricesJson = prefs.getString('shop_prices');
      if (pricesJson != null) {
        _prices = ShopPrice.fromMap(jsonDecode(pricesJson));
      }

      final ordersJson = prefs.getString('shop_orders');
      if (ordersJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(ordersJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _orders[key] = PrintOrder.fromMap(key, Map<String, dynamic>.from(value));
          }
        });
      }

      final expensesJson = prefs.getString('shop_expenses');
      if (expensesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(expensesJson);
        decoded.forEach((key, value) {
          if (value is Map) {
            _expenses[key] = ExpenseEntry.fromMap(key, Map<String, dynamic>.from(value));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_prices', jsonEncode(_prices.toMap()));

      final ordersMap = <String, dynamic>{};
      _orders.forEach((key, val) => ordersMap[key] = val.toMap());
      await prefs.setString('shop_orders', jsonEncode(ordersMap));

      final expensesMap = <String, dynamic>{};
      _expenses.forEach((key, val) => expensesMap[key] = val.toMap());
      await prefs.setString('shop_expenses', jsonEncode(expensesMap));
    } catch (_) {}
  }

  void _emitPrices() => _pricesController.add(_prices);
  void _emitOrders() =>
      _ordersController.add(List.unmodifiable(_orders.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt))));
  void _emitExpenses() =>
      _expensesController.add(List.unmodifiable(_expenses.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt))));

  Stream<ShopPrice> prices() async* {
    yield _prices;
    yield* _pricesController.stream;
  }

  Stream<List<PrintOrder>> allOrders() async* {
    yield List.unmodifiable(_orders.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
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
    yield List.unmodifiable(_expenses.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
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

  Future<void> updatePrices(ShopPrice newPrices) async {
    _prices = newPrices;
    _emitPrices();
    await _saveToDisk();
  }

  String newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    String code;
    do {
      code = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
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
      paymentStatus: paymentStatus != PaymentStatus.unpaid
          ? paymentStatus
          : (paymentMode == PaymentMode.online ? PaymentStatus.paid : PaymentStatus.unpaid),
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    _orders[id] = order;
    _emitOrders();
    await _saveToDisk();
    return id;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> changes) async {
    final existing = _orders[id];
    if (existing == null) return;

    _orders[id] = existing.copyWith(
      paymentStatus: changes.containsKey('paymentStatus')
          ? _enum(changes['paymentStatus'], PaymentStatus.values, existing.paymentStatus)
          : existing.paymentStatus,
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
    );
    _emitOrders();
    await _saveToDisk();
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
    for (final item in values) {
      if (item.name == val.toString()) return item;
    }
    return fallback;
  }

  void dispose() {
    _pricesController.close();
    _ordersController.close();
    _expensesController.close();
  }
}
