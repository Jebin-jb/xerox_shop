import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/pdf_page_filter_service.dart';
import '../../services/storage_service.dart';
import '../../services/payment/payment_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
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
  final Uint8List? originalBytes;
  final int? prefilledPages;
  final int? prefilledTotalDocumentPages;
  final int? prefilledRemovedPages;
  final String? prefilledSpecialInstructions;
  final double? prefilledTotalAmount;
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
  final List<int>? prefilledSelectedPages;
  final String? prefilledPageSelection;
  final List<PrintConfigItem>? prefilledAdditionalServices;

  const CreateOrder({
    super.key,
    required this.dataService,
    required this.profile,
    required this.prices,
    required this.onToggleTheme,
    this.prefilledFile,
    this.prefilledBytes,
    this.originalBytes,
    this.prefilledPages,
    this.prefilledTotalDocumentPages,
    this.prefilledRemovedPages,
    this.prefilledSpecialInstructions,
    this.prefilledTotalAmount,
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
    this.prefilledSelectedPages,
    this.prefilledPageSelection,
    this.prefilledAdditionalServices,
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
  int? _detectedColorPages;
  int? _detectedBwPages;
  List<int> _colorPageNumbers = const [];

  int _totalDocumentPages = 1;
  int _removedPages = 0;
  String _pageSelectionStr = '';
  double? _prefilledTotalAmount;
  bool _isCustomPageSelection = false;
  final TextEditingController _pageRangeCtrl = TextEditingController();
  List<int> _selectedPageNumbers = const [];

  final specialInstructionsCtrl = TextEditingController();
  String? selectedPaperTypeId;
  String? selectedGsmId;
  String? selectedBindingId;
  StreamSubscription<LiveShopPricing>? _pricingSub;

  @override
  void initState() {
    super.initState();
    _pricingSub = widget.dataService.livePricing().listen((_) {
      if (mounted) setState(() {});
    });
    _applyPrefilled();
  }

  void _applyPrefilled() {
    selectedPaperTypeId =
        widget.prefilledPaperTypeId ??
        (enabledPaperTypes
                    .where(
                      (i) =>
                          i.name.toUpperCase() == 'A4' ||
                          i.id == 'cfg_paper_a4',
                    )
                    .firstOrNull ??
                enabledPaperTypes.firstOrNull)
            ?.id;
    selectedGsmId = widget.prefilledGsmId;
    selectedBindingId = widget.prefilledBindingId;

    if (widget.prefilledSpecialInstructions != null) {
      specialInstructionsCtrl.text = widget.prefilledSpecialInstructions!;
    }
    if (widget.prefilledTotalAmount != null) {
      _prefilledTotalAmount = widget.prefilledTotalAmount;
    }

    if (widget.prefilledFile != null) {
      file = widget.prefilledFile;
      bytes = widget.prefilledBytes;
      fileSizeBytes =
          widget.prefilledBytes?.length ?? widget.prefilledFile!.size;
      _totalDocumentPages =
          widget.prefilledTotalDocumentPages ?? widget.prefilledPages ?? 1;
      pages = widget.prefilledPages ?? 1;
      _removedPages =
          widget.prefilledRemovedPages ?? (_totalDocumentPages - pages);
      if (_removedPages < 0) _removedPages = 0;
      color = widget.prefilledColor ?? false;
      doubleSided = widget.prefilledDoubleSided ?? false;
      paperType = widget.prefilledPaperType ?? PaperType.standard75Gsm;
      bindingType = widget.prefilledBindingType ?? BindingType.none;
      copies = widget.prefilledCopies ?? 1;
      lamination = widget.prefilledLamination ?? false;
      _detectedBwPages = widget.prefilledBwPages;
      _detectedColorPages = widget.prefilledColorPages;
      _colorPageNumbers = widget.prefilledColorPageNumbers ?? const [];
      if (widget.prefilledSelectedPages != null &&
          widget.prefilledSelectedPages!.isNotEmpty) {
        _isCustomPageSelection = true;
        _selectedPageNumbers = widget.prefilledSelectedPages!;
        _pageSelectionStr =
            widget.prefilledPageSelection ??
            PdfPageFilterService().formatPageRanges(_selectedPageNumbers);
        _pageRangeCtrl.text = _pageSelectionStr;
        pages = _selectedPageNumbers.length;
      } else if (widget.prefilledPageSelection != null) {
        _pageSelectionStr = widget.prefilledPageSelection!;
      }
    }
  }

  @override
  void didUpdateWidget(covariant CreateOrder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefilledFile != oldWidget.prefilledFile ||
        widget.prefilledBytes != oldWidget.prefilledBytes ||
        widget.prefilledPages != oldWidget.prefilledPages ||
        widget.prefilledTotalAmount != oldWidget.prefilledTotalAmount) {
      setState(() {
        _applyPrefilled();
      });
    }
  }

  @override
  void dispose() {
    _pricingSub?.cancel();
    _pageRangeCtrl.dispose();
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
    if (selectedPaperTypeId != null) {
      final match = enabledPaperTypes
          .where((i) => i.id == selectedPaperTypeId)
          .firstOrNull;
      if (match != null) return match;
    }
    final a4 = enabledPaperTypes
        .where((i) => i.name.toUpperCase() == 'A4' || i.id == 'cfg_paper_a4')
        .firstOrNull;
    return a4 ?? enabledPaperTypes.firstOrNull;
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
    int activeColorCount;
    int activeBwCount;

    if (_isCustomPageSelection && _selectedPageNumbers.isNotEmpty) {
      if (_colorPageNumbers.isNotEmpty) {
        activeColorCount = _selectedPageNumbers
            .where((p) => _colorPageNumbers.contains(p))
            .length;
        activeBwCount = _selectedPageNumbers.length - activeColorCount;
      } else {
        activeColorCount = color ? _selectedPageNumbers.length : 0;
        activeBwCount = color ? 0 : _selectedPageNumbers.length;
      }
    } else {
      activeBwCount = _detectedBwPages ?? (color ? 0 : pages);
      activeColorCount = _detectedColorPages ?? (color ? pages : 0);
    }

    final bwRate =
        (doubleSided
            ? livePricing.printingPrices.bwDoublePerSheet
            : livePricing.printingPrices.bwSinglePerSheet) +
        paperRate +
        gsmRate;
    final colorRate =
        (doubleSided
            ? livePricing.printingPrices.colorDoublePerSheet
            : livePricing.printingPrices.colorSinglePerSheet) +
        paperRate +
        gsmRate;

    if (doubleSided) {
      final colorSheets = (activeColorCount / 2).ceil();
      final bwSheets = (activeBwCount / 2).ceil();
      return (colorSheets * colorRate + bwSheets * bwRate) * copies;
    } else {
      return (activeColorCount * colorRate + activeBwCount * bwRate) * copies;
    }
  }

  double get laminationCost {
    if (!lamination) return 0.0;
    final match = livePricing.configItems
        .where((i) => i.name.toLowerCase().contains('lamination') && i.enabled)
        .firstOrNull;
    final unitPrice =
        match?.price ??
        (livePricing.laminationTypes.isNotEmpty
            ? livePricing.laminationTypes.first.price
            : 10.0);
    return unitPrice * copies;
  }

  double get additionalServicesCost => 0.0;

  double get total {
    if (_prefilledTotalAmount != null && _prefilledTotalAmount! > 0) {
      return _prefilledTotalAmount!;
    }
    return printTotal + laminationCost + bindingCost;
  }

  Future<void> submit() async {
    if (file == null) {
      return _show('Please choose a document to print.');
    }
    if (copies < 1) {
      return _show('Please enter at least 1 copy.');
    }
    selectedPaperTypeId ??= enabledPaperTypes.isNotEmpty
        ? enabledPaperTypes.first.id
        : null;

    setState(() {
      busy = true;
      uploadProgress = 0.1;
    });

    try {
      Uint8List printableBytes = bytes ?? Uint8List(0);
      int printablePages = pages;
      String? pageSelectionStr = _pageSelectionStr.isNotEmpty
          ? _pageSelectionStr
          : null;
      final isPdf = file!.name.toLowerCase().endsWith('.pdf');

      if (widget.originalBytes == null &&
          _isCustomPageSelection &&
          _selectedPageNumbers.isNotEmpty) {
        printablePages = _selectedPageNumbers.length;
        pageSelectionStr = PdfPageFilterService().formatPageRanges(
          _selectedPageNumbers,
        );
        if (isPdf && printableBytes.isNotEmpty) {
          printableBytes = await PdfPageFilterService()
              .generateSelectedPagesPdf(
                sourceBytes: printableBytes,
                selectedPages: _selectedPageNumbers,
              );
        }
      }

      // 1. Upload to Supabase/Vault storage with progress
      final url = await StorageService().upload(
        uid: widget.profile.id,
        fileName: file!.name,
        bytes: printableBytes,
        onProgress: (p) {
          if (mounted) {
            setState(() => uploadProgress = p);
          }
        },
      );

      int bwCount = _detectedBwPages ?? (color ? 0 : printablePages);
      int colorCount = _detectedColorPages ?? (color ? printablePages : 0);
      List<int> finalColorPageNumbers = _colorPageNumbers;

      if (widget.originalBytes == null &&
          _isCustomPageSelection &&
          _selectedPageNumbers.isNotEmpty) {
        if (_colorPageNumbers.isNotEmpty) {
          finalColorPageNumbers = _selectedPageNumbers
              .where((p) => _colorPageNumbers.contains(p))
              .toList();
          colorCount = finalColorPageNumbers.length;
          bwCount = _selectedPageNumbers.length - colorCount;
        } else {
          colorCount = color ? printablePages : 0;
          bwCount = color ? 0 : printablePages;
          finalColorPageNumbers = color
              ? List.generate(printablePages, (i) => i + 1)
              : <int>[];
        }
      }

      final List<PagePrintSetting> finalPageSettings =
          widget.prefilledPageSettings ??
          List.generate(
            printablePages,
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
        'pdfPages': printablePages,
        'total_pages': printablePages,
        'originalPages': _totalDocumentPages,
        'removedPages': _removedPages,
        'originalFileName': file!.name,
        'pageSelection': pageSelectionStr,
        'bw_page_count': bwCount,
        'color_page_count': colorCount,
        'color_page_numbers': finalColorPageNumbers,
        'page_settings': finalPageSettings
            .whereType<PagePrintSetting>()
            .map((s) => s.toMap())
            .toList(),
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
          'additional_services_cost': additionalServicesCost,
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
          'id': selectedPaperType?.id ?? 'std',
          'name': selectedPaperType?.name ?? 'Standard Paper',
          'price': selectedPaperType?.price ?? 0.0,
        },
        'paperTypeName': selectedPaperType?.name ?? 'Standard Paper',
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
        fileSizeBytes: printableBytes.length,
        pages: printablePages,
        copies: copies,
        color: colorCount > 0,
        doubleSided: doubleSided,
        lamination: lamination,
        binding: selectedBinding != null,
        paperType: paperType,
        bindingType: bindingType,
        paperTypeName: selectedPaperType?.name ?? 'Standard Paper',
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
        originalFileName: file!.name,
        pageSelection: pageSelectionStr,
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
    final orderCode = createdOrder?.code ?? widget.dataService.newCode();

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
    final isDark = theme.brightness == Brightness.dark;

    if (file == null) {
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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 56,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Document Configured',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please select and configure your document in Auto Detect first.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Go to Auto Detect',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

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
                // 1. Compact Read-Only Print Summary
                _buildReadOnlyPrintSummary(theme, sizeMb),

                const SizedBox(height: 18),

                // 2. Payment Method
                const PageIntro(
                  title: 'Payment Method',
                  subtitle: 'Select how you would like to pay for this order.',
                ),
                const SizedBox(height: 10),
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _paymentOption(
                        mode: PaymentMode.online,
                        title: 'Online Pay',
                        subtitle:
                            'UPI, Cards, NetBanking with instant confirmation.',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(height: 10),
                      _paymentOption(
                        mode: PaymentMode.counter,
                        title: 'Pay at Counter',
                        subtitle:
                            'Pay cash or UPI at the shop counter with collection code.',
                        icon: Icons.storefront_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Total Amount & 4. Pay / Confirm Order Button
                GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (busy && uploadProgress > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Uploading Document…',
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
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TOTAL AMOUNT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '$pages printable ${pages == 1 ? "page" : "pages"} • $copies ${copies > 1 ? "copies" : "copy"}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                              ? 'Proceed to Pay'
                              : 'Confirm Order',
                          icon: payment == PaymentMode.online
                              ? Icons.lock_outline_rounded
                              : Icons.check_circle_outline_rounded,
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

  Widget _buildReadOnlyPrintSummary(ThemeData theme, String sizeMb) {
    final int originalPages = _totalDocumentPages > 0
        ? _totalDocumentPages
        : pages;
    final int printablePages = pages;
    final int bwCount = _detectedBwPages ?? (color ? 0 : pages);
    final int colorCount = _detectedColorPages ?? (color ? pages : 0);
    final int removedCount = _removedPages > 0
        ? _removedPages
        : ((originalPages - printablePages) > 0
              ? (originalPages - printablePages)
              : 0);

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$originalPages Original Pages • $sizeMb MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _summaryRow(
            'Selected Printable Pages',
            '$printablePages pages${_pageSelectionStr.isNotEmpty ? " ($_pageSelectionStr)" : ""}',
            theme,
            isBold: true,
          ),
          _summaryRow('B&W Pages', '$bwCount', theme),
          _summaryRow('Colour Pages', '$colorCount', theme),
          _summaryRow(
            'Removed Pages',
            '$removedCount',
            theme,
            isRemoved: removedCount > 0,
          ),
          _summaryRow('Copies', '$copies', theme),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _summaryRow(
            'Print Sides',
            doubleSided ? 'Double Side (Back to Back)' : 'Single Side',
            theme,
          ),
          _summaryRow('Paper Type', paperName, theme),
          if (selectedBinding != null)
            _summaryRow('Binding', bindingName, theme),
          if (lamination)
            _summaryRow(
              'Lamination',
              'Included (+₹${laminationCost.toStringAsFixed(2)})',
              theme,
            ),
          if (specialInstructionsCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Special Instructions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                specialInstructionsCtrl.text.trim(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
    bool isRemoved = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isRemoved
                  ? Colors.red
                  : (isBold
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface),
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
}
