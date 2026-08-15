import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class WithdrawAmountScreen extends StatefulWidget {
  const WithdrawAmountScreen({super.key});

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  int? _selectedChip;
  final List<int> _quickAmounts = [100000, 200000, 500000, 1000000, 2000000];
  final List<String> _quickLabels = ['100K', '200K', '500K', '1M', '2M'];
  double _availableBalance = 0;
  bool _isLoadingBalance = true;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    try {
      final wallet = await ApiService.getWallet();
      if (mounted) {
        setState(() {
          _availableBalance =
              (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _isLoadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _formatNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final num = int.tryParse(digits) ?? 0;
    return _formatInt(num);
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

  void _onChipTap(int index) {
    setState(() {
      _selectedChip = index;
      _amountCtrl.text = _formatInt(_quickAmounts[index]);
      _validateAmount();
    });
  }

  void _validateAmount() {
    if (_amount > _availableBalance) {
      _amountError =
          'Vượt quá số dư khả dụng (${_formatCurrency(_availableBalance)})';
    } else {
      _amountError = null;
    }
  }

  void _goToSelectBank() {
    context.push('/withdraw/select-bank', extra: _amount);
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _amount >= 1000 && _amount <= _availableBalance;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Rút tiền',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SỐ DƯ KHẢ DỤNG (VÍ CỦA TÔI)',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingBalance
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _formatCurrency(_availableBalance),
                          style: GoogleFonts.dmSans(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Amount label
            Text(
              'SỐ TIỀN (VND)',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              onChanged: (val) {
                final formatted = _formatNumber(val);
                if (formatted != val) {
                  _amountCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
                setState(() {
                  _selectedChip = null;
                  _validateAmount();
                });
              },
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
                suffixText: '₫',
                suffixStyle: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white,
                errorText: _amountError,
                errorStyle: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.error,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_quickAmounts.length, (i) {
                final selected = _selectedChip == i;
                return ChoiceChip(
                  label: Text(_quickLabels[i]),
                  selected: selected,
                  onSelected: (_) => _onChipTap(i),
                  selectedColor: AppColors.primaryNavy,
                  backgroundColor: AppColors.inputFill,
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                );
              }),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canContinue ? _goToSelectBank : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  disabledBackgroundColor: AppColors.inputFill,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Chọn ngân hàng đích',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
