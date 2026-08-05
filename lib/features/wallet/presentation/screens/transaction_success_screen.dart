import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const TransactionSuccessScreen({super.key, required this.data});

  @override
  State<TransactionSuccessScreen> createState() => _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  
  late String _currentStatus;
  Timer? _pollTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = (widget.data['status'] as String?)?.toUpperCase() ?? 'PENDING';
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();
    
    if (_currentStatus == 'PENDING') {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPolling || !mounted) return;
      _isPolling = true;
      try {
        final targetAmount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
        final txs = await ApiService.getTransactions();
        if (txs.isNotEmpty) {
          for (final tx in txs.take(5)) {
            final status = (tx['status'] as String?)?.toUpperCase();
            final txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

            if (status != null && status != 'PENDING') {
              if ((txAmount.abs() - targetAmount.abs()).abs() < 1.0) {
                if (mounted) {
                  setState(() {
                    _currentStatus = status;
                    _animCtrl.forward(from: 0.0);
                  });
                  timer.cancel();
                }
                break;
              }
            }
          }
        }
      } catch (_) {
        // ignore errors
      } finally {
        _isPolling = false;
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.now());
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM dd, yyyy • HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final amount = d['amount'] as double? ?? 0;
    final fromName = d['fromName'] as String? ?? '';
    final toName = d['toName'] as String? ?? '';
    final fromSub = d['fromSub'] as String? ?? '';
    final toSub = d['toSub'] as String? ?? '';
    final refCode = d['referenceCode'] as String? ?? '-';
    final createdAt = d['createdAt'] as String?;
    final isPending = _currentStatus == 'PENDING';
    final isFailed = _currentStatus == 'FAILED';

    return Scaffold(
      body: Column(
        children: [
          // Green gradient top
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPending
                    ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                    : isFailed
                        ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                        : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Animated check icon
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: isPending
                          ? [const Color(0xFFFBBF24), const Color(0xFFD97706)]
                          : isFailed
                              ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                              : [const Color(0xFF4ADE80), const Color(0xFF16A34A)]),
                      boxShadow: [BoxShadow(color: (isPending ? const Color(0xFFF59E0B) : isFailed ? const Color(0xFFEF4444) : const Color(0xFF22C55E)).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: Icon(isPending ? Icons.hourglass_top_rounded : isFailed ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 12),
                Text(isPending ? 'GIAO DỊCH ĐANG XỬ LÝ' : isFailed ? 'GIAO DỊCH THẤT BẠI' : 'GIAO DỊCH THÀNH CÔNG', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.85), letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(_formatCurrency(amount), style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                // From → To pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(fromName, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Flexible(child: Text(toName, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Ngày & Giờ', _formatDateTime(createdAt)),
                        _divider(),
                        _detailRow('Từ', fromName, sub: fromSub),
                        _divider(),
                        _detailRow('Đến', toName, sub: toSub),
                        _divider(),
                        _detailRow('Phí', '0 ₫'),
                        _divider(),
                        _detailRow('Mã tham chiếu', refCode, mono: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Done button
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Xong', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // View in History (placeholder)
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                         Navigator.of(context).popUntil((route) => route.isFirst);
                         // Note: To navigate to history tab specifically, we would need state management or a deep link
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryNavy,
                        side: BorderSide(color: AppColors.primaryNavy),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Xem trong Lịch sử', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _detailRow(String label, String value, {String? sub, bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: mono ? GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textPrimary) : GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.end),
                if (sub != null) Text(sub, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.end),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: AppColors.border.withOpacity(0.6), height: 1);
}
