import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class PinManagementSheet extends StatefulWidget {
  final bool hasPin;
  final String userEmail;

  const PinManagementSheet({
    super.key,
    required this.hasPin,
    required this.userEmail,
  });

  static Future<bool?> show(BuildContext context, {required bool hasPin, required String userEmail}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PinManagementSheet(hasPin: hasPin, userEmail: userEmail),
      ),
    );
  }

  @override
  State<PinManagementSheet> createState() => _PinManagementSheetState();
}

class _PinManagementSheetState extends State<PinManagementSheet> {
  // Step enum: 1 = Enter PIN, 2 = Confirm PIN, 3 = Verify OTP, 4 = Success
  int _currentStep = 1;

  // PIN inputs
  String _firstPin = '';
  String _confirmPin = '';
  String _otpCode = '';

  // Controllers & Focus nodes for 6-box input
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // State flags
  bool _isLoading = false;
  String? _errorMessage;

  // OTP Countdown
  static const int _otpCooldownSeconds = 45;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _maskedEmail {
    final email = widget.userEmail;
    final atIdx = email.indexOf('@');
    if (atIdx <= 0) return email;
    final local = email.substring(0, atIdx);
    final domain = email.substring(atIdx);
    if (local.length <= 3) return '${local[0]}***$domain';
    return '${local.substring(0, 3)}***$domain';
  }

  void _clearInput() {
    _inputController.clear();
    setState(() => _errorMessage = null);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _otpCooldownSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── Step Transitions & Validation ────────────────────────────────────────

  bool _isAllIdenticalDigits(String pin) {
    if (pin.length != 6) return false;
    return pin.split('').every((char) => char == pin[0]);
  }

  Future<void> _handleNextStep() async {
    final code = _inputController.text;
    if (code.length < 6 || _isLoading) return;

    if (_currentStep == 1) {
      // Step 1: Validate First PIN
      if (_isAllIdenticalDigits(code)) {
        setState(() => _errorMessage = 'Mã PIN không được là 6 chữ số giống nhau (vd: 111111).');
        return;
      }
      _firstPin = code;
      _clearInput();
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Step 2: Validate Confirm PIN & Send Request to Backend
      if (code != _firstPin) {
        setState(() => _errorMessage = 'Mã PIN xác nhận không khớp. Vui lòng thử lại.');
        _clearInput();
        return;
      }
      _confirmPin = code;
      await _submitPinRequest();
    } else if (_currentStep == 3) {
      // Step 3: Confirm OTP & Finalize PIN
      _otpCode = code;
      await _submitOtpConfirmation();
    }
  }

  Future<void> _submitPinRequest() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ApiService.requestCreatePin(_confirmPin);
      if (mounted) {
        _clearInput();
        setState(() {
          _currentStep = 3;
          _isLoading = false;
        });
        _startCountdown();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiService.parseDioError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể gửi yêu cầu tạo mã PIN. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _isLoading) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ApiService.requestCreatePin(_confirmPin);
      if (mounted) {
        _clearInput();
        setState(() => _isLoading = false);
        _startCountdown();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể gửi lại mã OTP. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _submitOtpConfirmation() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ApiService.confirmCreatePin(_otpCode);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 4;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiService.parseDioError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Xác thực OTP thất bại. Vui lòng kiểm tra lại.';
        });
      }
    }
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  String get _sheetTitle {
    if (widget.hasPin) {
      return _currentStep == 4 ? 'Đổi mã PIN' : 'Cập nhật mã PIN';
    }
    return 'Tạo mã PIN';
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return widget.hasPin ? 'Nhập mã PIN mới' : 'Tạo mã PIN mới';
      case 2:
        return 'Xác nhận mã PIN';
      case 3:
        return 'Xác thực Email OTP';
      case 4:
        return widget.hasPin ? 'Đổi mã PIN thành công' : 'Tạo mã PIN thành công';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 1:
        return 'Nhập 6 chữ số để thiết lập mã PIN giao dịch của bạn.';
      case 2:
        return 'Nhập lại 6 chữ số mã PIN để xác nhận.';
      case 3:
        return 'Mã xác thực 6 chữ số đã được gửi tới email $_maskedEmail.';
      case 4:
        return widget.hasPin
            ? 'Mã PIN giao dịch của bạn đã được cập nhật thành công.'
            : 'Mã PIN giao dịch của bạn đã được thiết lập thành công.';
      default:
        return '';
    }
  }

  IconData get _stepIcon {
    switch (_currentStep) {
      case 1:
        return Icons.key_rounded;
      case 2:
        return Icons.shield_outlined;
      case 3:
        return Icons.email_outlined;
      case 4:
        return Icons.check_circle_rounded;
      default:
        return Icons.lock_outline;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Top Header (Title + Close button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _sheetTitle,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 24),

          // Icon Badge
          _buildBadge(),
          const SizedBox(height: 16),

          // Step Title & Subtitle
          Text(
            _stepTitle,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _stepSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Code Boxes (for Steps 1, 2, 3)
          if (_currentStep < 4) ...[
            _buildCodeBoxes(obscure: _currentStep == 1 || _currentStep == 2),
            const SizedBox(height: 16),
          ],

          // OTP Resend Countdown (Step 3 only)
          if (_currentStep == 3) ...[
            _buildOtpCountdown(),
            const SizedBox(height: 16),
          ],

          // Error Banner
          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],

          // Action Button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    final isSuccess = _currentStep == 4;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isSuccess
              ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
              : [AppColors.deepNavy, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? const Color(0xFF22C55E) : AppColors.deepNavy).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(_stepIcon, size: 30, color: Colors.white),
    );
  }

  Widget _buildCodeBoxes({required bool obscure}) {
    final code = _inputController.text;
    return SizedBox(
      width: 46 * 6 + 8 * 5,
      height: 54,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final isFocused = _focusNode.hasFocus && code.length == i ||
                  (_focusNode.hasFocus && i == 5 && code.length == 6);
              final isFilled = i < code.length;
              final char = isFilled ? code[i] : '';

              return Container(
                width: 46,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppColors.primaryNavy
                        : isFilled
                            ? AppColors.primaryNavy.withValues(alpha: 0.35)
                            : AppColors.border,
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  obscure && isFilled ? '●' : char,
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCountdown() {
    if (_countdown > 0) {
      return Text(
        'Gửi lại mã sau ${_countdown}s',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    return GestureDetector(
      onTap: _resendOtp,
      child: Text(
        'Gửi lại mã OTP',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryNavy,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_currentStep == 4) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            'Xong',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final isFormValid = _inputController.text.length == 6;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (isFormValid && !_isLoading) ? _handleNextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          disabledBackgroundColor: AppColors.primaryNavy.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _currentStep == 3 ? 'Hoàn tất xác thực' : 'Tiếp tục',
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
