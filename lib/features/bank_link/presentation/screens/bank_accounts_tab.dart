import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class BankAccountsTab extends StatefulWidget {
  final VoidCallback? onBankListChanged;
  const BankAccountsTab({super.key, this.onBankListChanged});

  @override
  State<BankAccountsTab> createState() => _BankAccountsTabState();
}

class _BankAccountsTabState extends State<BankAccountsTab> {
  List<Map<String, dynamic>> _linkedBanks = [];
  bool _isLoading = true;
  String? _error;

  // Mapping of bank codes to theme colors
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
    _loadLinkedBanks();
  }

  Future<void> _loadLinkedBanks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getLinkedBankAccounts();
      final mappedBanks = response.map((item) {
        final code = item['bankCode'] as String? ?? '';
        final accNo = item['accountNumber'] as String? ?? '';
        final masked = accNo.length >= 4 
            ? '····  ····  ····  ${accNo.substring(accNo.length - 4)}'
            : accNo;
        return {
          'id': item['id'],
          'code': code,
          'name': item['bankName'],
          'color': _bankColors[code] ?? AppColors.primaryNavy,
          'maskedAccount': masked,
          'holder': item['accountHolderName'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _linkedBanks = mappedBanks;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.parseDioError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách ngân hàng';
          _isLoading = false;
        });
      }
    }
  }

  // Tracks which bank ID is currently being unlinked (for per-card loading state)
  String? _unlinkingId;

  Future<void> _showRemoveConfirmation(Map<String, dynamic> bank) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
              ),
              const SizedBox(height: 16),
              Text('Xóa tài khoản ngân hàng?', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Thao tác này sẽ hủy liên kết ${bank['name']} khỏi ví của bạn. Bạn có thể thêm lại bất cứ lúc nào.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Text('Giữ lại', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final id = bank['id']?.toString();
    if (id == null) return;

    setState(() => _unlinkingId = id);
    try {
      await ApiService.unlinkBankAccount(id);
      if (mounted) {
        setState(() {
          _linkedBanks.removeWhere((b) => b['id']?.toString() == id);
          _unlinkingId = null;
        });
        widget.onBankListChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã hủy liên kết ${bank['name']} thành công'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _unlinkingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.parseDioError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unlinkingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xảy ra lỗi, vui lòng thử lại.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }


  void _navigateToAddBank() async {
    final linkedCodes = _linkedBanks.map((b) => b['code'] as String).toList();
    await context.push('/select-bank', extra: linkedCodes);
    if (mounted) {
      _loadLinkedBanks(); // refresh the tab's own list
      widget.onBankListChanged?.call(); // notify dashboard to refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // light surface from image
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tài khoản ngân hàng',
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy, // very dark blue
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddBank,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero, // Override global infinite width
                      backgroundColor: const Color(0xFF1F2937), // dark gray/navy
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadLinkedBanks,
                color: AppColors.primaryNavy,
                child: _buildBodyContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
    }
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
              onPressed: _loadLinkedBanks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_linkedBanks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: _buildEmptyState(),
      );
    }
    return _buildList();
  }

  Widget _buildList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _linkedBanks.length,
      itemBuilder: (context, index) {
        final bank = _linkedBanks[index];
        return _buildBankCard(bank);
      },
    );
  }

  Widget _buildBankCard(Map<String, dynamic> bank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bank['color'], borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(bank['code'], style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        bank['name'],
                        style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('ĐÃ XÁC MINH', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(bank['maskedAccount'], style: GoogleFonts.robotoMono(fontSize: 14, color: AppColors.textSecondary, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(bank['holder'], style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Overflow Menu / Loading indicator
          Builder(builder: (_) {
            final isUnlinking = _unlinkingId == bank['id']?.toString();
            return Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isUnlinking
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'remove') {
                          _showRemoveConfirmation(bank);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Text('Xóa', style: GoogleFonts.dmSans(color: AppColors.error, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text('Chưa có ngân hàng liên kết', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Liên kết tài khoản ngân hàng để dễ dàng nạp và rút tiền từ ví của bạn.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddBank,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm tài khoản ngân hàng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
