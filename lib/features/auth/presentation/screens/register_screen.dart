import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';
import '../widgets/password_strength_bar.dart';
import '../widgets/step_indicator.dart';

class RegisterScreen extends StatefulWidget {
  final RegisterPayload? initialData;

  const RegisterScreen({super.key, this.initialData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;

  String? _emailServerError;
  String? _phoneServerError;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    if (initialData != null) {
      _fullNameController.text = initialData.fullName;
      _emailController.text = initialData.email;
      _phoneController.text = initialData.phoneNumber;
      _passwordController.text = initialData.password;
      _confirmPasswordController.text = initialData.password;
      _emailServerError = initialData.emailServerError;
      _phoneServerError = initialData.phoneServerError;

      if (_emailServerError != null || _phoneServerError != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _formKey.currentState?.validate();
        });
      }
    }
    _passwordController.addListener(_validatePasswordCriteria);
    _validatePasswordCriteria();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _validatePasswordCriteria() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  int get _passwordStrength {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasNumber) strength++;
    if (_hasUppercase) strength++;
    if (_hasSpecialChar) strength++;
    return strength;
  }

  Future<void> _handleRegister() async {
    setState(() {
      _emailServerError = null;
      _phoneServerError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final payload = RegisterPayload(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    try {
      await ApiService.precheckRegistration(
        email: payload.email,
        fullName: payload.fullName,
        phoneNumber: payload.phoneNumber,
        password: payload.password,
      );
      if (!mounted) return;
      // Navigate to Step 2 — Identity Verification
      context.push(AppRouter.registerIdentity, extra: payload);
    } on DioException catch (e) {
      final serverError = ApiService.parseDioError(e);
      final errorCode = ApiService.parseErrorCode(e);
      setState(() {
        if (errorCode == 'EMAIL_ALREADY_EXISTS' ||
            (errorCode == null && _isEmailError(serverError))) {
          _emailServerError = serverError;
        } else if (errorCode == 'PHONE_NUMBER_ALREADY_EXISTS' ||
            (errorCode == null && _isPhoneError(serverError))) {
          _phoneServerError = serverError;
        } else {
          _emailServerError = serverError;
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }
  }

  bool _isEmailError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('xac thuc') ||
        lower.contains('xác thực') ||
        lower.contains('verification')) {
      return false;
    }
    return lower.contains('email');
  }

  bool _isPhoneError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('phone') ||
        lower.contains('dien thoai') ||
        lower.contains('điện thoại');
  }

  Widget _buildCriteriaItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isValid ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => context.go(AppRouter.login), // Goes to Login
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Tạo tài khoản',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tham gia Walli — chỉ mất một phút',
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicator
              const StepIndicator(currentStep: 1),
              const SizedBox(height: 24),

              // Full Name
              FadeUpAnimation(
                delayInMilliseconds: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Họ và tên *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'Nhập họ và tên của bạn',
                      ),
                      validator: Validators.validateFullName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Email
              FadeUpAnimation(
                delayInMilliseconds: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Email *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'Nhập email của bạn',
                      ),
                      onChanged: (_) {
                        if (_emailServerError != null) {
                          setState(() => _emailServerError = null);
                        }
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        final localErr = Validators.validateEmail(val);
                        if (localErr != null) return localErr;
                        return _emailServerError;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Phone
              FadeUpAnimation(
                delayInMilliseconds: 150,
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
                      onChanged: (_) {
                        if (_phoneServerError != null) {
                          setState(() => _phoneServerError = null);
                        }
                      },
                      validator: (val) {
                        final localErr = Validators.validatePhone(val);
                        if (localErr != null) return localErr;
                        return _phoneServerError;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Password
              FadeUpAnimation(
                delayInMilliseconds: 150,
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
                        hintText: 'Tạo mật khẩu',
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
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 12),
                    PasswordStrengthBar(strength: _passwordStrength),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Criteria
              FadeUpAnimation(
                delayInMilliseconds: 180,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 20.0),
                  child: Column(
                    children: [
                      _buildCriteriaItem(
                        'Ít nhất 8 ký tự',
                        _hasMinLength,
                      ),
                      _buildCriteriaItem('Chứa ít nhất 1 số', _hasNumber),
                      _buildCriteriaItem(
                        'Chứa chữ in hoa',
                        _hasUppercase,
                      ),
                      _buildCriteriaItem(
                        'Chứa ký tự đặc biệt',
                        _hasSpecialChar,
                      ),
                    ],
                  ),
                ),
              ),

              // Confirm Password
              FadeUpAnimation(
                delayInMilliseconds: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Xác nhận mật khẩu *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _isConfirmObscured,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        hintText: 'Nhập lại mật khẩu của bạn',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmObscured = !_isConfirmObscured;
                            });
                          },
                        ),
                      ),
                      validator: (val) => Validators.validateConfirmPassword(
                        _passwordController.text,
                        val,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Register Button
              FadeUpAnimation(
                delayInMilliseconds: 250,
                child: GradientButton(
                  onPressed: _handleRegister,
                  text: 'Tiếp theo — Thông tin danh tính',
                ),
              ),
              const SizedBox(height: 28),

              // Link to Login
              FadeUpAnimation(
                delayInMilliseconds: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản? ',
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () =>
                          context.go(AppRouter.login), // Flow: Goes to Login
                      child: Text('Đăng nhập →', style: AppTextStyles.linkText),
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
