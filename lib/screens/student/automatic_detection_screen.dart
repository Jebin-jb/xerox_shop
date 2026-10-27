import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/document_analysis_service.dart';
import '../../services/pdf_page_filter_service.dart';
import '../../services/pdf_thumbnail_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'create_order.dart';

class DocumentPickResult {
  final PlatformFile file;
  final Uint8List bytes;

  const DocumentPickResult({required this.file, required this.bytes});
}

class AutomaticDetectionScreen extends StatefulWidget {
  final DataService dataService;
  final UserProfile profile;
  final VoidCallback onToggleTheme;
  final PlatformFile? initialFile;
  final Uint8List? initialBytes;
  final DocumentAnalysisResult? initialAnalysis;
  final bool isShopkeeperMode;

  const AutomaticDetectionScreen({
    super.key,
    required this.dataService,
    required this.profile,
    required this.onToggleTheme,
    this.initialFile,
    this.initialBytes,
    this.initialAnalysis,
    this.isShopkeeperMode = false,
  });

  static Future<FilePickerResult?> Function()? filePickerOverride;

  static Future<DocumentPickResult?> pickDocument(BuildContext context) async {
    try {
      final FilePickerResult? result;
      if (filePickerOverride != null) {
        result = await filePickerOverride!();
      } else {
        result = await FilePicker.platform.pickFiles(
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
      }

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final picked = result.files.first;
      final len = picked.size;

      if (len > StorageService.maxFileSizeBytes) {
        final sizeMb = (len / (1024 * 1024)).toStringAsFixed(1);
        if (context.mounted) {
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
                'The selected file is $sizeMb MB. Campus Xerox allows files up to a maximum of 50 MB.\n\nPlease select a smaller file.',
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
        return null;
      }

      Uint8List b = picked.bytes ?? Uint8List(0);
      if (b.isEmpty && picked.path != null && !kIsWeb) {
        try {
          final f = File(picked.path!);
          if (await f.exists()) {
            b = await f.readAsBytes();
          }
        } catch (e) {
          debugPrint('Error reading file bytes: $e');
        }
      }

      return DocumentPickResult(file: picked, bytes: b);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
      return null;
    }
  }

  @override
  State<AutomaticDetectionScreen> createState() =>
      _AutomaticDetectionScreenState();
}

class _AutomaticDetectionScreenState extends State<AutomaticDetectionScreen>
    with SingleTickerProviderStateMixin {
  final DocumentAnalysisService _analysisService = DocumentAnalysisService();
  final TextEditingController _specialInstructionsCtrl =
      TextEditingController();

  PlatformFile? _file;
  Uint8List? _bytes;
  DocumentAnalysisResult? _analysis;
  bool _isAnalyzing = false;
  String _scanningStatus = '';

  // Print Configuration Options
  bool _doubleSided = false;
  bool _skipBlankPages = true;
  String? _selectedPaperTypeId;
  String? _selectedGsmId;
  String? _selectedBindingId;
  int _copies = 1;
  bool _lamination = false;

  LiveShopPricing get _livePricing => widget.dataService.currentLivePricing;

  List<PrintConfigItem> get _enabledPaperTypes =>
      _livePricing.paperTypeOptions.where((p) => p.enabled).toList();

  List<PrintConfigItem> get _enabledGsmOptions =>
      _livePricing.gsmOptions.where((g) => g.enabled).toList();

  List<PrintConfigItem> get _enabledBindings =>
      _livePricing.bindingAndFinishingOptions.where((b) => b.enabled).toList();

  PrintConfigItem? get _selectedPaperType {
    if (_selectedPaperTypeId != null) {
      final match = _enabledPaperTypes
          .where((p) => p.id == _selectedPaperTypeId)
          .firstOrNull;
      if (match != null) return match;
    }
    // Default to A4 for every print order
    final a4 = _enabledPaperTypes
        .where((p) => p.name.toUpperCase() == 'A4' || p.id == 'cfg_paper_a4')
        .firstOrNull;
    return a4 ?? _enabledPaperTypes.firstOrNull;
  }

  PrintConfigItem? get _selectedGsm {
    if (_selectedGsmId == null) return null;
    return _enabledGsmOptions.where((g) => g.id == _selectedGsmId).firstOrNull;
  }

  PrintConfigItem? get _selectedBinding {
    if (_selectedBindingId == null) return null;
    return _enabledBindings
        .where((b) => b.id == _selectedBindingId)
        .firstOrNull;
  }

  late AnimationController _scanAnimController;
  StreamSubscription<LiveShopPricing>? _pricingSub;

  @override
  void initState() {
    super.initState();
    // Set A4 as the default paper size
    final defaultA4 =
        _enabledPaperTypes
            .where(
              (p) => p.name.toUpperCase() == 'A4' || p.id == 'cfg_paper_a4',
            )
            .firstOrNull ??
        _enabledPaperTypes.firstOrNull;
    if (defaultA4 != null) {
      _selectedPaperTypeId = defaultA4.id;
    }

    _pricingSub = widget.dataService.livePricing().listen((_) {
      if (mounted) {
        if (_selectedPaperTypeId == null) {
          final a4 =
              _enabledPaperTypes
                  .where(
                    (p) =>
                        p.name.toUpperCase() == 'A4' || p.id == 'cfg_paper_a4',
                  )
                  .firstOrNull ??
              _enabledPaperTypes.firstOrNull;
          if (a4 != null) _selectedPaperTypeId = a4.id;
        }
        setState(() {});
      }
    });

    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (widget.initialAnalysis != null) {
      _analysis = widget.initialAnalysis;
      _file =
          widget.initialFile ??
          PlatformFile(
            name: widget.initialAnalysis!.fileName,
            size: widget.initialAnalysis!.fileSizeBytes,
            bytes: Uint8List(0),
          );
    } else if (widget.initialFile != null && widget.initialBytes != null) {
      _file = widget.initialFile;
      _bytes = widget.initialBytes;
      _runAnalysis(widget.initialFile!.name, widget.initialBytes!);
    }
  }

  @override
  void didUpdateWidget(covariant AutomaticDetectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAnalysis != null &&
        widget.initialAnalysis != oldWidget.initialAnalysis) {
      setState(() {
        _analysis = widget.initialAnalysis;
        _file =
            widget.initialFile ??
            PlatformFile(
              name: widget.initialAnalysis!.fileName,
              size: widget.initialAnalysis!.fileSizeBytes,
              bytes: Uint8List(0),
            );
      });
    }
  }

  @override
  void dispose() {
    _pricingSub?.cancel();
    _scanAnimController.dispose();
    _specialInstructionsCtrl.dispose();
    if (_file != null && _bytes != null) {
      PdfThumbnailService().clearDocumentCache(
        '${_file!.name}_${_bytes!.length}',
      );
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final pickedResult = await AutomaticDetectionScreen.pickDocument(context);
    if (pickedResult != null && mounted) {
      setState(() {
        _file = pickedResult.file;
        _bytes = pickedResult.bytes;
      });
      await _runAnalysis(pickedResult.file.name, pickedResult.bytes);
    }
  }

  Future<void> _runAnalysis(String name, Uint8List bytes) async {
    setState(() {
      _isAnalyzing = true;
      _scanningStatus = 'Scanning document binary stream…';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(
        () => _scanningStatus = 'Detecting page catalog and page count…',
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _scanningStatus = 'Analyzing document pages & colors…');
    }

    final result = await _analysisService.analyzeDocument(
      fileName: name,
      bytes: bytes,
    );

    if (mounted) {
      setState(() {
        _analysis = result;
        _isAnalyzing = false;
        _scanningStatus = '';
      });
    }
  }

  void _togglePageColor(int index) {
    if (_analysis == null) return;
    final p = _analysis!.pages[index];
    if (p.isRemoved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This page is excluded. Long-press to restore it.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      p.isColor = !p.isColor;
    });
  }

  void _togglePageRemoval(int index) {
    if (_analysis == null) return;
    setState(() {
      final p = _analysis!.pages[index];
      if (!p.isRemoved) {
        p.previousPrintType = p.printType;
        p.isRemoved = true;
      } else {
        p.isRemoved = false;
        if (p.previousPrintType != null) {
          p.printType = p.previousPrintType!;
        }
      }
    });
  }

  void _applyToAllPages(PrintType type) {
    if (_analysis == null) return;
    setState(() {
      for (final p in _analysis!.pages) {
        if (!p.isRemoved) {
          p.printType = type;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == PrintType.color
              ? 'Applied Colour to all included pages'
              : 'Applied B&W to all included pages',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyToAllOrientation(String orient) {
    if (_analysis == null) return;
    setState(() {
      for (final p in _analysis!.pages) {
        if (!p.isRemoved) {
          p.orientation = orient;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied $orient orientation to all included pages'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _proceedToOrder(ShopPrice prices) async {
    if (_file == null || _analysis == null) return;

    _selectedPaperTypeId ??= _selectedPaperType?.id;
    if (_selectedPaperTypeId == null && _enabledPaperTypes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Paper Type.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_copies < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least 1 copy.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final includedPages = _analysis!.pages
        .where((p) => !p.isRemoved && (!_skipBlankPages || !p.isBlank))
        .toList();

    if (includedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All pages are removed. Please include at least one page to print.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final printablePageNumbers = includedPages
        .map((p) => p.pageNumber)
        .toList();
    final bwPages = includedPages.where((p) => !p.isColor).length;
    final colorPages = includedPages.where((p) => p.isColor).length;

    // Generate filtered printable PDF containing ONLY included pages
    Uint8List printableBytes = _bytes ?? Uint8List(0);
    final isPdf = _file!.name.toLowerCase().endsWith('.pdf');
    if (isPdf &&
        _bytes != null &&
        _bytes!.isNotEmpty &&
        printablePageNumbers.length < _analysis!.totalPages) {
      printableBytes = await PdfPageFilterService().generateSelectedPagesPdf(
        sourceBytes: _bytes!,
        selectedPages: printablePageNumbers,
      );
    }

    final pageSelectionStr =
        printablePageNumbers.length == _analysis!.totalPages
        ? 'All ${_analysis!.totalPages} pages'
        : PdfPageFilterService().formatPageRanges(printablePageNumbers);

    final finalCost = _calculateTotalCost(prices);

    final printableColorPageNumbers = <int>[];
    final pageSettings = <PagePrintSetting>[];
    for (int i = 0; i < includedPages.length; i++) {
      final p = includedPages[i];
      final printablePageNum = i + 1;
      if (p.isColor) {
        printableColorPageNumbers.add(printablePageNum);
      }
      pageSettings.add(
        PagePrintSetting(
          pageNumber: printablePageNum,
          printType: p.printType,
          unitPrice: p.isColor
              ? (_doubleSided ? prices.colorDouble : prices.colorSingle)
              : (_doubleSided ? prices.bwDouble : prices.bwSingle),
          orientation: p.orientation,
        ),
      );
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrder(
          dataService: widget.dataService,
          profile: widget.profile,
          prices: prices,
          onToggleTheme: widget.onToggleTheme,
          prefilledFile: _file,
          prefilledBytes: printableBytes,
          originalBytes: _bytes,
          prefilledPages: includedPages.length,
          prefilledTotalDocumentPages: _analysis!.totalPages,
          prefilledSelectedPages: printablePageNumbers,
          prefilledPageSelection: pageSelectionStr,
          prefilledBwPages: bwPages,
          prefilledColorPages: colorPages,
          prefilledRemovedPages: _analysis!.totalPages - includedPages.length,
          prefilledColorPageNumbers: printableColorPageNumbers,
          prefilledColor: colorPages > 0,
          prefilledDoubleSided: _doubleSided,
          prefilledCopies: _copies,
          prefilledLamination: _lamination,
          prefilledPageSettings: pageSettings,
          prefilledPaperTypeId: _selectedPaperTypeId,
          prefilledGsmId: _selectedGsmId,
          prefilledBindingId: _selectedBindingId,
          prefilledSpecialInstructions: _specialInstructionsCtrl.text.trim(),
          prefilledTotalAmount: finalCost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<ShopPrice>(
      stream: widget.dataService.prices(),
      builder: (context, snap) {
        final prices =
            snap.data ??
            ShopPrice(
              bwSingle: 1.0,
              bwDouble: 1.5,
              colorSingle: 5.0,
              colorDouble: 8.0,
              photocopy: 1.0,
              lamination: 10.0,
              updatedAt: DateTime.now(),
            );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isShopkeeperMode
                      ? Icons.print_rounded
                      : Icons.description_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.isShopkeeperMode
                        ? 'Shopkeeper Order'
                        : (_file != null || _analysis != null
                              ? 'Per-Page Inspection'
                              : 'Documents'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: [
                    // File Picker / Upload Box (Direct document selection)
                    _buildUploadBox(theme),
                    const SizedBox(height: 18),

                    // Scanning indicator
                    if (_isAnalyzing) ...[
                      _buildScanningAnimation(theme),
                      const SizedBox(height: 18),
                    ],

                    // Results section
                    if (_analysis != null && !_isAnalyzing) ...[
                      _buildSummaryCards(theme, prices),
                      const SizedBox(height: 18),
                      _buildPageGrid(theme),
                      const SizedBox(height: 18),
                      _buildStudentSummary(theme),
                      const SizedBox(height: 18),
                      _buildPrintOptionsCard(theme),
                      const SizedBox(height: 18),
                      _buildSpecialInstructionsCard(theme),
                    ],
                  ],
                ),
              ),

              // Bottom Sticky Action Bar
              if (_analysis != null && !_isAnalyzing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomBar(theme, prices),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadBox(ThemeData theme) {
    final sizeMb = _file != null
        ? (_file!.size / (1024 * 1024)).toStringAsFixed(1)
        : '0';

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      onTap: _isAnalyzing ? null : _pickFile,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _file != null ? Colors.green : AppTheme.primary,
                      _file != null ? Colors.teal : const Color(0xFF00A2FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_file != null ? Colors.green : AppTheme.primary)
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _file != null
                      ? Icons.check_circle_rounded
                      : Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _file?.name ?? 'Tap to Select Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _file == null
                          ? 'PDF, Word, PPT, or Image (Up to 50 MB)'
                          : '$sizeMb MB • Ready for inspection',
                      style: TextStyle(
                        color: _file != null
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: _file != null
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _isAnalyzing ? null : _pickFile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(_file == null ? 'Browse' : 'Change'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scanAnimController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.95 + (_scanAnimController.value * 0.1),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF6750F4), Color(0xFF00A2FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF6750F4,
                        ).withValues(alpha: 0.3 * _scanAnimController.value),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            _scanningStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, ShopPrice prices) {
    final result = _analysis!;
    final total = result.totalPages;
    final color = result.colorPagesCount;
    final bw = result.bwPagesCount;
    final blanks = result.blankPagesCount;
    final sheets = result.sheetsNeeded(
      doubleSided: _doubleSided,
      skipBlankPages: _skipBlankPages,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detection Results',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Analysis Complete',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Metrics Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _metricPill(
              title: 'Total Pages',
              value: '$total',
              subtitle: 'Document pages',
              icon: Icons.auto_stories_rounded,
              color: AppTheme.primary,
            ),
            _metricPill(
              title: 'Physical Sheets',
              value: '$sheets',
              subtitle: _doubleSided ? 'Double-sided' : 'Single-sided',
              icon: Icons.layers_rounded,
              color: const Color(0xFF00A2FF),
            ),
            _metricPill(
              title: 'Color Pages',
              value: '$color',
              subtitle: 'Color pages',
              icon: Icons.palette_rounded,
              color: Colors.purpleAccent,
            ),
            _metricPill(
              title: 'B&W Pages',
              value: '$bw',
              subtitle: blanks > 0
                  ? '$bw text + $blanks blank'
                  : 'Black & white',
              icon: Icons.filter_b_and_w_rounded,
              color: Colors.blueGrey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricPill({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  static const ColorFilter _grayscaleMatrixFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  Widget _buildStudentSummary(ThemeData theme) {
    if (_analysis == null) return const SizedBox.shrink();
    final originalTotal = _analysis!.totalPages;
    final includedPages = _analysis!.pages
        .where((p) => !p.isRemoved && (!_skipBlankPages || !p.isBlank))
        .toList();
    final colorPages = includedPages
        .where((p) => p.isColor)
        .map((p) => p.pageNumber)
        .toList();

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Student Print Summary',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Original Pages: $originalTotal',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (colorPages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Colour Pages: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      PdfPageFilterService().formatPageRanges(colorPages),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageGrid(ThemeData theme) {
    final pages = _analysis!.pages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per-Page Visual Inspection',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Apply To All Pages',
              onSelected: (val) {
                if (val == 'bw') _applyToAllPages(PrintType.bw);
                if (val == 'color') _applyToAllPages(PrintType.color);
                if (val == 'portrait') _applyToAllOrientation('Portrait');
                if (val == 'landscape') _applyToAllOrientation('Landscape');
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'bw',
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_b_and_w_rounded,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(width: 8),
                      Text('Set All to B&W'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'color',
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        size: 18,
                        color: Color(0xFF8B5CF6),
                      ),
                      SizedBox(width: 8),
                      Text('Set All to Color'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'portrait',
                  child: Row(
                    children: [
                      Icon(
                        Icons.stay_current_portrait_rounded,
                        size: 18,
                        color: Colors.teal,
                      ),
                      SizedBox(width: 8),
                      Text('Set All to Portrait'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'landscape',
                  child: Row(
                    children: [
                      Icon(
                        Icons.stay_current_landscape_rounded,
                        size: 18,
                        color: Colors.indigo,
                      ),
                      SizedBox(width: 8),
                      Text('Set All to Landscape'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'APPLY TO ALL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                '${pages.length} Pages',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lazy-loaded horizontal preview for all pages
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = pages[i];
              return _pageThumbnail(p, i, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _pageThumbnail(PageAnalysis p, int index, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isRemoved = p.isRemoved;
    final isColor = p.isColor && !p.isBlank;
    final isBlank = p.isBlank;

    return GestureDetector(
      onTap: () => _togglePageColor(index),
      onLongPress: () => _togglePageRemoval(index),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isRemoved ? 0.38 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 144,
          decoration: BoxDecoration(
            color: isRemoved
                ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRemoved
                  ? Colors.redAccent.withValues(alpha: 0.45)
                  : isBlank
                  ? Colors.grey.withValues(alpha: 0.3)
                  : isColor
                  ? const Color(0xFF8B5CF6)
                  : (isDark ? Colors.blueGrey.shade700 : Colors.grey.shade400),
              width: isRemoved ? 1.5 : (isColor ? 2 : 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: isRemoved
                    ? Colors.transparent
                    : isColor
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page Number Header
              Text(
                'Page ${p.pageNumber} of ${_analysis!.pages.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  decoration: isRemoved ? TextDecoration.lineThrough : null,
                  color: isRemoved
                      ? Colors.redAccent.withValues(alpha: 0.7)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Actual Page Preview Canvas / Thumbnail
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isRemoved
                              ? Colors.redAccent.withValues(alpha: 0.35)
                              : Colors.grey.shade300,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isBlank
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.crop_portrait_rounded,
                                    size: 24,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'BLANK PAGE',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ColorFiltered(
                              colorFilter: isColor
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.multiply,
                                    )
                                  : _grayscaleMatrixFilter,
                              child: _buildRealPageThumbnail(p),
                            ),
                    ),
                    if (isRemoved)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.block_rounded,
                              color: Colors.white70,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealPageThumbnail(PageAnalysis p) {
    final fileName = _file?.name.toLowerCase() ?? '';
    final hasBytes = _bytes != null && _bytes!.isNotEmpty;
    final isPdf = fileName.endsWith('.pdf');
    final isImage =
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png');

    if (hasBytes && isPdf) {
      final docKey = '${_file?.name ?? 'doc'}_${_bytes!.length}';
      final cached = PdfThumbnailService().getCachedThumbnail(
        docKey,
        p.pageNumber,
      );
      if (cached != null) {
        return Image.memory(
          cached,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        );
      }

      return FutureBuilder<Uint8List?>(
        future: PdfThumbnailService().getPageThumbnail(
          documentKey: docKey,
          bytes: _bytes!,
          pageNumber: p.pageNumber,
          targetWidth: 160,
          targetHeight: 220,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            );
          }
          if (snapshot.hasError) {
            return _buildVectorDocumentSheet(p);
          }
          return _buildThumbnailLoadingSkeleton(p);
        },
      );
    } else if (hasBytes && isImage) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }

    return _buildVectorDocumentSheet(p);
  }

  Widget _buildThumbnailLoadingSkeleton(PageAnalysis p) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Page ${p.pageNumber}',
            style: const TextStyle(
              fontSize: 8,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVectorDocumentSheet(PageAnalysis p) {
    final hasChart = (p.pageNumber % 3 == 0) || (p.pageNumber == 1);
    final hasBanner = (p.pageNumber == 1) || (p.pageNumber % 4 == 0);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBanner)
            Container(
              height: 14,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFF6750F4),
              ),
              child: Center(
                child: Container(
                  height: 3,
                  width: 35,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            )
          else ...[
            Container(
              height: 4,
              width: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Container(height: 2.5, width: 75, color: Colors.grey.shade400),
          const SizedBox(height: 3),
          Container(height: 2.5, width: 65, color: Colors.grey.shade300),
          const SizedBox(height: 3),
          Container(height: 2.5, width: 70, color: Colors.grey.shade300),
          const SizedBox(height: 5),
          if (hasChart)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      height: 18,
                      width: 7,
                      color: const Color(0xFF3B82F6),
                    ),
                    Container(
                      height: 28,
                      width: 7,
                      color: const Color(0xFF10B981),
                    ),
                    Container(
                      height: 38,
                      width: 7,
                      color: const Color(0xFFF59E0B),
                    ),
                    Container(
                      height: 22,
                      width: 7,
                      color: const Color(0xFFEC4899),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 2.5,
                    width: 78,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: 72,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: 55,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: 74,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: 68,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: 60,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 2, width: 25, color: Colors.grey.shade400),
              Text(
                '${p.pageNumber}',
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
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

  Widget _buildPrintOptionsCard(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Print Configuration',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Double Sided
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              value: _doubleSided,
              onChanged: (v) => setState(() => _doubleSided = v),
              title: const Text(
                'Double Sided (Back to Back)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _doubleSided
                    ? 'Reduces sheets to ${(_analysis!.totalPages / 2).ceil()}'
                    : 'Single sided prints',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_analysis != null && _analysis!.blankPagesCount > 0) ...[
            const Divider(height: 1),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                value: _skipBlankPages,
                onChanged: (v) => setState(() => _skipBlankPages = v),
                title: Text(
                  'Skip ${_analysis!.blankPagesCount} Blank / Empty Pages',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: const Text(
                  'Exclude blank pages to save paper and printing fees.',
                  style: TextStyle(fontSize: 11),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 1. Dynamic Paper Type (Single Selection)
          const Text(
            'Paper Type',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _enabledPaperTypes.map((p) {
              final isSel = _selectedPaperTypeId == p.id;
              final extra = p.price > 0
                  ? ' (+₹${p.price.toStringAsFixed(1)})'
                  : '';
              return _buildSingleOptionCard(
                label: p.name,
                extraPrice: extra,
                isSelected: isSel,
                onTap: () => setState(() => _selectedPaperTypeId = p.id),
                theme: theme,
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 3. Finishing & Binding
          const Text(
            'Finishing & Binding',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSingleOptionCard(
                label: 'None',
                isSelected: _selectedBindingId == null,
                onTap: () => setState(() => _selectedBindingId = null),
                theme: theme,
              ),
              ..._enabledBindings.map((b) {
                final isSel = _selectedBindingId == b.id;
                final extra = b.price > 0
                    ? ' (+₹${b.price.toStringAsFixed(0)})'
                    : '';
                return _buildSingleOptionCard(
                  label: b.name,
                  extraPrice: extra,
                  isSelected: isSel,
                  onTap: () => setState(() => _selectedBindingId = b.id),
                  theme: theme,
                );
              }),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Number of Copies
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Number of Copies',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text(
                '$_copies',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _copies++),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const Divider(height: 1),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              value: _lamination,
              onChanged: (v) => setState(() => _lamination = v),
              title: const Text(
                'Document Lamination',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '+₹10 / copy (Protective gloss film)',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialInstructionsCard(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Special Instructions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _specialInstructionsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText:
                  'e.g. Please staple top-left, print cover page in high quality…',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalCost(ShopPrice prices) {
    if (_analysis == null) return 0.0;
    final effectivePages = _analysis!.pages
        .where((p) => !p.isRemoved && (!_skipBlankPages || !p.isBlank))
        .toList();
    if (effectivePages.isEmpty) return 0.0;

    final paperExtra = _selectedPaperType?.price ?? 0.0;
    final gsmExtra = _selectedGsm?.price ?? 0.0;
    final perPageExtra = paperExtra + gsmExtra;

    final bwPages = effectivePages.where((p) => !p.isColor).length;
    final colorPages = effectivePages.where((p) => p.isColor).length;

    final double basePrintTotal;
    if (_doubleSided) {
      final bwSheets = (bwPages / 2).ceil();
      final colorSheets = (colorPages / 2).ceil();
      basePrintTotal =
          (bwSheets * (prices.bwDouble + perPageExtra)) +
          (colorSheets * (prices.colorDouble + perPageExtra));
    } else {
      basePrintTotal =
          (bwPages * (prices.bwSingle + perPageExtra)) +
          (colorPages * (prices.colorSingle + perPageExtra));
    }

    final printTotal = basePrintTotal * _copies;
    final bindingExtra = (_selectedBinding?.price ?? 0.0) * _copies;
    final laminationExtra = (_lamination ? prices.lamination : 0.0) * _copies;

    return printTotal + bindingExtra + laminationExtra;
  }

  Widget _buildBottomBar(ThemeData theme, ShopPrice prices) {
    final cost = _calculateTotalCost(prices);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CALCULATED TOTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '₹${cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _proceedToOrder(prices),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Proceed to Print Order'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
