import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';
import '../widgets/step_indicator.dart';

class RegisterIdentityScreen extends StatefulWidget {
  final RegisterPayload step1Data;

  const RegisterIdentityScreen({super.key, required this.step1Data});

  @override
  State<RegisterIdentityScreen> createState() => _RegisterIdentityScreenState();
}

class _RegisterIdentityScreenState extends State<RegisterIdentityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityNumberController = TextEditingController();
  final _dobDisplayController = TextEditingController();
  final _hometownController = TextEditingController();

  DateTime? _selectedDob;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identityNumberController.dispose();
    _dobDisplayController.dispose();
    _hometownController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: AppColors.textWhite,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobDisplayController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      // Re-validate after picking
      _formKey.currentState?.validate();
    }
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullPayload = widget.step1Data.copyWith(
      identityNumber: _identityNumberController.text.trim(),
      dob: _selectedDob,
      hometown: _hometownController.text.trim().isEmpty
          ? null
          : _hometownController.text.trim(),
    );

    try {
      await ApiService.requestOtp(
        email: fullPayload.email,
        fullName: fullPayload.fullName,
      );
      if (!mounted) return;
      context.push(AppRouter.otpVerify, extra: fullPayload);
    } on DioException catch (e) {
      setState(() {
        _errorMessage = ApiService.parseDioError(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi, vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Widget _buildFieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppTextStyles.label,
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppTextStyles.label.copyWith(color: AppColors.error),
                  ),
                ]
              : [],
        ),
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
              onPressed: () => context.pop(),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Xác minh danh tính',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thêm vài thông tin để hoàn tất tài khoản',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textWhite.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
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
              const StepIndicator(currentStep: 2),
              const SizedBox(height: 28),

              // Identity Number
              FadeUpAnimation(
                delayInMilliseconds: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('SỐ CMND / CCCD', required: true),
                    TextFormField(
                      controller: _identityNumberController,
                      keyboardType: TextInputType.number,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        hintText: 'Số CMND / CCCD',
                        counterText: '',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập số CMND/CCCD';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Date of Birth
              FadeUpAnimation(
                delayInMilliseconds: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('NGÀY SINH', required: true),
                    TextFormField(
                      controller: _dobDisplayController,
                      readOnly: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onTap: _pickDate,
                      decoration: InputDecoration(
                        hintText: 'DD/MM/YYYY',
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      validator: (val) {
                        if (_selectedDob == null) {
                          return 'Vui lòng chọn ngày sinh';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hometown
              FadeUpAnimation(
                delayInMilliseconds: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('QUÊ QUÁN'),
                    TextFormField(
                      controller: _hometownController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'VD: Thành phố Hồ Chí Minh',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Error message
              if (_errorMessage != null)
                FadeUpAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Create Account button
              FadeUpAnimation(
                delayInMilliseconds: 200,
                child: GradientButton(
                  onPressed: _isLoading ? null : _handleCreateAccount,
                  text: _isLoading ? 'Đang xử lý...' : 'Tạo tài khoản',
                ),
              ),
              const SizedBox(height: 28),

              // Sign in link
              FadeUpAnimation(
                delayInMilliseconds: 250,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản? ',
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRouter.login),
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
