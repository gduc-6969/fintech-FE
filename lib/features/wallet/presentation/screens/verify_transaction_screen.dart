import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/transaction_flow_data.dart';
import '../../../../core/services/api_service.dart';
import '../../../face_id/domain/face_id_policy.dart';
import '../../../face_id/domain/face_id_token.dart';

class VerifyTransactionScreen extends StatefulWidget {
  final TransactionFlowData data;
  final FaceIdToken? faceIdToken;

  const VerifyTransactionScreen({
    super.key,
    required this.data,
    this.faceIdToken,
  });

  @override
  State<VerifyTransactionScreen> createState() =>
      _VerifyTransactionScreenState();
}

class _VerifyTransactionScreenState extends State<VerifyTransactionScreen> {
  static const int _maxAttempts = 5;
  static const int _otpCooldownSeconds = 45;

  // Tab state
  bool _isPinTab = true;

  // PIN visibility
  bool _showPin = false;

  // 6-box code input
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String get _code => _codeController.text;

  // Attempt tracking
  int _attemptsRemaining = _maxAttempts;
  bool get _isLocked => _attemptsRemaining <= 0;

  // OTP state
  int _countdown = 0;
  Timer? _countdownTimer;
  Timer? _faceTokenTimer;
  String _maskedEmail = '···';
  bool _isRequestingOtp = false;
  bool _otpEverRequested = false;

  // UI state
  bool _isVerifying = false;
  bool _faceTokenConsumed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaskedEmail();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    if (_requiresFaceId) {
      _faceTokenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (!_hasUsableFaceToken) setState(() {});
      });
    }
  }

  Future<void> _loadMaskedEmail() async {
    try {
      final profile = await ApiService.getUserProfile();
      final email = profile['email']?.toString() ?? '';
      if (mounted) setState(() => _maskedEmail = _maskEmail(email));
    } catch (_) {}
  }

  String _maskEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx <= 0) return email;
    final local = email.substring(0, atIdx);
    final domain = email.substring(atIdx);
    if (local.length <= 3) return '${local[0]}***$domain';
    return '${local.substring(0, 3)}***$domain';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _faceTokenTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Tab switching ─────────────────────────────────────────────────────────

  void _switchTab(bool toPin) {
    if (_isPinTab == toPin) return;
    setState(() {
      _isPinTab = toPin;
      _error = null;
      _clearCode();
    });
    // Trigger OTP send the first time the OTP tab is opened
    if (!toPin && !_otpEverRequested) {
      _requestOtp();
    }
  }

  void _clearCode() {
    _codeController.clear();
  }

  // ── OTP helpers ───────────────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    if (_isRequestingOtp || _countdown > 0) return;
    setState(() {
      _isRequestingOtp = true;
      _error = null;
    });
    try {
      await ApiService.requestTransactionOtp();
      _otpEverRequested = true;
      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không thể gửi mã OTP. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isRequestingOtp = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _otpCooldownSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── Verify ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (_code.length < 6 || _isVerifying || _isLocked || !_hasUsableFaceToken) {
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final type = widget.data.type;
    final amount = widget.data.amount;
    final idempotencyKey = widget.data.idempotencyKey;
    if (idempotencyKey == null) {
      setState(() {
        _isVerifying = false;
        _error = 'Không thể xác định yêu cầu giao dịch. Vui lòng quay lại.';
      });
      return;
    }
    final String? pin = _isPinTab ? _code : null;
    final String? otpCode = _isPinTab ? null : _code;

    try {
      TransactionSubmissionResult response;
      if (type == TransactionType.deposit) {
        response = await ApiService.topUpFromBank(
          linkedBankAccountId: widget.data.bankId!,
          amount: amount,
          idempotencyKey: idempotencyKey,
          pin: pin,
          otpCode: otpCode,
          faceIdToken: widget.faceIdToken?.value,
        );
      } else if (type == TransactionType.withdraw) {
        response = await ApiService.withdrawToBank(
          linkedBankAccountId: widget.data.bankId!,
          amount: amount,
          idempotencyKey: idempotencyKey,
          pin: pin,
          otpCode: otpCode,
          faceIdToken: widget.faceIdToken?.value,
        );
      } else {
        response = await ApiService.transferToWallet(
          recipientPhoneNumber: widget.data.recipientPhone!,
          amount: amount,
          idempotencyKey: idempotencyKey,
          pin: pin,
          otpCode: otpCode,
          faceIdToken: widget.faceIdToken?.value,
        );
      }

      if (mounted) {
        context.pushReplacement(
          '/transaction/success',
          extra: widget.data.copyWith(
            transactionId: response.id,
            referenceCode: response.referenceCode,
            createdAt: response.createdAt ?? DateTime.now().toIso8601String(),
            outcome: response.outcome,
          ),
        );
      }
    } on DioException catch (e) {
      // A timeout is ambiguous: the server may or may not have accepted it.
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        if (mounted) {
          context.pushReplacement(
            '/transaction/success',
            extra: widget.data.copyWith(
              referenceCode: idempotencyKey,
              createdAt: DateTime.now().toIso8601String(),
              outcome: TransactionOutcome.unknown,
            ),
          );
        }
        return;
      }
      if (mounted) {
        final errorCode = ApiService.parseErrorCode(e);
        if (_requiresFaceId) _faceTokenConsumed = true;
        if (_requiresFaceId &&
            (errorCode == 'INVALID_PIN' ||
                errorCode == 'INVALID_TRANSACTION_OTP' ||
                errorCode == 'FACEID_TOKEN_INVALID' ||
                errorCode == 'FACEID_REQUIRED')) {
          setState(() {
            _isVerifying = false;
            _clearCode();
          });
          await _requireNewFaceScan(
            errorCode == 'FACEID_TOKEN_INVALID' ||
                    errorCode == 'FACEID_REQUIRED'
                ? 'Mã xác thực khuôn mặt đã hết hạn hoặc không còn hợp lệ. Bạn cần quét lại trước khi tiếp tục.'
                : 'PIN hoặc OTP chưa đúng. Mã khuôn mặt chỉ dùng một lần, vì vậy bạn cần quét lại trước khi nhập lại mã.',
          );
          return;
        }
        setState(() {
          _isVerifying = false;
          if (errorCode == 'PIN_LOCKED') {
            _attemptsRemaining = 0;
          } else if (errorCode == 'INVALID_PIN' ||
              errorCode == 'INVALID_TRANSACTION_OTP') {
            _attemptsRemaining = (_attemptsRemaining - 1).clamp(
              0,
              _maxAttempts,
            );
            _clearCode();
            _error = ApiService.parseDioError(e);
          } else {
            _error = ApiService.parseDioError(e);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          if (_requiresFaceId) _faceTokenConsumed = true;
          _error = 'Đã xảy ra lỗi không mong muốn.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCurrency(num value) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);

  bool get _requiresFaceId => FaceIdPolicy.isRequiredFor(widget.data);

  bool get _hasUsableFaceToken =>
      !_requiresFaceId ||
      (!_faceTokenConsumed &&
          widget.faceIdToken != null &&
          !widget.faceIdToken!.isExpired());

  Future<void> _requireNewFaceScan(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cần quét lại khuôn mặt'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Quét lại'),
          ),
        ],
      ),
    );
    if (mounted) {
      context.pushReplacement('/transaction/face-id', extra: widget.data);
    }
  }

  String get _typeLabel {
    switch (widget.data.type) {
      case TransactionType.deposit:
        return 'Authorize deposit';
      case TransactionType.withdraw:
        return 'Authorize withdrawal';
      case TransactionType.transfer:
        return 'Authorize transfer';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final amount = widget.data.amount;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Verify Transaction',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
          child: Column(
            children: [
              // ── Shield icon ──────────────────────────────────────────────
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.primaryNavy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),

              // ── Header text ──────────────────────────────────────────────
              Text(
                _typeLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Confirm your identity to move '),
                    TextSpan(
                      text: _formatCurrency(amount),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Segmented toggle ─────────────────────────────────────────
              if (_requiresFaceId) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _hasUsableFaceToken
                        ? AppColors.success.withValues(alpha: 0.08)
                        : AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasUsableFaceToken
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _hasUsableFaceToken
                            ? Icons.check_circle_outline_rounded
                            : Icons.timer_off_outlined,
                        color: _hasUsableFaceToken
                            ? AppColors.success
                            : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasUsableFaceToken
                              ? 'Bước 1 hoàn tất: khuôn mặt đã được xác minh. Nhập PIN hoặc OTP để gửi giao dịch.'
                              : 'Mã khuôn mặt đã được sử dụng hoặc hết hạn. Giao dịch chưa được gửi.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: _hasUsableFaceToken
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _buildToggle(),
              const SizedBox(height: 28),

              // ── Main content ─────────────────────────────────────────────
              if (_isLocked)
                _buildLockedState()
              else if (_isPinTab)
                _buildPinContent()
              else
                _buildOtpContent(),

              const SizedBox(height: 24),

              // ── Error banner ─────────────────────────────────────────────
              if (_error != null && !_isLocked) ...[
                _buildErrorBanner(_error!),
                const SizedBox(height: 20),
              ],

              // ── Verify button + attempts counter ─────────────────────────
              if (!_isLocked) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        (_code.length == 6 &&
                            !_isVerifying &&
                            _hasUsableFaceToken)
                        ? _verify
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      disabledBackgroundColor: AppColors.primaryNavy
                          .withOpacity(0.45),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Verify & Confirm',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_attemptsRemaining verification attempt${_attemptsRemaining == 1 ? '' : 's'} remaining',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (_requiresFaceId && !_hasUsableFaceToken && !_isLocked) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushReplacement(
                      '/transaction/face-id',
                      extra: widget.data,
                    ),
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: const Text('Quét lại khuôn mặt'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _toggleButton(
            label: 'PIN',
            icon: Icons.lock_outline_rounded,
            selected: _isPinTab,
            onTap: () => _switchTab(true),
          ),
          _toggleButton(
            label: 'Email OTP',
            icon: Icons.email_outlined,
            selected: !_isPinTab,
            onTap: () => _switchTab(false),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinContent() {
    return Column(
      children: [
        Text(
          'ENTER TRANSACTION PIN',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 18),
        _buildCodeBoxes(obscure: !_showPin),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => setState(() => _showPin = !_showPin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showPin
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _showPin ? 'Hide PIN' : 'Show PIN',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpContent() {
    return Column(
      children: [
        // Email chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                'Code sent to $_maskedEmail',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _buildCodeBoxes(obscure: false),
        const SizedBox(height: 22),
        _buildCountdown(),
      ],
    );
  }

  Widget _buildCodeBoxes({required bool obscure}) {
    return SizedBox(
      width: 46 * 6 + 8 * 5,
      height: 54,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final isFocused =
                  _focusNode.hasFocus && _code.length == i ||
                  (_focusNode.hasFocus && i == 5 && _code.length == 6);
              final isFilled = i < _code.length;
              final char = isFilled ? _code[i] : '';

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
                controller: _codeController,
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
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    final bool canResend =
        _countdown == 0 && !_isRequestingOtp && _otpEverRequested;
    if (_isRequestingOtp) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryNavy,
        ),
      );
    }
    if (_countdown > 0) {
      return Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: _countdown / _otpCooldownSeconds,
                    strokeWidth: 3.5,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryNavy,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${_countdown}s',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Resend available in ${_countdown}s',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }
    if (canResend) {
      return GestureDetector(
        onTap: _requestOtp,
        child: Text(
          'Resend code',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryNavy,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primaryNavy,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLockedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: AppColors.error,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verification locked',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have exceeded the maximum number of verification attempts. Please try again later or contact support.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
