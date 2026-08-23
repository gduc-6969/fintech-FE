import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class TransactionHistoryTab extends StatefulWidget {
  const TransactionHistoryTab({super.key});

  @override
  State<TransactionHistoryTab> createState() => _TransactionHistoryTabState();
}

class _TransactionHistoryTabState extends State<TransactionHistoryTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _transactions = [];
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Map UI filter to backend type for server-side filtering where possible
      String? apiType;
      if (_selectedFilter == 'DEPOSIT') {
        apiType = 'BANK_TO_WALLET';
      } else if (_selectedFilter == 'WITHDRAW') {
        apiType = 'WALLET_TO_BANK';
      }
      // TRANSFER maps to two backend types (WALLET_TRANSFER_IN + WALLET_TRANSFER_OUT),
      // so it is handled client-side below after fetching all records.

      final txs = await ApiService.getTransactions(type: apiType);

      List<dynamic> filteredTxs = txs;
      if (_selectedFilter == 'TRANSFER') {
        filteredTxs = txs.where((tx) {
          final type = (tx['type'] as String?)?.toUpperCase() ?? '';
          return type == 'WALLET_TRANSFER_IN' || type == 'WALLET_TRANSFER_OUT';
        }).toList();
      }

      if (mounted) {
        setState(() {
          _transactions = filteredTxs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải lịch sử giao dịch';
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = value);
            _fetchHistory();
          }
        },
        selectedColor: AppColors.primaryNavy,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppColors.primaryNavy : AppColors.border),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildTxRow(dynamic tx) {
    final typeStr = (tx['type'] as String?)?.toUpperCase() ?? 'BANK_TO_WALLET';
    final statusStr = (tx['status'] as String?)?.toUpperCase() ?? 'SUCCESS';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = tx['updatedAt'] as String? ?? '';
    
    bool isCredit = typeStr == 'BANK_TO_WALLET' || typeStr == 'WALLET_TRANSFER_IN';

    IconData icon;
    Color iconBg;
    Color iconColor;
    String labelText;

    if (typeStr == 'BANK_TO_WALLET') {
      icon = Icons.south_west_rounded;
      iconBg = const Color(0xFFDCFCE7);
      iconColor = AppColors.success;
      labelText = 'Nạp tiền';
    } else if (typeStr == 'WALLET_TO_BANK') {
      icon = Icons.north_east_rounded;
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFF59E0B);
      labelText = 'Rút tiền';
    } else {
      icon = Icons.swap_horiz_rounded;
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF3B82F6);
      labelText = 'Chuyển tiền';
    }

    Color statusColor;
    String statusLabel;
    if (statusStr == 'SUCCESS') {
      statusColor = AppColors.success;
      statusLabel = 'THÀNH CÔNG';
    } else if (statusStr == 'PENDING') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'ĐANG XỬ LÝ';
    } else if (statusStr == 'TIMED_OUT') {
      statusColor = const Color(0xFF8B5CF6);
      statusLabel = 'HẾT THỜI GIAN';
    } else {
      statusColor = AppColors.error;
      statusLabel = 'THẤT BẠI';
    }

    final amountDisplay = isCredit ? '+${_formatVnd(amount.abs())}' : '-${_formatVnd(amount.abs())}';

    return GestureDetector(
      onTap: () {
        context.push('/transaction/detail', extra: tx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labelText, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_formatDate(dateStr), style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
                  if (tx['description'] is String && (tx['description'] as String).isNotEmpty)
                    Text(
                      tx['description'] as String,
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountDisplay,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(statusLabel, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text('Lịch sử giao dịch', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'ALL'),
                _buildFilterChip('Nạp tiền', 'DEPOSIT'),
                _buildFilterChip('Rút tiền', 'WITHDRAW'),
                _buildFilterChip('Chuyển tiền', 'TRANSFER'),
              ],
            ),
          ),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchHistory,
              color: AppColors.primaryNavy,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.error)))
                      : _transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text('Không tìm thấy giao dịch nào.', style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textSecondary)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) => _buildTxRow(_transactions[index]),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
