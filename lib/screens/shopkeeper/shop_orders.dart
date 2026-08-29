import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/document_preview_dialog.dart';

class ShopOrders extends StatefulWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const ShopOrders({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  State<ShopOrders> createState() => _ShopOrdersState();
}

class _ShopOrdersState extends State<ShopOrders> {
  final search = TextEditingController();
  OrderStatus? statusFilter;
  final Set<String> _downloading = {};

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _downloadAndPurge(PrintOrder o) async {
    setState(() => _downloading.add(o.id));
    try {
      final storage = StorageService();
      final bytes = await storage.downloadFile(o.fileUrl);
      String? savedPath;
      if (bytes != null && bytes.isNotEmpty) {
        savedPath = await storage.saveFileToDevice(
          fileName: o.fileName,
          bytes: bytes,
          orderCode: o.code,
        );
      }

      // Auto-delete from cloud vault for student privacy
      await storage.deleteFile(o.fileUrl);

      await widget.dataService.updateOrder(o.id, {
        'isDownloaded': true,
        'isPurged': true,
      });

      if (mounted) {
        final pathNotice = savedPath != null
            ? 'Saved to: $savedPath'
            : 'Saved to Downloads folder.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.teal[800],
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document "${o.fileName}" downloaded!',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pathNotice (Purged from cloud for privacy)',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(o.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<PrintOrder>>(
      stream: widget.dataService.allOrders(),
      builder: (context, snap) {
        var orders = snap.data ?? [];
        final q = search.text.trim().toUpperCase();
        if (q.isNotEmpty) {
          orders = orders
              .where((x) =>
                  x.code.contains(q) ||
                  x.studentName.toUpperCase().contains(q) ||
                  x.studentId.toUpperCase().contains(q) ||
                  x.fileName.toUpperCase().contains(q))
              .toList();
        }
        if (statusFilter != null) {
          orders = orders.where((x) => x.status == statusFilter).toList();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Order Queue',
              subtitle: 'Active print orders submitted by campus students.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign Out',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Search and filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search code (e.g. CX402), student, file…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: search.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => search.clear()),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Orders'),
                    selected: statusFilter == null,
                    onSelected: (_) => setState(() => statusFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...OrderStatus.values.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(orderStatusLabel(s)),
                        selected: statusFilter == s,
                        onSelected: (_) => setState(() => statusFilter = s),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (orders.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No orders match your filter.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeSlide(
                    child: GlassPanel(
                      padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                o.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  color: AppTheme.primary,
                                ),
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
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${o.studentName} • ${o.studentId.isNotEmpty ? o.studentId : o.studentEmail}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: orderStatusLabel(o.status).toUpperCase(),
                              color: statusColor(o.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Specs row
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _specTag(Icons.auto_stories_rounded, '${o.pages} pages × ${o.copies} ${o.copies == 1 ? "copy" : "copies"}'),
                            _specTag(Icons.palette_outlined, o.color ? 'Color' : 'B&W'),
                            _specTag(Icons.flip_rounded, o.doubleSided ? 'Double-Sided' : 'Single-Sided'),
                            _specTag(Icons.description_rounded, o.paperType.name),
                            if (o.bindingType != BindingType.none)
                              _specTag(Icons.menu_book_rounded, o.bindingType.name),
                            if (o.lamination)
                              _specTag(Icons.layers_outlined, 'Laminated'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Payment & Download Bar
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOTAL: ₹${o.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        o.paymentStatus == PaymentStatus.paid
                                            ? Icons.check_circle_rounded
                                            : Icons.pending_rounded,
                                        size: 13,
                                        color: o.paymentStatus == PaymentStatus.paid
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          o.paymentMode == PaymentMode.counter
                                              ? (o.paymentStatus == PaymentStatus.paid ? 'Paid at Counter' : 'Pay at Counter')
                                              : '${o.paymentMode.name.toUpperCase()} • ${o.paymentStatus.name.toUpperCase()}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: o.paymentStatus == PaymentStatus.paid
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Download & Purge Action
                            if (!o.isPurged)
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                  foregroundColor: Colors.teal[800],
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: _downloading.contains(o.id)
                                    ? null
                                    : () => _downloadAndPurge(o),
                                icon: _downloading.contains(o.id)
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_download_rounded, size: 16),
                                label: Text(
                                  _downloading.contains(o.id)
                                      ? 'Saving…'
                                      : (o.isDownloaded ? 'Downloaded' : 'Download & Purge'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 14, color: Colors.teal),
                                    SizedBox(width: 6),
                                    Text(
                                      'File Purged (Privacy)',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.teal),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _actions(o),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _actions(PrintOrder o) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          // In-App Document Preview / Print
          if (!o.isPurged)
            OutlinedButton.icon(
              onPressed: () => _previewDocument(o),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View / Print in App'),
            ),

          // Delete File After Printing option
          if (!o.isPurged)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: () => _deleteAfterPrinting(o),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete File (Printed)'),
            ),

          // Reject action
          if (o.status == OrderStatus.pending)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: () => _reject(o),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
            ),

          // Prominent "Mark as Paid at Counter" option
          if (o.paymentMode == PaymentMode.counter &&
              o.paymentStatus == PaymentStatus.unpaid &&
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.rejected)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () => _markPaidAtCounter(o),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('Mark as Paid (₹${o.total.toStringAsFixed(0)} Received)'),
            ),

          // Accept Order
          if (o.status == OrderStatus.pending)
            FilledButton.icon(
              onPressed: () => widget.dataService.updateOrder(o.id, {'status': 'accepted'}),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Accept Order'),
            ),

          // Start Printing
          if (o.status == OrderStatus.accepted)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0091EA)),
              onPressed: () =>
                  widget.dataService.updateOrder(o.id, {'status': 'printing'}),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Start Printing'),
            ),

          // Mark Ready
          if (o.status == OrderStatus.printing)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
              onPressed: () =>
                  widget.dataService.updateOrder(o.id, {'status': 'ready'}),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark Ready for Pickup'),
            ),

          // Complete Order (Auto-cleans up residual files)
          if (o.status == OrderStatus.ready)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                await StorageService().deleteAfterPrinting(
                  fileUrl: o.fileUrl,
                  fileName: o.fileName,
                  orderId: o.id,
                  orderCode: o.code,
                );
                await widget.dataService.updateOrder(o.id, {
                  'status': 'completed',
                  'isPurged': true,
                  'completedAt': DateTime.now(),
                });
              },
              icon: const Icon(Icons.task_alt_rounded, size: 18),
              label: const Text('Complete Order'),
            ),
        ],
      );

  void _previewDocument(PrintOrder o) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentPreviewDialog(
        order: o,
        onDeleteAfterPrint: () => _deleteAfterPrinting(o),
      ),
    );
  }

  Future<void> _deleteAfterPrinting(PrintOrder o) async {
    await StorageService().deleteAfterPrinting(
      fileUrl: o.fileUrl,
      fileName: o.fileName,
      orderId: o.id,
      orderCode: o.code,
    );
    await widget.dataService.updateOrder(o.id, {
      'isPurged': true,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal[800],
          content: Row(
            children: [
              const Icon(Icons.cleaning_services_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Document "${o.fileName}" deleted from device and cloud after printing.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _markPaidAtCounter(PrintOrder o) async {
    await widget.dataService.updateOrder(o.id, {
      'paymentStatus': 'paid',
      if (o.status == OrderStatus.pending) 'status': 'accepted',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Text(
            'Order #${o.code} marked as PAID at counter (₹${o.total.toStringAsFixed(0)} received).',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<void> _reject(PrintOrder o) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejecting order #${o.code}:'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Document unreadable or corrupt',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Reject Order'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await StorageService().deleteFile(o.fileUrl);
      await widget.dataService.updateOrder(o.id, {
        'status': 'rejected',
        'isPurged': true,
        'paymentStatus': o.paymentMode == PaymentMode.online
            ? 'refundPending'
            : 'unpaid',
        'cancellationReason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order #${o.code} rejected.')),
        );
      }
    }
  }

  Widget _specTag(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
}
