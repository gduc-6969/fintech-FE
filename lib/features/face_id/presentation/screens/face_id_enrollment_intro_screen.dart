import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import 'face_id_preparation_screen.dart';
import '../widgets/face_id_components.dart';

class FaceIdEnrollmentIntroScreen extends StatefulWidget {
  final bool returnToCaller;

  const FaceIdEnrollmentIntroScreen({super.key, this.returnToCaller = false});

  @override
  State<FaceIdEnrollmentIntroScreen> createState() =>
      _FaceIdEnrollmentIntroScreenState();
}

class _FaceIdEnrollmentIntroScreenState
    extends State<FaceIdEnrollmentIntroScreen> {
  bool _consented = false;

  Future<void> _continue() async {
    if (!_consented) return;
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const FaceIdPreparationScreen()),
    );
    if (!mounted || enrolled != true) return;
    if (widget.returnToCaller) {
      Navigator.of(context).pop(true);
    } else {
      context.go('/wallet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Thiết lập xác thực khuôn mặt'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  children: [
                    const FaceIdHeroIcon(
                      icon: Icons.face_retouching_natural_rounded,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bảo vệ giao dịch giá trị cao',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chúng tôi sẽ chụp 5 góc khuôn mặt để tạo hồ sơ xác thực cho bạn.',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          FaceIdInfoTile(
                            icon: Icons.verified_user_outlined,
                            text: 'Xác nhận đúng chủ tài khoản',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.visibility_off_outlined,
                            text: 'Hỗ trợ chống ảnh giả và màn hình giả mạo',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.payments_outlined,
                            text: 'Bắt buộc với giao dịch từ 10.000.000 ₫',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Khoảng 1–2 phút',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Năm ảnh khuôn mặt được gửi đến hệ thống để xử lý sinh trắc học và không được lưu vào thư viện.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Chính sách quyền riêng tư đang được cập nhật.',
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                              alignment: Alignment.centerLeft,
                            ),
                            child: const Text(
                              'Xem chính sách quyền riêng tư',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      checked: _consented,
                      button: true,
                      label: 'Đồng ý xử lý dữ liệu khuôn mặt',
                      child: InkWell(
                        onTap: () => setState(() => _consented = !_consented),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _consented,
                                onChanged: (value) =>
                                    setState(() => _consented = value ?? false),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Tôi đã đọc và đồng ý cho hệ thống xử lý dữ liệu khuôn mặt để xác minh danh tính.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: Colors.white,
              child: FaceIdPrimaryButton(
                label: 'Tôi đồng ý — Tiếp tục',
                onPressed: _consented ? _continue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
