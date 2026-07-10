import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class AccountDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> bank;
  const AccountDetailsScreen({super.key, required this.bank});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final TextEditingController _accCtrl = TextEditingController();
  
  String _lookupState = 'initial'; // initial, loading, found, error
  String? _accountHolderName;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _accCtrl.addListener(() {
      if (_lookupState != 'initial' && _lookupState != 'loading') {
        setState(() => _lookupState = 'initial');
      } else {
        setState(() {}); // to toggle Find button disabled state
      }
    });
  }

  @override
  void dispose() {
    _accCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleFind() async {
    if (_accCtrl.text.length < 6) return;

    setState(() {
      _isLoading = true;
      _lookupState = 'loading';
      _errorMessage = null;
    });

    try {
      final enteredAccount = _accCtrl.text.trim();
      final selectedBankCode = (widget.bank['code'] as String).toUpperCase();

      // Fetch all mock-bank accounts from backend
      final allBanks = await ApiService.getBanks();

      // Find matching bank entry by code + account number
      final match = allBanks.firstWhere(
        (b) =>
            (b['bankCode'] as String?)?.toUpperCase() == selectedBankCode &&
            (b['accountNumber'] as String?)?.trim() == enteredAccount,
        orElse: () => null,
      );

      if (!mounted) return;

      if (match == null) {
        setState(() {
          _lookupState = 'error';
          _errorMessage = 'Không tìm thấy tài khoản. Vui lòng kiểm tra lại số tài khoản và ngân hàng đã chọn.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _lookupState = 'found';
        _accountHolderName = match['accountHolderName'] as String? ?? 'KHÔNG XÁC ĐỊNH';
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          _errorMessage = ApiService.parseDioError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          _errorMessage = 'Đã xảy ra lỗi không mong muốn';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirm() async {
    setState(() => _isConfirming = true);

    try {
      final response = await ApiService.linkBankAccount(
        bankCode: widget.bank['code'],
        accountNumber: _accCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _isConfirming = false);
        final accountNo = _accCtrl.text.trim();
        final masked = accountNo.length >= 4 
            ? '····  ····  ····  ${accountNo.substring(accountNo.length - 4)}'
            : accountNo;

        final successData = {
          ...widget.bank,
          'maskedAccount': masked,
          'holder': response['accountHolderName'] as String? ?? _accountHolderName,
        };

        context.pushReplacement('/bank-link-success', extra: successData);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          String parsedMsg = ApiService.parseDioError(e);
          if (parsedMsg.toLowerCase().contains('already linked')) {
            parsedMsg = 'Tài khoản ngân hàng này đã được liên kết với một ví khác.';
          }
          _errorMessage = parsedMsg;
          _isConfirming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lookupState = 'error';
          _errorMessage = 'Đã xảy ra lỗi không mong muốn';
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canFind = _accCtrl.text.length >= 6;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Chi tiết tài khoản', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Bank Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.bank['color'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.bank['code'], style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.bank['name'], style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text('Thay đổi', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Input Row
            Row(
              children: [
                Text('SỐ TÀI KHOẢN', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                Text(' *', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _accCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Nhập số tài khoản',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52, // match textfield height roughly
                  child: ElevatedButton(
                    onPressed: canFind && !_isLoading ? _handleFind : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero, // Override global infinite width
                      backgroundColor: AppColors.primaryNavy,
                      disabledBackgroundColor: AppColors.inputFill,
                      disabledForegroundColor: AppColors.textSecondary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Tìm', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Outcomes
            if (_lookupState == 'error')
              _buildErrorPanel(),
            if (_lookupState == 'found')
              _buildSuccessCard(),
              
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
          const SizedBox(height: 16),
          Text('Liên kết tài khoản thất bại', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error)),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Đã xảy ra lỗi không xác định.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.error.withOpacity(0.8)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleFind,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    final accStr = _accCtrl.text;
    final masked = '···· ···· ···· ${accStr.length > 4 ? accStr.substring(accStr.length - 4) : accStr}';
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('TÀI KHOẢN ĐÃ XÁC MINH', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Số tài khoản', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                  Text(masked, style: GoogleFonts.robotoMono(fontSize: 14, color: AppColors.textPrimary, letterSpacing: 1)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chủ tài khoản', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                  Text(_accountHolderName ?? 'UNKNOWN', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isConfirming ? null : _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isConfirming 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Xác nhận & Liên kết tài khoản', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
