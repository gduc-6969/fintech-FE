import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/transaction_flow_data.dart';
import '../../../face_id/domain/face_id_policy.dart';
import '../../../face_id/domain/transaction_face_authorization.dart';

class TransactionReviewScreen extends StatefulWidget {
  final TransactionFlowData data;
  const TransactionReviewScreen({super.key, required this.data});

  @override
  State<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  TransactionType get _type => widget.data.type;

  String get _title {
    switch (_type) {
      case TransactionType.deposit:
        return 'Xác nhận nạp tiền';
      case TransactionType.withdraw:
        return 'Xác nhận rút tiền';
      case TransactionType.transfer:
        return 'Xác nhận chuyển tiền';
    }
  }

  String get _confirmLabel {
    switch (_type) {
      case TransactionType.deposit:
        return 'Xác nhận Nạp tiền';
      case TransactionType.withdraw:
        return 'Xác nhận Rút tiền';
      case TransactionType.transfer:
        return 'Xác nhận Chuyển tiền';
    }
  }

  Color get _amountColor {
    switch (_type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdraw:
        return AppColors.primaryNavy;
      case TransactionType.transfer:
        return const Color(0xFF3B82F6);
    }
  }

  void _handleConfirm() {
    final String prefix;
    if (_type == TransactionType.deposit) {
      prefix = 'topup';
    } else if (_type == TransactionType.withdraw) {
      prefix = 'withdraw';
    } else {
      prefix = 'wallet-transfer';
    }
    final idempotencyKey = '$prefix-${const Uuid().v7()}';
    final data = widget.data.copyWith(idempotencyKey: idempotencyKey);
    if (FaceIdPolicy.isRequiredFor(data.amount)) {
      context.push('/transaction/face-id', extra: data);
    } else {
      context.push(
        '/transaction/verify',
        extra: TransactionAuthorizationData(transaction: data),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.data.amount;

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
          _title,
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _reviewRow(
                    'Từ',
                    widget.data.fromName,
                    sub: widget.data.fromSub,
                  ),
                  _divider(),
                  _reviewRow('Đến', widget.data.toName, sub: widget.data.toSub),
                  _divider(),
                  // Amount row (special styling)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số tiền',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatCurrency(amount),
                          style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _reviewRow('Phí', '0 ₫'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (FaceIdPolicy.isRequiredFor(amount)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryNavy.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: AppColors.primaryNavy,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giao dịch từ 10.000.000 ₫ yêu cầu quét khuôn mặt trước, sau đó xác nhận bằng PIN hoặc OTP.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Giao dịch không thể hoàn tác sau khi xác nhận.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _confirmLabel,
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

  Widget _reviewRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.end,
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.end,
                  ),
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
