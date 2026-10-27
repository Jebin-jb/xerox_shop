import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_payment_config_service.dart';
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
  final Set<String> _deleting = {};
  final Set<String> _completing = {};

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<PrintOrder>>(
      stream: widget.dataService.allOrders(),
      initialData: widget.dataService.allOrdersDirect,
      builder: (context, snap) {
        var orders = (snap.data ?? [])
            .where((x) => !x.isDeletedFromQueue && !x.isPurged)
            .toList();
        final q = search.text.trim().toUpperCase();
        if (q.isNotEmpty) {
          orders = orders
              .where(
                (x) =>
                    x.code.contains(q) ||
                    x.studentName.toUpperCase().contains(q) ||
                    x.studentId.toUpperCase().contains(q) ||
                    x.fileName.toUpperCase().contains(q),
              )
              .toList();
        }
        if (statusFilter != null) {
          orders = orders.where((x) => x.status == statusFilter).toList();
        }

        return RefreshIndicator(
          onRefresh: () => widget.dataService.refreshOrders(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 120),
            children: [
              PageIntro(
                title: 'Order Queue',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Shop UPI Payment Settings',
                      icon: const Icon(Icons.qr_code_2_rounded),
                      onPressed: () => _openPaymentSettingsDialog(context),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                      onPressed: widget.onToggleTheme,
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Sign Out',
                      onPressed: widget.onSignOut,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                      ),
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
                        hintText:
                            'Search 4-digit code (e.g. 5727), student, file…',
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

              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData)
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
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FadeSlide(
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Header: Code Badge and Status Chip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    o.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                      letterSpacing: 0.8,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                StatusChip(
                                  label: orderStatusLabel(
                                    o.status,
                                  ).toUpperCase(),
                                  color: statusColor(o.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 2. File Name (top-level View Document action removed)
                            Text(
                              o.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // 3. Student & Timestamp Subtitle
                            Text(
                              '${o.studentName}${o.studentId.isNotEmpty ? " • Reg: ${o.studentId}" : ""}'
                              ' • ${DateFormat('dd MMM, hh:mm a').format(o.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),

                            const SizedBox(height: 4),

                            // 4. Detailed Print Summary (Matches Student New Print Order page)
                            _buildShopPrintSummary(o, Theme.of(context)),

                            // 5. Special Instructions (Only if non-empty)
                            if (o.specialInstructions.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notes_rounded,
                                      size: 14,
                                      color: Colors.amber[900],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Note: ${o.specialInstructions.trim()}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 6. Cancellation note (if cancelled/rejected)
                            if (o.status == OrderStatus.cancelled ||
                                o.status == OrderStatus.rejected) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Cancelled by ${o.cancellationBy ?? "User"}: ${o.cancellationReason ?? "No reason"}'
                                  '${o.refundStatus != null && o.refundStatus != "NONE" ? " • (${o.refundStatus})" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // 7. Payment Info (Download button permanently removed from card)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _paymentBadge(o),
                                if (o.isPurged)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 12,
                                          color: Colors.teal,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'File Purged',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 8. Actions
                            _actions(o),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentBadge(PrintOrder o) {
    if (o.paymentMode == PaymentMode.counter) {
      final isPaid = o.paymentStatus == PaymentStatus.paid;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isPaid ? const Color(0xFF00C853) : Colors.amber[800]!)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPaid ? const Color(0xFF00C853) : Colors.amber[800]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid ? Icons.check_circle_rounded : Icons.storefront_rounded,
              size: 13,
              color: isPaid ? const Color(0xFF00C853) : Colors.amber[800],
            ),
            const SizedBox(width: 4),
            Text(
              isPaid ? 'Counter: Paid' : 'Counter: Due',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isPaid ? const Color(0xFF00C853) : Colors.amber[900],
              ),
            ),
          ],
        ),
      );
    } else {
      final isPaid = o.paymentStatus == PaymentStatus.paid;
      final isPending =
          o.paymentStatus == PaymentStatus.payment_submitted ||
          o.paymentStatus == PaymentStatus.verification_pending;
      final color = isPaid
          ? const Color(0xFF00C853)
          : (isPending ? Colors.orange[800]! : Colors.red);
      final label = isPaid
          ? 'Online: Paid'
          : (isPending
                ? (o.transactionReference != null &&
                          o.transactionReference!.isNotEmpty
                      ? 'Verify UTR: ${o.transactionReference}'
                      : 'Verify Online Payment')
                : (o.paymentStatus == PaymentStatus.payment_initiated
                      ? 'Online: Initiated'
                      : 'Online: Unpaid'));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid
                  ? Icons.verified_rounded
                  : (isPending
                        ? Icons.schedule_rounded
                        : Icons.pending_rounded),
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _actions(PrintOrder o) {
    // 1. Rejected or Cancelled: No actions available. Bin is NOT required or shown.
    if (o.status == OrderStatus.rejected || o.status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    // 2. Completed: Show View / Print (if document not purged) and Bin button
    if (o.status == OrderStatus.completed) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!o.isPurged && o.fileUrl.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onPressed: () => _previewDocument(o),
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: const Text('View / Print'),
            ),
          IconButton(
            tooltip: 'Delete Document & Remove from Queue',
            icon: _deleting.contains(o.id)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.redAccent,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
            onPressed: _deleting.contains(o.id)
                ? null
                : () => _handleBinClick(o),
          ),
        ],
      );
    }

    // 3. Active stages: Pending, Accepted, Printing, Ready (Steps 1 & 3)
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // View / Print (Available for pending, accepted, printing, ready if not purged)
        if (!o.isPurged && o.fileUrl.isNotEmpty)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: () => _previewDocument(o),
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: const Text('View / Print'),
          ),

        // PENDING: Reject & Accept actions. Bin button is HIDDEN. Printing actions are HIDDEN.
        if (o.status == OrderStatus.pending) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: () => _reject(o),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (o.paymentMode == PaymentMode.counter &&
              o.paymentStatus == PaymentStatus.unpaid)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onPressed: () => _markPaidAtCounter(o),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(
                'Receive ₹${o.total.toStringAsFixed(0)} & Accept',
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (o.paymentMode == PaymentMode.online &&
              (o.paymentStatus == PaymentStatus.payment_submitted ||
                  o.paymentStatus == PaymentStatus.verification_pending))
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onPressed: () => _verifyOnlinePayment(o),
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: const Text(
                'Verify Payment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onPressed: () =>
                  widget.dataService.updateOrder(o.id, {'status': 'accepted'}),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                'Accept',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],

        // ACCEPTED: Start Printing. Reject is HIDDEN. Accept is HIDDEN. Bin is HIDDEN.
        if (o.status == OrderStatus.accepted)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0091EA),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () =>
                widget.dataService.updateOrder(o.id, {'status': 'printing'}),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Start Printing'),
          ),

        // PRINTING: Mark Ready. Bin is HIDDEN.
        if (o.status == OrderStatus.printing)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () =>
                widget.dataService.updateOrder(o.id, {'status': 'ready'}),
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: const Text('Mark Ready'),
          ),

        // READY: Complete Order. Bin is HIDDEN.
        if (o.status == OrderStatus.ready)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _completeOrder(o),
            icon: const Icon(Icons.task_alt_rounded, size: 16),
            label: const Text('Complete Order'),
          ),
      ],
    );
  }

  void _previewDocument(PrintOrder o) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentPreviewDialog(order: o),
    );
  }

  Future<void> _completeOrder(PrintOrder o) async {
    if (_completing.contains(o.id)) return;
    setState(() => _completing.add(o.id));
    try {
      await widget.dataService.updateOrder(o.id, {
        'status': 'completed',
        'completedAt': DateTime.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal[800],
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order #${o.code} marked as Completed. File retained until Bin cleanup.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing.remove(o.id));
    }
  }

  Future<void> _handleBinClick(PrintOrder o) async {
    if (_deleting.contains(o.id)) return;

    // Step 5 Guard: Restrict deletion to eligible completed orders only
    final isEligible = o.status == OrderStatus.completed;

    if (!isEligible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only completed orders can be deleted via Bin.'),
          ),
        );
      }
      return;
    }

    // Confirmation dialog without reason text field (Task 1: Completed Orders Bin Deletion)
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_rounded,
          color: Colors.redAccent,
          size: 38,
        ),
        title: Text(
          'Delete Order #${o.code}?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete document "${o.fileName}" and remove Order #${o.code} from queue?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '• The associated document will be permanently deleted from storage.\n'
                '• The order will be removed from your active queue.\n'
                '• Order history and payment records (₹${o.total.toStringAsFixed(2)}) will be safely retained in reports.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return; // Cancelled
    }

    setState(() => _deleting.add(o.id));
    try {
      final storage = StorageService();

      // Delete from Supabase Storage and local cache/vault, verifying deletion
      final deletionSuccess = await storage.deleteAfterPrinting(
        fileUrl: o.fileUrl,
        fileName: o.fileName,
        orderId: o.id,
        orderCode: o.code,
      );

      // If deletion fails because of a network issue or permissions, show error and allow safe retry
      if (!deletionSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red[800],
              duration: const Duration(seconds: 6),
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Failed to delete file from Supabase Storage. Check network connection and retry.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleBinClick(o),
              ),
            ),
          );
        }
        return;
      }

      final now = DateTime.now();
      // Update database state & invalidate file reference, preserving order and financial records
      await widget.dataService.updateOrder(o.id, {
        'isPurged': true,
        'is_purged': true,
        'fileUrl': '',
        'file_url': '',
        'isDeletedFromQueue': true,
        'is_deleted_from_queue': true,
        'removedAt': now.toIso8601String(),
        'removed_at': now.toIso8601String(),
        'removedBy': 'Shopkeeper',
        'removed_by': 'Shopkeeper',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal[800],
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order #${o.code} and document deleted from queue.',
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
            duration: const Duration(seconds: 6),
            content: Text('Error deleting order: $e'),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleBinClick(o),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(o.id));
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

  Future<void> _verifyOnlinePayment(PrintOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.verified_rounded,
          color: Color(0xFF00C853),
          size: 36,
        ),
        title: const Text(
          'Verify Student Payment',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order: ${o.code}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Student: ${o.studentName} (${o.studentEmail})'),
            const SizedBox(height: 4),
            Text(
              'Amount: ₹${o.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF00C853),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Payment Mode: ONLINE'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Reference / UTR:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    (o.transactionReference ?? '').isNotEmpty
                        ? o.transactionReference!
                        : 'No reference entered',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Did you receive this payment in your UPI account / bank statement?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('VERIFY & CONFIRM PAID'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.dataService.updateOrder(o.id, {
        'paymentStatus': 'paid',
        'paidAt': DateTime.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment verified successfully for Order #${o.code}. You can now accept the order.',
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reject(PrintOrder o) async {
    final reasonController = TextEditingController();
    String? validationError;

    final confirmedReason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          icon: const Icon(
            Icons.cancel_outlined,
            color: Colors.redAccent,
            size: 38,
          ),
          title: Text(
            'Reject Order #${o.code}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please provide a reason for rejecting order #${o.code} (${o.studentName}):',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for Rejection',
                    hintText:
                        'e.g. Incomplete pages, unreadable formatting, printer offline...',
                    errorText: validationError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    if (validationError != null && text.trim().isNotEmpty) {
                      setDlgState(() => validationError = null);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final trimmed = reasonController.text.trim();
                if (trimmed.isEmpty) {
                  setDlgState(() {
                    validationError = 'Reason for Rejection cannot be empty.';
                  });
                  return;
                }
                Navigator.pop(ctx, trimmed);
              },
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );

    if (confirmedReason == null || confirmedReason.trim().isEmpty) {
      // Cancelled, leave order unchanged
      return;
    }

    final reason = confirmedReason.trim();
    final isOnlinePaid =
        o.paymentMode == PaymentMode.online &&
        o.paymentStatus == PaymentStatus.paid;

    try {
      await widget.dataService.updateOrder(o.id, {
        'status': 'rejected',
        'cancellationBy': 'SHOPKEEPER',
        'cancellationReason': reason,
        'cancellation_reason': reason,
        'rejectionReason': reason,
        'rejection_reason': reason,
        'refundStatus': isOnlinePaid ? 'REFUND_INITIATED' : 'NONE',
        if (isOnlinePaid) 'paymentStatus': 'refundPending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnlinePaid
                        ? 'Order #${o.code} rejected (refund initiated). Reason recorded.'
                        : 'Order #${o.code} rejected. Reason recorded.',
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
            duration: const Duration(seconds: 6),
            content: Text('Failed to reject order: $e'),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _reject(o),
            ),
          ),
        );
      }
    }
  }

  Widget _buildShopPrintSummary(PrintOrder o, ThemeData theme) {
    final int bwCount = o.calculatedBwPages;
    final int colorCount = o.calculatedColorPages;
    final String paperName = o.paperTypeName.isNotEmpty
        ? o.paperTypeName
        : o.paperType.name;
    final String gsmText = o.gsmName.isNotEmpty ? ' (${o.gsmName})' : '';
    final String bindingText =
        o.bindingName.isNotEmpty && o.bindingName.toLowerCase() != 'none'
        ? o.bindingName
        : (o.bindingType != BindingType.none ? o.bindingType.name : '');

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Print Summary',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (o.pageSettings.isNotEmpty || o.calculatedColorPages > 0)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _showPerPageDetailsDialog(context, o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 12,
                          color: Color(0xFF8B5CF6),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Per-Page Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _summaryRow('B&W Pages', '$bwCount (${o.bwPagesDisplayText})', theme),
          _summaryRow(
            'Colour Pages',
            '$colorCount (${o.colorPagesDisplayText})',
            theme,
          ),
          _summaryRow('Removed Pages', '${o.removedPagesCount}', theme),
          _summaryRow('Copies', '${o.copies}', theme),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _summaryRow(
            'Print Sides',
            o.doubleSided ? 'Double Side (Back to Back)' : 'Single Side',
            theme,
          ),
          _summaryRow('Paper Type', '$paperName$gsmText', theme),
          if (bindingText.isNotEmpty)
            _summaryRow('Binding', bindingText, theme),
          if (o.lamination) _summaryRow('Lamination', 'Included', theme),
          if (o.priceSnapshot?['additionalServices'] is List &&
              (o.priceSnapshot!['additionalServices'] as List).isNotEmpty)
            _summaryRow(
              'Additional Services',
              (o.priceSnapshot!['additionalServices'] as List)
                  .map(
                    (s) =>
                        s is Map ? s['name']?.toString() ?? '' : s.toString(),
                  )
                  .where((name) => name.isNotEmpty)
                  .join(', '),
              theme,
            ),

          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _summaryRow(
            'Total Amount',
            '₹${o.total.toStringAsFixed(2)}',
            theme,
            isBold: true,
            isPrimary: true,
          ),
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
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isRemoved
                    ? Colors.redAccent
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                color: isRemoved
                    ? Colors.redAccent
                    : (isPrimary ? AppTheme.primary : null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentSettingsDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final config = await FirebasePaymentConfigService.instance
        .getPaymentConfig();

    final nameController = TextEditingController(text: config.merchantName);
    final upiController = TextEditingController(text: config.upiId);
    bool saving = false;
    String? errorText;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.account_balance_wallet_rounded,
            color: theme.colorScheme.primary,
            size: 36,
          ),
          title: const Text(
            'Shop UPI Payment Settings',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure the official Xerox shop merchant name and UPI ID. Students will make payments directly to this account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant / Shop Name',
                    hintText: 'e.g. Campus Xerox Shop',
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: upiController,
                  decoration: InputDecoration(
                    labelText: 'Shop UPI ID',
                    hintText: 'e.g. campusxerox@upi',
                    prefixIcon: const Icon(Icons.payment_rounded),
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Never enter passwords, PINs, or banking keys.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final upi = upiController.text.trim();
                      final name = nameController.text.trim();
                      if (upi.isEmpty || !upi.contains('@')) {
                        setDialogState(() {
                          errorText = 'Enter a valid UPI ID (e.g. name@upi)';
                        });
                        return;
                      }

                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });

                      try {
                        await FirebasePaymentConfigService.instance
                            .updatePaymentConfig(
                              ShopPaymentConfig(
                                merchantName: name.isNotEmpty
                                    ? name
                                    : 'Campus Xerox Shop',
                                upiId: upi,
                                updatedAt: DateTime.now(),
                              ),
                            );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Shop UPI Payment Settings saved to Firebase!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          errorText = 'Error saving settings: $e';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPerPageDetailsDialog(BuildContext context, PrintOrder o) {
    showDialog(
      context: context,
      builder: (ctx) => PerPageDetailsDialog(order: o),
    );
  }
}

class PerPageDetailsDialog extends StatefulWidget {
  final PrintOrder order;
  const PerPageDetailsDialog({super.key, required this.order});

  @override
  State<PerPageDetailsDialog> createState() => _PerPageDetailsDialogState();
}

class _PerPageDetailsDialogState extends State<PerPageDetailsDialog> {
  int _filterIndex = 0; // 0 = All, 1 = Color Only, 2 = B&W Only

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.order;
    final total = o.pages;
    final colorCount = o.calculatedColorPages;
    final bwCount = o.calculatedBwPages;

    final List<PagePrintSetting> allSettings;
    if (o.pageSettings.isNotEmpty) {
      allSettings = o.pageSettings.whereType<PagePrintSetting>().toList();
    } else {
      final colorSet = o.colorPageNumbers.toSet();
      allSettings = List.generate(
        total,
        (i) => PagePrintSetting(
          pageNumber: i + 1,
          printType: (colorSet.contains(i + 1) || (o.color && colorSet.isEmpty))
              ? PrintType.color
              : PrintType.bw,
        ),
      );
    }

    final filtered = allSettings.where((s) {
      if (_filterIndex == 1) return s.isColor;
      if (_filterIndex == 2) return !s.isColor;
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${o.code}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Per-Page Print Configuration',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary stats card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: $total Pages',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          'B&W: $bwCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Text(
                          'Color: $colorCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    if (colorCount > 0) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Color Pages: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              o.formattedColorPageRanges,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All ($total)'),
                      selected: _filterIndex == 0,
                      onSelected: (_) => setState(() => _filterIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Color ($colorCount)'),
                      selected: _filterIndex == 1,
                      onSelected: (_) => setState(() => _filterIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('B&W ($bwCount)'),
                      selected: _filterIndex == 2,
                      onSelected: (_) => setState(() => _filterIndex = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Lazy-loaded ListView.builder for large PDF page lists (5, 10, 50, 111+ pages)
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No pages match filter.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          final isColor = item.isColor;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Page ${item.pageNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isColor
                                        ? const Color(
                                            0xFF8B5CF6,
                                          ).withValues(alpha: 0.15)
                                        : Colors.blueGrey.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isColor
                                          ? const Color(
                                              0xFF8B5CF6,
                                            ).withValues(alpha: 0.4)
                                          : Colors.blueGrey.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    isColor ? 'COLOR' : 'B&W',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: isColor
                                          ? const Color(0xFF8B5CF6)
                                          : Colors.blueGrey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
