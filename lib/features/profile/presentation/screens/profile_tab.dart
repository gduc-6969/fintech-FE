import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/pin_management_sheet.dart';

class ProfileTab extends StatefulWidget {
  /// Callback to switch a sibling tab in the parent WalletScreen's IndexedStack.
  final void Function(int index) onSwitchTab;

  const ProfileTab({super.key, required this.onSwitchTab});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _hasPin = false;
  Map<String, dynamic>? _profile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getUserProfile();
      bool hasPin = false;
      try {
        hasPin = await ApiService.getPinStatus();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profile = data;
          _hasPin = hasPin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải thông tin hồ sơ.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đăng xuất?', style: AppTextStyles.heading2),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất không?',
          style: AppTextStyles.bodySecondary,
        ),
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
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    'Ở lại',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đăng xuất',
                    style: TextStyle(color: Colors.white),
                  ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _initials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _maskIdentityNumber(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    if (raw.length <= 8) return raw;
    final first4 = raw.substring(0, 4);
    final last4 = raw.substring(raw.length - 4);
    return '$first4 •••• $last4';
  }

  String _formatDob(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dobStr);
      final age = _computeAge(dt);
      final formatted = DateFormat('d MMMM yyyy', 'vi').format(dt);
      return '$formatted ($age tuổi)';
    } catch (_) {
      return dobStr;
    }
  }

  int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 20,
        title: Text('Hồ sơ', style: AppTextStyles.heading2),
        actions: [
          if (!_isLoading && _errorMessage == null)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: _fetchProfile,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _errorMessage != null
          ? _buildError()
          : _buildContent(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Skeleton
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile card skeleton
          _SkeletonCard(
            child: Row(
              children: [
                _SkeletonBox(width: 60, height: 60, radius: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 150, height: 16),
                      const SizedBox(height: 8),
                      _SkeletonBox(width: 60, height: 22, radius: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SkeletonBox(width: 140, height: 12),
          const SizedBox(height: 8),
          _SkeletonCard(
            child: Column(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SkeletonBox(width: 100, height: 12),
                      _SkeletonBox(width: 130, height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SkeletonBox(width: 140, height: 12),
          const SizedBox(height: 8),
          _SkeletonCard(
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      _SkeletonBox(width: 36, height: 36, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBox(width: 120, height: 13),
                            const SizedBox(height: 6),
                            _SkeletonBox(width: 180, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loaded content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final p = _profile!;
    final fullName = p['fullName'] as String?;
    final tier = p['tier'] as int? ?? 0;
    final identityNumber = p['identityNumber'] as String?;
    final dobStr = p['dob'] as String?;
    final email = p['email'] as String?;
    final phoneNumber = p['phoneNumber'] as String?;
    final hometown = p['hometown'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Profile Card ──
          _buildProfileCard(fullName: fullName, tier: tier),
          const SizedBox(height: 20),

          // ── Section 2: Personal Info ──
          _sectionLabel('THÔNG TIN CÁ NHÂN'),
          const SizedBox(height: 8),
          _buildPersonalInfoCard(
            identityNumber: identityNumber,
            dobStr: dobStr,
            email: email,
            phoneNumber: phoneNumber,
            hometown: hometown,
          ),
          const SizedBox(height: 20),

          // ── Section 3: App & Security ──
          _sectionLabel('ỨNG DỤNG & BẢO MẬT'),
          const SizedBox(height: 8),
          _buildSecurityCard(),
          const SizedBox(height: 24),

          // ── Sign Out ──
          _buildSignOutButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileCard({String? fullName, required int tier}) {
    final bool isAdult = tier >= 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.deepNavy, AppColors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _initials(fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name + Tier
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName ?? 'Người dùng',
                  style: AppTextStyles.heading2.copyWith(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _TierBadge(isAdult: isAdult),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard({
    String? identityNumber,
    String? dobStr,
    String? email,
    String? phoneNumber,
    String? hometown,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            label: 'Số CMND/CCCD',
            value: _maskIdentityNumber(identityNumber),
            isMonospace: true,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoRow(label: 'Ngày sinh', value: _formatDob(dobStr)),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoRow(label: 'Email', value: email ?? '—'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoRow(label: 'Điện thoại', value: phoneNumber ?? '—'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoRow(label: 'Quê quán', value: hometown ?? '—'),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: isMonospace
                  ? GoogleFonts.robotoMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    )
                  : AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _securityRow(
            icon: Icons.credit_card_outlined,
            label: 'Tài khoản ngân hàng',
            subtitle: 'Quản lý tài khoản liên kết',
            onTap: () => widget.onSwitchTab(2), // Cards tab
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _securityRow(
            icon: Icons.history_rounded,
            label: 'Lịch sử giao dịch',
            subtitle: 'Xem tất cả giao dịch',
            onTap: () => widget.onSwitchTab(1), // History tab
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _securityRow(
            icon: Icons.key_rounded,
            label: _hasPin ? 'Đổi mã PIN' : 'Tạo mã PIN',
            subtitle: _hasPin
                ? 'Cập nhật mã PIN giao dịch'
                : 'Đặt mã PIN để xác thực giao dịch',
            onTap: _openPinManagementSheet,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _securityRow(
            icon: Icons.face_retouching_natural_rounded,
            label: 'Xác thực khuôn mặt',
            subtitle: 'Thiết lập hoặc cập nhật cho giao dịch giá trị cao',
            onTap: () => context.push(AppRouter.faceIdEnrollment),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _securityRow(
            icon: Icons.lock_outline_rounded,
            label: 'Đổi mật khẩu',
            subtitle: 'Cập nhật thông tin bảo mật',
            onTap: () => context.push(AppRouter.resetPassword),
          ),
        ],
      ),
    );
  }

  Future<void> _openPinManagementSheet() async {
    final email = _profile?['email']?.toString() ?? '';
    final success = await PinManagementSheet.show(
      context,
      hasPin: _hasPin,
      userEmail: email,
    );
    if (success == true && mounted) {
      setState(() => _hasPin = true);
    }
  }

  Widget _securityRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryNavy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _handleLogout,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.error,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(_isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tier Badge Widget
// ─────────────────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isAdult;

  const _TierBadge({required this.isAdult});

  @override
  Widget build(BuildContext context) {
    final Color bg = isAdult
        ? AppColors.indigo.withOpacity(0.12)
        : const Color(0xFFF59E0B).withOpacity(0.12);
    final Color fg = isAdult ? AppColors.indigo : const Color(0xFFB45309);
    final String label = isAdult ? 'NGƯỜI LỚN' : 'VỊ THÀNH NIÊN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFE2E8F0),
              Color(0xFFCBD5E1),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Widget child;

  const _SkeletonCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
