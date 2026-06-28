import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class DepositAmountScreen extends StatefulWidget {
  final Map<String, dynamic> bank;
  const DepositAmountScreen({super.key, required this.bank});

  @override
  State<DepositAmountScreen> createState() => _DepositAmountScreenState();
}

class _DepositAmountScreenState extends State<DepositAmountScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  int? _selectedChip;
  final List<int> _quickAmounts = [100000, 200000, 500000, 1000000, 2000000];
  final List<String> _quickLabels = ['100K', '200K', '500K', '1M', '2M'];

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

  int get _amount {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  void _onChipTap(int index) {
    setState(() {
      _selectedChip = index;
      _amountCtrl.text = _formatInt(_quickAmounts[index]);
    });
  }

  void _goToReview() {
    final reviewData = {
      'type': 'deposit',
      'fromName': widget.bank['name'],
      'fromSub': widget.bank['maskedAccount'],
      'toName': ApiService.currentUserFullName ?? 'Ví của tôi',
      'toSub': 'Ví Walli',
      'amount': _amount.toDouble(),
      'bankId': widget.bank['id'],
      'bankColor': widget.bank['color'],
      'bankCode': widget.bank['code'],
    };
    context.push('/transaction/review', extra: reviewData);
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _amount >= 1000;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: Text('Nạp tiền', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flow indicator
            _buildFlowIndicator(),
            const SizedBox(height: 28),
            // Amount label
            Text('SỐ TIỀN (VND)', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            // Amount input
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
                setState(() => _selectedChip = null);
              },
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textSecondary.withOpacity(0.4)),
                suffixText: '₫',
                suffixStyle: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
            const SizedBox(height: 14),
            // Quick chips
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(_quickAmounts.length, (i) {
                final selected = _selectedChip == i;
                return ChoiceChip(
                  label: Text(_quickLabels[i]),
                  selected: selected,
                  onSelected: (_) => _onChipTap(i),
                  selectedColor: AppColors.primaryNavy,
                  backgroundColor: AppColors.inputFill,
                  labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide.none,
                );
              }),
            ),
            const SizedBox(height: 40),
            // Continue button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: canContinue ? _goToReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  disabledBackgroundColor: AppColors.inputFill,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Tiếp tục', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: widget.bank['color'] as Color, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(widget.bank['code'], style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.bank['name'], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
          Icon(Icons.arrow_downward_rounded, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text('Ví của tôi', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
