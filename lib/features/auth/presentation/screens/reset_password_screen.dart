import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _codeSent = false;
  bool _isOtpVerified = false;
  bool _isLoading = false;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasNumber(String password) => RegExp(r'[0-9]').hasMatch(password);
  bool _hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  bool _hasSpecialChar(String password) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

  Future<void> _handleSendCode() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email');
      return;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Vui lòng nhập email hợp lệ');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _codeSent = true;
        _infoMessage =
            'Nếu $email đã được đăng ký, bạn sẽ nhận được mã ngay.';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      // 401/404: email not registered — don't reveal this for security.
      // Show the same "check your inbox" message so the user knows to look,
      // and an attacker can't enumerate valid emails.
      if (statusCode == 401 || statusCode == 404) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
          _infoMessage =
              'Nếu $email đã được đăng ký, bạn sẽ nhận được mã ngay.';
        });
      } else {
        // Real errors (timeout, 5xx, network down) — show the error banner.
        setState(() {
          _isLoading = false;
          _errorMessage = ApiService.parseDioError(e);
        });
      }
    }
  }

  void _handleVerifyOtp() {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Vui lòng nhập đủ 6 số');
      return;
    }
    setState(() {
      _isOtpVerified = true;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  Future<void> _handleResetPassword() async {
    setState(() => _errorMessage = null);

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 8) {
      setState(
        () => _errorMessage = 'Mật khẩu phải có ít nhất 8 ký tự',
      );
      return;
    }
    if (!_hasNumber(newPassword)) {
      setState(
        () => _errorMessage = 'Mật khẩu phải chứa ít nhất một số',
      );
      return;
    }
    if (!_hasUppercase(newPassword)) {
      setState(
        () =>
            _errorMessage = 'Mật khẩu phải chứa ít nhất một chữ in hoa',
      );
      return;
    }
    if (!_hasSpecialChar(newPassword)) {
      setState(
        () =>
            _errorMessage = 'Mật khẩu phải chứa ít nhất một ký tự đặc biệt',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Mật khẩu không khớp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.resetPassword(
        email: _emailController.text.trim(),
        verificationCode: _otpController.text.trim(),
        newPassword: newPassword,
      );
      if (!mounted) return;
      context.go(AppRouter.resetPasswordSuccess);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = ApiService.parseDioError(e);
      final lowerMsg = message.toLowerCase();
      // If the OTP was wrong, let the user go back and re-enter it.
      final isInvalidOtp = lowerMsg.contains('reset code') ||
          lowerMsg.contains('verification') ||
          lowerMsg.contains('expired') ||
          e.response?.statusCode == 400;
      setState(() {
        _isLoading = false;
        _errorMessage = isInvalidOtp
            ? 'Mã xác thực không hợp lệ hoặc đã hết hạn. Vui lòng nhập lại.'
            : message;
        if (isInvalidOtp) {
          // Let the user go back and correct the OTP.
          _isOtpVerified = false;
        }
      });
    }
  }

  // ── PINPUT THEMES ──
  PinTheme _defaultPinTheme() => PinTheme(
        width: 44,
        height: 52,
        textStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          border: Border.all(color: Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      );

  PinTheme _focusedPinTheme(PinTheme defaultTheme) =>
      defaultTheme.copyWith(
        width: 46,
        height: 54,
        decoration: defaultTheme.decoration!.copyWith(
          color: AppColors.textWhite,
          border: Border.all(color: AppColors.primaryNavy, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141E293B),
              blurRadius: 8,
              spreadRadius: 3,
            ),
          ],
        ),
      );

  PinTheme _submittedPinTheme(PinTheme defaultTheme) =>
      defaultTheme.copyWith(
        textStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
        decoration: defaultTheme.decoration!.copyWith(
          color: AppColors.primaryNavy,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final newPw = _newPasswordController.text;
    final defaultPinTheme = _defaultPinTheme();

    return AuthLayout(
      headerHeight: 220,
      headerContent: Stack(
        children: [
          Positioned(
            top: 24,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: AppColors.textWhite,
                size: 20,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRouter.login);
                }
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Đặt lại mật khẩu',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập email của bạn, xác thực mã,\nsau đó đặt mật khẩu mới',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textWhite.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════ EMAIL ═══════════════
            FadeUpAnimation(
              delayInMilliseconds: 50,
              child: _buildEmailSection(),
            ),
            const SizedBox(height: 12),

            // Info / Error banners
            if (_infoMessage != null)
              FadeUpAnimation(child: _buildInfoBanner(_infoMessage!)),
            if (_errorMessage != null)
              FadeUpAnimation(child: _buildErrorBanner(_errorMessage!)),

            const SizedBox(height: 16),

            // ═══════════════ OTP ═══════════════
            FadeUpAnimation(
              delayInMilliseconds: 100,
              child: _buildOtpSection(defaultPinTheme),
            ),
            const SizedBox(height: 12),

            // Verified banner
            if (_isOtpVerified)
              FadeUpAnimation(child: _buildVerifiedBanner()),

            // ═══════════════ PASSWORD FIELDS ═══════════════
            if (_isOtpVerified) ...[
              const SizedBox(height: 24),
              FadeUpAnimation(
                delayInMilliseconds: 50,
                child: _buildNewPasswordSection(newPw),
              ),
              const SizedBox(height: 20),
              FadeUpAnimation(
                delayInMilliseconds: 100,
                child: _buildConfirmPasswordSection(),
              ),
              const SizedBox(height: 32),
              FadeUpAnimation(
                delayInMilliseconds: 150,
                child: _buildResetButton(),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── EMAIL SECTION ──
  Widget _buildEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('EMAIL *', style: AppTextStyles.label),
            const Spacer(),
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: _handleSendCode,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _codeSent ? 'Gửi lại mã' : 'Gửi mã',
                  style: AppTextStyles.linkText,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Nhập email của bạn',
            prefixIcon: Icon(
              Icons.email_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── OTP SECTION ──
  Widget _buildOtpSection(PinTheme defaultPinTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('MÃ XÁC THỰC *', style: AppTextStyles.label),
            if (_isOtpVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              const SizedBox(width: 4),
              Text(
                'Đã xác thực',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            const Spacer(),
            if (!_isOtpVerified)
              ElevatedButton(
                onPressed: (_isLoading || !_codeSent) ? null : _handleVerifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: AppColors.textWhite,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Xong',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Pinput(
            length: 6,
            controller: _otpController,
            focusNode: _otpFocusNode,
            enabled: !_isOtpVerified,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: _focusedPinTheme(defaultPinTheme),
            submittedPinTheme: _submittedPinTheme(defaultPinTheme),
            showCursor: true,
          ),
        ),
      ],
    );
  }

  // ── NEW PASSWORD ──
  Widget _buildNewPasswordSection(String password) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MẬT KHẨU MỚI *', style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _isNewPasswordObscured,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Tạo mật khẩu mạnh',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isNewPasswordObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(
                  () => _isNewPasswordObscured = !_isNewPasswordObscured,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _pwCheck('8+ ký tự', _hasMinLength(password)),
            _pwCheck('Số', _hasNumber(password)),
            _pwCheck('Chữ in hoa', _hasUppercase(password)),
            _pwCheck('Ký tự đặc biệt', _hasSpecialChar(password)),
          ],
        ),
      ],
    );
  }

  // ── CONFIRM PASSWORD ──
  Widget _buildConfirmPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('XÁC NHẬN MẬT KHẨU MỚI *', style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _isConfirmPasswordObscured,
          decoration: InputDecoration(
            hintText: 'Nhập lại mật khẩu mới',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(
                  () =>
                      _isConfirmPasswordObscured =
                          !_isConfirmPasswordObscured,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── RESET BUTTON ──
  Widget _buildResetButton() {
    return GradientButton(
      onPressed: _isLoading ? null : _handleResetPassword,
      text: _isLoading ? 'Đang đặt lại...' : 'Đặt lại mật khẩu',
    );
  }

  // ── INFO BANNER ──
  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR BANNER ──
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }

  // ── VERIFIED BANNER ──
  Widget _buildVerifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã xác thực danh tính \u2014 đặt mật khẩu mới của bạn bên dưới',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── PASSWORD CHECK ITEM ──
  Widget _pwCheck(String label, bool checked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: checked,
            onChanged: null,
            activeColor: AppColors.success,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: checked ? AppColors.success : AppColors.textSecondary,
            fontWeight: checked ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}