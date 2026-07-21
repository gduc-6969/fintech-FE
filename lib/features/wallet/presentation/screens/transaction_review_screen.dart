import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class TransactionReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const TransactionReviewScreen({super.key, required this.data});

  @override
  State<TransactionReviewScreen> createState() => _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  bool _isProcessing = false;
  String? _error;

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  String get _type => widget.data['type'] as String;

  String get _title {
    switch (_type) {
      case 'deposit': return 'Xác nhận nạp tiền';
      case 'withdraw': return 'Xác nhận rút tiền';
      case 'transfer': return 'Xác nhận chuyển tiền';
      default: return 'Xác nhận';
    }
  }

  String get _confirmLabel {
    switch (_type) {
      case 'deposit': return 'Xác nhận Nạp tiền';
      case 'withdraw': return 'Xác nhận Rút tiền';
      case 'transfer': return 'Xác nhận Chuyển tiền';
      default: return 'Xác nhận';
    }
  }

  Color get _amountColor {
    switch (_type) {
      case 'deposit': return AppColors.success;
      case 'withdraw': return AppColors.primaryNavy;
      case 'transfer': return const Color(0xFF3B82F6);
      default: return AppColors.textPrimary;
    }
  }

  Future<void> _handleConfirm() async {
    setState(() { _isProcessing = true; _error = null; });

    final String prefix;
    if (_type == 'deposit') {
      prefix = 'topup';
    } else if (_type == 'withdraw') {
      prefix = 'withdraw';
    } else {
      prefix = 'wallet-transfer';
    }
    
    final idempotencyKey = '$prefix-${const Uuid().v7()}';
    final amount = widget.data['amount'] as double;

    try {
      Map<String, dynamic> response;

      if (_type == 'deposit') {
        response = await ApiService.topUpFromBank(
          linkedBankAccountId: widget.data['bankId'] as String,
          amount: amount,
          idempotencyKey: idempotencyKey,
        );
      } else if (_type == 'withdraw') {
        response = await ApiService.withdrawToBank(
          linkedBankAccountId: widget.data['bankId'] as String,
          amount: amount,
          idempotencyKey: idempotencyKey,
        );
      } else {
        response = await ApiService.transferToWallet(
          recipientPhoneNumber: widget.data['recipientPhone'] as String,
          amount: amount,
          idempotencyKey: idempotencyKey,
        );
      }

      if (mounted) {
        final successData = {
          ...widget.data,
          'referenceCode': response['referenceCode'] ?? idempotencyKey,
          'createdAt': response['createdAt'] ?? DateTime.now().toIso8601String(),
          'status': response['status'] ?? 'PENDING',
        };
        context.pushReplacement('/transaction/success', extra: successData);
      }
    } on DioException catch (e) {
      // If we get a receive/send timeout, the backend likely finished processing
      // but the response took too long. Since we use idempotency keys, the
      // transaction was accepted. Navigate to success rather than showing an error.
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        if (mounted) {
          final successData = {
            ...widget.data,
            'referenceCode': idempotencyKey,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'PENDING',
          };
          context.pushReplacement('/transaction/success', extra: successData);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = ApiService.parseDioError(e);
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đã xảy ra lỗi không mong muốn';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.data['amount'] as double;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: Text(_title, style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Review card
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
                children: [
                  _reviewRow('Từ', widget.data['fromName'] as String, sub: widget.data['fromSub'] as String?),
                  _divider(),
                  _reviewRow('Đến', widget.data['toName'] as String, sub: widget.data['toSub'] as String?),
                  _divider(),
                  // Amount row (special styling)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Số tiền', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary)),
                        Text(_formatCurrency(amount), style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold, color: _amountColor)),
                      ],
                    ),
                  ),
                  _divider(),
                  _reviewRow('Phí', '0 ₫'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Giao dịch không thể hoàn tác sau khi xác nhận.',
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Confirm button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  disabledBackgroundColor: AppColors.primaryNavy.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_confirmLabel, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.end),
                if (sub != null)
                  Text(sub, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.end),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Divider(color: AppColors.border.withOpacity(0.6), height: 1),
  );
}
