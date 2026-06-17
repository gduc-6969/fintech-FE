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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;
  String? _serverError;
  bool _isWrongCredentials = false;
  String? _otpVerificationRequiredError;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _serverError = null;
      _isWrongCredentials = false;
      _otpVerificationRequiredError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    try {
      await ApiService.login(phoneNumber: phone, password: password);
      if (!mounted) return;
      context.go(AppRouter.wallet);
    } on DioException catch (e) {
      final message = ApiService.parseDioError(e);
      final lowerMsg = message.toLowerCase();
      setState(() {
        _isLoading = false;
        if (e.response?.statusCode == 401 ||
            lowerMsg.contains('incorrect') ||
            lowerMsg.contains('invalid') ||
            lowerMsg.contains('wrong') ||
            lowerMsg.contains('password') ||
            lowerMsg.contains('credentials')) {
          _isWrongCredentials = true;
        } else {
          _serverError = message;
        }
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
            const SizedBox(height: 30),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.surface.withOpacity(0.2),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                color: AppColors.surface.withOpacity(0.1),
              ),
              child: const Center(
                child: Text(
                  'Logo',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Title card',
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
                    Text('Phone Number *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: '0xxxxxxxxx or +84xxxxxxxxx',
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
                    Text('Password *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
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
                          return 'Password is required';
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
                  child: Text(
                    'Forgot Password?',
                    style: AppTextStyles.linkText,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Incorrect phone/password inline warning
              if (_isWrongCredentials)
                FadeUpAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Incorrect phone number or password',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Login Button
              FadeUpAnimation(
                delayInMilliseconds: 210,
                child: GradientButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  text: _isLoading ? 'Logging in...' : 'Login',
                ),
              ),

              // Account Status/Error Banners
              if (_otpVerificationRequiredError != null)
                FadeUpAnimation(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _otpVerificationRequiredError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

              if (_serverError != null)
                FadeUpAnimation(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
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
                      "Don't have an account? ",
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRouter.register),
                      child: Text(
                        'Create one →',
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
