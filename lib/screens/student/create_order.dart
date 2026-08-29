import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/payment_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'order_receipt.dart';

class CreateOrder extends StatefulWidget {
  final DataService dataService;
  final UserProfile profile;
  final ShopPrice prices;
  final VoidCallback onToggleTheme;

  const CreateOrder({
    super.key,
    required this.dataService,
    required this.profile,
    required this.prices,
    required this.onToggleTheme,
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

  double get paperRate => widget.prices.paperExtra(paperType);
  double get printRate =>
      widget.prices.printRate(color: color, doubleSided: doubleSided) + paperRate;
  double get bindingCost => widget.prices.bindingPrice(bindingType) * copies;
  double get laminationCost =>
      (lamination ? widget.prices.lamination * copies : 0.0);

  double get total =>
      (pages * copies * printRate) + laminationCost + bindingCost;

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
          'png'
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
                icon: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 36),
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
      }
    } catch (e) {
      _show('Error selecting document: $e');
    }
  }

  Future<void> submit() async {
    if (file == null) {
      return _show('Please choose a document to print.');
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

      // 2. Create order record
      final id = await widget.dataService.createOrder(
        studentId: widget.profile.id,
        studentName: widget.profile.name,
        studentEmail: widget.profile.email,
        fileName: file!.name,
        fileUrl: url,
        fileSizeBytes: fileSizeBytes,
        pages: pages,
        copies: copies,
        color: color,
        doubleSided: doubleSided,
        lamination: lamination,
        binding: bindingType != BindingType.none,
        paperType: paperType,
        bindingType: bindingType,
        total: total,
        paymentMode: payment,
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
        // 3. Launch online payment gateway redirection
        if (!mounted) return;
        final service = PaymentService();
        await service.startOnlinePayment(
          context: context,
          amountPaise: (total * 100).round(),
          appOrderId: id,
          studentEmail: widget.profile.email,
          onSuccess: (response) async {
            final ok = await service.verify(appOrderId: id, response: response);
            if (ok) {
              await widget.dataService.updateOrder(id, {
                'paymentStatus': 'paid',
              });
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
              await widget.dataService.updateOrder(id, {'paymentStatus': 'failed'});
              if (mounted) _show('Payment verification failed.');
            }
          },
          onFailure: (response) async {
            await widget.dataService.updateOrder(id, {'paymentStatus': 'failed'});
            if (mounted) _show('Payment cancelled or failed.');
          },
        );
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
              isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
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
                              color: file != null ? Colors.green : AppTheme.primary,
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
                            value: (fileSizeBytes / StorageService.maxFileSizeBytes)
                                .clamp(0.02, 1.0),
                            backgroundColor:
                                theme.dividerColor.withValues(alpha: 0.1),
                            color: AppTheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

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
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${(uploadProgress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: uploadProgress,
                          backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: Colors.teal, size: 18),
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
                      SwitchListTile.adaptive(
                        value: color,
                        onChanged: (v) => setState(() => color = v),
                        title: const Text(
                          'Color Printing',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '₹${(color ? (doubleSided ? widget.prices.colorDouble : widget.prices.colorSingle) : (doubleSided ? widget.prices.bwDouble : widget.prices.bwSingle)).toStringAsFixed(2)} / page',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: doubleSided,
                        onChanged: (v) => setState(() => doubleSided = v),
                        title: const Text(
                          'Double Sided (Back to Back)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          doubleSided ? 'Enabled' : 'Single sided',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Paper Type Selector
                      const Text(
                        'Paper Type & GSM',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('75 GSM Standard'),
                            selected: paperType == PaperType.standard75Gsm,
                            onSelected: (_) => setState(() => paperType = PaperType.standard75Gsm),
                          ),
                          ChoiceChip(
                            label: Text('100 GSM Bond (+₹${widget.prices.paper100Gsm.toStringAsFixed(1)})'),
                            selected: paperType == PaperType.executive100Gsm,
                            onSelected: (_) => setState(() => paperType = PaperType.executive100Gsm),
                          ),
                          ChoiceChip(
                            label: Text('Glossy Sheet (+₹${widget.prices.paperGlossy.toStringAsFixed(1)})'),
                            selected: paperType == PaperType.glossyPhoto,
                            onSelected: (_) => setState(() => paperType = PaperType.glossyPhoto),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Binding Selector
                      const Text(
                        'Binding & Finishing',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: bindingType == BindingType.none,
                            onSelected: (_) => setState(() => bindingType = BindingType.none),
                          ),
                          ChoiceChip(
                            label: const Text('Staple (₹2)'),
                            selected: bindingType == BindingType.staple,
                            onSelected: (_) => setState(() => bindingType = BindingType.staple),
                          ),
                          ChoiceChip(
                            label: Text('Spiral (+₹${widget.prices.spiralBinding.toStringAsFixed(0)})'),
                            selected: bindingType == BindingType.spiral,
                            onSelected: (_) => setState(() => bindingType = BindingType.spiral),
                          ),
                          ChoiceChip(
                            label: Text('Hard Cover (+₹${widget.prices.hardBinding.toStringAsFixed(0)})'),
                            selected: bindingType == BindingType.hardCover,
                            onSelected: (_) => setState(() => bindingType = BindingType.hardCover),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _counterRow('Number of Pages', pages, 1, (v) => setState(() => pages = v)),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _counterRow('Number of Copies', copies, 1, (v) => setState(() => copies = v)),
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
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        contentPadding: EdgeInsets.zero,
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
                        subtitle: 'Instant payment gateway redirection with SSL protection.',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(height: 10),
                      _paymentOption(
                        mode: PaymentMode.counter,
                        title: 'Pay at Counter',
                        subtitle: 'Receive a collection code; pay cash/UPI at shop counter.',
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
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
  ) =>
      Row(
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
}
