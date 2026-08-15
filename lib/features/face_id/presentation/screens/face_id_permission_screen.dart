import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/face_capture_pose.dart';
import 'face_capture_screen.dart';
import '../widgets/face_id_components.dart';

class FaceIdPermissionScreen extends StatefulWidget {
  final FaceCaptureRequest request;

  const FaceIdPermissionScreen({super.key, required this.request});

  @override
  State<FaceIdPermissionScreen> createState() => _FaceIdPermissionScreenState();
}

class _FaceIdPermissionScreenState extends State<FaceIdPermissionScreen>
    with WidgetsBindingObserver {
  bool _requesting = false;
  bool _openingCapture = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus(openCaptureWhenGranted: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus(openCaptureWhenGranted: true);
    }
  }

  Future<void> _refreshStatus({required bool openCaptureWhenGranted}) async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _permanentlyDenied = status.isPermanentlyDenied);
    if (status.isGranted && openCaptureWhenGranted) {
      await _openCapture();
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
    if (status.isGranted) {
      await _openCapture();
    }
  }

  Future<void> _openCapture() async {
    if (_openingCapture) return;
    _openingCapture = true;
    final images = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => FaceCaptureScreen(request: widget.request),
      ),
    );
    if (!mounted) return;
    _openingCapture = false;
    if (images == null) return;
    Navigator.of(context).pop(images);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Xác thực khuôn mặt'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              const FaceIdHeroIcon(icon: Icons.photo_camera_outlined),
              const SizedBox(height: 18),
              Text(
                _permanentlyDenied
                    ? 'Camera đang bị tắt'
                    : 'Cho phép truy cập camera',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _permanentlyDenied
                    ? 'Hãy bật quyền Camera trong Cài đặt để tiếp tục xác thực khuôn mặt.'
                    : 'Ứng dụng cần camera trước để chụp khuôn mặt phục vụ xác minh danh tính.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              FaceIdPrimaryButton(
                label: _permanentlyDenied ? 'Mở Cài đặt' : 'Cho phép camera',
                icon: _permanentlyDenied
                    ? Icons.settings_outlined
                    : Icons.camera_alt_outlined,
                loading: _requesting,
                onPressed: _permanentlyDenied
                    ? _openSettings
                    : _requestPermission,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
