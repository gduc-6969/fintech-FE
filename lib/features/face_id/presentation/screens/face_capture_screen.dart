import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/face_capture_pose.dart';
import '../../domain/face_id_policy.dart';
import '../widgets/face_id_components.dart';

class FaceCaptureScreen extends StatefulWidget {
  final FaceCaptureRequest request;

  const FaceCaptureScreen({super.key, required this.request});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  static const _enrollmentPoses = FaceCapturePose.values;

  CameraController? _controller;
  CameraDescription? _camera;
  final List<String> _capturedImages = <String>[];
  bool _initializing = true;
  bool _capturing = false;
  bool _returningResult = false;
  String? _error;
  int _step = 0;
  int? _countdown;

  bool get _isTransaction => widget.request.mode == FaceCaptureMode.transaction;

  FaceCapturePose get _pose {
    if (_isTransaction) return FaceCapturePose.straight;
    if (widget.request.mode == FaceCaptureMode.enrollmentRetake) {
      return widget.request.retakePose!;
    }
    return _enrollmentPoses[_step];
  }

  int get _totalSteps =>
      widget.request.mode == FaceCaptureMode.enrollment ? 5 : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      _camera ??= (await availableCameras()).firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => throw CameraException(
          'frontCameraUnavailable',
          'Thiết bị không có camera trước.',
        ),
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _initializing = false);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = error.description ?? 'Không thể khởi tạo camera trước.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Không thể khởi tạo camera trước. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      for (var second = 3; second >= 1; second--) {
        if (!mounted) return;
        setState(() => _countdown = second);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _countdown = null);

      final framesToTake = _isTransaction
          ? FaceIdPolicy.transactionFrameCount
          : 1;
      for (var frame = 0; frame < framesToTake; frame++) {
        final xFile = await controller.takePicture();
        try {
          final bytes = await xFile.readAsBytes();
          _capturedImages.add('data:image/jpeg;base64,${base64Encode(bytes)}');
        } finally {
          try {
            await File(xFile.path).delete();
          } catch (_) {
            // The camera plugin may already have removed its temporary file.
          }
        }
        if (frame + 1 < framesToTake) {
          await Future<void>.delayed(FaceIdPolicy.transactionFrameInterval);
        }
      }

      if (!mounted) return;
      if (widget.request.mode == FaceCaptureMode.enrollment && _step < 4) {
        setState(() {
          _step++;
          _capturing = false;
        });
      } else {
        _returningResult = true;
        Navigator.of(context).pop(List<String>.of(_capturedImages));
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _countdown = null;
          _error = error.description ?? 'Không thể chụp ảnh. Vui lòng thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _countdown = null;
          _error = 'Ảnh chưa được ghi nhận. Hãy giữ yên và thử lại.';
        });
      }
    }
  }

  Future<void> _close() async {
    if (_capturing) return;
    if (_capturedImages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng chụp khuôn mặt?'),
        content: const Text('Các ảnh vừa chụp sẽ bị xóa khỏi bộ nhớ ứng dụng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục chụp'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dừng'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    if (!_returningResult) _capturedImages.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_capturing && _capturedImages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            tooltip: 'Đóng camera',
            onPressed: _capturing ? null : _close,
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            _isTransaction
                ? 'Xác thực giao dịch'
                : 'Bước ${_step + 1}/$_totalSteps',
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (!_isTransaction)
                LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  color: AppColors.primaryNavy,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    children: [
                      _buildPreview(),
                      const SizedBox(height: 20),
                      Text(
                        _isTransaction ? 'Nhìn thẳng vào camera' : _pose.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isTransaction
                            ? 'Giữ đầu thẳng và yên trong khi hệ thống ghi nhận khuôn mặt.'
                            : _pose.instruction,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_isTransaction) ...[
                        const SizedBox(height: 12),
                        const FaceIdBanner(
                          message:
                              'Một lần quét sẽ tự động ghi nhận năm khung hình liên tiếp. Hãy giữ yên.',
                          icon: Icons.center_focus_strong_rounded,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        FaceIdBanner(
                          message: _error!,
                          icon: Icons.error_outline_rounded,
                          color: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                color: Colors.white,
                child: FaceIdPrimaryButton(
                  label: _isTransaction ? 'Quét khuôn mặt' : 'Chụp góc này',
                  icon: Icons.camera_alt_outlined,
                  loading: _capturing,
                  onPressed: _initializing || _error != null ? null : _capture,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: const Color(0xFF111827),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_initializing)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else if (_controller?.value.isInitialized == true)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final controller = _controller!;
                    final boxRatio =
                        constraints.maxWidth / constraints.maxHeight;
                    var scale = controller.value.aspectRatio / boxRatio;
                    if (scale < 1) scale = 1 / scale;
                    return ClipRect(
                      child: Transform.scale(
                        scale: scale,
                        child: Center(child: CameraPreview(controller)),
                      ),
                    );
                  },
                )
              else
                const Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              Center(
                child: Container(
                  width: 220,
                  height: 286,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(112),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (_countdown != null)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: 'Chụp sau $_countdown giây',
                      child: Text(
                        '$_countdown',
                        style: GoogleFonts.dmSans(
                          fontSize: 72,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
