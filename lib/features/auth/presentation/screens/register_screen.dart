import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';
import '../widgets/password_strength_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;

  String? _phoneServerError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordCriteria);
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

  void _handleRegister() {
    setState(() {
      _phoneServerError = null;
    });

    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();

      if (phone == '0901234567') {
        setState(() {
          _phoneServerError = 'This phone number is already registered';
        });
        return;
      }

      context.push(AppRouter.otpVerify, extra: phone);
    }
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
                  'Create Account',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in your details',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textWhite.withOpacity(0.8),
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
              // Full Name
              FadeUpAnimation(
                delayInMilliseconds: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Full name *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                      ),
                      validator: Validators.validateFullName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Phone
              FadeUpAnimation(
                delayInMilliseconds: 100,
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
                    Text('Password *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        hintText: 'Create a password',
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
                        'At least 8 characters',
                        _hasMinLength,
                      ),
                      _buildCriteriaItem('Contains a number', _hasNumber),
                      _buildCriteriaItem(
                        'Contains an uppercase letter',
                        _hasUppercase,
                      ),
                      _buildCriteriaItem(
                        'Contains a special character',
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
                    Text('Confirm Password *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _isConfirmObscured,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
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
                  text: 'Create Account',
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
                      'Already have an account? ',
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () =>
                          context.go(AppRouter.login), // Flow: Goes to Login
                      child: Text('Sign in →', style: AppTextStyles.linkText),
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
