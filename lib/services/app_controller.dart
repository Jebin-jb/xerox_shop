import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _seedDemoData();
  }

  UserRole _role = UserRole.student;
  String studentName = 'Krishna Sharma';
  String studentId = 'CSE26A001';

  ShopPrice prices = ShopPrice(
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

  final List<PrintOrder> _orders = [];
  final List<ExpenseEntry> _expenses = [];

  UserRole get role => _role;
  List<PrintOrder> get allOrders => List.unmodifiable(_orders);
  List<PrintOrder> get studentOrders => List.unmodifiable(
    _orders.where((o) => o.studentId == studentId).toList(),
  );
  List<ExpenseEntry> get expenses => List.unmodifiable(_expenses);

  double get totalRevenue => _orders
      .where(
        (o) =>
            o.paymentStatus == PaymentStatus.paid &&
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.rejected,
      )
      .fold(0.0, (sum, o) => sum + o.total);

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  double get netProfit => totalRevenue - totalExpenses;

  void switchRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void updatePrices(ShopPrice next) {
    prices = next;
    notifyListeners();
  }

  double calculateTotal({
    required int pages,
    required int copies,
    required bool color,
    required bool doubleSided,
    required bool lamination,
    required bool binding,
  }) {
    final printTotal =
        pages *
        copies *
        prices.priceFor(color: color, doubleSided: doubleSided);
    final extras =
        (lamination ? prices.lamination : 0.0) +
        (binding ? prices.binding : 0.0);
    return printTotal + extras;
  }

  PrintOrder createOrder({
    required String fileName,
    required int pages,
    required int copies,
    required bool color,
    required bool doubleSided,
    required bool lamination,
    required bool binding,
    required PaymentMode paymentMode,
  }) {
    final total = calculateTotal(
      pages: pages,
      copies: copies,
      color: color,
      doubleSided: doubleSided,
      lamination: lamination,
      binding: binding,
    );
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final code = _makeCode(id);
    final order = PrintOrder(
      id: id,
      code: code,
      studentName: studentName,
      studentId: studentId,
      fileName: fileName,
      fileUrl: '',
      pages: pages,
      copies: copies,
      color: color,
      doubleSided: doubleSided,
      lamination: lamination,
      binding: binding,
      total: total,
      paymentMode: paymentMode,
      paymentStatus: PaymentStatus.unpaid,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  void updateOrderStatus(String id, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(status: status);
    notifyListeners();
  }

  void receiveCounterPayment(String id) {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    final order = _orders[index];
    _orders[index] = order.copyWith(paymentStatus: PaymentStatus.paid);
    notifyListeners();
  }

  void cancelByStudent(String id) {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    final order = _orders[index];
    if (!order.studentCanCancel) return;
    final nextPayment = order.paymentMode == PaymentMode.online
        ? PaymentStatus.refundPending
        : PaymentStatus.unpaid;
    _orders[index] = order.copyWith(
      status: OrderStatus.cancelled,
      paymentStatus: nextPayment,
      cancellationReason: 'Cancelled by student',
    );
    notifyListeners();
  }

  void rejectByShopkeeper(String id, String reason) {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    final order = _orders[index];
    if (order.status != OrderStatus.pending) return;
    _orders[index] = order.copyWith(
      status: OrderStatus.rejected,
      paymentStatus: order.paymentMode == PaymentMode.online
          ? PaymentStatus.refundPending
          : PaymentStatus.unpaid,
      cancellationReason: reason,
    );
    notifyListeners();
  }

  void addExpense({
    required String category,
    required String description,
    required double amount,
  }) {
    _expenses.insert(
      0,
      ExpenseEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: category,
        description: description,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  PrintOrder? findByCode(String code) {
    try {
      return _orders.firstWhere(
        (o) => o.code.toUpperCase() == code.trim().toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _makeCode(String source) {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var value = source.hashCode.abs();
    final result = StringBuffer();
    for (var i = 0; i < 6; i++) {
      result.write(chars[value % chars.length]);
      value ~/= chars.length;
      value = value + source.codeUnitAt(i % source.length) * (i + 7);
    }
    return result.toString();
  }

  void _seedDemoData() {
    final now = DateTime.now();
    _orders.addAll([
      PrintOrder(
        id: 'demo1',
        code: 'X7K29P',
        studentName: 'Aarav Kumar',
        studentId: 'CSE26A014',
        fileName: 'OS_Assignment.pdf',
        fileUrl: '',
        pages: 18,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: true,
        total: 48.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      PrintOrder(
        id: 'demo2',
        code: 'M4P8QZ',
        studentName: 'Priya Patel',
        studentId: 'ECE26B022',
        fileName: 'Record_Notebook.pdf',
        fileUrl: '',
        pages: 10,
        copies: 2,
        color: true,
        doubleSided: false,
        lamination: false,
        binding: false,
        total: 100.0,
        paymentMode: PaymentMode.counter,
        paymentStatus: PaymentStatus.unpaid,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      PrintOrder(
        id: 'demo3',
        code: 'R2D4XK',
        studentName: 'Krishna Sharma',
        studentId: 'CSE26A001',
        fileName: 'MiniProject_Final.pdf',
        fileUrl: '',
        pages: 24,
        copies: 1,
        color: false,
        doubleSided: true,
        lamination: false,
        binding: false,
        total: 36.0,
        paymentMode: PaymentMode.online,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    _expenses.addAll([
      ExpenseEntry(
        id: 'e1',
        category: 'Paper',
        description: 'A4 paper bundle 500 sheets',
        amount: 500.0,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ExpenseEntry(
        id: 'e2',
        category: 'Toner',
        description: 'Black toner cartridge refill',
        amount: 850.0,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ]);
  }
}
