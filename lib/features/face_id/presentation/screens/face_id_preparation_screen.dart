import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/face_capture_pose.dart';
import 'face_id_enrollment_review_screen.dart';
import 'face_id_permission_screen.dart';
import '../widgets/face_id_components.dart';

class FaceIdPreparationScreen extends StatelessWidget {
  const FaceIdPreparationScreen({super.key});

  Future<void> _openCamera(BuildContext context) async {
    final images = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => const FaceIdPermissionScreen(
          request: FaceCaptureRequest.enrollment(),
        ),
      ),
    );
    if (!context.mounted || images == null || images.length != 5) return;
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FaceIdEnrollmentReviewScreen(images: images),
      ),
    );
    images.clear();
    if (context.mounted && enrolled == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Chuẩn bị trước khi chụp'),
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
                            icon: Icons.visibility_off_outlined,
                            text: 'Tháo kính, khẩu trang và mũ',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.face_outlined,
                            text: 'Để lộ rõ trán, mắt, mũi và cằm',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.light_mode_outlined,
                            text:
                                'Đứng ở nơi đủ sáng, tránh ánh sáng chiếu thẳng',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.photo_camera_outlined,
                            text:
                                'Lau sạch camera trước và giữ điện thoại ngang tầm mắt',
                          ),
                          FaceIdInfoTile(
                            icon: Icons.person_outline_rounded,
                            text: 'Chỉ một người xuất hiện trong khung hình',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FaceIdBanner(
                      message: 'Không thể sử dụng ảnh có sẵn trong thư viện.',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: Colors.white,
              child: FaceIdPrimaryButton(
                label: 'Mở camera',
                icon: Icons.camera_alt_outlined,
                onPressed: () => _openCamera(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
