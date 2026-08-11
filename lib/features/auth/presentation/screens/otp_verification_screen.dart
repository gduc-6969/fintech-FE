import 'dart:async';
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
import '../widgets/otp_countdown_timer.dart';

class OtpVerificationScreen extends StatefulWidget {
  final RegisterPayload registerData;

  const OtpVerificationScreen({super.key, required this.registerData});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isExpired = false;
  int _attemptsRemaining = 5;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleResend() async {
    setState(() {
      _errorMessage = null;
      _attemptsRemaining = 5;
      _isExpired = false;
    });

    try {
      await ApiService.requestOtp(
        email: widget.registerData.email,
        fullName: widget.registerData.fullName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP đã được gửi lại!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _errorMessage = ApiService.parseDioError(e);
      });
    }
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();

    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 số';
      });
      return;
    }

    try {
      await ApiService.register(
        email: widget.registerData.email,
        fullName: widget.registerData.fullName,
        phoneNumber: widget.registerData.phoneNumber,
        password: widget.registerData.password,
        verificationCode: code,
        identityNumber: widget.registerData.identityNumber,
        dob: widget.registerData.dob,
        hometown: widget.registerData.hometown,
      );
      if (!mounted) {
        return;
      }
      context.go(AppRouter.success);
    } on DioException catch (e) {
      final errorMessage = ApiService.parseDioError(e);
      final errorCode = ApiService.parseErrorCode(e);
      if (errorCode == 'EMAIL_ALREADY_EXISTS' ||
          errorCode == 'PHONE_NUMBER_ALREADY_EXISTS' ||
          _isEmailAlreadyExistsError(errorMessage) ||
          _isPhoneAlreadyExistsError(errorMessage)) {
        if (!mounted) {
          return;
        }
        context.go(
          AppRouter.register,
          extra: widget.registerData.copyWith(
            emailServerError: (errorCode == 'EMAIL_ALREADY_EXISTS' || _isEmailAlreadyExistsError(errorMessage)) ? errorMessage : null,
            phoneServerError: (errorCode == 'PHONE_NUMBER_ALREADY_EXISTS' || _isPhoneAlreadyExistsError(errorMessage)) ? errorMessage : null,
          ),
        );
        return;
      }

      setState(() {
        _errorMessage = errorMessage;
        if (_attemptsRemaining > 0) {
          _attemptsRemaining--;
        }
      });
    }
  }

  bool _isEmailAlreadyExistsError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('xac thuc') ||
        lower.contains('xác thực') ||
        lower.contains('verification')) {
      return false;
    }
    return lower.contains('email') &&
        (lower.contains('ton tai') ||
            lower.contains('tồn tại') ||
            lower.contains('already') ||
            lower.contains('da duoc dang ky') ||
            lower.contains('đã được đăng ký'));
  }

  bool _isPhoneAlreadyExistsError(String error) {
    final lower = error.toLowerCase();
    return (lower.contains('phone') ||
            lower.contains('dien thoai') ||
            lower.contains('điện thoại')) &&
        (lower.contains('ton tai') ||
            lower.contains('tồn tại') ||
            lower.contains('already') ||
            lower.contains('da duoc dang ky') ||
            lower.contains('đã được đăng ký'));
  }

  @override
  Widget build(BuildContext context) {
    // Premium style for Pinput
    final defaultPinTheme = PinTheme(
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

    // Simulated 1.05 scale and shadow
    final focusedPinTheme = defaultPinTheme.copyWith(
      width: 46,
      height: 54,
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppColors.textWhite,
        border: Border.all(color: AppColors.primaryNavy, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x141E293B), blurRadius: 8, spreadRadius: 3),
        ],
      ),
    );

    // Inverts for filled
    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textWhite,
      ),
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppColors.primaryNavy,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFFFF5F5),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
    );

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
              onPressed: () =>
                  context.go(AppRouter.register), // Goes to Register
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Xác thực tài khoản',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chúng tôi đã gửi mã đến ${widget.registerData.email}',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textWhite.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24.0,
              32.0,
              24.0,
              32.0 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timer
                  FadeUpAnimation(
                    delayInMilliseconds: 50,
                    child: Center(
                      child: _isExpired
                          ? const Icon(
                              Icons.timer_off,
                              size: 50,
                              color: AppColors.error,
                            )
                          : OtpCountdownTimer(
                              totalSeconds: 300,
                              onTimerComplete: () {
                                setState(() {
                                  _isExpired = true;
                                  _errorMessage =
                                      'Mã đã hết hạn. Vui lòng gửi lại.';
                                });
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pinput input field
                  FadeUpAnimation(
                    delayInMilliseconds: 100,
                    child: Center(
                      child: Pinput(
                        length: 6,
                        controller: _otpController,
                        focusNode: _focusNode,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        errorPinTheme: errorPinTheme,
                        validator: (s) {
                          return _errorMessage == null ? null : '';
                        },
                        errorText: '',
                        showCursor: true,
                        onCompleted: (pin) => _handleVerify(),
                      ),
                    ),
                  ),

                  if (_errorMessage != null)
                    FadeUpAnimation(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Resend status
                  FadeUpAnimation(
                    delayInMilliseconds: 150,
                    child: Center(
                      child: _isExpired
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Chưa nhận được mã? ",
                                  style: AppTextStyles.bodySecondary,
                                ),
                                TextButton(
                                  onPressed: _handleResend,
                                  child: Text(
                                    'Gửi lại OTP',
                                    style: AppTextStyles.linkText,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              "Mã có hiệu lực trong 5 phút",
                              style: AppTextStyles.bodySecondary,
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attempts remaining
                  FadeUpAnimation(
                    delayInMilliseconds: 180,
                    child: Center(
                      child: Text(
                        'Số lần thử còn lại: $_attemptsRemaining',
                        style: TextStyle(
                          fontSize: 13,
                          color: _attemptsRemaining <= 2
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: _attemptsRemaining <= 2
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Verify Button
                  FadeUpAnimation(
                    delayInMilliseconds: 220,
                    child: GradientButton(
                      onPressed: (_attemptsRemaining > 0 && !_isExpired)
                          ? _handleVerify
                          : null,
                      text: 'Xác thực mã',
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Link: Wrong number? Go back
                  FadeUpAnimation(
                    delayInMilliseconds: 250,
                    child: Center(
                      child: TextButton(
                        onPressed: () => context.go(AppRouter.register),
                        child: Text(
                          'Sai số? Quay lại',
                          style: AppTextStyles.linkText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
