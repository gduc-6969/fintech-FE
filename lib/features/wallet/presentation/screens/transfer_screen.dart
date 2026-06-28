import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  // Lookup state
  String _lookupState = 'initial'; // initial | loading | found | error
  String? _recipientFullName;
  String? _lookupError;

  // Chip selection
  int? _selectedChip;
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000, 1000000];
  final List<String> _quickLabels = ['50K', '100K', '200K', '500K', '1M'];

  // Balance
  double _availableBalance = 0;
  bool _isLoadingBalance = true;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _phoneCtrl.addListener(() {
      // Reset lookup whenever phone changes
      if (_lookupState != 'initial' && _lookupState != 'loading') {
        setState(() {
          _lookupState = 'initial';
          _recipientFullName = null;
          _lookupError = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _fetchBalance() async {
    try {
      final wallet = await ApiService.getWallet();
      if (mounted) {
        setState(() {
          _availableBalance = (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _isLoadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return _formatInt(int.tryParse(digits) ?? 0);
  }

  String _formatInt(int value) {
    return NumberFormat.decimalPattern('vi_VN').format(value);
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  int get _amount {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  void _validateAmount() {
    if (_amount > _availableBalance) {
      _amountError = 'Vượt quá số dư khả dụng (${_formatCurrency(_availableBalance)})';
    } else {
      _amountError = null;
    }
  }

  // ── Lookup ─────────────────────────────────────────────────────────────────

  Future<void> _handleFind() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) return;

    setState(() {
      _lookupState = 'loading';
      _lookupError = null;
      _recipientFullName = null;
    });

    try {
      final fullName = await ApiService.lookupTransferRecipient(
        recipientPhoneNumber: phone,
      );
      if (mounted) {
        setState(() {
          _lookupState = 'found';
          _recipientFullName = fullName;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          _lookupError = ApiService.parseDioError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          _lookupError = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
        });
      }
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goToReview() {
    final phone = _phoneCtrl.text.trim();
    final reviewData = {
      'type': 'transfer',
      'fromName': ApiService.currentUserFullName ?? 'Ví của tôi',
      'fromSub': 'Ví Walli',
      'toName': _recipientFullName ?? 'Người dùng ví',
      'toSub': phone,
      'amount': _amount.toDouble(),
      'recipientPhone': phone,
    };
    context.push('/transaction/review', extra: reviewData);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final phone = _phoneCtrl.text.trim();
    final bool canFind = phone.length >= 10 && _lookupState != 'loading';
    final bool recipientFound = _lookupState == 'found';
    final bool canReview = recipientFound && _amount >= 1000 && _amount <= _availableBalance;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Chuyển tiền', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available balance chip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Text('Khả dụng: ', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                _isLoadingBalance
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_formatCurrency(_availableBalance),
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Step 1: Recipient phone ─────────────────────────────────────
            Text('SỐ ĐIỆN THOẠI NGƯỜI NHẬN',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                  style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'vd. 0123456789',
                    hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.textSecondary),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canFind ? _handleFind : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: AppColors.primaryNavy,
                    disabledBackgroundColor: AppColors.inputFill,
                    disabledForegroundColor: AppColors.textSecondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: _lookupState == 'loading'
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Tìm', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),

            // Lookup result
            if (_lookupState == 'found' && _recipientFullName != null) ...[
              const SizedBox(height: 14),
              _buildRecipientCard(),
            ],
            if (_lookupState == 'error') ...[
              const SizedBox(height: 14),
              _buildLookupError(),
            ],

            const SizedBox(height: 24),

            // ── Step 2: Amount (only active after found) ────────────────────
            Row(children: [
              Text('SỐ TIỀN (VND)',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold,
                      color: recipientFound ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.4), letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 8),
            AbsorbPointer(
              absorbing: !recipientFound,
              child: Opacity(
                opacity: recipientFound ? 1.0 : 0.4,
                child: Column(
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      onChanged: (val) {
                        final formatted = _formatNumber(val);
                        if (formatted != val) {
                          _amountCtrl.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }
                        setState(() { _selectedChip = null; _validateAmount(); });
                      },
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary.withOpacity(0.4)),
                        suffixText: '₫',
                        suffixStyle: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        filled: true, fillColor: Colors.white,
                        errorText: _amountError,
                        errorStyle: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_quickAmounts.length, (i) {
                        final selected = _selectedChip == i;
                        return ChoiceChip(
                          label: Text(_quickLabels[i]),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedChip = i;
                              _amountCtrl.text = _formatInt(_quickAmounts[i]);
                              _validateAmount();
                            });
                          },
                          selectedColor: AppColors.primaryNavy,
                          backgroundColor: AppColors.inputFill,
                          labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.textPrimary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide.none,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Review button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: canReview ? _goToReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  disabledBackgroundColor: AppColors.inputFill,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Xem lại giao dịch', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    final initials = (_recipientFullName ?? 'W').split(' ')
        .where((w) => w.isNotEmpty).take(2)
        .map((w) => w[0].toUpperCase()).join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(initials, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_recipientFullName ?? 'Người dùng ví',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(_phoneCtrl.text.trim(),
              style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
            const SizedBox(width: 4),
            Text('Đã xác minh', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLookupError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(_lookupError ?? 'Không tìm thấy người nhận.',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
