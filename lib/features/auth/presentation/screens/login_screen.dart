import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;
  String? _serverError;
  bool _isWrongCredentials = false;
  bool _isAccountLocked = false;
  String? _otpError;
  int? _remainingAttempts;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _serverError = null;
      _isWrongCredentials = false;
      _otpError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final otp = _isAccountLocked ? _otpController.text.trim() : null;

    try {
      final token = await ApiService.login(
        phoneNumber: phone,
        password: password,
        verificationCode: otp,
      );
      if (!mounted) return;
      if (token.isEmpty || !ApiService.isAuthenticated) {
        throw StateError('Login completed without a valid session.');
      }
      context.go(AppRouter.wallet);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = ApiService.parseDioError(e);
      final errorCode = ApiService.parseErrorCode(e);
      final details = ApiService.parseErrorDetails(e);

      setState(() {
        _isLoading = false;

        final normalizedMessage = message.toLowerCase();
        final rawResponseStr = e.response?.data?.toString().toLowerCase() ?? '';
        final isAccountLockedError = errorCode == 'ACCOUNT_LOCKED' ||
            normalizedMessage.contains('khoa') ||
            normalizedMessage.contains('khóa') ||
            normalizedMessage.contains('locked') ||
            rawResponseStr.contains('account_locked') ||
            rawResponseStr.contains('tai khoan bi khoa') ||
            (details != null && details['remainingLoginAttempts'] == 0);

        final isInvalidUnlockCodeError = errorCode == 'INVALID_UNLOCK_CODE' ||
            normalizedMessage.contains('mã mở khóa') ||
            normalizedMessage.contains('ma mo khoa') ||
            rawResponseStr.contains('invalid_unlock_code');

        if (isAccountLockedError) {
          _isAccountLocked = true;
          _isWrongCredentials = false;
          _remainingAttempts = 0;
          _otpError = null;
          _serverError = null;
        } else if (isInvalidUnlockCodeError) {
          _isAccountLocked = true;
          _isWrongCredentials = false;
          _otpError = message;
          _serverError = null;
        } else if (errorCode == 'INVALID_CREDENTIALS' ||
            (errorCode == null && e.response?.statusCode == 401)) {
          _isWrongCredentials = true;
          if (details != null && details['remainingLoginAttempts'] is num) {
            _remainingAttempts =
                (details['remainingLoginAttempts'] as num).toInt();
            if (_remainingAttempts == 0) {
              _isAccountLocked = true;
              _isWrongCredentials = false;
            }
          } else {
            _remainingAttempts = null;
          }
        } else {
          _serverError = message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _serverError = 'Không thể bắt đầu phiên đăng nhập. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      headerHeight: 220,
      headerContent: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Semantics(
              image: true,
              label: 'Biểu trưng CMC',
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/cmc_logo.png',
                  width: 110,
                  height: 70,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đăng nhập',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textWhite,
              ),
            ),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phone Input
              FadeUpAnimation(
                delayInMilliseconds: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Số điện thoại *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: '0xxxxxxxxx hoặc +84xxxxxxxxx',
                      ),
                      validator: Validators.validatePhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Password Input
              FadeUpAnimation(
                delayInMilliseconds: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Mật khẩu *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu của bạn',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRouter.resetPassword),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Quên mật khẩu?', style: AppTextStyles.linkText),
                ),
              ),
              const SizedBox(height: 4),

              // Incorrect phone/password inline warning
              if (_isWrongCredentials)
                FadeUpAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _remainingAttempts != null && _remainingAttempts! > 0
                          ? 'Số điện thoại hoặc mật khẩu không chính xác (còn $_remainingAttempts lần thử)'
                          : 'Số điện thoại hoặc mật khẩu không chính xác',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Account Locked warning & OTP input section
              if (_isAccountLocked) ...[
                const SizedBox(height: 12),
                FadeUpAnimation(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Tài khoản đang bị tạm khóa',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tài khoản bị khóa do nhập sai mật khẩu 5 lần. Vui lòng nhập đúng mật khẩu và mã OTP 6 số đã gửi tới email để mở khóa và đăng nhập.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeUpAnimation(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'MÃ OTP MỞ KHÓA *',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          hintText: 'Nhập mã OTP 6 chữ số',
                          counterText: '',
                          prefixIcon: Icon(
                            Icons.shield_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        validator: (val) {
                          if (!_isAccountLocked) return null;
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mã OTP mở khóa';
                          }
                          if (val.trim().length != 6) {
                            return 'Mã OTP phải gồm đúng 6 chữ số';
                          }
                          return null;
                        },
                      ),
                      if (_otpError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _otpError!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Login Button
              FadeUpAnimation(
                delayInMilliseconds: 210,
                child: GradientButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  text: _isLoading
                      ? 'Đang xử lý...'
                      : (_isAccountLocked
                          ? 'Mở khóa & Đăng nhập'
                          : 'Đăng nhập'),
                ),
              ),

              if (_serverError != null)
                FadeUpAnimation(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _serverError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Link to Register
              FadeUpAnimation(
                delayInMilliseconds: 290,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Chưa có tài khoản? ",
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRouter.register),
                      child: Text(
                        'Tạo tài khoản →',
                        style: AppTextStyles.linkText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
