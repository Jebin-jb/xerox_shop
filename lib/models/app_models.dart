enum UserRole { student, shopkeeper }
enum PaymentMode { online, counter }
enum PaymentStatus { unpaid, paid, failed, refundPending, refunded }
enum OrderStatus { pending, accepted, printing, ready, completed, cancelled, rejected }
enum PaperType { standard75Gsm, executive100Gsm, glossyPhoto }
enum BindingType { none, staple, spiral, hardCover }

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  final String studentId;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.studentId,
  });

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) => UserProfile(
        id: id,
        name: (data['name'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        role: (data['role'] ?? 'student').toString(),
        studentId: (data['studentId'] ?? data['student_id'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'studentId': studentId,
      };

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? studentId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
    );
  }
}

class ShopPrice {
  final double bwSingle;
  final double bwDouble;
  final double colorSingle;
  final double colorDouble;
  final double photocopy;
  final double paper75Gsm;
  final double paper100Gsm;
  final double paperGlossy;
  final double spiralBinding;
  final double hardBinding;
  final double lamination;
  final DateTime updatedAt;

  const ShopPrice({
    required this.bwSingle,
    required this.bwDouble,
    required this.colorSingle,
    required this.colorDouble,
    required this.photocopy,
    this.paper75Gsm = 0.0,
    this.paper100Gsm = 1.5,
    this.paperGlossy = 10.0,
    double? spiralBinding,
    double? binding,
    this.hardBinding = 150.0,
    required this.lamination,
    required this.updatedAt,
  }) : spiralBinding = spiralBinding ?? binding ?? 30.0;

  double get binding => spiralBinding;

  factory ShopPrice.fromMap(Map<String, dynamic> d) => ShopPrice(
        bwSingle: _double(d['bwSingle'] ?? d['bw_single'], 1.0),
        bwDouble: _double(d['bwDouble'] ?? d['bw_double'], 1.5),
        colorSingle: _double(d['colorSingle'] ?? d['color_single'], 5.0),
        colorDouble: _double(d['colorDouble'] ?? d['color_double'], 8.0),
        photocopy: _double(d['photocopy'], 1.0),
        paper75Gsm: _double(d['paper75Gsm'] ?? d['paper_75_gsm'], 0.0),
        paper100Gsm: _double(d['paper100Gsm'] ?? d['paper_100_gsm'], 1.5),
        paperGlossy: _double(d['paperGlossy'] ?? d['paper_glossy'], 10.0),
        spiralBinding: _double(d['spiralBinding'] ?? d['spiral_binding'] ?? d['binding'], 30.0),
        hardBinding: _double(d['hardBinding'] ?? d['hard_binding'], 150.0),
        lamination: _double(d['lamination'], 10.0),
        updatedAt: _date(d['updatedAt'] ?? d['updated_at']),
      );

  Map<String, dynamic> toMap() => {
        'bwSingle': bwSingle,
        'bwDouble': bwDouble,
        'colorSingle': colorSingle,
        'colorDouble': colorDouble,
        'photocopy': photocopy,
        'paper75Gsm': paper75Gsm,
        'paper100Gsm': paper100Gsm,
        'paperGlossy': paperGlossy,
        'spiralBinding': spiralBinding,
        'hardBinding': hardBinding,
        'lamination': lamination,
        'binding': spiralBinding,
        'updatedAt': updatedAt.toIso8601String(),
      };

  double printRate({required bool color, required bool doubleSided}) =>
      color ? (doubleSided ? colorDouble : colorSingle) : (doubleSided ? bwDouble : bwSingle);

  double priceFor({required bool color, required bool doubleSided}) =>
      printRate(color: color, doubleSided: doubleSided);

  double paperExtra(PaperType type) => switch (type) {
        PaperType.standard75Gsm => paper75Gsm,
        PaperType.executive100Gsm => paper100Gsm,
        PaperType.glossyPhoto => paperGlossy,
      };

  double bindingPrice(BindingType type) => switch (type) {
        BindingType.none => 0.0,
        BindingType.staple => 2.0,
        BindingType.spiral => spiralBinding,
        BindingType.hardCover => hardBinding,
      };

  ShopPrice copyWith({
    double? bwSingle,
    double? bwDouble,
    double? colorSingle,
    double? colorDouble,
    double? photocopy,
    double? paper75Gsm,
    double? paper100Gsm,
    double? paperGlossy,
    double? spiralBinding,
    double? hardBinding,
    double? lamination,
    DateTime? updatedAt,
  }) {
    return ShopPrice(
      bwSingle: bwSingle ?? this.bwSingle,
      bwDouble: bwDouble ?? this.bwDouble,
      colorSingle: colorSingle ?? this.colorSingle,
      colorDouble: colorDouble ?? this.colorDouble,
      photocopy: photocopy ?? this.photocopy,
      paper75Gsm: paper75Gsm ?? this.paper75Gsm,
      paper100Gsm: paper100Gsm ?? this.paper100Gsm,
      paperGlossy: paperGlossy ?? this.paperGlossy,
      spiralBinding: spiralBinding ?? this.spiralBinding,
      hardBinding: hardBinding ?? this.hardBinding,
      lamination: lamination ?? this.lamination,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static DateTime _date(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}

class PrintOrder {
  final String id;
  final String code;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String fileName;
  final String fileUrl;
  final int fileSizeBytes;
  final int pages;
  final int copies;
  final bool color;
  final bool doubleSided;
  final bool lamination;
  final bool binding;
  final PaperType paperType;
  final BindingType bindingType;
  final double total;
  final PaymentMode paymentMode;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final DateTime createdAt;
  final String? cancellationReason;
  final bool isDownloaded;
  final bool isPurged;

  const PrintOrder({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    required this.fileName,
    required this.fileUrl,
    this.fileSizeBytes = 0,
    required this.pages,
    required this.copies,
    required this.color,
    required this.doubleSided,
    required this.lamination,
    required this.binding,
    this.paperType = PaperType.standard75Gsm,
    this.bindingType = BindingType.none,
    required this.total,
    required this.paymentMode,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.cancellationReason,
    this.isDownloaded = false,
    this.isPurged = false,
  });

  int get fileSize => fileSizeBytes;

  factory PrintOrder.fromMap(String id, Map<String, dynamic> d) => PrintOrder(
        id: id,
        code: (d['code'] ?? '').toString(),
        studentId: (d['studentId'] ?? d['student_id'] ?? '').toString(),
        studentName: (d['studentName'] ?? d['student_name'] ?? '').toString(),
        studentEmail: (d['studentEmail'] ?? d['student_email'] ?? '').toString(),
        fileName: (d['fileName'] ?? d['file_name'] ?? '').toString(),
        fileUrl: (d['fileUrl'] ?? d['file_url'] ?? '').toString(),
        fileSizeBytes: _int(d['fileSizeBytes'] ?? d['file_size_bytes'] ?? d['fileSize'], 0),
        pages: _int(d['pages'], 1),
        copies: _int(d['copies'], 1),
        color: d['color'] == true,
        doubleSided: (d['doubleSided'] ?? d['double_sided']) == true,
        lamination: d['lamination'] == true,
        binding: d['binding'] == true,
        paperType: _enumValue(PaperType.values, d['paperType'] ?? d['paper_type'], PaperType.standard75Gsm),
        bindingType: _enumValue(BindingType.values, d['bindingType'] ?? d['binding_type'], d['binding'] == true ? BindingType.spiral : BindingType.none),
        total: _double(d['total']),
        paymentMode: _enumValue(PaymentMode.values, d['paymentMode'] ?? d['payment_mode'], PaymentMode.counter),
        paymentStatus: _enumValue(PaymentStatus.values, d['paymentStatus'] ?? d['payment_status'], PaymentStatus.unpaid),
        status: _enumValue(OrderStatus.values, d['status'], OrderStatus.pending),
        createdAt: DateTime.tryParse('${d['createdAt'] ?? d['created_at']}') ?? DateTime.now(),
        cancellationReason: (d['cancellationReason'] ?? d['cancellation_reason'])?.toString(),
        isDownloaded: (d['isDownloaded'] ?? d['is_downloaded']) == true,
        isPurged: (d['isPurged'] ?? d['is_purged']) == true,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileSizeBytes': fileSizeBytes,
        'pages': pages,
        'copies': copies,
        'color': color,
        'doubleSided': doubleSided,
        'lamination': lamination,
        'binding': binding,
        'paperType': paperType.name,
        'bindingType': bindingType.name,
        'total': total,
        'paymentMode': paymentMode.name,
        'paymentStatus': paymentStatus.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'cancellationReason': cancellationReason,
        'isDownloaded': isDownloaded,
        'isPurged': isPurged,
      };

  PrintOrder copyWith({
    String? id,
    String? code,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? fileName,
    String? fileUrl,
    int? fileSizeBytes,
    int? pages,
    int? copies,
    bool? color,
    bool? doubleSided,
    bool? lamination,
    bool? binding,
    PaperType? paperType,
    BindingType? bindingType,
    double? total,
    PaymentMode? paymentMode,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    DateTime? createdAt,
    String? cancellationReason,
    bool? isDownloaded,
    bool? isPurged,
  }) {
    return PrintOrder(
      id: id ?? this.id,
      code: code ?? this.code,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pages: pages ?? this.pages,
      copies: copies ?? this.copies,
      color: color ?? this.color,
      doubleSided: doubleSided ?? this.doubleSided,
      lamination: lamination ?? this.lamination,
      binding: binding ?? this.binding,
      paperType: paperType ?? this.paperType,
      bindingType: bindingType ?? this.bindingType,
      total: total ?? this.total,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isPurged: isPurged ?? this.isPurged,
    );
  }

  bool get studentCanCancel => status == OrderStatus.pending;

  static int _int(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static T _enumValue<T extends Enum>(List<T> values, dynamic value, T fallback) {
    for (final item in values) {
      if (item.name == value?.toString()) return item;
    }
    return fallback;
  }
}

class ExpenseEntry {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime createdAt;

  const ExpenseEntry({
    required this.id,
    required this.category,
    String? description,
    String? title,
    required this.amount,
    required this.createdAt,
  }) : description = description ?? title ?? '';

  String get title => description;

  factory ExpenseEntry.fromMap(String id, Map<String, dynamic> d) => ExpenseEntry(
        id: id,
        category: (d['category'] ?? 'Other').toString(),
        description: (d['description'] ?? d['title'] ?? '').toString(),
        amount: d['amount'] is num ? (d['amount'] as num).toDouble() : double.tryParse('${d['amount']}') ?? 0,
        createdAt: DateTime.tryParse('${d['createdAt'] ?? d['created_at'] ?? d['date']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'category': category,
        'description': description,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
      };
}
