import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

class DocumentPreviewDialog extends StatefulWidget {
  final PrintOrder order;
  final VoidCallback? onDeleteAfterPrint;

  const DocumentPreviewDialog({
    super.key,
    required this.order,
    this.onDeleteAfterPrint,
  });

  @override
  State<DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<DocumentPreviewDialog> {
  bool _loading = true;
  Uint8List? _fileBytes;
  String? _errorMessage;
  bool _savingToDevice = false;
  PdfControllerPinch? _pdfController;
  int _pdfPage = 1;
  int _totalPdfPages = 0;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    if (widget.order.isPurged || widget.order.fileUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'This document has been removed and securely purged from storage.';
          _loading = false;
        });
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final storage = StorageService();
      final bytes = await storage.downloadFile(widget.order.fileUrl);
      if (mounted) {
        if (bytes != null &&
            bytes.isNotEmpty &&
            widget.order.fileName.toLowerCase().endsWith('.pdf')) {
          try {
            _pdfController = PdfControllerPinch(
              document: PdfDocument.openData(bytes),
            );
          } catch (e) {
            debugPrint('Could not initialize PdfControllerPinch: $e');
          }
        }
        setState(() {
          _fileBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportToDevice() async {
    setState(() => _savingToDevice = true);
    try {
      var bytes = _fileBytes;
      if (bytes == null || bytes.isEmpty) {
        bytes = await StorageService().downloadFile(widget.order.fileUrl);
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _fileBytes = bytes);
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.amber[900],
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document file is still downloading or unavailable. Please wait a moment and try again.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }

      final path = await StorageService().saveFileToDevice(
        fileName: widget.order.fileName,
        bytes: bytes,
        orderCode: widget.order.code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal[800],
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    path != null
                        ? 'Downloaded "${widget.order.fileName}" to:\n$path'
                        : 'Downloaded "${widget.order.fileName}" to device Downloads folder.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Download failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingToDevice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isImage =
        o.fileName.toLowerCase().endsWith('.jpg') ||
        o.fileName.toLowerCase().endsWith('.jpeg') ||
        o.fileName.toLowerCase().endsWith('.png') ||
        o.fileName.toLowerCase().endsWith('.webp');

    final isPdf = o.fileName.toLowerCase().endsWith('.pdf');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : (isImage
                                ? Icons.image_rounded
                                : Icons.description_rounded),
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
                          o.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        Text(
                          'Code: #${o.code} • ${o.studentName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download Document',
                    icon: _savingToDevice
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.download_rounded,
                            size: 24,
                            color: AppTheme.primary,
                          ),
                    onPressed: _savingToDevice ? null : _exportToDevice,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Content Preview Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPreviewBody(isImage, isPdf),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Print Specs Summary
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _specBadge(
                    '${o.pages} Pages × ${o.copies} ${o.copies == 1 ? "Copy" : "Copies"}',
                  ),
                  _specBadge(o.color ? 'Color Print' : 'B&W Print'),
                  _specBadge(o.doubleSided ? 'Double-Sided' : 'Single-Sided'),
                  _specBadge(
                    o.paperTypeName.isNotEmpty
                        ? o.paperTypeName
                        : o.paperType.name,
                  ),
                  if (o.gsmName.isNotEmpty) _specBadge(o.gsmName),
                  if (o.bindingName.isNotEmpty &&
                      o.bindingName.toLowerCase() != 'none')
                    _specBadge(o.bindingName)
                  else if (o.bindingType != BindingType.none)
                    _specBadge(o.bindingType.name),
                  if (o.lamination) _specBadge('Lamination'),
                ],
              ),

              const SizedBox(height: 10),

              // Special Instructions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: o.specialInstructions.trim().isNotEmpty
                      ? Colors.amber.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: o.specialInstructions.trim().isNotEmpty
                        ? Colors.amber.withValues(alpha: 0.45)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 14,
                          color: o.specialInstructions.trim().isNotEmpty
                              ? Colors.amber[800]
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Special Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.3,
                            color: o.specialInstructions.trim().isNotEmpty
                                ? Colors.amber[900]
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      o.specialInstructions.trim().isNotEmpty
                          ? o.specialInstructions.trim()
                          : 'No special instructions.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: o.specialInstructions.trim().isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontStyle: o.specialInstructions.trim().isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action button (Close / Done)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody(bool isImage, bool isPdf) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Loading file from secure in-app vault…',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!.startsWith('This document')
                    ? _errorMessage!
                    : 'Unable to load preview: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1. High-fidelity Interactive Image Preview
    if (_fileBytes != null && _fileBytes!.isNotEmpty && isImage) {
      return InteractiveViewer(
        panEnabled: true,
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            _fileBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Center(child: Icon(Icons.broken_image_rounded, size: 48)),
          ),
        ),
      );
    }

    // 2. High-fidelity Interactive PDF Viewer with Pinch-Zoom & Multi-page
    if (isPdf && _pdfController != null) {
      return Stack(
        children: [
          PdfViewPinch(
            controller: _pdfController!,
            onPageChanged: (page) {
              if (mounted) setState(() => _pdfPage = page);
            },
            onDocumentLoaded: (doc) {
              if (mounted) setState(() => _totalPdfPages = doc.pagesCount);
            },
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _totalPdfPages > 0
                    ? 'Page $_pdfPage of $_totalPdfPages'
                    : 'Page $_pdfPage',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Previous Page',
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                  onPressed: _pdfPage > 1
                      ? () => _pdfController?.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Next Page',
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onPressed: _totalPdfPages == 0 || _pdfPage < _totalPdfPages
                      ? () => _pdfController?.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final fileSizeKb = widget.order.fileSizeBytes > 0
        ? (widget.order.fileSizeBytes / 1024).toStringAsFixed(1)
        : null;

    // 3. Document representation for non-PDF documents or fallback
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.file_present_rounded,
              size: 58,
              color: isPdf ? Colors.redAccent : AppTheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              widget.order.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            if (fileSizeKb != null) ...[
              const SizedBox(height: 4),
              Text(
                '$fileSizeKb KB • Ready for Xerox',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_clock_rounded, size: 14, color: Colors.green),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Stored in Secure App Vault • Ready for Print',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: _savingToDevice ? null : _exportToDevice,
              icon: _savingToDevice
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_rounded, size: 18),
              label: Text(
                _savingToDevice ? 'Exporting…' : 'Save Copy to Downloads',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
