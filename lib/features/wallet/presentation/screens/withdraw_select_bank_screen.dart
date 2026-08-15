import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/transaction_flow_data.dart';
import '../../../../core/services/api_service.dart';

class WithdrawSelectBankScreen extends StatefulWidget {
  final int amount;
  const WithdrawSelectBankScreen({super.key, required this.amount});

  @override
  State<WithdrawSelectBankScreen> createState() =>
      _WithdrawSelectBankScreenState();
}

class _WithdrawSelectBankScreenState extends State<WithdrawSelectBankScreen> {
  List<Map<String, dynamic>> _banks = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, Color> _bankColors = {
    'VCB': const Color(0xFF007B40),
    'TCB': const Color(0xFFCC0000),
    'MB': const Color(0xFF1B4E9B),
    'BIDV': const Color(0xFF0D5A86),
    'ACB': const Color(0xFF005DAA),
    'VPB': const Color(0xFF00A651),
  };

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getLinkedBankAccounts();
      final mapped = response.map((item) {
        final code = item['bankCode'] as String? ?? '';
        final accNo = item['accountNumber'] as String? ?? '';
        final masked = accNo.length >= 4
            ? '···· ···· ···· ${accNo.substring(accNo.length - 4)}'
            : accNo;
        return {
          'id': item['id']?.toString() ?? '',
          'code': code,
          'name': item['bankName'] ?? code,
          'color': _bankColors[code] ?? AppColors.primaryNavy,
          'maskedAccount': masked,
          'holder': item['accountHolderName'] ?? '',
        };
      }).toList();
      if (mounted)
        setState(() {
          _banks = mapped;
          _isLoading = false;
        });
    } on DioException catch (e) {
      if (mounted)
        setState(() {
          _error = ApiService.parseDioError(e);
          _isLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Không thể tải danh sách ngân hàng liên kết';
          _isLoading = false;
        });
    }
  }

  void _selectBank(Map<String, dynamic> bank) {
    final reviewData = TransactionFlowData(
      type: TransactionType.withdraw,
      fromName: ApiService.currentUserFullName ?? 'Ví của tôi',
      fromSub: 'Ví Walli',
      toName: bank['name']?.toString() ?? '',
      toSub: bank['maskedAccount']?.toString(),
      amount: widget.amount,
      bankId: bank['id']?.toString(),
    );
    context.push('/transaction/review', extra: reviewData);
  }

  @override
  Widget build(BuildContext context) {
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
          'Rút tiền — Chọn ngân hàng',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryNavy),
      );
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.dmSans(color: AppColors.error)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadBanks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_banks.isEmpty) return _buildEmptyState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Chọn ngân hàng đích',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _banks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildBankRow(_banks[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildBankRow(Map<String, dynamic> bank) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectBank(bank),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bank['color'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  bank['code'],
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank['name'],
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bank['maskedAccount'],
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bank['holder'],
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏦', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Chưa có ngân hàng liên kết',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Liên kết ngân hàng để rút tiền.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/select-bank', extra: <String>[]),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Liên kết ngân hàng'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
