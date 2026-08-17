import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/transaction_flow_data.dart';
import '../../../../core/services/api_service.dart';
import '../../data/face_id_service.dart';
import '../../domain/face_capture_pose.dart';
import '../../domain/transaction_face_authorization.dart';
import 'face_id_enrollment_intro_screen.dart';
import 'face_id_permission_screen.dart';
import '../widgets/face_id_components.dart';

class TransactionFaceIdScreen extends StatefulWidget {
  final TransactionFlowData transaction;

  const TransactionFaceIdScreen({super.key, required this.transaction});

  @override
  State<TransactionFaceIdScreen> createState() =>
      _TransactionFaceIdScreenState();
}

class _TransactionFaceIdScreenState extends State<TransactionFaceIdScreen> {
  bool _verifying = false;
  bool _notRegistered = false;
  bool _directDemoVerified = false;
  String? _error;

  String get _amount => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(widget.transaction.amount);

  Future<void> _scanAndVerify() async {
    if (_verifying) return;
    final images = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => const FaceIdPermissionScreen(
          request: FaceCaptureRequest.transaction(),
        ),
      ),
    );
    if (!mounted || images == null || images.length < 2) return;
    setState(() {
      _verifying = true;
      _notRegistered = false;
      _directDemoVerified = false;
      _error = null;
    });
    try {
      final token = await FaceIdService.verifyForTransaction(images);
      images.clear();
      if (!mounted) return;
      if (token.isDirectDemo) {
        setState(() {
          _verifying = false;
          _directDemoVerified = true;
        });
        return;
      }
      context.pushReplacement(
        '/transaction/verify',
        extra: TransactionAuthorizationData(
          transaction: widget.transaction,
          faceIdToken: token,
        ),
      );
    } on DioException catch (exception) {
      images.clear();
      if (!mounted) return;
      final code = ApiService.parseErrorCode(exception);
      setState(() {
        _verifying = false;
        _notRegistered = code == 'FACEID_NOT_REGISTERED';
        if (_notRegistered) {
          _error =
              'Bạn chưa thiết lập hồ sơ khuôn mặt. Thông tin giao dịch vẫn được giữ.';
        } else if (code == 'FACEID_VERIFICATION_FAILED') {
          _error =
              'Khuôn mặt không khớp hoặc ảnh chưa đạt yêu cầu. Hãy thử lại ở nơi đủ sáng.';
        } else if (code == 'FACEID_SERVICE_UNAVAILABLE') {
          _error =
              'Dịch vụ xác thực khuôn mặt đang tạm thời không khả dụng. Giao dịch chưa được gửi.';
        } else {
          _error = ApiService.parseDioError(exception);
        }
      });
    } catch (_) {
      images.clear();
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'Không thể xác thực khuôn mặt. Giao dịch chưa được gửi.';
        });
      }
    }
  }

  Future<void> _enroll() async {
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const FaceIdEnrollmentIntroScreen(returnToCaller: true),
      ),
    );
    if (!mounted || enrolled != true) return;
    setState(() {
      _notRegistered = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_verifying,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Xác thực khuôn mặt'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const FaceIdHeroIcon(
                        icon: Icons.face_retouching_natural_rounded,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Quét khuôn mặt trước khi nhập PIN/OTP',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giao dịch $_amount cần thêm một lớp bảo vệ sinh trắc học.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            _SecurityStep(
                              number: '1',
                              label: 'Quét khuôn mặt nhìn thẳng',
                              active: true,
                            ),
                            _SecurityStep(
                              number: '2',
                              label: 'Nhập PIN hoặc OTP',
                            ),
                            _SecurityStep(
                              number: '3',
                              label: 'Gửi giao dịch',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const FaceIdBanner(
                        message:
                            'Nhìn thẳng và giữ yên. Một lần quét sẽ ghi nhận năm khung hình để đáp ứng kiểm tra chống giả mạo.',
                        icon: Icons.center_focus_strong_rounded,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        FaceIdBanner(
                          message: _error!,
                          icon: Icons.error_outline_rounded,
                          color: _notRegistered
                              ? AppColors.warning
                              : AppColors.error,
                        ),
                      ],
                      if (_directDemoVerified) ...[
                        const SizedBox(height: 14),
                        const FaceIdBanner(
                          message:
                              'Xác thực khuôn mặt trực tiếp thành công. Đây là chế độ thử nghiệm nên giao dịch chưa được gửi.',
                          icon: Icons.check_circle_outline_rounded,
                          color: Colors.green,
                        ),
                      ],
                      if (_verifying) ...[
                        const SizedBox(height: 28),
                        const CircularProgressIndicator(
                          color: AppColors.primaryNavy,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Đang kiểm tra chống giả mạo và đối chiếu khuôn mặt...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                color: Colors.white,
                child: Column(
                  children: [
                    FaceIdPrimaryButton(
                      label: _notRegistered
                          ? 'Thiết lập khuôn mặt'
                          : 'Bắt đầu quét',
                      icon: _notRegistered
                          ? Icons.person_add_alt_1_outlined
                          : Icons.camera_alt_outlined,
                      loading: _verifying,
                      onPressed: _notRegistered ? _enroll : _scanAndVerify,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _verifying ? null : () => context.pop(),
                        child: const Text('Hủy giao dịch'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityStep extends StatelessWidget {
  final String number;
  final String label;
  final bool active;
  final bool isLast;

  const _SecurityStep({
    required this.number,
    required this.label,
    this.active = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryNavy : AppColors.inputFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? AppColors.primaryNavy : AppColors.border,
                ),
              ),
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            if (!isLast)
              Container(width: 1, height: 24, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
