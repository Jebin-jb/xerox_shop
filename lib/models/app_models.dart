enum UserRole { student, shopkeeper }

enum PaymentMode { online, counter }

enum PaymentStatus {
  unpaid,
  // ignore: constant_identifier_names
  payment_initiated,
  // ignore: constant_identifier_names
  payment_submitted,
  // ignore: constant_identifier_names
  verification_pending,
  paid,
  failed,
  // ignore: constant_identifier_names
  payment_failed,
  cancelled,
  // ignore: constant_identifier_names
  refund_initiated,
  refunded;

  static const PaymentStatus paymentInitiated = PaymentStatus.payment_initiated;
  static const PaymentStatus paymentSubmitted = PaymentStatus.payment_submitted;
  static const PaymentStatus verificationPending =
      PaymentStatus.payment_submitted;
  static const PaymentStatus paymentFailed = PaymentStatus.payment_failed;
  static const PaymentStatus refundPending = PaymentStatus.refund_initiated;

  String get dbValue => name;
}

enum OrderStatus {
  pending,
  accepted,
  printing,
  ready,
  completed,
  cancelled,
  rejected,
}

enum PaperType { standard75Gsm, executive100Gsm, glossyPhoto }

enum BindingType { none, staple, spiral, hardCover }

enum PrintType {
  bw,
  color;

  String get label => this == PrintType.color ? 'COLOR' : 'B&W';
  bool get isColor => this == PrintType.color;
  bool get isBw => this == PrintType.bw;

  static PrintType fromString(String? val) {
    if (val == null) return PrintType.bw;
    final lower = val.toLowerCase().trim();
    if (lower == 'color' || lower == 'colour') return PrintType.color;
    return PrintType.bw;
  }
}

class PagePrintSetting {
  final int pageNumber;
  final PrintType printType;
  final double unitPrice;

  const PagePrintSetting({
    required this.pageNumber,
    required this.printType,
    this.unitPrice = 0.0,
  });

  bool get isColor => printType == PrintType.color;
  bool get isBw => printType == PrintType.bw;

  PagePrintSetting copyWith({
    int? pageNumber,
    PrintType? printType,
    double? unitPrice,
  }) {
    return PagePrintSetting(
      pageNumber: pageNumber ?? this.pageNumber,
      printType: printType ?? this.printType,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toMap() => {
    'pageNumber': pageNumber,
    'printType': printType.name,
    'unitPrice': unitPrice,
  };

  factory PagePrintSetting.fromMap(Map<String, dynamic> map) {
    return PagePrintSetting(
      pageNumber: (map['pageNumber'] ?? map['page_number'] ?? 1) is int
          ? (map['pageNumber'] ?? map['page_number'] ?? 1) as int
          : int.tryParse('${map['pageNumber'] ?? map['page_number']}') ?? 1,
      printType: PrintType.fromString(
        map['printType']?.toString() ?? map['print_type']?.toString(),
      ),
      unitPrice: (map['unitPrice'] ?? map['unit_price'] ?? 0.0) is num
          ? (map['unitPrice'] ?? map['unit_price'] as num).toDouble()
          : double.tryParse('${map['unitPrice'] ?? map['unit_price']}') ?? 0.0,
    );
  }
}

/// Formats a list of page numbers into readable range string
/// e.g. [3, 18, 19, 20, 21, 22, 47, 78, 79, 80, 81, 111] -> "3, 18-22, 47, 78-81, 111"
String formatPageRanges(List<int> pages) {
  if (pages.isEmpty) return '';
  final sorted = List<int>.from(pages.where((p) => p > 0)).toSet().toList()..sort();
  if (sorted.isEmpty) return '';
  final List<String> ranges = [];
  int start = sorted[0];
  int end = sorted[0];

  for (int i = 1; i < sorted.length; i++) {
    if (sorted[i] == end + 1) {
      end = sorted[i];
    } else {
      ranges.add(start == end ? '$start' : '$start-$end');
      start = sorted[i];
      end = sorted[i];
    }
  }
  ranges.add(start == end ? '$start' : '$start-$end');
  return ranges.join(', ');
}

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

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) =>
      UserProfile(
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
    spiralBinding: _double(
      d['spiralBinding'] ?? d['spiral_binding'] ?? d['binding'],
      30.0,
    ),
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

  double printRate({required bool color, required bool doubleSided}) => color
      ? (doubleSided ? colorDouble : colorSingle)
      : (doubleSided ? bwDouble : bwSingle);

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
  final String? cancellationBy; // 'STUDENT' or 'SHOPKEEPER'
  final String? refundStatus; // 'REFUND_INITIATED', 'REFUNDED', etc.
  final String?
  paymentMethod; // 'GOOGLE_PAY', 'PHONEPE', 'PAYTM', 'QR_UPI', 'COUNTER'
  final String? transactionReference;
  final DateTime? paidAt;
  final bool isDownloaded;
  final bool isPurged;
  final Map<String, dynamic>? priceSnapshot;
  final String specialInstructions;
  final String paperTypeName;
  final String gsmName;
  final String bindingName;
  final int? bwPageCount;
  final int? colorPageCount;
  final List<int> colorPageNumbers;
  final List<PagePrintSetting> pageSettings;

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
    this.cancellationBy,
    this.refundStatus,
    this.paymentMethod,
    this.transactionReference,
    this.paidAt,
    this.isDownloaded = false,
    this.isPurged = false,
    this.priceSnapshot,
    this.specialInstructions = '',
    this.paperTypeName = '',
    this.gsmName = '',
    this.bindingName = '',
    this.bwPageCount,
    this.colorPageCount,
    this.colorPageNumbers = const [],
    this.pageSettings = const [],
  });

  int get fileSize => fileSizeBytes;
  int get calculatedBwPages => bwPageCount ?? (color ? 0 : pages);
  int get calculatedColorPages => colorPageCount ?? (color ? pages : 0);
  bool get hasPerDetailPageConfig => pageSettings.isNotEmpty || colorPageNumbers.isNotEmpty;
  String get formattedColorPageRanges => formatPageRanges(colorPageNumbers);

  factory PrintOrder.fromMap(String id, Map<String, dynamic> d) => PrintOrder(
    id: id,
    code: (d['code'] ?? '').toString(),
    studentId: (d['studentId'] ?? d['student_id'] ?? '').toString(),
    studentName: (d['studentName'] ?? d['student_name'] ?? '').toString(),
    studentEmail: (d['studentEmail'] ?? d['student_email'] ?? '').toString(),
    fileName: (d['fileName'] ?? d['file_name'] ?? '').toString(),
    fileUrl: (d['fileUrl'] ?? d['file_url'] ?? '').toString(),
    fileSizeBytes: _int(
      d['fileSizeBytes'] ?? d['file_size_bytes'] ?? d['fileSize'],
      0,
    ),
    pages: _int(d['pages'], 1),
    copies: _int(d['copies'], 1),
    color: d['color'] == true,
    doubleSided: (d['doubleSided'] ?? d['double_sided']) == true,
    lamination: d['lamination'] == true,
    binding: d['binding'] == true,
    paperType: _enumValue(
      PaperType.values,
      d['paperType'] is String
          ? d['paperType']
          : (d['paper_type'] is String
              ? d['paper_type']
              : d['paperTypeEnum']),
      PaperType.standard75Gsm,
    ),
    bindingType: _enumValue(
      BindingType.values,
      d['bindingType'] ?? d['binding_type'],
      d['binding'] == true ? BindingType.spiral : BindingType.none,
    ),
    total: _double(d['total']),
    paymentMode: _enumValue(
      PaymentMode.values,
      d['paymentMode'] ?? d['payment_mode'],
      PaymentMode.counter,
    ),
    paymentStatus: _enumValue(
      PaymentStatus.values,
      d['paymentStatus'] ?? d['payment_status'],
      PaymentStatus.unpaid,
    ),
    status: _enumValue(OrderStatus.values, d['status'], OrderStatus.pending),
    createdAt:
        DateTime.tryParse('${d['createdAt'] ?? d['created_at']}') ??
        DateTime.now(),
    cancellationReason: (d['cancellationReason'] ?? d['cancellation_reason'])
        ?.toString(),
    cancellationBy: (d['cancellationBy'] ?? d['cancellation_by'])?.toString(),
    refundStatus: (d['refundStatus'] ?? d['refund_status'])?.toString(),
    paymentMethod: (d['paymentMethod'] ?? d['payment_method'])?.toString(),
    transactionReference:
        (d['transactionReference'] ??
                d['transaction_reference'] ??
                d['transactionId'] ??
                d['transaction_id'])
            ?.toString(),
    paidAt:
        d['paidAt'] != null ||
            d['paid_at'] != null ||
            d['paymentTime'] != null ||
            d['payment_time'] != null
        ? DateTime.tryParse(
            '${d['paidAt'] ?? d['paid_at'] ?? d['paymentTime'] ?? d['payment_time']}',
          )
        : null,
    isDownloaded: (d['isDownloaded'] ?? d['is_downloaded']) == true,
    isPurged: (d['isPurged'] ?? d['is_purged']) == true,
    priceSnapshot: d['priceSnapshot'] != null && d['priceSnapshot'] is Map
        ? Map<String, dynamic>.from(d['priceSnapshot'])
        : null,
    specialInstructions: (d['specialInstructions'] ??
            d['special_instructions'] ??
            '')
        .toString(),
    paperTypeName: (d['paperTypeName'] ??
            d['paper_type_name'] ??
            (d['paperType'] is Map ? d['paperType']['name'] : (d['paperType'] is String ? d['paperType'] : '')) ??
            '')
        .toString(),
    gsmName: (d['gsmName'] ??
            d['gsm_name'] ??
            (d['gsm'] is Map ? d['gsm']['name'] : (d['gsm'] is String ? d['gsm'] : '')) ??
            '')
        .toString(),
    bindingName: (d['bindingName'] ??
            d['binding_type_name'] ??
            d['bindingType'] ??
            '')
        .toString(),
    bwPageCount: d['bw_page_count'] != null
        ? _int(d['bw_page_count'], 0)
        : (d['bwPageCount'] != null
            ? _int(d['bwPageCount'], 0)
            : (d['priceSnapshot'] is Map && d['priceSnapshot']['bw_page_count'] != null
                ? _int(d['priceSnapshot']['bw_page_count'], 0)
                : null)),
    colorPageCount: d['color_page_count'] != null
        ? _int(d['color_page_count'], 0)
        : (d['colorPageCount'] != null
            ? _int(d['colorPageCount'], 0)
            : (d['priceSnapshot'] is Map && d['priceSnapshot']['color_page_count'] != null
                ? _int(d['priceSnapshot']['color_page_count'], 0)
                : null)),
    colorPageNumbers: d['color_page_numbers'] is List
        ? (d['color_page_numbers'] as List).map((e) => _int(e, 0)).where((e) => e > 0).toList()
        : (d['colorPageNumbers'] is List
            ? (d['colorPageNumbers'] as List).map((e) => _int(e, 0)).where((e) => e > 0).toList()
            : (d['priceSnapshot'] is Map && d['priceSnapshot']['color_page_numbers'] is List
                ? (d['priceSnapshot']['color_page_numbers'] as List).map((e) => _int(e, 0)).where((e) => e > 0).toList()
                : const [])),
    pageSettings: d['page_settings'] is List
        ? (d['page_settings'] as List)
            .whereType<Map>()
            .map((e) => PagePrintSetting.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : (d['pageSettings'] is List
            ? (d['pageSettings'] as List)
                .whereType<Map>()
                .map((e) => PagePrintSetting.fromMap(Map<String, dynamic>.from(e)))
                .toList()
            : (d['priceSnapshot'] is Map && d['priceSnapshot']['page_settings'] is List
                ? (d['priceSnapshot']['page_settings'] as List)
                    .whereType<Map>()
                    .map((e) => PagePrintSetting.fromMap(Map<String, dynamic>.from(e)))
                    .toList()
                : const [])),
  );

  String? get transactionId => transactionReference;
  String? get paymentReference => code;
  DateTime? get paymentTime => paidAt;

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
    'paperType': priceSnapshot?['paperType'] ?? paperType.name,
    'paperTypeEnum': paperType.name,
    'gsm': priceSnapshot?['gsm'],
    'bindingType': bindingType.name,
    'total': total,
    'paymentMode': paymentMode.name,
    'paymentStatus': paymentStatus.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'cancellationReason': cancellationReason,
    'cancellationBy': cancellationBy,
    'refundStatus': refundStatus,
    'paymentMethod': paymentMethod,
    'transactionReference': transactionReference,
    'transactionId': transactionReference,
    'paymentReference': code,
    'paidAt': paidAt?.toIso8601String(),
    'paymentTime': paidAt?.toIso8601String(),
    'isDownloaded': isDownloaded,
    'isPurged': isPurged,
    'priceSnapshot': priceSnapshot,
    'specialInstructions': specialInstructions,
    'paperTypeName': paperTypeName,
    'gsmName': gsmName,
    'bindingName': bindingName,
    'bw_page_count': bwPageCount ?? calculatedBwPages,
    'color_page_count': colorPageCount ?? calculatedColorPages,
    'color_page_numbers': colorPageNumbers,
    'page_settings': pageSettings.map((s) => s.toMap()).toList(),
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
    String? cancellationBy,
    String? refundStatus,
    String? paymentMethod,
    String? transactionReference,
    DateTime? paidAt,
    bool? isDownloaded,
    bool? isPurged,
    Map<String, dynamic>? priceSnapshot,
    String? specialInstructions,
    String? paperTypeName,
    String? gsmName,
    String? bindingName,
    int? bwPageCount,
    int? colorPageCount,
    List<int>? colorPageNumbers,
    List<PagePrintSetting>? pageSettings,
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
      cancellationBy: cancellationBy ?? this.cancellationBy,
      refundStatus: refundStatus ?? this.refundStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      paidAt: paidAt ?? this.paidAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isPurged: isPurged ?? this.isPurged,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      paperTypeName: paperTypeName ?? this.paperTypeName,
      gsmName: gsmName ?? this.gsmName,
      bindingName: bindingName ?? this.bindingName,
      bwPageCount: bwPageCount ?? this.bwPageCount,
      colorPageCount: colorPageCount ?? this.colorPageCount,
      colorPageNumbers: colorPageNumbers ?? this.colorPageNumbers,
      pageSettings: pageSettings ?? this.pageSettings,
    );
  }

  bool get studentCanCancel => status == OrderStatus.pending;

  static int _int(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static T _enumValue<T extends Enum>(
    List<T> values,
    dynamic value,
    T fallback,
  ) {
    final str = value?.toString();
    for (final item in values) {
      if (item.name == str) return item;
    }
    if (T == PaymentStatus) {
      final s = str?.toString().trim() ?? '';
      final lower = s.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      if (lower == 'unpaid') return PaymentStatus.unpaid as T;
      if (lower == 'paymentinitiated' || lower == 'initiated') {
        return PaymentStatus.payment_initiated as T;
      }
      if (lower == 'paymentsubmitted' ||
          lower == 'submitted' ||
          lower == 'verificationpending' ||
          lower == 'verifying') {
        return PaymentStatus.payment_submitted as T;
      }
      if (lower == 'paid') return PaymentStatus.paid as T;
      if (lower == 'failed' || lower == 'paymentfailed') {
        return PaymentStatus.failed as T;
      }
      if (lower == 'refundinitiated' || lower == 'refundpending') {
        return PaymentStatus.refund_initiated as T;
      }
      if (lower == 'refunded') return PaymentStatus.refunded as T;
      if (lower == 'cancelled' || lower == 'canceled') {
        return PaymentStatus.cancelled as T;
      }
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

  factory ExpenseEntry.fromMap(String id, Map<String, dynamic> d) =>
      ExpenseEntry(
        id: id,
        category: (d['category'] ?? 'Other').toString(),
        description: (d['description'] ?? d['title'] ?? '').toString(),
        amount: d['amount'] is num
            ? (d['amount'] as num).toDouble()
            : double.tryParse('${d['amount']}') ?? 0,
        createdAt:
            DateTime.tryParse(
              '${d['createdAt'] ?? d['created_at'] ?? d['date']}',
            ) ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'category': category,
    'description': description,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Registered Shopkeeper Payment Configuration.
/// Stored securely in Firebase Cloud Firestore (/shops/{shopId}/settings/payment).
/// Never stores sensitive bank secrets, passwords, PINs, or CVV.
class ShopPaymentConfig {
  final String merchantName;
  final String upiId;
  final String provider;
  final DateTime updatedAt;

  String get shopName => merchantName;

  const ShopPaymentConfig({
    this.merchantName = 'Campus Xerox',
    this.upiId = '',
    this.provider = 'UPI Payment',
    required this.updatedAt,
  });

  factory ShopPaymentConfig.defaultConfig() => ShopPaymentConfig(
    merchantName: 'Campus Xerox',
    upiId: '',
    provider: 'UPI Payment',
    updatedAt: DateTime.now(),
  );

  factory ShopPaymentConfig.fromMap(Map<String, dynamic> d) =>
      ShopPaymentConfig(
        merchantName:
            (d['paymentDisplayName'] ??
                    d['shopName'] ??
                    d['merchantName'] ??
                    d['merchant_name'] ??
                    'Campus Xerox')
                .toString(),
        upiId: (d['upiId'] ?? d['upi_id'] ?? '').toString(),
        provider: (d['provider'] ?? 'UPI Payment').toString(),
        updatedAt:
            DateTime.tryParse('${d['updatedAt'] ?? d['updated_at']}') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'shopName': merchantName,
    'merchantName': merchantName,
    'paymentDisplayName': merchantName,
    'upiId': upiId,
    'provider': provider,
    'updatedAt': updatedAt.toIso8601String(),
  };

  ShopPaymentConfig copyWith({
    String? merchantName,
    String? upiId,
    String? provider,
    DateTime? updatedAt,
  }) {
    return ShopPaymentConfig(
      merchantName: merchantName ?? this.merchantName,
      upiId: upiId ?? this.upiId,
      provider: provider ?? this.provider,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Paper Type Item for Live Price Control
class PaperTypeItem {
  final String id;
  final String name;
  final String size;
  final String gsm;
  final double basePrice;
  final bool isEnabled;
  final bool isAvailable;

  const PaperTypeItem({
    required this.id,
    required this.name,
    required this.size,
    this.gsm = '75 GSM',
    required this.basePrice,
    this.isEnabled = true,
    this.isAvailable = true,
  });

  factory PaperTypeItem.fromMap(Map<String, dynamic> d) {
    final rawPrice = d['basePrice'] ?? d['base_price'];
    return PaperTypeItem(
      id: (d['id'] ?? '').toString(),
      name: (d['name'] ?? '').toString(),
      size: (d['size'] ?? 'A4').toString(),
      gsm: (d['gsm'] ?? '75 GSM').toString(),
      basePrice: (rawPrice is num)
          ? rawPrice.toDouble()
          : double.tryParse('$rawPrice') ?? 0.0,
      isEnabled: d['isEnabled'] != false,
      isAvailable: d['isAvailable'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'size': size,
    'gsm': gsm,
    'basePrice': basePrice,
    'isEnabled': isEnabled,
    'isAvailable': isAvailable,
  };

  PaperTypeItem copyWith({
    String? id,
    String? name,
    String? size,
    String? gsm,
    double? basePrice,
    bool? isEnabled,
    bool? isAvailable,
  }) {
    return PaperTypeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      gsm: gsm ?? this.gsm,
      basePrice: basePrice ?? this.basePrice,
      isEnabled: isEnabled ?? this.isEnabled,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// Printing Prices per Sheet
class PrintingPrices {
  final double bwSinglePerSheet;
  final double bwDoublePerSheet;
  final double colorSinglePerSheet;
  final double colorDoublePerSheet;
  final bool isEnabled;

  const PrintingPrices({
    required this.bwSinglePerSheet,
    required this.bwDoublePerSheet,
    required this.colorSinglePerSheet,
    required this.colorDoublePerSheet,
    this.isEnabled = true,
  });

  factory PrintingPrices.fromMap(Map<String, dynamic> d) {
    final rawBwSingle = d['bwSinglePerSheet'] ?? d['bw_single'];
    final rawBwDouble = d['bwDoublePerSheet'] ?? d['bw_double'];
    final rawColorSingle = d['colorSinglePerSheet'] ?? d['color_single'];
    final rawColorDouble = d['colorDoublePerSheet'] ?? d['color_double'];

    return PrintingPrices(
      bwSinglePerSheet: (rawBwSingle is num)
          ? rawBwSingle.toDouble()
          : double.tryParse('$rawBwSingle') ?? 1.0,
      bwDoublePerSheet: (rawBwDouble is num)
          ? rawBwDouble.toDouble()
          : double.tryParse('$rawBwDouble') ?? 1.5,
      colorSinglePerSheet: (rawColorSingle is num)
          ? rawColorSingle.toDouble()
          : double.tryParse('$rawColorSingle') ?? 5.0,
      colorDoublePerSheet: (rawColorDouble is num)
          ? rawColorDouble.toDouble()
          : double.tryParse('$rawColorDouble') ?? 8.0,
      isEnabled: d['isEnabled'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'bwSinglePerSheet': bwSinglePerSheet,
    'bwDoublePerSheet': bwDoublePerSheet,
    'colorSinglePerSheet': colorSinglePerSheet,
    'colorDoublePerSheet': colorDoublePerSheet,
    'isEnabled': isEnabled,
  };

  PrintingPrices copyWith({
    double? bwSinglePerSheet,
    double? bwDoublePerSheet,
    double? colorSinglePerSheet,
    double? colorDoublePerSheet,
    bool? isEnabled,
  }) {
    return PrintingPrices(
      bwSinglePerSheet: bwSinglePerSheet ?? this.bwSinglePerSheet,
      bwDoublePerSheet: bwDoublePerSheet ?? this.bwDoublePerSheet,
      colorSinglePerSheet: colorSinglePerSheet ?? this.colorSinglePerSheet,
      colorDoublePerSheet: colorDoublePerSheet ?? this.colorDoublePerSheet,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Binding Type Item
class BindingTypeItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isEnabled;

  const BindingTypeItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.isEnabled = true,
  });

  factory BindingTypeItem.fromMap(Map<String, dynamic> d) => BindingTypeItem(
    id: (d['id'] ?? '').toString(),
    name: (d['name'] ?? '').toString(),
    description: (d['description'] ?? '').toString(),
    price: (d['price'] is num)
        ? (d['price'] as num).toDouble()
        : double.tryParse('${d['price']}') ?? 0.0,
    isEnabled: d['isEnabled'] != false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'isEnabled': isEnabled,
  };

  BindingTypeItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    bool? isEnabled,
  }) {
    return BindingTypeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Lamination Type Item
class LaminationTypeItem {
  final String id;
  final String name;
  final double price;
  final bool isEnabled;

  const LaminationTypeItem({
    required this.id,
    required this.name,
    required this.price,
    this.isEnabled = true,
  });

  factory LaminationTypeItem.fromMap(Map<String, dynamic> d) =>
      LaminationTypeItem(
        id: (d['id'] ?? '').toString(),
        name: (d['name'] ?? '').toString(),
        price: (d['price'] is num)
            ? (d['price'] as num).toDouble()
            : double.tryParse('${d['price']}') ?? 0.0,
        isEnabled: d['isEnabled'] != false,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'isEnabled': isEnabled,
  };

  LaminationTypeItem copyWith({
    String? id,
    String? name,
    double? price,
    bool? isEnabled,
  }) {
    return LaminationTypeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Additional Service Pricing Unit
enum AdditionalServiceUnit {
  perOrder,
  perSheet,
  perPage,
  perCopy;

  String get label => switch (this) {
    perOrder => 'Per Order',
    perSheet => 'Per Sheet',
    perPage => 'Per Page',
    perCopy => 'Per Copy',
  };

  static AdditionalServiceUnit fromString(String? val) {
    if (val == null) return perOrder;
    for (final u in values) {
      if (u.name.toLowerCase() == val.toLowerCase() ||
          u.label.toLowerCase() == val.toLowerCase()) {
        return u;
      }
    }
    return perOrder;
  }
}

/// Additional Service Item
class AdditionalServiceItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final AdditionalServiceUnit pricingUnit;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdditionalServiceItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.pricingUnit = AdditionalServiceUnit.perOrder,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdditionalServiceItem.fromMap(Map<String, dynamic> d) =>
      AdditionalServiceItem(
        id: (d['id'] ?? '').toString(),
        name: (d['name'] ?? '').toString(),
        description: (d['description'] ?? '').toString(),
        price: (d['price'] is num)
            ? (d['price'] as num).toDouble()
            : double.tryParse('${d['price']}') ?? 0.0,
        pricingUnit: AdditionalServiceUnit.fromString(
          d['pricingUnit']?.toString() ?? d['pricing_unit']?.toString(),
        ),
        isEnabled: d['isEnabled'] != false,
        createdAt:
            DateTime.tryParse('${d['createdAt'] ?? d['created_at']}') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse('${d['updatedAt'] ?? d['updated_at']}') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'pricingUnit': pricingUnit.name,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  AdditionalServiceItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    AdditionalServiceUnit? pricingUnit,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdditionalServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Configurable print option item for dynamic paper types, GSM, finishing & binding.
/// Stored in Firestore as the single source of truth for print configuration.
class PrintConfigItem {
  final String id;
  final String name;
  final String category; // 'paperType', 'gsm', 'binding', 'finishing', 'additionalService'
  final double price;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrintConfigItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrintConfigItem.fromMap(Map<String, dynamic> d) => PrintConfigItem(
    id: (d['id'] ?? '').toString(),
    name: (d['name'] ?? '').toString(),
    category: (d['category'] ?? 'paperType').toString(),
    price: (d['price'] is num)
        ? (d['price'] as num).toDouble()
        : double.tryParse('${d['price']}') ?? 0.0,
    enabled: d['enabled'] != false && d['isEnabled'] != false,
    createdAt:
        DateTime.tryParse('${d['createdAt'] ?? d['created_at']}') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse('${d['updatedAt'] ?? d['updated_at']}') ??
        DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'price': price,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  PrintConfigItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrintConfigItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Complete Live Pricing Configuration.
/// Shopkeeper maintains full real-time control via Firestore.
class LiveShopPricing {
  final List<PaperTypeItem> paperTypes;
  final PrintingPrices printingPrices;
  final List<BindingTypeItem> bindingTypes;
  final List<LaminationTypeItem> laminationTypes;
  final List<AdditionalServiceItem> additionalServices;
  final List<PrintConfigItem> configItems;
  final DateTime updatedAt;

  const LiveShopPricing({
    required this.paperTypes,
    required this.printingPrices,
    required this.bindingTypes,
    required this.laminationTypes,
    required this.additionalServices,
    required this.configItems,
    required this.updatedAt,
  });

  List<PrintConfigItem> get paperTypeOptions =>
      configItems.where((i) => i.category == 'paperType').toList();

  List<PrintConfigItem> get gsmOptions =>
      configItems.where((i) => i.category == 'gsm').toList();

  List<PrintConfigItem> get bindingAndFinishingOptions => configItems
      .where((i) => i.category == 'binding' || i.category == 'finishing')
      .toList();

  List<PrintConfigItem> get additionalServiceOptions =>
      configItems.where((i) => i.category == 'additionalService').toList();

  static List<PrintConfigItem> defaultConfigItems() {
    final now = DateTime.now();
    return [
      // 1. Paper Types
      PrintConfigItem(
        id: 'cfg_paper_a4',
        name: 'A4',
        category: 'paperType',
        price: 0.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_paper_a3',
        name: 'A3',
        category: 'paperType',
        price: 2.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_paper_legal',
        name: 'Legal',
        category: 'paperType',
        price: 1.5,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_paper_photo',
        name: 'Photo Paper',
        category: 'paperType',
        price: 10.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),

      // 2. GSM Options
      PrintConfigItem(
        id: 'cfg_gsm_70',
        name: '70 GSM',
        category: 'gsm',
        price: 0.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_gsm_75',
        name: '75 GSM',
        category: 'gsm',
        price: 0.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_gsm_80',
        name: '80 GSM',
        category: 'gsm',
        price: 0.5,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_gsm_100',
        name: '100 GSM',
        category: 'gsm',
        price: 1.5,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),

      // 3. Finishing & Binding
      PrintConfigItem(
        id: 'cfg_bind_none',
        name: 'No Binding',
        category: 'binding',
        price: 0.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_bind_staple',
        name: 'Stapling',
        category: 'binding',
        price: 2.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_bind_spiral',
        name: 'Spiral Binding',
        category: 'binding',
        price: 30.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_bind_hard',
        name: 'Hard Binding',
        category: 'binding',
        price: 150.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_bind_comb',
        name: 'Comb Binding',
        category: 'binding',
        price: 40.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      PrintConfigItem(
        id: 'cfg_finish_lam',
        name: 'Lamination',
        category: 'finishing',
        price: 10.0,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  factory LiveShopPricing.defaultPricing() => LiveShopPricing(
    paperTypes: const [
      PaperTypeItem(
        id: 'paper_a4_normal',
        name: 'A4 Normal',
        size: 'A4',
        gsm: '75 GSM',
        basePrice: 0.0,
      ),
      PaperTypeItem(
        id: 'paper_a3_normal',
        name: 'A3 Normal',
        size: 'A3',
        gsm: '75 GSM',
        basePrice: 2.0,
      ),
      PaperTypeItem(
        id: 'paper_a4_thick',
        name: 'A4 Thick Paper',
        size: 'A4',
        gsm: '100 GSM',
        basePrice: 1.5,
      ),
      PaperTypeItem(
        id: 'paper_a4_color',
        name: 'A4 Color Paper',
        size: 'A4',
        gsm: '80 GSM',
        basePrice: 2.5,
      ),
      PaperTypeItem(
        id: 'paper_photo',
        name: 'Photo Paper',
        size: 'A4',
        gsm: '180 GSM',
        basePrice: 10.0,
      ),
    ],
    printingPrices: const PrintingPrices(
      bwSinglePerSheet: 1.0,
      bwDoublePerSheet: 1.5,
      colorSinglePerSheet: 5.0,
      colorDoublePerSheet: 8.0,
    ),
    bindingTypes: const [
      BindingTypeItem(
        id: 'bind_none',
        name: 'No Binding',
        description: 'Loose printed sheets',
        price: 0.0,
      ),
      BindingTypeItem(
        id: 'bind_staple',
        name: 'Staple Binding',
        description: 'Corner or side stapled',
        price: 2.0,
      ),
      BindingTypeItem(
        id: 'bind_spiral',
        name: 'Spiral Binding',
        description: 'Plastic spiral ring binding',
        price: 30.0,
      ),
      BindingTypeItem(
        id: 'bind_soft',
        name: 'Soft Binding',
        description: 'Clear acetate sheet cover',
        price: 50.0,
      ),
      BindingTypeItem(
        id: 'bind_hard',
        name: 'Hard Binding',
        description: 'Gold embossed hard cover',
        price: 150.0,
      ),
      BindingTypeItem(
        id: 'bind_project',
        name: 'Project Binding',
        description: 'College final thesis binding',
        price: 200.0,
      ),
    ],
    laminationTypes: const [
      LaminationTypeItem(id: 'lam_a4', name: 'A4 Lamination', price: 10.0),
      LaminationTypeItem(id: 'lam_a3', name: 'A3 Lamination', price: 20.0),
      LaminationTypeItem(id: 'lam_id', name: 'ID Card Lamination', price: 15.0),
    ],
    additionalServices: [
      AdditionalServiceItem(
        id: 'srv_stapling',
        name: 'Stapling',
        description: 'Corner or double stapling',
        price: 2.0,
        pricingUnit: AdditionalServiceUnit.perCopy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AdditionalServiceItem(
        id: 'srv_scanning',
        name: 'Document Scanning',
        description: 'High resolution digital PDF scan',
        price: 5.0,
        pricingUnit: AdditionalServiceUnit.perPage,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AdditionalServiceItem(
        id: 'srv_cover',
        name: 'Project Cover Sheet',
        description: 'Embossed glossy cover sheet',
        price: 15.0,
        pricingUnit: AdditionalServiceUnit.perCopy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ],
    configItems: defaultConfigItems(),
    updatedAt: DateTime.now(),
  );

  factory LiveShopPricing.fromMap(Map<String, dynamic> d) {
    final rawPaper = d['paperTypes'] ?? d['paper_types'];
    final rawBinding = d['bindingTypes'] ?? d['binding_types'];
    final rawLam = d['laminationTypes'] ?? d['lamination_types'];
    final rawServices = d['additionalServices'] ?? d['additional_services'];
    final rawConfig = d['configItems'] ?? d['config_items'];

    List<PrintConfigItem> items;
    if (rawConfig is List && rawConfig.isNotEmpty) {
      items = rawConfig
          .map(
            (e) =>
                PrintConfigItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } else {
      items = LiveShopPricing.defaultConfigItems();
    }

    return LiveShopPricing(
      paperTypes: rawPaper is List
          ? rawPaper
                .map(
                  (e) => PaperTypeItem.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : LiveShopPricing.defaultPricing().paperTypes,
      printingPrices: d['printingPrices'] != null
          ? PrintingPrices.fromMap(
              Map<String, dynamic>.from(d['printingPrices'] as Map),
            )
          : (d['printing_prices'] != null
                ? PrintingPrices.fromMap(
                    Map<String, dynamic>.from(d['printing_prices'] as Map),
                  )
                : LiveShopPricing.defaultPricing().printingPrices),
      bindingTypes: rawBinding is List
          ? rawBinding
                .map(
                  (e) => BindingTypeItem.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : LiveShopPricing.defaultPricing().bindingTypes,
      laminationTypes: rawLam is List
          ? rawLam
                .map(
                  (e) => LaminationTypeItem.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : LiveShopPricing.defaultPricing().laminationTypes,
      additionalServices: rawServices is List
          ? rawServices
                .map(
                  (e) => AdditionalServiceItem.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : LiveShopPricing.defaultPricing().additionalServices,
      configItems: items,
      updatedAt:
          DateTime.tryParse('${d['updatedAt'] ?? d['updated_at']}') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'paperTypes': paperTypes.map((e) => e.toMap()).toList(),
    'printingPrices': printingPrices.toMap(),
    'bindingTypes': bindingTypes.map((e) => e.toMap()).toList(),
    'laminationTypes': laminationTypes.map((e) => e.toMap()).toList(),
    'additionalServices': additionalServices.map((e) => e.toMap()).toList(),
    'configItems': configItems.map((e) => e.toMap()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Backwards compatibility converter to ShopPrice
  ShopPrice toShopPrice() {
    double paper75 = 0.0;
    double paper100 = 1.5;
    double paperPhoto = 10.0;

    // First check dynamic configItems
    for (final c in configItems) {
      if (c.category == 'paperType') {
        if (c.name.toLowerCase().contains('photo')) {
          paperPhoto = c.price;
        }
      }
      if (c.category == 'gsm') {
        if (c.name.contains('75')) {
          paper75 = c.price;
        } else if (c.name.contains('100')) {
          paper100 = c.price;
        }
      }
    }

    for (final p in paperTypes) {
      if (p.name.contains('75') || p.id.contains('a4_normal')) {
        paper75 = p.basePrice;
      }
      if (p.name.contains('100') || p.id.contains('thick')) {
        paper100 = p.basePrice;
      }
      if (p.name.contains('Photo') || p.id.contains('photo')) {
        paperPhoto = p.basePrice;
      }
    }

    double spiral = 30.0;
    double hard = 150.0;
    for (final c in configItems) {
      if (c.category == 'binding') {
        if (c.name.toLowerCase().contains('spiral')) spiral = c.price;
        if (c.name.toLowerCase().contains('hard')) hard = c.price;
      }
    }
    for (final b in bindingTypes) {
      if (b.name.toLowerCase().contains('spiral')) spiral = b.price;
      if (b.name.toLowerCase().contains('hard')) hard = b.price;
    }

    double lam = 10.0;
    for (final c in configItems) {
      if (c.category == 'finishing' && c.name.toLowerCase().contains('lam')) {
        lam = c.price;
      }
    }
    if (laminationTypes.isNotEmpty) {
      lam = laminationTypes.first.price;
    }

    return ShopPrice(
      bwSingle: printingPrices.bwSinglePerSheet,
      bwDouble: printingPrices.bwDoublePerSheet,
      colorSingle: printingPrices.colorSinglePerSheet,
      colorDouble: printingPrices.colorDoublePerSheet,
      photocopy: printingPrices.bwSinglePerSheet,
      paper75Gsm: paper75,
      paper100Gsm: paper100,
      paperGlossy: paperPhoto,
      spiralBinding: spiral,
      hardBinding: hard,
      lamination: lam,
      updatedAt: updatedAt,
    );
  }

  LiveShopPricing copyWith({
    List<PaperTypeItem>? paperTypes,
    PrintingPrices? printingPrices,
    List<BindingTypeItem>? bindingTypes,
    List<LaminationTypeItem>? laminationTypes,
    List<AdditionalServiceItem>? additionalServices,
    List<PrintConfigItem>? configItems,
    DateTime? updatedAt,
  }) {
    return LiveShopPricing(
      paperTypes: paperTypes ?? this.paperTypes,
      printingPrices: printingPrices ?? this.printingPrices,
      bindingTypes: bindingTypes ?? this.bindingTypes,
      laminationTypes: laminationTypes ?? this.laminationTypes,
      additionalServices: additionalServices ?? this.additionalServices,
      configItems: configItems ?? this.configItems,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Secure Shop Payment Account model.
/// Configured by the Shopkeeper to receive online student payments.
class ShopPaymentAccount {
  final String shopId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String branchName;
  final String upiId;
  final String paymentDisplayName;
  final String paymentApp;
  final String qrImageUrl;
  final bool isOnlinePaymentEnabled;
  final DateTime? createdAt;
  final DateTime updatedAt;

  const ShopPaymentAccount({
    this.shopId = 'campus-xerox',
    this.accountHolderName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.branchName = '',
    this.upiId = '',
    this.paymentDisplayName = '',
    this.paymentApp = 'Google Pay',
    this.qrImageUrl = '',
    this.isOnlinePaymentEnabled = false,
    this.createdAt,
    required this.updatedAt,
  });

  String get payeeName =>
      paymentDisplayName.trim().isNotEmpty
          ? paymentDisplayName.trim()
          : (accountHolderName.trim().isNotEmpty
              ? accountHolderName.trim()
              : 'Campus Xerox');

  bool get isActive => isOnlinePaymentEnabled;

  /// Displays masked bank account number (e.g. XXXXXXXX1234)
  String get maskedAccountNumber {
    final clean = accountNumber.trim();
    if (clean.isEmpty) return '';
    if (clean.length <= 4) return 'XXXX$clean';
    final lastFour = clean.substring(clean.length - 4);
    return 'XXXXXXXX$lastFour';
  }

  /// Whether online payment is properly configured and enabled
  bool get isConfigured =>
      upiId.trim().isNotEmpty &&
      isOnlinePaymentEnabled;

  static ShopPaymentAccount empty() => ShopPaymentAccount(
    shopId: 'campus-xerox',
    accountHolderName: '',
    bankName: '',
    accountNumber: '',
    ifsc: '',
    branchName: '',
    upiId: '',
    paymentDisplayName: '',
    paymentApp: 'Google Pay',
    qrImageUrl: '',
    isOnlinePaymentEnabled: false,
    updatedAt: DateTime.now(),
  );

  factory ShopPaymentAccount.fromMap(
    Map<String, dynamic> d,
  ) => ShopPaymentAccount(
    shopId: (d['shop_id'] ?? d['shopId'] ?? 'campus-xerox').toString(),
    accountHolderName:
        (d['accountHolderName'] ?? d['account_holder_name'] ?? d['payee_name'] ?? d['payeeName'] ?? '').toString(),
    bankName: (d['bankName'] ?? d['bank_name'] ?? d['payment_app'] ?? d['paymentApp'] ?? '').toString(),
    accountNumber: (d['accountNumber'] ?? d['account_number'] ?? '').toString(),
    ifsc: (d['ifsc'] ?? d['ifscCode'] ?? '').toString(),
    branchName: (d['branchName'] ?? d['branch_name'] ?? '').toString(),
    upiId: (d['upiId'] ?? d['upi_id'] ?? '').toString(),
    paymentDisplayName:
        (d['paymentDisplayName'] ?? d['payment_display_name'] ?? d['payee_name'] ?? d['payeeName'] ?? '').toString(),
    paymentApp: (d['paymentApp'] ?? d['payment_app'] ?? 'Google Pay').toString(),
    qrImageUrl: (d['qrImageUrl'] ?? d['qr_image_url'] ?? '').toString(),
    isOnlinePaymentEnabled:
        d['isOnlinePaymentEnabled'] == true ||
        d['is_online_payment_enabled'] == true ||
        d['isActive'] == true ||
        d['is_active'] == true,
    createdAt: d['createdAt'] != null
        ? DateTime.tryParse('${d['createdAt']}')
        : null,
    updatedAt:
        DateTime.tryParse('${d['updatedAt'] ?? d['updated_at']}') ??
        DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'shopId': shopId,
    'accountHolderName': accountHolderName,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'maskedAccountNumber': maskedAccountNumber,
    'ifsc': ifsc,
    'branchName': branchName,
    'upiId': upiId,
    'paymentDisplayName': paymentDisplayName,
    'paymentApp': paymentApp,
    'qrImageUrl': qrImageUrl,
    'isOnlinePaymentEnabled': isOnlinePaymentEnabled,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Serializes into the exact schema of Supabase `payment_settings` table
  Map<String, dynamic> toPaymentSettingsMap() => {
    'id': 'campus-xerox',
    'shop_id': shopId.isNotEmpty ? shopId : 'campus-xerox',
    'upi_id': upiId.trim(),
    'payee_name': payeeName,
    'payment_app': paymentApp.trim().isNotEmpty ? paymentApp.trim() : 'Google Pay',
    'qr_image_url': qrImageUrl.trim(),
    'is_active': isOnlinePaymentEnabled,
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Safe map for student clients without sensitive bank numbers or IFSC
  Map<String, dynamic> toSafeStudentMap() => {
    'shopId': shopId,
    'upiId': upiId,
    'paymentDisplayName': payeeName,
    'payeeName': payeeName,
    'paymentApp': paymentApp,
    'qrImageUrl': qrImageUrl,
    'isOnlinePaymentEnabled': isOnlinePaymentEnabled,
  };

  ShopPaymentConfig toPaymentConfig() => ShopPaymentConfig(
    merchantName: payeeName,
    upiId: upiId,
    provider: paymentApp.isNotEmpty ? paymentApp : 'UPI Payment',
    updatedAt: updatedAt,
  );

  ShopPaymentAccount copyWith({
    String? shopId,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? branchName,
    String? upiId,
    String? paymentDisplayName,
    String? paymentApp,
    String? qrImageUrl,
    bool? isOnlinePaymentEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopPaymentAccount(
      shopId: shopId ?? this.shopId,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      branchName: branchName ?? this.branchName,
      upiId: upiId ?? this.upiId,
      paymentDisplayName: paymentDisplayName ?? this.paymentDisplayName,
      paymentApp: paymentApp ?? this.paymentApp,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      isOnlinePaymentEnabled:
          isOnlinePaymentEnabled ?? this.isOnlinePaymentEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Catalog item for the Supabase `services` table
class ShopServiceItem {
  final String id;
  final String shopId;
  final String serviceName;
  final String description;
  final double price;
  final String pricingUnit;
  final bool isActive;
  final DateTime updatedAt;

  const ShopServiceItem({
    required this.id,
    this.shopId = 'campus-xerox',
    required this.serviceName,
    this.description = '',
    required this.price,
    this.pricingUnit = 'per_page',
    this.isActive = true,
    required this.updatedAt,
  });

  factory ShopServiceItem.fromMap(Map<String, dynamic> d) => ShopServiceItem(
    id: (d['id'] ?? '').toString(),
    shopId: (d['shop_id'] ?? d['shopId'] ?? 'campus-xerox').toString(),
    serviceName: (d['service_name'] ?? d['serviceName'] ?? '').toString(),
    description: (d['description'] ?? '').toString(),
    price: (d['price'] is num)
        ? (d['price'] as num).toDouble()
        : double.tryParse('${d['price']}') ?? 0.0,
    pricingUnit:
        (d['pricing_unit'] ?? d['pricingUnit'] ?? 'per_page').toString(),
    isActive: d['is_active'] == true || d['isActive'] == true,
    updatedAt: DateTime.tryParse('${d['updated_at'] ?? d['updatedAt']}') ??
        DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'shop_id': shopId,
    'service_name': serviceName,
    'description': description,
    'price': price,
    'pricing_unit': pricingUnit,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
  };
}
