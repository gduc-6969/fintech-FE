import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Map<String, dynamic> _tx;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tx = Map<String, dynamic>.from(widget.transaction);
    final txId = _tx['id']?.toString();
    if (txId != null && txId.isNotEmpty && txId != '-') {
      _fetchDetails(txId);
    }
  }

  Future<void> _fetchDetails(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final details = await ApiService.getTransactionDetail(id);
      if (mounted) {
        setState(() {
          // Merge details into _tx map (keep original ID)
          _tx.addAll(details);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatVnd(double amount) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return format.format(amount);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeStr = (_tx['type'] as String?)?.toUpperCase() ?? 'BANK_TO_WALLET';
    final statusStr = (_tx['status'] as String?)?.toUpperCase() ?? 'SUCCESS';
    final amount = (_tx['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = _tx['updatedAt'] as String? ?? _tx['createdAt'] as String? ?? '';
    final txId = _tx['id']?.toString() ?? '-';
    final description = _tx['description'] as String? ?? '-';
    
    String counterparty = 'Hệ thống ví';
    if (typeStr == 'BANK_TO_WALLET' || typeStr == 'DEPOSIT') {
      counterparty = 'Nạp từ ngân hàng';
    } else if (typeStr == 'WALLET_TO_BANK' || typeStr == 'WITHDRAW') {
      counterparty = 'Rút về ngân hàng';
    } else {
      final cpName = _tx['counterpartyFullName'] as String?;
      final cpPhone = _tx['counterpartyPhoneNumber'] as String?;
      if (cpName != null && cpName.isNotEmpty) {
        counterparty = cpPhone != null ? '$cpName ($cpPhone)' : cpName;
      } else {
        counterparty = _tx['counterparty'] as String? ?? 'Hệ thống ví';
      }
    }

    bool isCredit = typeStr == 'BANK_TO_WALLET' || typeStr == 'WALLET_TRANSFER_IN' || typeStr == 'DEPOSIT';

    IconData icon;
    Color iconBg;
    Color iconColor;
    String typeLabel;
    String statusLabel;

    if (typeStr == 'BANK_TO_WALLET' || typeStr == 'DEPOSIT') {
      icon = Icons.south_west_rounded;
      iconBg = const Color(0xFFDCFCE7);
      iconColor = AppColors.success;
      typeLabel = 'Nạp tiền';
    } else if (typeStr == 'WALLET_TO_BANK' || typeStr == 'WITHDRAW') {
      icon = Icons.north_east_rounded;
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFF59E0B);
      typeLabel = 'Rút tiền';
    } else {
      icon = Icons.swap_horiz_rounded;
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF3B82F6);
      typeLabel = 'Chuyển tiền';
    }

    Color statusColor;
    if (statusStr == 'SUCCESS') {
      statusColor = AppColors.success;
      statusLabel = 'THÀNH CÔNG';
    } else if (statusStr == 'PENDING') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'ĐANG XỬ LÝ';
    } else {
      statusColor = AppColors.error;
      statusLabel = 'THẤT BẠI';
    }

    final amountDisplay = isCredit ? '+${_formatVnd(amount.abs())}' : '-${_formatVnd(amount.abs())}';
    final amountColor = isCredit ? AppColors.success : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Chi tiết giao dịch',
          style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  const SizedBox(height: 8),
                  
                  // Amount
                  Text(
                    amountDisplay,
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Type Subtitle
                  Text(
                    typeLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Mã giao dịch', txId, isMono: true),
                        _buildDivider(),
                        _buildDetailRow('Loại giao dịch', typeLabel.toUpperCase()),
                        _buildDivider(),
                        _buildDetailRow('Trạng thái', statusLabel, valueColor: statusColor),
                        _buildDivider(),
                        _buildDetailRow('Thời gian', _formatDate(dateStr)),
                        _buildDivider(),
                        _buildDetailRow('Nội dung', description),
                        _buildDivider(),
                        _buildDetailRow('Đối tác', counterparty),
                        _buildDivider(),
                        _buildDetailRow('Phí', '0 ₫'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMono = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: isMono
                  ? GoogleFonts.robotoMono(
                      fontSize: 14,
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )
                  : GoogleFonts.dmSans(
                      fontSize: 14,
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppColors.border.withOpacity(0.5),
      height: 1,
      thickness: 1,
    );
  }
}
