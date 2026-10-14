import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/document_analysis_service.dart';
import '../../services/storage_service.dart';
import '../../services/payment/payment_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'automatic_detection_screen.dart';
import 'order_receipt.dart';
import 'payment_screen.dart';
import 'payment_status_screens.dart';

class CreateOrder extends StatefulWidget {
  final DataService dataService;
  final UserProfile profile;
  final ShopPrice prices;
  final VoidCallback onToggleTheme;
  final PlatformFile? prefilledFile;
  final Uint8List? prefilledBytes;
  final int? prefilledPages;
  final bool? prefilledColor;
  final bool? prefilledDoubleSided;
  final PaperType? prefilledPaperType;
  final BindingType? prefilledBindingType;
  final int? prefilledCopies;
  final bool? prefilledLamination;
  final int? prefilledBwPages;
  final int? prefilledColorPages;
  final List<int>? prefilledColorPageNumbers;
  final List<PagePrintSetting>? prefilledPageSettings;
  final bool? prefilledIsAutoDetect;
  final String? prefilledPaperTypeId;
  final String? prefilledGsmId;
  final String? prefilledBindingId;

  const CreateOrder({
    super.key,
    required this.dataService,
    required this.profile,
    required this.prices,
    required this.onToggleTheme,
    this.prefilledFile,
    this.prefilledBytes,
    this.prefilledPages,
    this.prefilledColor,
    this.prefilledDoubleSided,
    this.prefilledPaperType,
    this.prefilledBindingType,
    this.prefilledCopies,
    this.prefilledLamination,
    this.prefilledBwPages,
    this.prefilledColorPages,
    this.prefilledColorPageNumbers,
    this.prefilledPageSettings,
    this.prefilledIsAutoDetect,
    this.prefilledPaperTypeId,
    this.prefilledGsmId,
    this.prefilledBindingId,
  });

  @override
  State<CreateOrder> createState() => _CreateOrderState();
}

class _CreateOrderState extends State<CreateOrder> {
  PlatformFile? file;
  Uint8List? bytes;
  int fileSizeBytes = 0;
  bool color = false;
  bool doubleSided = false;
  bool lamination = false;
  PaperType paperType = PaperType.standard75Gsm;
  BindingType bindingType = BindingType.none;
  bool busy = false;
  double uploadProgress = 0.0;
  int copies = 1;
  int pages = 1;
  PaymentMode payment = PaymentMode.online;
  int? _autoDetectedPages;
  int? _detectedColorPages;
  int? _detectedBwPages;
  List<int> _colorPageNumbers = const [];
  List<PagePrintSetting> _pageSettings = const [];
  bool _isAutoDetect = false;
  bool _isAutoDetecting = false;

  final specialInstructionsCtrl = TextEditingController();
  String? selectedPaperTypeId;
  String? selectedGsmId;
  String? selectedBindingId;
  StreamSubscription<LiveShopPricing>? _pricingSub;

  @override
  void initState() {
    super.initState();
    selectedPaperTypeId = widget.prefilledPaperTypeId;
    selectedGsmId = widget.prefilledGsmId;
    selectedBindingId = widget.prefilledBindingId;

    _pricingSub = widget.dataService.livePricing().listen((_) {
      if (mounted) setState(() {});
    });

    if (widget.prefilledFile != null) {
      file = widget.prefilledFile;
      bytes = widget.prefilledBytes;
      fileSizeBytes = widget.prefilledFile!.size;
      pages = widget.prefilledPages ?? 1;
      color = widget.prefilledColor ?? false;
      doubleSided = widget.prefilledDoubleSided ?? false;
      paperType = widget.prefilledPaperType ?? PaperType.standard75Gsm;
      bindingType = widget.prefilledBindingType ?? BindingType.none;
      copies = widget.prefilledCopies ?? 1;
      lamination = widget.prefilledLamination ?? false;
      _autoDetectedPages = widget.prefilledPages;
      _detectedBwPages = widget.prefilledBwPages;
      _detectedColorPages = widget.prefilledColorPages;
      _colorPageNumbers = widget.prefilledColorPageNumbers ?? const [];
      _pageSettings = widget.prefilledPageSettings ?? const [];
      _isAutoDetect =
          widget.prefilledIsAutoDetect ?? (_detectedBwPages != null);
    }
  }

  @override
  void dispose() {
    _pricingSub?.cancel();
    specialInstructionsCtrl.dispose();
    super.dispose();
  }

  LiveShopPricing get livePricing => widget.dataService.currentLivePricing;

  List<PrintConfigItem> get enabledPaperTypes =>
      livePricing.paperTypeOptions.where((i) => i.enabled).toList();

  List<PrintConfigItem> get enabledGsmOptions =>
      livePricing.gsmOptions.where((i) => i.enabled).toList();

  List<PrintConfigItem> get enabledBindingOptions =>
      livePricing.bindingAndFinishingOptions.where((i) => i.enabled).toList();

  PrintConfigItem? get selectedPaperType {
    if (selectedPaperTypeId == null) return null;
    return enabledPaperTypes
        .where((i) => i.id == selectedPaperTypeId)
        .firstOrNull;
  }

  PrintConfigItem? get selectedGsm {
    if (selectedGsmId == null) return null;
    return enabledGsmOptions.where((i) => i.id == selectedGsmId).firstOrNull;
  }

  PrintConfigItem? get selectedBinding {
    if (selectedBindingId == null) return null;
    return enabledBindingOptions
        .where((i) => i.id == selectedBindingId)
        .firstOrNull;
  }

  int get sheetsRequired => doubleSided ? (pages / 2).ceil() : pages;

  double get paperRate => selectedPaperType?.price ?? 0.0;
  double get gsmRate => selectedGsm?.price ?? 0.0;

  String get paperName {
    final pt = selectedPaperType?.name ?? 'Not selected';
    final gsm = selectedGsm?.name;
    return gsm != null ? '$pt ($gsm)' : pt;
  }

  String get bindingName => selectedBinding?.name ?? 'No Binding';

  double get bindingCost => (selectedBinding?.price ?? 0.0) * copies;

  double get bwPrintRate => doubleSided
      ? livePricing.printingPrices.bwDoublePerSheet
      : livePricing.printingPrices.bwSinglePerSheet;

  double get colorPrintRate => doubleSided
      ? livePricing.printingPrices.colorDoublePerSheet
      : livePricing.printingPrices.colorSinglePerSheet;

  double get standardPrintRate => color ? colorPrintRate : bwPrintRate;

  double get printRatePerSheet => standardPrintRate + paperRate + gsmRate;

  double get printTotal {
    final bwPages = _detectedBwPages ?? (color ? 0 : pages);
    final colorPages = _detectedColorPages ?? (color ? pages : 0);

    final bwRate = (doubleSided
            ? livePricing.printingPrices.bwDoublePerSheet
            : livePricing.printingPrices.bwSinglePerSheet) +
        paperRate +
        gsmRate;
    final colorRate = (doubleSided
            ? livePricing.printingPrices.colorDoublePerSheet
            : livePricing.printingPrices.colorSinglePerSheet) +
        paperRate +
        gsmRate;

    if (doubleSided) {
      final colorSheets = (colorPages / 2).ceil();
      final bwSheets = (bwPages / 2).ceil();
      return (colorSheets * colorRate + bwSheets * bwRate) * copies;
    } else {
      return (colorPages * colorRate + bwPages * bwRate) * copies;
    }
  }

  double get laminationCost {
    if (!lamination) return 0.0;
    final match = livePricing.configItems
        .where(
          (i) => i.name.toLowerCase().contains('lamination') && i.enabled,
        )
        .firstOrNull;
    final unitPrice =
        match?.price ??
        (livePricing.laminationTypes.isNotEmpty
            ? livePricing.laminationTypes.first.price
            : 10.0);
    return unitPrice * copies;
  }

  double get total => printTotal + laminationCost + bindingCost;

  Future<void> _runAutoDetection(PlatformFile picked, Uint8List b) async {
    setState(() => _isAutoDetecting = true);
    try {
      final analysis = await DocumentAnalysisService().analyzeDocument(
        fileName: picked.name,
        bytes: b,
      );
      if (mounted) {
        setState(() {
          _autoDetectedPages = analysis.totalPages;
          _detectedColorPages = analysis.colorPagesCount;
          _detectedBwPages = analysis.bwPagesCount;
          _colorPageNumbers = analysis.colorPageNumbers;
          _pageSettings = analysis.toPagePrintSettings(
            prices: widget.prices,
            doubleSided: doubleSided,
          );
          _isAutoDetect = true;
          pages = analysis.totalPages;
          color = analysis.colorPagesCount > 0;
          _isAutoDetecting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAutoDetecting = false);
    }
  }

  void _openAutoDetectScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AutomaticDetectionScreen(
          dataService: widget.dataService,
          profile: widget.profile,
          onToggleTheme: widget.onToggleTheme,
          initialFile: file,
          initialBytes: bytes,
        ),
      ),
    );
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'jpg',
          'jpeg',
          'png',
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final len = picked.size;

        // 50 MB Validation
        if (len > StorageService.maxFileSizeBytes) {
          final sizeMb = (len / (1024 * 1024)).toStringAsFixed(1);
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 36,
                ),
                title: const Text('File Exceeds 50MB Limit'),
                content: Text(
                  'The selected file is $sizeMb MB. Campus Xerox allows files up to a maximum of 50 MB per order.\n\nPlease compress your document or choose a smaller file.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Understood'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        Uint8List b = picked.bytes ?? Uint8List(0);
        if (b.isEmpty && picked.path != null && !kIsWeb) {
          try {
            final f = File(picked.path!);
            if (await f.exists()) {
              b = await f.readAsBytes();
            }
          } catch (e) {
            debugPrint('Could not read file from path: $e');
          }
        }

        setState(() {
          file = picked;
          bytes = b;
          fileSizeBytes = b.isNotEmpty ? b.length : len;
        });

        _runAutoDetection(picked, b);
      }
    } catch (e) {
      _show('Error selecting document: $e');
    }
  }

  Future<void> submit() async {
    if (file == null) {
      return _show('Please choose a document to print.');
    }
    if (selectedPaperTypeId == null) {
      return _show('Please select a Paper Type.');
    }
    if (copies < 1) {
      return _show('Please enter at least 1 copy.');
    }

    setState(() {
      busy = true;
      uploadProgress = 0.1;
    });

    try {
      // 1. Upload to Supabase/Vault storage with progress
      final url = await StorageService().upload(
        uid: widget.profile.id,
        fileName: file!.name,
        bytes: bytes,
        onProgress: (p) {
          if (mounted) {
            setState(() => uploadProgress = p);
          }
        },
      );

      final bwCount = _detectedBwPages ?? (color ? 0 : pages);
      final colorCount = _detectedColorPages ?? (color ? pages : 0);
      final finalColorPageNumbers = _colorPageNumbers.isNotEmpty
          ? _colorPageNumbers
          : (color ? List.generate(pages, (i) => i + 1) : <int>[]);
      final finalPageSettings = _pageSettings.isNotEmpty
          ? _pageSettings
          : List.generate(
              pages,
              (i) => PagePrintSetting(
                pageNumber: i + 1,
                printType: finalColorPageNumbers.contains(i + 1)
                    ? PrintType.color
                    : PrintType.bw,
                unitPrice: finalColorPageNumbers.contains(i + 1)
                    ? (doubleSided
                        ? livePricing.printingPrices.colorDoublePerSheet
                        : livePricing.printingPrices.colorSinglePerSheet)
                    : (doubleSided
                        ? livePricing.printingPrices.bwDoublePerSheet
                        : livePricing.printingPrices.bwSinglePerSheet),
              ),
            );

      // 2. Build complete immutable price snapshot
      final snapshot = {
        'document': file!.name,
        'pdfPages': pages,
        'total_pages': pages,
        'bw_page_count': bwCount,
        'color_page_count': colorCount,
        'color_page_numbers': finalColorPageNumbers,
        'page_settings': finalPageSettings.map((s) => s.toMap()).toList(),
        'price_breakdown': {
          'bw_rate': bwPrintRate,
          'color_rate': colorPrintRate,
          'paper_rate': paperRate,
          'gsm_rate': gsmRate,
          'bw_pages': bwCount,
          'color_pages': colorCount,
          'copies': copies,
          'printing_cost': printTotal,
          'binding_cost': bindingCost,
          'lamination_cost': laminationCost,
          'total': total,
        },
        'color': colorCount > 0,
        'printing': colorCount > 0
            ? (bwCount > 0 ? 'Mixed (Per-Page)' : 'Color')
            : 'B&W',
        'doubleSided': doubleSided,
        'sides': doubleSided ? 'Double Side' : 'Single Side',
        'sheetsRequired': sheetsRequired,
        'copies': copies,
        'paperType': {
          'id': selectedPaperType!.id,
          'name': selectedPaperType!.name,
          'price': selectedPaperType!.price,
        },
        'paperTypeName': selectedPaperType!.name,
        'paperRate': paperRate,
        if (selectedGsm != null)
          'gsm': {
            'id': selectedGsm!.id,
            'name': selectedGsm!.name,
            'price': selectedGsm!.price,
          },
        'gsmName': selectedGsm?.name ?? '',
        'gsmRate': gsmRate,
        if (selectedBinding != null)
          'binding': {
            'id': selectedBinding!.id,
            'name': selectedBinding!.name,
            'price': selectedBinding!.price,
          },
        'bindingName': bindingName,
        'bindingCost': bindingCost,
        'lamination': lamination,
        'laminationCost': laminationCost,
        'specialInstructions': specialInstructionsCtrl.text.trim(),
        'printPricePerSheet': standardPrintRate,
        'printingCost': printTotal,
        'totalAmount': total,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // 3. Create order record
      final id = await widget.dataService.createOrder(
        studentId: widget.profile.id,
        studentName: widget.profile.name,
        studentEmail: widget.profile.email,
        fileName: file!.name,
        fileUrl: url,
        fileSizeBytes: fileSizeBytes,
        pages: pages,
        copies: copies,
        color: colorCount > 0,
        doubleSided: doubleSided,
        lamination: lamination,
        binding: selectedBinding != null,
        paperType: paperType,
        bindingType: bindingType,
        paperTypeName: selectedPaperType!.name,
        gsmName: selectedGsm?.name ?? '',
        bindingName: bindingName,
        specialInstructions: specialInstructionsCtrl.text.trim(),
        total: total,
        paymentMode: payment,
        priceSnapshot: snapshot,
        bwPageCount: bwCount,
        colorPageCount: colorCount,
        colorPageNumbers: finalColorPageNumbers,
        pageSettings: finalPageSettings,
      );

      if (payment == PaymentMode.counter) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderReceipt(
                orderId: id,
                dataService: widget.dataService,
                onToggleTheme: widget.onToggleTheme,
                isNew: true,
              ),
            ),
          );
        }
      } else {
        // 4. Launch online payment gateway
        if (!mounted) return;
        await _processOnlinePayment(id);
      }
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _processOnlinePayment(String orderId) async {
    final orderList = widget.dataService.allOrdersDirect;
    final createdOrder = orderList.where((o) => o.id == orderId).firstOrNull;
    final orderCode =
        createdOrder?.code ??
        'CP-${orderId.substring(orderId.length > 5 ? orderId.length - 5 : 0).toUpperCase()}';

    final UpiPaymentResult? result = await Navigator.push<UpiPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId: orderId,
          dataService: widget.dataService,
          totalAmount: total,
          orderCode: orderCode,
          studentName: widget.profile.name,
          studentEmail: widget.profile.email,
          pages: pages,
          copies: copies,
          isColor: color,
          isDoubleSided: doubleSided,
          bindingType: bindingType,
          paperType: paperType,
          lamination: lamination,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result.method == PaymentAppMethod.counter) {
      await widget.dataService.updateOrder(orderId, {
        'paymentMode': 'counter',
        'paymentStatus': 'unpaid',
        'status': 'pending',
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderReceipt(
              orderId: orderId,
              dataService: widget.dataService,
              onToggleTheme: widget.onToggleTheme,
              isNew: true,
            ),
          ),
        );
      }
      return;
    }

    if (result != null && result.isPaid) {
      await widget.dataService.updateOrder(orderId, {
        'paymentMode': 'online',
        'paymentMethod': result.method.dbCode,
        'transactionReference': result.transactionReference,
        'paidAt': result.paidAt.toIso8601String(),
        'paymentStatus': 'paid',
        'status': 'pending',
      });
      final updatedOrder =
          (await widget.dataService.order(orderId).first) ?? createdOrder;
      if (mounted && updatedOrder != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              order: updatedOrder,
              dataService: widget.dataService,
              onToggleTheme: widget.onToggleTheme,
            ),
          ),
        );
      }
    } else if (result != null && result.isVerificationPending) {
      await widget.dataService.updateOrder(orderId, {
        'paymentMode': 'online',
        'paymentMethod': result.method.dbCode,
        'transactionReference': result.transactionReference,
        'paymentStatus': 'verification_pending',
        'status': 'pending',
      });
      final updatedOrder =
          (await widget.dataService.order(orderId).first) ?? createdOrder;
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentVerificationPendingScreen(
              order: updatedOrder,
              amount: total,
              onToggleTheme: widget.onToggleTheme,
              onTryAgain: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onChooseAnotherMethod: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onPayAtCounter: () async {
                await widget.dataService.updateOrder(orderId, {
                  'paymentMode': 'counter',
                  'paymentStatus': 'unpaid',
                  'status': 'pending',
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderReceipt(
                        orderId: orderId,
                        dataService: widget.dataService,
                        onToggleTheme: widget.onToggleTheme,
                        isNew: true,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } else if (result != null && result.isFailed) {
      await widget.dataService.updateOrder(orderId, {
        'paymentMode': 'online',
        'paymentStatus': 'failed',
      });
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentFailureScreen(
              amount: total,
              onToggleTheme: widget.onToggleTheme,
              onTryAgain: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onChooseAnotherMethod: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onPayAtCounter: () async {
                await widget.dataService.updateOrder(orderId, {
                  'paymentMode': 'counter',
                  'paymentStatus': 'unpaid',
                  'status': 'pending',
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderReceipt(
                        orderId: orderId,
                        dataService: widget.dataService,
                        onToggleTheme: widget.onToggleTheme,
                        isNew: true,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } else {
      // Cancelled
      await widget.dataService.updateOrder(orderId, {
        'paymentMode': 'online',
        'paymentStatus': 'cancelled',
      });
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentCancelledScreen(
              amount: total,
              onToggleTheme: widget.onToggleTheme,
              onTryAgain: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onChooseAnotherMethod: () {
                Navigator.pop(context);
                _processOnlinePayment(orderId);
              },
              onPayAtCounter: () async {
                await widget.dataService.updateOrder(orderId, {
                  'paymentMode': 'counter',
                  'paymentStatus': 'unpaid',
                  'status': 'pending',
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderReceipt(
                        orderId: orderId,
                        dataService: widget.dataService,
                        onToggleTheme: widget.onToggleTheme,
                        isNew: true,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Print Order',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                // File Picker Box
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  onTap: busy ? null : pickFile,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: file != null
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              file != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_rounded,
                              color: file != null
                                  ? Colors.green
                                  : AppTheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file?.name ?? 'Tap to Select Document',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  file == null
                                      ? 'PDF, Word, PPT, or Image (Total Max: 50 MB / order)'
                                      : '$sizeMb MB of 50 MB max limit • Ready',
                                  style: TextStyle(
                                    color: file != null
                                        ? Colors.green
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12.5,
                                    fontWeight: file != null
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      if (file != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value:
                                (fileSizeBytes /
                                        StorageService.maxFileSizeBytes)
                                    .clamp(0.02, 1.0),
                            backgroundColor: theme.dividerColor.withValues(
                              alpha: 0.1,
                            ),
                            color: AppTheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_isAutoDetecting) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Auto Detect: analyzing page count & colors…',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_autoDetectedPages != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Auto Detect: $_autoDetectedPages Pages (${_detectedColorPages ?? 0} Color, ${_detectedBwPages ?? (_autoDetectedPages! - (_detectedColorPages ?? 0))} B&W)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openAutoDetectScreen,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Auto Detect Details'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openAutoDetectScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Auto Detect',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (busy && uploadProgress > 0) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Uploading to Secure Storage…',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${(uploadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: uploadProgress,
                          backgroundColor: theme.dividerColor.withValues(
                            alpha: 0.1,
                          ),
                          color: AppTheme.primary,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // Privacy notice box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy Auto-Delete: File is automatically deleted from cloud storage once the shopkeeper downloads it.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const PageIntro(
                  title: 'Print Specifications',
                  subtitle: 'Configure your print settings and extra services.',
                ),
                const SizedBox(height: 12),

                // Specifications Panel
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_detectedBwPages != null &&
                          _detectedColorPages != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isAutoDetect
                                ? Colors.green.withValues(alpha: 0.1)
                                : theme.dividerColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isAutoDetect
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : theme.dividerColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: _isAutoDetect
                                    ? Colors.green
                                    : theme.colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto Detect: Mixed Pricing',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: _isAutoDetect
                                            ? Colors.green
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_detectedBwPages ?? 0} B&W × ₹${bwPrintRate.toStringAsFixed(2)} + ${_detectedColorPages ?? 0} Color × ₹${colorPrintRate.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isAutoDetect,
                                onChanged: (v) =>
                                    setState(() => _isAutoDetect = v),
                                // ignore: deprecated_member_use
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                      ],
                      if (!_isAutoDetect) ...[
                        SwitchListTile.adaptive(
                          value: color,
                          onChanged: (v) => setState(() => color = v),
                          title: const Text(
                            'Color Printing',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '₹${(color ? (doubleSided ? widget.prices.colorDouble : widget.prices.colorSingle) : (doubleSided ? widget.prices.bwDouble : widget.prices.bwSingle)).toStringAsFixed(2)} / page',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(height: 1),
                      ],
                      SwitchListTile.adaptive(
                        value: doubleSided,
                        onChanged: (v) => setState(() => doubleSided = v),
                        title: const Text(
                          'Double Sided (Back to Back)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          doubleSided ? 'Enabled' : 'Single sided',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // 1. Dynamic Paper Type Selector (Single Selection)
                      const Text(
                        'Paper Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: enabledPaperTypes.map((p) {
                          final isSel = selectedPaperTypeId == p.id;
                          final extra = p.price > 0
                              ? ' (+₹${p.price.toStringAsFixed(1)})'
                              : '';
                          return _buildSingleOptionCard(
                            label: p.name,
                            extraPrice: extra,
                            isSelected: isSel,
                            onTap: () =>
                                setState(() => selectedPaperTypeId = p.id),
                            theme: theme,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),



                      // 3. Dynamic Binding & Finishing Selector
                      const Text(
                        'Binding & Finishing',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSingleOptionCard(
                            label: 'None',
                            isSelected: selectedBindingId == null,
                            onTap: () =>
                                setState(() => selectedBindingId = null),
                            theme: theme,
                          ),
                          ...enabledBindingOptions.map((b) {
                            final isSel = selectedBindingId == b.id;
                            final extra = b.price > 0
                                ? ' (+₹${b.price.toStringAsFixed(0)})'
                                : '';
                            return _buildSingleOptionCard(
                              label: b.name,
                              extraPrice: extra,
                              isSelected: isSel,
                              onTap: () =>
                                  setState(() => selectedBindingId = b.id),
                              theme: theme,
                            );
                          }),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _counterRow(
                        'Number of Pages',
                        pages,
                        1,
                        (v) => setState(() => pages = v),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _counterRow(
                        'Number of Copies',
                        copies,
                        1,
                        (v) => setState(() => copies = v),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: lamination,
                        onChanged: (v) => setState(() => lamination = v),
                        title: const Text(
                          'Lamination',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '+₹${widget.prices.lamination.toStringAsFixed(0)} / copy',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Special Instructions Box
                      TextField(
                        controller: specialInstructionsCtrl,
                        maxLines: 3,
                        minLines: 2,
                        maxLength: 300,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Special Instructions',
                          helperText:
                              'Add any instructions for the Xerox shopkeeper',
                          hintText:
                              'e.g. Print the first page in color and remaining pages in B&W.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const PageIntro(
                  title: 'Payment Method',
                  subtitle: 'Select how you would like to pay for this order.',
                ),
                const SizedBox(height: 12),

                // Payment Options Panel
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _paymentOption(
                        mode: PaymentMode.online,
                        title: 'Pay Online (UPI / Card / NetBanking)',
                        subtitle:
                            'Instant payment gateway redirection with SSL protection.',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(height: 10),
                      _paymentOption(
                        mode: PaymentMode.counter,
                        title: 'Pay at Counter',
                        subtitle:
                            'Receive a collection code; pay cash/UPI at shop counter.',
                        icon: Icons.storefront_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Summary & Submit Panel
                GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildPrintSummaryBreakdown(theme),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: payment == PaymentMode.online
                              ? 'Pay ₹${total.toStringAsFixed(2)} & Place Order'
                              : 'Place Pay-at-Counter Order',
                          icon: payment == PaymentMode.online
                              ? Icons.lock_outline_rounded
                              : Icons.send_rounded,
                          busy: busy,
                          onPressed: busy ? null : submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintSummaryBreakdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'PRINT SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryItem(
            'Document',
            file?.name ?? 'Document not selected',
            theme,
          ),
          _summaryItem('PDF Pages', '$pages', theme),
          _summaryItem('Printing', color ? 'Color' : 'B&W', theme),
          _summaryItem(
            'Sides',
            doubleSided ? 'Double Side' : 'Single Side',
            theme,
          ),
          _summaryItem(
            'Sheets Required',
            '$sheetsRequired sheets',
            theme,
            isBold: true,
          ),
          _summaryItem('Copies', '$copies', theme),
          _summaryItem('Paper', paperName, theme),
          const Divider(height: 14),
          _summaryItem(
            'Printing Cost',
            '$sheetsRequired sheets × ₹${standardPrintRate.toStringAsFixed(2)} × $copies = ₹${printTotal.toStringAsFixed(2)}',
            theme,
            isHighlight: true,
          ),
          if (selectedBinding != null)
            _summaryItem(
              'Binding & Finishing',
              '$bindingName (₹${bindingCost.toStringAsFixed(2)})',
              theme,
            ),
          if (lamination)
            _summaryItem(
              'Lamination',
              '₹${laminationCost.toStringAsFixed(2)}',
              theme,
            ),
          if (specialInstructionsCtrl.text.trim().isNotEmpty)
            _summaryItem(
              'Instructions',
              specialInstructionsCtrl.text.trim(),
              theme,
            ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold || isHighlight
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: isHighlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required PaymentMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = payment == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => payment = mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2.0 : 1.0,
          ),
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<PaymentMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: payment,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => payment = v!),
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterRow(
    String label,
    int value,
    int min,
    ValueChanged<int> update,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      IconButton(
        onPressed: value > min ? () => update(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline_rounded),
        color: AppTheme.primary,
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      IconButton(
        onPressed: () => update(value + 1),
        icon: const Icon(Icons.add_circle_outline_rounded),
        color: AppTheme.primary,
      ),
    ],
  );

  Widget _buildSingleOptionCard({
    required String label,
    String? extraPrice,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            if (extraPrice != null && extraPrice.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                extraPrice,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.85)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
