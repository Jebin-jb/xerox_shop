import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/storage_service.dart';

class BankPaymentAccountScreen extends StatefulWidget {
  final DataService dataService;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const BankPaymentAccountScreen({
    super.key,
    required this.dataService,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  State<BankPaymentAccountScreen> createState() =>
      _BankPaymentAccountScreenState();
}

class _BankPaymentAccountScreenState extends State<BankPaymentAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _upiIdCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  bool _isOnlinePaymentEnabled = true;
  bool _isEditing = false;
  bool _saving = false;
  bool _uploadingQr = false;
  String _qrImageUrl = '';
  ShopPaymentAccount _currentAccount = ShopPaymentAccount.empty();

  @override
  void initState() {
    super.initState();
    _loadCurrentAccount();
  }

  void _loadCurrentAccount() {
    _currentAccount = widget.dataService.currentPaymentAccount;
    _populateFields(_currentAccount);
    _isEditing = !_currentAccount.isConfigured;
  }

  void _populateFields(ShopPaymentAccount acc) {
    _upiIdCtrl.text = acc.upiId;
    _displayNameCtrl.text = acc.payeeName;
    _bankCtrl.text = acc.paymentApp.isNotEmpty ? acc.paymentApp : (acc.bankName.isNotEmpty ? acc.bankName : 'Google Pay');
    _holderCtrl.text = acc.accountHolderName;
    _accountNumberCtrl.text = acc.accountNumber;
    _ifscCtrl.text = acc.ifsc;
    _isOnlinePaymentEnabled = acc.isOnlinePaymentEnabled;
    _qrImageUrl = acc.qrImageUrl;
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _displayNameCtrl.dispose();
    _bankCtrl.dispose();
    _holderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadQr() async {
    setState(() => _uploadingQr = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        Uint8List? bytes = picked.bytes;
        if (bytes == null && picked.path != null) {
          bytes = await File(picked.path!).readAsBytes();
        }

        if (bytes != null && bytes.isNotEmpty) {
          final uploadedUrl = await StorageService().uploadPaymentQr(
            bytes: bytes,
            fileName: picked.name,
          );

          setState(() {
            _qrImageUrl = uploadedUrl;
            _currentAccount = _currentAccount.copyWith(
              qrImageUrl: uploadedUrl,
              updatedAt: DateTime.now(),
            );
          });

          // Save immediately to Supabase
          await widget.dataService.updatePaymentAccount(_currentAccount);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment QR uploaded & updated successfully!',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF00C853),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading QR code: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _savePaymentAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final updated = _currentAccount.copyWith(
        upiId: _upiIdCtrl.text.trim().toLowerCase(),
        paymentDisplayName: _displayNameCtrl.text.trim(),
        paymentApp: _bankCtrl.text.trim().isNotEmpty ? _bankCtrl.text.trim() : 'Google Pay',
        bankName: _bankCtrl.text.trim(),
        accountHolderName: _displayNameCtrl.text.trim(),
        qrImageUrl: _qrImageUrl,
        isOnlinePaymentEnabled: _isOnlinePaymentEnabled,
        updatedAt: DateTime.now(),
      );

      await widget.dataService.updatePaymentAccount(updated);

      setState(() {
        _currentAccount = updated;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bank & Payment Account saved successfully.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving payment details: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<ShopPaymentAccount>(
        stream: widget.dataService.paymentAccount(),
        initialData: _currentAccount,
        builder: (context, snapshot) {
          if (snapshot.hasData && !_saving && !_isEditing) {
            _currentAccount = snapshot.data!;
          }

          return Column(
            children: [
              _buildHeader(theme, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _isEditing
                          ? _buildEditForm(theme)
                          : _buildSavedOverviewCard(theme),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final canPop = Navigator.canPop(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Back to Dashboard',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank & Payment Account',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  'Configured UPI & Scannable QR for Student Payments',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedOverviewCard(ThemeData theme) {
    final lastUpdatedFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(_currentAccount.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Current QR Code Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, color: Colors.purple, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current QR Code',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              'Scanned by students for Online Pay',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        _populateFields(_currentAccount);
                        setState(() => _isEditing = true);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Details'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Scannable QR Display Container
                _buildScannableQrCard(theme, _currentAccount.qrImageUrl),

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _uploadingQr ? null : _pickAndUploadQr,
                      icon: _uploadingQr
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(_uploadingQr ? 'Uploading QR…' : 'Upload / Change QR Code'),
                    ),
                    if (_currentAccount.qrImageUrl.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showFullscreenQr(context, theme),
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: const Text('Enlarge QR'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Account Details Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Account Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentAccount.isOnlinePaymentEnabled
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _currentAccount.isOnlinePaymentEnabled ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Text(
                        _currentAccount.isOnlinePaymentEnabled ? 'ACTIVE ✓' : 'DISABLED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _currentAccount.isOnlinePaymentEnabled ? Colors.green[800] : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                _infoRow('UPI ID', _currentAccount.upiId, theme, isProminent: true),
                const SizedBox(height: 12),
                _infoRow('Payee Name', _currentAccount.payeeName, theme, isProminent: true),
                const SizedBox(height: 12),
                _infoRow('Payment App / Bank', _currentAccount.paymentApp, theme),
                const SizedBox(height: 12),
                _infoRow('Last Updated', lastUpdatedFormatted, theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannableQrCard(ThemeData theme, String qrUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: const Text(
              'Scan & Pay with any UPI App',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.purple,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Display uploaded QR
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              height: 220,
              color: Colors.grey.shade50,
              alignment: Alignment.center,
              child: qrUrl.isNotEmpty
                  ? Image.network(
                      qrUrl,
                      key: ValueKey(qrUrl),
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'QR Image Failed to Load',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No QR Uploaded Yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload your payment QR below',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentAccount.payeeName.isNotEmpty ? _currentAccount.payeeName : 'Campus Xerox',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _currentAccount.upiId.isNotEmpty ? _currentAccount.upiId : 'No UPI ID configured',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Edit Bank & Payment Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (_currentAccount.isConfigured)
                        TextButton(
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // UPI ID Field
                  TextFormField(
                    controller: _upiIdCtrl,
                    decoration: InputDecoration(
                      labelText: 'Merchant UPI ID *',
                      hintText: 'e.g. campusxerox@okaxis',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      helperText: 'Students will pay directly to this UPI address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'UPI ID is required.';
                      if (!val.contains('@')) return 'Enter a valid UPI ID (e.g., example@okaxis).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Payee Name Field
                  TextFormField(
                    controller: _displayNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Payee Name *',
                      hintText: 'e.g. Campus Xerox Shop',
                      prefixIcon: const Icon(Icons.person_rounded),
                      helperText: 'Displayed as merchant name in UPI apps',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Payee Name is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Payment App / Bank Name Field
                  TextFormField(
                    controller: _bankCtrl,
                    decoration: InputDecoration(
                      labelText: 'Payment App / Bank Name *',
                      hintText: 'e.g. Google Pay / State Bank of India',
                      prefixIcon: const Icon(Icons.account_balance_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Payment App or Bank Name is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // QR Code Section in Edit Form
                  Text(
                    'PAYMENT QR CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: _qrImageUrl.isNotEmpty
                                ? Image.network(
                                    _qrImageUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2_rounded, size: 36),
                                  )
                                : const Icon(Icons.qr_code_scanner_rounded, size: 36, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _qrImageUrl.isNotEmpty ? 'QR Code Attached' : 'No QR Code Uploaded',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _qrImageUrl.isNotEmpty
                                    ? 'Payment QR code image attached'
                                    : 'Upload a clear screenshot of your UPI QR code',
                                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _uploadingQr ? null : _pickAndUploadQr,
                          icon: _uploadingQr
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(_uploadingQr ? 'Uploading…' : (_qrImageUrl.isNotEmpty ? 'Change' : 'Upload')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Online Payment Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Accept Online Payments', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Allow students to pay online using this UPI account'),
                    value: _isOnlinePaymentEnabled,
                    onChanged: (val) => setState(() => _isOnlinePaymentEnabled = val),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _savePaymentAccount,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving ? 'Saving…' : 'Save Payment Details',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullscreenQr(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan & Pay QR',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black87),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _currentAccount.qrImageUrl.isNotEmpty
                    ? Image.network(
                        _currentAccount.qrImageUrl,
                        width: 280,
                        height: 280,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                        ),
                      )
                    : const SizedBox(
                        width: 280,
                        height: 280,
                        child: Center(
                          child: Text(
                            'No QR uploaded yet',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                _currentAccount.payeeName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                _currentAccount.upiId,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme, {bool isProminent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value.isNotEmpty ? value : 'Not configured',
            style: TextStyle(
              fontSize: isProminent ? 14 : 13,
              fontWeight: isProminent ? FontWeight.w900 : FontWeight.w700,
              color: isProminent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
