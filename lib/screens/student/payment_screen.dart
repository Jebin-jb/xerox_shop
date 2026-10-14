import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/payment/payment_models.dart';
import '../../services/payment/upi_payment_service.dart';
import '../../services/supabase_service.dart';

class PaymentScreen extends StatefulWidget {
  final String? orderId;
  final DataService? dataService;
  final double totalAmount;
  final String orderCode;
  final String studentName;
  final String studentEmail;
  final int pages;
  final int copies;
  final bool isColor;
  final bool isDoubleSided;
  final BindingType bindingType;
  final PaperType paperType;
  final bool lamination;

  const PaymentScreen({
    super.key,
    this.orderId,
    this.dataService,
    required this.totalAmount,
    required this.orderCode,
    required this.studentName,
    required this.studentEmail,
    required this.pages,
    required this.copies,
    required this.isColor,
    required this.isDoubleSided,
    required this.bindingType,
    required this.paperType,
    required this.lamination,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  ShopPaymentAccount _shopAccount = ShopPaymentAccount.empty();
  bool _isLoadingConfig = true;
  bool _isProcessing = false;
  bool _hasLaunchedUpi = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFreshPaymentConfig();
  }

  /// Always fetch the freshest payment settings directly from Supabase
  Future<void> _loadFreshPaymentConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final account = await SupabaseService().getFreshPaymentSettings();
      if (mounted) {
        setState(() {
          _shopAccount = account;
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fresh payment settings: $e');
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  bool get _isOnlinePaymentAvailable =>
      _shopAccount.isOnlinePaymentEnabled && _shopAccount.upiId.isNotEmpty;

  /// Builds standard UPI URI with proper Uri.encodeComponent to prevent `+` in transaction note
  Uri _buildCurrentUpiUri() {
    return UpiPaymentService.instance.buildUpiUri(
      account: _shopAccount,
      amount: widget.totalAmount,
      orderCode: widget.orderCode,
      note: 'Campus Xerox Order ${widget.orderCode}',
    );
  }

  Future<void> _handleOpenUpiApp() async {
    if (!_isOnlinePaymentAvailable) {
      _showUnavailableDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Opening UPI Payment App…';
    });

    // 1. Mark order payment status as PAYMENT_INITIATED
    final orderId = widget.orderId;
    if (orderId != null && widget.dataService != null) {
      await widget.dataService!.updateOrder(orderId, {
        'paymentStatus': 'payment_initiated',
        'paymentMode': 'online',
      });
    }

    // 2. Build correctly encoded UPI URI with fresh Supabase data
    final uri = _buildCurrentUpiUri();

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        // Try launching anyway or report error
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showErrorSnackBar(
              'No UPI payment app found. Please install Google Pay, PhonePe, or Paytm, or pay at counter.',
            );
          }
          return;
        }
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasLaunchedUpi = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar('Could not launch payment app: $e');
      }
    }
  }

  void _copyUpiId() {
    if (_shopAccount.upiId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _shopAccount.upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('UPI ID "${_shopAccount.upiId}" copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showIHavePaidDialog() {
    final utrController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF00C853), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Payment Proof',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                          Text(
                            'Enter your UPI reference for shopkeeper verification',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Paid:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00C853),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: utrController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'UPI Transaction ID / UTR / Reference No. *',
                    hintText: 'e.g. 428198271822 or UPI ref number',
                    prefixIcon: const Icon(Icons.receipt_long_rounded),
                    helperText: 'Found in your Google Pay, PhonePe, or Paytm receipt',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the transaction reference / UTR number.';
                    }
                    if (val.trim().length < 6) {
                      return 'Transaction reference should be at least 6 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'SUBMIT FOR VERIFICATION',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final utr = utrController.text.trim();

                    Navigator.pop(ctx); // Close sheet

                    // Update order in Supabase & local cache: status -> PAYMENT_SUBMITTED
                    final orderId = widget.orderId;
                    if (orderId != null && widget.dataService != null) {
                      await widget.dataService!.updateOrder(orderId, {
                        'paymentMode': 'online',
                        'paymentStatus': 'payment_submitted',
                        'transactionReference': utr,
                        'paymentMethod': 'UPI',
                      });
                    }

                    final result = UpiPaymentResult.submitted(
                      method: PaymentAppMethod.otherUpi,
                      amount: widget.totalAmount,
                      orderCode: widget.orderCode,
                      transactionReference: utr,
                    );

                    if (mounted) {
                      Navigator.pop(context, result);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSwitchToCounter() async {
    final orderId = widget.orderId;
    if (orderId != null && widget.dataService != null) {
      await widget.dataService!.updateOrder(orderId, {
        'paymentMode': 'counter',
        'paymentStatus': 'unpaid',
        'status': 'pending',
      });
    }

    final counterResult = UpiPaymentResult(
      status: PaymentStatusState.pending,
      method: PaymentAppMethod.counter,
      transactionReference: 'COUNTER',
      amount: 0,
      paidAt: DateTime.now(),
    );

    if (mounted) {
      Navigator.pop(context, counterResult);
    }
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 36),
        title: const Text(
          'Online Payment Unavailable',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Online payment is temporarily unavailable. Please choose Pay at Counter.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleSwitchToCounter();
            },
            child: const Text('Choose Pay at Counter'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ONLINE PAY', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh Payment Settings',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFreshPaymentConfig,
          ),
        ],
      ),
      body: _isLoadingConfig
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching latest payment settings…'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Order Total & Code Header
                  _buildOrderSummaryCard(theme),
                  const SizedBox(height: 16),

                  // 2. Post-UPI Feedback Banner (If student returned from UPI app)
                  if (_hasLaunchedUpi) ...[
                    _buildPostUpiBanner(theme),
                    const SizedBox(height: 16),
                  ],

                  // 3. Dynamic Scannable QR Code Card (from Supabase)
                  _buildDynamicQrCard(theme),
                  const SizedBox(height: 20),

                  // 4. Action Buttons
                  if (!_hasLaunchedUpi) ...[
                    // Primary button: OPEN UPI APP
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          _isProcessing ? _statusMessage : 'OPEN UPI APP',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        onPressed: _isProcessing ? null : () => _handleOpenUpiApp(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fallback button: PAY AT COUNTER
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.storefront_rounded, size: 18),
                        label: const Text(
                          'PAY AT COUNTER',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: _handleSwitchToCounter,
                      ),
                    ),
                  ] else ...[
                    // Post-UPI action buttons
                    _buildPostUpiButtons(theme),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount to Pay',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${widget.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'ORDER: ${widget.orderCode}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicQrCard(ThemeData theme) {
    final qrUrl = _shopAccount.qrImageUrl;
    final payeeName = _shopAccount.payeeName.isNotEmpty ? _shopAccount.payeeName : 'Campus Xerox';
    final upiId = _shopAccount.upiId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Campus Xerox',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Scan & Pay',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.purple.shade700,
            ),
          ),
          const SizedBox(height: 16),

          // Scannable un-distorted QR container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: qrUrl.isNotEmpty
                  ? Image.network(
                      qrUrl,
                      key: ValueKey(qrUrl),
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain, // SCANNABLE: Never distorted!
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 220,
                        height: 220,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('QR Image Loading Error', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      width: 220,
                      height: 220,
                      color: Colors.grey.shade50,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.purple.shade300),
                          const SizedBox(height: 8),
                          Text(
                            upiId.isNotEmpty ? upiId : 'No QR uploaded by shop',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Payee & UPI details
          Text(
            'Payee: $payeeName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'UPI ID: $upiId',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _copyUpiId,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Amount: ₹${widget.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00C853),
            ),
          ),
          const SizedBox(height: 14),

          // Copy UPI ID button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('COPY UPI ID', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: _copyUpiId,
          ),
        ],
      ),
    );
  }

  Widget _buildPostUpiBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment not yet confirmed',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Did your bank deduct money? Tap "I HAVE PAID" and enter your transaction ID. If it failed, retry or pay at counter.',
                  style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostUpiButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. I HAVE PAID (Enter UTR)
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text(
              'I HAVE PAID',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
            ),
            onPressed: _showIHavePaidDialog,
          ),
        ),
        const SizedBox(height: 10),

        // 2. RETRY PAYMENT
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'RETRY PAYMENT',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () async {
              // FIRST fetch latest payment settings from Supabase
              await _loadFreshPaymentConfig();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment details refreshed.'),
                  duration: Duration(seconds: 1),
                ),
              );
              _handleOpenUpiApp();
            },
          ),
        ),
        const SizedBox(height: 10),

        // 3. USE ANOTHER UPI APP
        SizedBox(
          height: 48,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
            label: const Text(
              'USE ANOTHER UPI APP',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () async {
              await _loadFreshPaymentConfig();
              _handleOpenUpiApp();
            },
          ),
        ),
        const SizedBox(height: 10),

        // 4. SWITCH TO PAY AT COUNTER
        SizedBox(
          height: 48,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepOrange,
            ),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text(
              'SWITCH TO PAY AT COUNTER',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _handleSwitchToCounter,
          ),
        ),
      ],
    );
  }
}
