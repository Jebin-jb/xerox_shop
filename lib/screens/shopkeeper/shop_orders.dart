import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_payment_config_service.dart';
import '../../services/payment/payment_models.dart';
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<PrintOrder>>(
      stream: widget.dataService.allOrders(),
      builder: (context, snap) {
        var orders = snap.data ?? [];
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageIntro(
              title: 'Order Queue',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Shop UPI Payment Settings',
                    icon: const Icon(Icons.qr_code_2_rounded),
                    onPressed: () => _openPaymentSettingsDialog(context),
                  ),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeSlide(
                    child: GlassPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Distinct Top Banner based on Payment Mode & Status
                          if (o.paymentMode == PaymentMode.counter) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: o.paymentStatus == PaymentStatus.paid
                                    ? const Color(
                                        0xFF00C853,
                                      ).withValues(alpha: 0.12)
                                    : Colors.amber.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: o.paymentStatus == PaymentStatus.paid
                                      ? const Color(0xFF00C853)
                                      : Colors.amber[700]!,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    o.paymentStatus == PaymentStatus.paid
                                        ? Icons.check_circle_rounded
                                        : Icons.storefront_rounded,
                                    color: o.paymentStatus == PaymentStatus.paid
                                        ? const Color(0xFF00C853)
                                        : Colors.amber[800],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'PAY AT COUNTER',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                            color:
                                                o.paymentStatus ==
                                                    PaymentStatus.paid
                                                ? const Color(0xFF00C853)
                                                : Colors.amber[900],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                o.paymentStatus ==
                                                    PaymentStatus.paid
                                                ? const Color(0xFF00C853)
                                                : Colors.amber[800],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            o.paymentStatus ==
                                                    PaymentStatus.paid
                                                ? 'PAID ✓'
                                                : 'UNPAID',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        if (o.paymentStatus !=
                                            PaymentStatus.paid)
                                          Text(
                                            'WAITING FOR STUDENT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: Colors.amber[900],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Collection Code: ${o.code}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color:
                                          o.paymentStatus == PaymentStatus.paid
                                          ? const Color(0xFF00C853)
                                          : Colors.amber[900],
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Online Payment banner
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: o.paymentStatus == PaymentStatus.paid
                                    ? const Color(
                                        0xFF00C853,
                                      ).withValues(alpha: 0.12)
                                    : (o.paymentStatus ==
                                              PaymentStatus.verification_pending
                                          ? Colors.orange.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.red.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: o.paymentStatus == PaymentStatus.paid
                                      ? const Color(0xFF00C853)
                                      : (o.paymentStatus ==
                                                PaymentStatus
                                                    .verification_pending
                                            ? Colors.orange
                                            : Colors.red),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        o.paymentStatus == PaymentStatus.paid
                                            ? Icons.verified_rounded
                                            : (o.paymentStatus ==
                                                      PaymentStatus
                                                          .verification_pending
                                                  ? Icons.schedule_rounded
                                                  : Icons.error_outline_rounded),
                                        color: o.paymentStatus == PaymentStatus.paid
                                            ? const Color(0xFF00C853)
                                            : (o.paymentStatus ==
                                                      PaymentStatus
                                                          .verification_pending
                                                  ? Colors.orange[800]
                                                  : Colors.red),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Payment Mode: ONLINE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11.5,
                                          color:
                                              o.paymentStatus == PaymentStatus.paid
                                              ? const Color(0xFF00C853)
                                              : (o.paymentStatus ==
                                                        PaymentStatus
                                                            .verification_pending
                                                    ? Colors.orange[900]
                                                    : Colors.red),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              o.paymentStatus == PaymentStatus.paid
                                              ? const Color(0xFF00C853)
                                              : ((o.paymentStatus ==
                                                          PaymentStatus
                                                              .payment_submitted ||
                                                      o.paymentStatus ==
                                                          PaymentStatus
                                                              .verification_pending)
                                                  ? Colors.orange[800]
                                                  : (o.paymentStatus ==
                                                          PaymentStatus
                                                              .payment_initiated
                                                      ? Colors.amber[800]
                                                      : Colors.red)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          o.paymentStatus == PaymentStatus.paid
                                              ? 'PAID ✓'
                                              : ((o.paymentStatus ==
                                                          PaymentStatus
                                                              .payment_submitted ||
                                                      o.paymentStatus ==
                                                          PaymentStatus
                                                              .verification_pending)
                                                  ? 'PAYMENT SUBMITTED (VERIFY)'
                                                  : (o.paymentStatus ==
                                                          PaymentStatus
                                                              .payment_initiated
                                                      ? 'INITIATED (AWAITING UTR)'
                                                      : (o.paymentStatus ==
                                                              PaymentStatus
                                                                  .cancelled
                                                          ? 'CANCELLED'
                                                          : 'UNPAID'))),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10.5,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((o.transactionReference ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.tag_rounded,
                                            size: 14,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'UTR: ${o.transactionReference}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
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
                                      '${o.studentName} • Reg: ${o.studentId.isNotEmpty ? o.studentId : "N/A"}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (o.studentEmail.isNotEmpty)
                                      Text(
                                        o.studentEmail,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusChip(
                                    label: orderStatusLabel(
                                      o.status,
                                    ).toUpperCase(),
                                    color: statusColor(o.status),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (o.status == OrderStatus.cancelled ||
                              o.status == OrderStatus.rejected) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cancelled by: ${o.cancellationBy ?? "Student"}'
                                      '${o.cancellationReason != null ? " • Reason: ${o.cancellationReason}" : ""}'
                                      '${o.refundStatus != null && o.refundStatus != "NONE" ? " • (${o.refundStatus == 'REFUND_INITIATED' ? 'Refund Initiated' : o.refundStatus})" : ""}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Specs row
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _specTag(
                                Icons.auto_stories_rounded,
                                '${o.pages} pages × ${o.copies} ${o.copies == 1 ? "copy" : "copies"}',
                              ),
                              _specTag(
                                Icons.palette_outlined,
                                o.calculatedColorPages > 0 && o.calculatedBwPages > 0
                                    ? 'Mixed (${o.calculatedBwPages} B&W, ${o.calculatedColorPages} Color)'
                                    : (o.color ? 'Color' : 'B&W'),
                              ),
                              _specTag(
                                Icons.flip_rounded,
                                o.doubleSided ? 'Double-Sided' : 'Single-Sided',
                              ),
                              _specTag(
                                Icons.description_rounded,
                                o.paperTypeName.isNotEmpty
                                    ? o.paperTypeName
                                    : o.paperType.name,
                              ),
                              if (o.gsmName.isNotEmpty)
                                _specTag(
                                  Icons.line_weight_rounded,
                                  o.gsmName,
                                ),
                              if (o.bindingName.isNotEmpty &&
                                  o.bindingName.toLowerCase() != 'none')
                                _specTag(
                                  Icons.menu_book_rounded,
                                  o.bindingName,
                                )
                              else if (o.bindingType != BindingType.none)
                                _specTag(
                                  Icons.menu_book_rounded,
                                  o.bindingType.name,
                                ),
                              if (o.lamination)
                                _specTag(Icons.layers_outlined, 'Laminated'),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Per-Page Print Configuration Panel for Shopkeeper
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: o.calculatedColorPages > 0
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
                                  : Colors.blueGrey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: o.calculatedColorPages > 0
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                                    : Colors.blueGrey.withValues(alpha: 0.2),
                                width: 1.1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 15,
                                      color: o.calculatedColorPages > 0
                                          ? const Color(0xFF8B5CF6)
                                          : Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Order #${o.code} Page Settings',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: o.calculatedColorPages > 0
                                            ? const Color(0xFF8B5CF6)
                                            : Colors.blueGrey,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.dividerColor.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        'Total: ${o.pages}p',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'B&W Pages: ${o.calculatedBwPages}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: o.calculatedColorPages > 0
                                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Color Pages: ${o.calculatedColorPages}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                          color: o.calculatedColorPages > 0
                                              ? const Color(0xFF8B5CF6)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (o.calculatedColorPages > 0) ...[
                                  const SizedBox(height: 8),
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
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide(
                                      color: o.calculatedColorPages > 0
                                          ? const Color(0xFF8B5CF6)
                                          : theme.dividerColor,
                                    ),
                                  ),
                                  onPressed: () => _showPerPageDetailsDialog(context, o),
                                  icon: const Icon(Icons.list_alt_rounded, size: 15),
                                  label: const Text(
                                    'VIEW PER-PAGE DETAILS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Special Instructions Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: o.specialInstructions.trim().isNotEmpty
                                  ? Colors.amber.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: o.specialInstructions.trim().isNotEmpty
                                    ? Colors.amber.withValues(alpha: 0.45)
                                    : theme.dividerColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notes_rounded,
                                      size: 15,
                                      color:
                                          o.specialInstructions
                                                  .trim()
                                                  .isNotEmpty
                                              ? Colors.amber[800]
                                              : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Special Instructions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                        letterSpacing: 0.3,
                                        color:
                                            o.specialInstructions
                                                    .trim()
                                                    .isNotEmpty
                                                ? Colors.amber[900]
                                                : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Divider(height: 6, thickness: 0.5),
                                const SizedBox(height: 4),
                                Text(
                                  o.specialInstructions.trim().isNotEmpty
                                      ? o.specialInstructions.trim()
                                      : 'No special instructions.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight:
                                        o.specialInstructions
                                                .trim()
                                                .isNotEmpty
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                    fontStyle:
                                        o.specialInstructions
                                                .trim()
                                                .isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
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
                                              : (o.paymentStatus ==
                                                        PaymentStatus
                                                            .verification_pending
                                                    ? Icons.schedule_rounded
                                                    : Icons.pending_rounded),
                                          size: 13,
                                          color:
                                              o.paymentStatus ==
                                                  PaymentStatus.paid
                                              ? Colors.green
                                              : (o.paymentStatus ==
                                                        PaymentStatus
                                                            .verification_pending
                                                    ? Colors.orange
                                                    : Colors.red),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            o.paymentMode == PaymentMode.counter
                                                ? (o.paymentStatus ==
                                                          PaymentStatus.paid
                                                      ? 'Paid at Counter'
                                                      : 'Pay at Counter (Waiting for Student)')
                                                : (o.paymentStatus ==
                                                          PaymentStatus.paid
                                                      ? (o.paymentMethod != null
                                                            ? 'Paid via ${PaymentAppMethod.fromDbCode(o.paymentMethod).displayName}'
                                                            : 'Online: PAID')
                                                      : (o.paymentStatus ==
                                                                PaymentStatus
                                                                    .verification_pending
                                                            ? 'Online: Verification Pending'
                                                            : 'Online: ${o.paymentStatus.name.toUpperCase()}')),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  o.paymentStatus ==
                                                      PaymentStatus.paid
                                                  ? Colors.green
                                                  : (o.paymentStatus ==
                                                            PaymentStatus
                                                                .verification_pending
                                                        ? Colors.orange
                                                        : Colors.red),
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
                                    backgroundColor: Colors.teal.withValues(
                                      alpha: 0.15,
                                    ),
                                    foregroundColor: Colors.teal[800],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: _downloading.contains(o.id)
                                      ? null
                                      : () => _downloadAndPurge(o),
                                  icon: _downloading.contains(o.id)
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cloud_download_rounded,
                                          size: 16,
                                        ),
                                  label: Text(
                                    _downloading.contains(o.id)
                                        ? 'Saving…'
                                        : (o.isDownloaded
                                              ? 'Downloaded'
                                              : 'Download & Purge'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 14,
                                        color: Colors.teal,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'File Purged (Privacy)',
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
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: () => _reject(o),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text(
            'REJECT',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: () => _markPaidAtCounter(o),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: Text('Receive ₹${o.total.toStringAsFixed(0)} & Accept Order'),
        ),

      // Online Order: Normal ACCEPT control ONLY for valid confirmed PAID online orders
      if (o.status == OrderStatus.pending &&
          o.paymentMode == PaymentMode.online &&
          o.paymentStatus == PaymentStatus.paid)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () =>
              widget.dataService.updateOrder(o.id, {'status': 'accepted'}),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text(
            'ACCEPT',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),

      // Verify Payment Button (When student submitted UTR for verification)
      if (o.status == OrderStatus.pending &&
          o.paymentMode == PaymentMode.online &&
          (o.paymentStatus == PaymentStatus.payment_submitted ||
              o.paymentStatus == PaymentStatus.verification_pending))
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => _verifyOnlinePayment(o),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text(
            'VERIFY PAYMENT',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),

      // If online order is pending but UNPAID or payment failed
      if (o.status == OrderStatus.pending &&
          o.paymentMode == PaymentMode.online &&
          o.paymentStatus != PaymentStatus.paid &&
          o.paymentStatus != PaymentStatus.payment_submitted &&
          o.paymentStatus != PaymentStatus.verification_pending)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (o.paymentStatus == PaymentStatus.payment_initiated
                    ? Colors.amber
                    : Colors.red)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (o.paymentStatus == PaymentStatus.payment_initiated
                      ? Colors.amber
                      : Colors.red)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            o.paymentStatus == PaymentStatus.payment_initiated
                ? 'Payment Initiated by Student (Awaiting UTR)'
                : 'Online Payment ${o.paymentStatus.name.toUpperCase()} (Cannot Accept)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: o.paymentStatus == PaymentStatus.payment_initiated
                  ? Colors.amber[900]
                  : Colors.red,
            ),
          ),
        ),

      // Start Printing (Only available after order is accepted/paid)
      if (o.status == OrderStatus.accepted)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0091EA),
          ),
          onPressed: () =>
              widget.dataService.updateOrder(o.id, {'status': 'printing'}),
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Start Printing'),
        ),

      // Mark Ready
      if (o.status == OrderStatus.printing)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
          ),
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
    await widget.dataService.updateOrder(o.id, {'isPurged': true});
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
            Text('Order: ${o.code}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
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
    const reasons = [
      'File cannot be opened',
      'Printer unavailable',
      'Paper unavailable',
      'Required service unavailable',
      'Shop temporarily unavailable',
      'Other',
    ];

    String selectedReason = reasons.first;
    final otherController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Reject Order',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select reason for rejecting order #${o.code}:'),
                const SizedBox(height: 12),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r, style: const TextStyle(fontSize: 13.5)),
                    value: r,
                    // ignore: deprecated_member_use
                    groupValue: selectedReason,
                    // ignore: deprecated_member_use
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedReason = v);
                    },
                  ),
                ),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherController,
                    decoration: const InputDecoration(
                      hintText: 'Please specify rejection reason...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final finalReason =
                    selectedReason == 'Other' &&
                        otherController.text.trim().isNotEmpty
                    ? otherController.text.trim()
                    : selectedReason;
                Navigator.pop(ctx, finalReason);
              },
              child: const Text('Reject Order'),
            ),
          ],
        ),
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await StorageService().deleteFile(o.fileUrl);
      final isOnlinePaid =
          o.paymentMode == PaymentMode.online &&
          o.paymentStatus == PaymentStatus.paid;

      await widget.dataService.updateOrder(o.id, {
        'status': 'cancelled',
        'isPurged': true,
        'cancellationBy': 'SHOPKEEPER',
        'cancellationReason': reason,
        'refundStatus': isOnlinePaid ? 'REFUND_INITIATED' : 'NONE',
        if (isOnlinePaid) 'paymentStatus': 'refundPending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnlinePaid
                  ? 'Order #${o.code} rejected. Refund initiated to student.'
                  : 'Order #${o.code} rejected.',
            ),
          ),
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
      allSettings = o.pageSettings;
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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                        Text('Total: $total Pages', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        Text('B&W: $bwCount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.blueGrey)),
                        Text('Color: $colorCount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF8B5CF6))),
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
                                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                        : Colors.blueGrey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isColor
                                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                                          : Colors.blueGrey.withValues(alpha: 0.3),
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
