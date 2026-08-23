import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import 'package:intl/intl.dart';
import '../../../bank_link/presentation/screens/bank_accounts_tab.dart';
import '../../../profile/presentation/screens/profile_tab.dart';
import 'transaction_history_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models (mock)
// ─────────────────────────────────────────────────────────────────────────────

enum _TxType { deposit, withdraw, transfer }
enum _TxStatus { success, pending, failed }
enum _TxState { loaded, loading, error, empty }

class _MockBank {
  final String code;
  final String name;
  final String maskedAccount;
  final Color color;
  const _MockBank(this.code, this.name, this.maskedAccount, this.color);
}

class _MockTx {
  final _TxType type;
  final String label;
  final String date;
  final double amount;
  final _TxStatus status;
  final Map<String, dynamic> rawData;
  const _MockTx(this.type, this.label, this.date, this.amount, this.status, this.rawData);
}

// ─────────────────────────────────────────────────────────────────────────────
// WalletScreen — entry point
// ─────────────────────────────────────────────────────────────────────────────

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _activeNavIndex = 0;
  bool _balanceHidden = false;
  bool _isLoggingOut = false;
  _TxState _txState = _TxState.loading;

  String _userName = 'Đang tải...';
  double? _balance;
  bool _isLoadingBalance = true;

  // ── Bank data ──
  List<_MockBank> _banks = [];
  bool _isLoadingBanks = true;

  Timer? _pendingPollTimer;

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _userName = ApiService.currentUserFullName ?? 'Người dùng';
    _fetchWallet();
    _fetchTransactions();
    _fetchLinkedBanks();
  }

  Future<void> _fetchLinkedBanks() async {
    try {
      final response = await ApiService.getLinkedBankAccounts();
      if (mounted) {
        setState(() {
          _banks = response.map((item) {
            final code = item['bankCode'] as String? ?? '';
            final name = item['bankName'] as String? ?? code;
            final accNo = item['accountNumber'] as String? ?? '';
            final masked = accNo.length >= 4 
                ? '···· ${accNo.substring(accNo.length - 4)}'
                : accNo;
            return _MockBank(code, name, masked, _getBankColor(code));
          }).toList();
          _isLoadingBanks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  Color _getBankColor(String code) {
    switch (code) {
      case 'VCB': return const Color(0xFF007B40);
      case 'TCB': return const Color(0xFFCC0000);
      case 'MB': return const Color(0xFF1B4E9B);
      case 'BIDV': return const Color(0xFF0D5A86);
      case 'ACB': return const Color(0xFF005DAA);
      case 'VPB': return const Color(0xFF00A651);
      default: return AppColors.primaryNavy;
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final txs = await ApiService.getTransactions();
      if (mounted) {
        if (txs.isEmpty) {
          setState(() => _txState = _TxState.empty);
        } else {
          setState(() {
            _transactions = txs.map((tx) {
              final typeStr = (tx['type'] as String?)?.toUpperCase() ?? 'BANK_TO_WALLET';
              final statusStr = (tx['status'] as String?)?.toUpperCase() ?? 'SUCCESS';
              
              _TxType type = _TxType.transfer;
              if (typeStr == 'BANK_TO_WALLET') type = _TxType.deposit;
              else if (typeStr == 'WALLET_TO_BANK') type = _TxType.withdraw;
              
              _TxStatus status = _TxStatus.success;
              if (statusStr == 'PENDING') status = _TxStatus.pending;
              else if (statusStr == 'FAILED') status = _TxStatus.failed;

              final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
              final dateStr = tx['updatedAt'] as String? ?? '';
              
              String formattedDate = dateStr;
              try {
                if (dateStr.length >= 10) {
                  final dt = DateTime.parse(dateStr).toLocal();
                  final now = DateTime.now();
                  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                    formattedDate = 'Hôm nay';
                  } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
                    formattedDate = 'Hôm qua';
                  } else {
                    formattedDate = DateFormat('dd/MM').format(dt);
                  }
                }
              } catch (_) {}

              // Use typeStr for label fallback if referenceCode is not clean
              bool isPositive = amount > 0;
              if (type == _TxType.deposit) isPositive = true;
              else if (type == _TxType.withdraw) isPositive = false;
              else if (type == _TxType.transfer) {
                 if (typeStr == 'WALLET_TRANSFER_IN') isPositive = true;
                 else if (typeStr == 'WALLET_TRANSFER_OUT') isPositive = false;
                 else isPositive = amount > 0;
              }
              
              String label = 'Giao dịch';
              if (type == _TxType.deposit) label = 'Nạp tiền';
              else if (type == _TxType.withdraw) label = 'Rút tiền';
              else if (type == _TxType.transfer) label = 'Chuyển tiền';

              return _MockTx(type, label, formattedDate, isPositive ? amount.abs() : -amount.abs(), status, tx);
            }).toList();
            _txState = _TxState.loaded;
          });
          _checkAndStartPendingPoll();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _txState = _TxState.error);
    }
  }

  void _checkAndStartPendingPoll() {
    final hasPending = _transactions.any((tx) => tx.status == _TxStatus.pending);
    if (hasPending) {
      _startPendingPoll();
    } else {
      _pendingPollTimer?.cancel();
    }
  }

  void _startPendingPoll() {
    if (_pendingPollTimer != null && _pendingPollTimer!.isActive) return;
    _pendingPollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      await _fetchTransactionsSilent();
      await _fetchWalletSilent();
    });
  }

  Future<void> _fetchTransactionsSilent() async {
    try {
      final txs = await ApiService.getTransactions();
      if (mounted && txs.isNotEmpty) {
        setState(() {
          _transactions = txs.map((tx) {
            final typeStr = (tx['type'] as String?)?.toUpperCase() ?? 'BANK_TO_WALLET';
            final statusStr = (tx['status'] as String?)?.toUpperCase() ?? 'SUCCESS';
            
            _TxType type = _TxType.transfer;
            if (typeStr == 'BANK_TO_WALLET') type = _TxType.deposit;
            else if (typeStr == 'WALLET_TO_BANK') type = _TxType.withdraw;
            
            _TxStatus status = _TxStatus.success;
            if (statusStr == 'PENDING') status = _TxStatus.pending;
            else if (statusStr == 'FAILED') status = _TxStatus.failed;

            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final dateStr = tx['updatedAt'] as String? ?? '';
            
            String formattedDate = dateStr;
            try {
              if (dateStr.length >= 10) {
                final dt = DateTime.parse(dateStr).toLocal();
                final now = DateTime.now();
                if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                  formattedDate = 'Hôm nay';
                } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
                  formattedDate = 'Hôm qua';
                } else {
                  formattedDate = DateFormat('dd/MM').format(dt);
                }
              }
            } catch (_) {}

            bool isPositive = amount > 0;
            if (type == _TxType.deposit) isPositive = true;
            else if (type == _TxType.withdraw) isPositive = false;
            else if (type == _TxType.transfer) {
               if (typeStr == 'WALLET_TRANSFER_IN') isPositive = true;
               else if (typeStr == 'WALLET_TRANSFER_OUT') isPositive = false;
               else isPositive = amount > 0;
            }
            
            String label = 'Giao dịch';
            if (type == _TxType.deposit) label = 'Nạp tiền';
            else if (type == _TxType.withdraw) label = 'Rút tiền';
            else if (type == _TxType.transfer) label = 'Chuyển tiền';

            return _MockTx(type, label, formattedDate, isPositive ? amount.abs() : -amount.abs(), status, tx);
          }).toList();
        });
        final stillHasPending = _transactions.any((tx) => tx.status == _TxStatus.pending);
        if (!stillHasPending) {
          _pendingPollTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchWalletSilent() async {
    try {
      final wallet = await ApiService.getWallet();
      if (mounted) {
        setState(() {
          _balance = (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _isLoadingBalance = false;
        });
      }
    } catch (_) {}
  }


  Future<void> _fetchWallet() async {
    try {
      final wallet = await ApiService.getWallet();
      if (mounted) {
        setState(() {
          _balance = (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _balance = 0.0; // fallback or handle error
          _isLoadingBalance = false;
        });
      }
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  List<_MockTx> _transactions = [];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text('Hủy', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      await ApiService.logout();
      if (mounted) context.go(AppRouter.login);
    } catch (_) {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Scrollable body / Tabs ──
          Expanded(
            child: IndexedStack(
              index: _activeNavIndex,
              children: [
                // 0: Home Tab
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeaderSection(context)),
                    SliverToBoxAdapter(child: _buildQuickActions()),
                    SliverToBoxAdapter(child: _buildLinkedBanks()),
                    SliverToBoxAdapter(child: _buildRecentTransactions()),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
                // 1: History Tab
                const TransactionHistoryTab(),
                // 2: Scan Tab (opens full-screen scanner via push)
                const _ScanTabPlaceholder(),
                // 3: Cards Tab
                BankAccountsTab(
                  onBankListChanged: () {
                    setState(() => _isLoadingBanks = true);
                    _fetchLinkedBanks();
                  },
                ),
                // 4: Profile Tab
                ProfileTab(
                  onSwitchTab: (index) {
                    setState(() => _activeNavIndex = index);
                  },
                ),
              ],
            ),
          ),
          // ── Bottom Nav Bar ──
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 1 + 2 — Header + Balance Card in a single Stack
  // (keeps card always on top of the header gradient)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeaderSection(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // The gradient header covers the greeting area + a portion the card overlaps into.
    const double greetingAreaH = 92.0; // muted text + name row + vertical padding
    const double overlapIntoHeader = 56.0; // how much of the card sits inside the header
    final double headerH = topPad + greetingAreaH + overlapIntoHeader;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Background gradient (header) ──
            Container(
              height: headerH,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.deepNavy, AppColors.midNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative indigo glow orb
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.indigo.withOpacity(0.22),
                      ),
                    ),
                  ),
                  // Greeting row
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 20, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_userName 👋',
                                style: GoogleFonts.dmSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            _frostedIconButton(Icons.notifications_none_rounded, onTap: () {}),
                            const SizedBox(width: 8),
                            _frostedIconButton(
                              _isLoggingOut ? Icons.hourglass_empty : Icons.logout_rounded,
                              onTap: _isLoggingOut ? null : _handleLogout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Balance Card — rendered LAST in the Stack = always on top ──
            Positioned(
              // Start card `overlapIntoHeader` px above the bottom of the header
              top: headerH - overlapIntoHeader,
              left: 16,
              right: 16,
              child: _buildBalanceCard(),
            ),
          ],
        ),
        // Spacer so the scroll content below starts below the card bottom.
        // Card starts at (headerH - overlapIntoHeader) from top of Stack.
        // We need extra space = card height - overlapIntoHeader.
        // The card has: padding 24*2 + label 18 + gap 14 + amount 48 + gap 20 + status 18 = ~166px
        const SizedBox(height: 130), // ≈ cardHeight - overlapIntoHeader + small gap
      ],
    );
  }

  Widget _frostedIconButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Balance Card content widget (used by _buildHeaderSection)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F2744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Label + icons
              Row(
                children: [
                  Text(
                    'SỐ DƯ KHẢ DỤNG',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                  const Spacer(),
                  _cardIconBtn(
                    _balanceHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                  ),
                  const SizedBox(width: 6),
                  _cardIconBtn(Icons.refresh_rounded, onTap: () {
                    setState(() => _isLoadingBalance = true);
                    _fetchWallet();
                    _fetchTransactions();
                  }),
                ],
              ),
              const SizedBox(height: 14),
              // Row 2: Amount
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _balanceHidden
                    ? Text(
                        '•••••••••',
                        key: const ValueKey('hidden'),
                        style: GoogleFonts.dmSans(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 6,
                        ),
                      )
                    : Text(
                        _isLoadingBalance ? '...' : _formatCurrency(_balance ?? 0),
                        key: const ValueKey('shown'),
                        style: GoogleFonts.dmSans(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ), // closes Text
                    ), // closes AnimatedSwitcher
                  ), // closes Align
                ), // closes SizedBox
              const SizedBox(height: 20),
              // Row 3: Status + masked ID
              Row(
                children: [
                  // Green dot + ACTIVE
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'HOẠT ĐỘNG',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'WLLI •••• 2024',
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  Widget _cardIconBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withOpacity(0.55), size: 20),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 3 — Quick Actions
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            children: [
              _actionButton(Icons.south_west_rounded, 'Nạp tiền', const Color(0xFFDCFCE7), AppColors.success),
              _actionButton(Icons.north_east_rounded, 'Rút tiền', const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
              _actionButton(Icons.swap_horiz_rounded, 'Chuyển tiền', const Color(0xFFDBEAFE), const Color(0xFF3B82F6)),
              _actionButton(Icons.access_time_rounded, 'Lịch sử', const Color(0xFFEDE9FE), const Color(0xFF8B5CF6)),
            ],
          ),
        ),
      );
  }

  Widget _actionButton(IconData icon, String label, Color bgColor, Color iconColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          switch (label) {
            case 'Nạp tiền':
              await context.push('/deposit/select-bank');
              _fetchWallet();
              _fetchTransactions();
              break;
            case 'Rút tiền':
              await context.push('/withdraw/amount');
              _fetchWallet();
              _fetchTransactions();
              break;
            case 'Chuyển tiền':
              await context.push('/transfer');
              _fetchWallet();
              _fetchTransactions();
              break;
            case 'Lịch sử':
              setState(() => _activeNavIndex = 1);
              break;
          }
        },
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 4 — Linked Banks
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLinkedBanks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Text('Ngân hàng liên kết', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeNavIndex = 2);
                  },
                  child: Row(
                    children: [
                      Text('Quản lý', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.indigo)),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.indigo),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Horizontal scroll row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_isLoadingBanks)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    ..._banks.map((b) => _bankCard(b)),
                  _addBankTile(),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _bankCard(_MockBank bank) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bank.color, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(bank.code, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bank.name, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(bank.maskedAccount, style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addBankTile() {
    return GestureDetector(
      onTap: () async {
        final linkedCodes = _banks.map((b) => b.code).toList();
        await context.push('/select-bank', extra: linkedCodes);
        if (mounted) {
          setState(() => _isLoadingBanks = true);
          _fetchLinkedBanks();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid, width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_rounded, size: 22, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text('Thêm', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 5 — Recent Transactions
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text('Giao dịch gần đây', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeNavIndex = 1);
                  },
                  child: Row(
                    children: [
                      Text('Xem tất cả', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.indigo)),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.indigo),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            // Content based on state
            _buildTxContent(),
          ],
        ),
      );
  }

  Widget _buildTxContent() {
    switch (_txState) {
      case _TxState.loaded:
        return Column(children: _transactions.map(_buildTxRow).toList());
      case _TxState.loading:
        return Column(children: List.generate(3, (_) => const _ShimmerPlaceholder()));
      case _TxState.error:
        return _buildTxError();
      case _TxState.empty:
        return _buildTxEmpty();
    }
  }

  Widget _buildTxRow(_MockTx tx) {
    final isPositive = tx.amount > 0;
    final amountStr = isPositive
        ? '+${_formatVnd(tx.amount)}'
        : '-${_formatVnd(tx.amount.abs())}';

    IconData icon;
    Color iconBg;
    Color iconColor;
    switch (tx.type) {
      case _TxType.deposit:
        icon = Icons.south_west_rounded;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = AppColors.success;
        break;
      case _TxType.withdraw:
        icon = Icons.north_east_rounded;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFF59E0B);
        break;
      case _TxType.transfer:
        icon = Icons.swap_horiz_rounded;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFF59E0B);
        break;
    }

    Color statusColor;
    switch (tx.status) {
      case _TxStatus.success:
        statusColor = AppColors.success;
        break;
      case _TxStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        break;
      case _TxStatus.failed:
        statusColor = AppColors.error;
        break;
    }

    return GestureDetector(
      onTap: () {
        context.push('/transaction/detail', extra: tx.rawData);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Label + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(tx.date, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            // Amount + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  switch (tx.status) {
                    _TxStatus.success => 'THÀNH CÔNG',
                    _TxStatus.pending => 'ĐANG XỬ LÝ',
                    _TxStatus.failed => 'THẤT BẠI',
                  },
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
          const SizedBox(height: 8),
          Text('Không thể tải giao dịch', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() => _txState = _TxState.loading),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildTxEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('💸', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Chưa có giao dịch nào', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Nạp tiền để bắt đầu', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Navigation Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const tabs = [
      (Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
      (Icons.history_rounded, Icons.history_outlined, 'Lịch sử'),
      (Icons.qr_code_scanner_rounded, Icons.qr_code_scanner, 'Quét QR'),
      (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Thẻ'),
      (Icons.person_rounded, Icons.person_outlined, 'Hồ sơ'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final isActive = i == _activeNavIndex;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Scan tab (index 2) → push full-screen scanner
                    if (i == 2) {
                      context.push('/scan-qr');
                    } else {
                      setState(() => _activeNavIndex = i);
                    }
                  },
                  child: Column(
                    children: [
                      // Top border indicator for active tab
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: isActive ? 28 : 0,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(
                        isActive ? tab.$1 : tab.$2,
                        size: 22,
                        color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.$3,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _formatVnd(num amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan Tab Placeholder — never actually shown; the Scan tap pushes the route
// ─────────────────────────────────────────────────────────────────────────────

class _ScanTabPlaceholder extends StatelessWidget {
  const _ScanTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    // This widget should never be visible because tapping the Scan tab always
    // pushes /scan-qr instead of switching the IndexedStack index. If it ever
    // renders, show a safe empty state.
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Placeholder widget
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
          ),
        ),
      ),
    );
  }
}
