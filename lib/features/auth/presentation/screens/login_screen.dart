import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
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
  String? _serverError;
  String? _otpVerificationRequiredError;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    setState(() {
      _serverError = null;
      _otpVerificationRequiredError = null;
    });

    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;

      if (phone == '0900000000') {
        setState(() {
          _otpVerificationRequiredError =
              'Account is not yet verified. Please complete OTP verification.';
        });
      } else if (phone == '0901111111') {
        setState(() {
          _serverError =
              'Account is temporarily locked due to too many failed attempts.';
        });
      } else if (password != 'Admin@123') {
        setState(() {
          _serverError = 'Incorrect phone number or password';
        });
      } else {
        context.go(AppRouter.wallet);
      }
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
                        hintText: 'e.g. 0901234567 or +84901234567',
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
              const SizedBox(height: 12),

              // Incorrect phone/password local warning
              if (_serverError == 'Incorrect phone number or password')
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
                child: GradientButton(onPressed: _handleLogin, text: 'Login'),
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

              if (_serverError != null &&
                  _serverError != 'Incorrect phone number or password')
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
