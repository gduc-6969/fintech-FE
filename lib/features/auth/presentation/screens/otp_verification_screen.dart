import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_up_animation.dart';
import '../widgets/gradient_button.dart';
import '../widgets/otp_countdown_timer.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

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

  void _handleResend() {
    setState(() {
      _errorMessage = null;
      _attemptsRemaining = 5;
      _isExpired = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP code has been resent!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _handleVerify() {
    final code = _otpController.text;

    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits';
      });
      return;
    }

    if (code == '111111') {
      context.go(AppRouter.success);
    } else {
      setState(() {
        if (_attemptsRemaining > 1) {
          _attemptsRemaining--;
          _errorMessage = 'Incorrect verification code. Please try again.';
          _otpController.clear();
        } else {
          _attemptsRemaining = 0;
          _errorMessage =
              'Maximum attempts reached. Please request a new code.';
        }
      });
    }
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
                  'Verify Phone',
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a code to ${widget.phoneNumber}',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textWhite.withOpacity(0.8),
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
                                      'Code expired. Please resend.';
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
                                  "Didn't receive a code? ",
                                  style: AppTextStyles.bodySecondary,
                                ),
                                TextButton(
                                  onPressed: _handleResend,
                                  child: Text(
                                    'Resend OTP',
                                    style: AppTextStyles.linkText,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              "Code is valid for 5 minutes",
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
                        'Attempts remaining: $_attemptsRemaining',
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
                      text: 'Verify Code',
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
                          'Wrong number? Go back',
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
