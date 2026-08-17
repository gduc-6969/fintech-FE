import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/face_capture_batch.dart';
import '../../domain/face_capture_pose.dart';
import '../../domain/face_id_frame_payload.dart';
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
  late final FaceCaptureBatch _captureBatch;
  final Set<String> _pendingTemporaryFiles = <String>{};
  bool _initializing = true;
  bool _capturing = false;
  bool _privacyCurtainVisible = false;
  String? _error;
  int _step = 0;
  int? _countdown;
  int _capturedFrameProgress = 0;
  int _cameraGeneration = 0;
  int _captureGeneration = 0;
  Future<void> _cameraDisposal = Future<void>.value();

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
    _captureBatch = FaceCaptureBatch(
      expectedFrameCount: switch (widget.request.mode) {
        FaceCaptureMode.enrollment => FaceIdPolicy.enrollmentFrameCount,
        FaceCaptureMode.enrollmentRetake => 1,
        FaceCaptureMode.transaction => FaceIdPolicy.transactionFrameCount,
      },
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _suspendCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _privacyCurtainVisible = false);
      }
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    final generation = ++_cameraGeneration;
    CameraController? nextController;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      await _cameraDisposal;
      if (!mounted || generation != _cameraGeneration) return;
      _camera ??= (await availableCameras()).firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => throw CameraException(
          'frontCameraUnavailable',
          'Thiết bị không có camera trước.',
        ),
      );
      nextController = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await nextController.initialize();
      await _configureCamera(nextController);
      if (!mounted || generation != _cameraGeneration) {
        await _safelyDisposeController(nextController);
        return;
      }

      final previousController = _controller;
      _controller = nextController;
      nextController = null;
      setState(() {
        _initializing = false;
        _error = null;
      });
      if (previousController != null) {
        await _safelyDisposeController(previousController);
      }
    } on CameraException catch (error) {
      if (nextController != null) {
        await _safelyDisposeController(nextController);
      }
      if (mounted && generation == _cameraGeneration) {
        setState(() {
          _initializing = false;
          _error = _cameraErrorMessage(error);
        });
      }
    } catch (_) {
      if (nextController != null) {
        await _safelyDisposeController(nextController);
      }
      if (mounted && generation == _cameraGeneration) {
        setState(() {
          _initializing = false;
          _error = 'Không thể khởi tạo camera trước. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _configureCamera(CameraController controller) async {
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException {
      // Some cameras do not expose orientation locking. The JPEG quality gate
      // still verifies that a decodable frame is produced.
    }
    try {
      await controller.setFlashMode(FlashMode.off);
    } on CameraException {
      // Front cameras commonly do not expose flash controls.
    }
    try {
      await controller.setFocusMode(FocusMode.auto);
    } on CameraException {
      // Fixed-focus front cameras can safely continue.
    }
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } on CameraException {
      // Fixed-exposure cameras can safely continue.
    }
  }

  void _suspendCamera() {
    _cameraGeneration++;
    _captureGeneration++;
    final controller = _controller;
    _controller = null;
    _captureBatch.clear();
    if (mounted) {
      setState(() {
        _privacyCurtainVisible = true;
        _initializing = true;
        _capturing = false;
        _countdown = null;
        _capturedFrameProgress = 0;
        _step = 0;
        _error = 'Phiên chụp đã được đặt lại để bảo vệ dữ liệu khuôn mặt.';
      });
    }
    if (controller != null) {
      _cameraDisposal = _cameraDisposal.then(
        (_) => _safelyDisposeController(controller),
      );
    }
    unawaited(_retryTemporaryFileDeletion());
  }

  Future<void> _safelyDisposeController(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // The camera may already have been released by the operating system.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }
    final generation = ++_captureGeneration;
    final checkpoint = _captureBatch.checkpoint();
    setState(() {
      _capturing = true;
      _error = null;
      _capturedFrameProgress = 0;
    });
    try {
      for (var second = 3; second >= 1; second--) {
        _ensureCaptureIsActive(generation, controller);
        setState(() => _countdown = second);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      _ensureCaptureIsActive(generation, controller);
      setState(() => _countdown = null);

      final framesToTake = _isTransaction
          ? FaceIdPolicy.transactionFrameCount
          : 1;
      for (var frame = 0; frame < framesToTake; frame++) {
        _ensureCaptureIsActive(generation, controller);
        final xFile = await controller.takePicture();
        try {
          final bytes = await xFile.readAsBytes();
          final capturedFrame = await _prepareFrame(bytes);
          _captureBatch.add(capturedFrame);
          _ensureCaptureIsActive(generation, controller);
          setState(() => _capturedFrameProgress = frame + 1);
        } finally {
          await _deleteTemporaryCapture(xFile.path);
        }
        if (frame + 1 < framesToTake) {
          await Future<void>.delayed(FaceIdPolicy.transactionFrameInterval);
        }
      }

      _ensureCaptureIsActive(generation, controller);
      if (widget.request.mode == FaceCaptureMode.enrollment && _step < 4) {
        setState(() {
          _step++;
          _capturing = false;
          _capturedFrameProgress = 0;
        });
      } else {
        final result = _captureBatch.complete();
        if (!mounted) return;
        Navigator.of(context).pop(result);
      }
    } on _CaptureInterruptedException {
      _rollbackCaptureAttempt(checkpoint);
    } on CameraException catch (error) {
      _rollbackCaptureAttempt(checkpoint);
      if (mounted && generation == _captureGeneration) {
        setState(() {
          _capturing = false;
          _countdown = null;
          _capturedFrameProgress = 0;
          _error = _cameraErrorMessage(error);
        });
      }
    } on _FaceCaptureQualityException catch (error) {
      _rollbackCaptureAttempt(checkpoint);
      if (mounted && generation == _captureGeneration) {
        setState(() {
          _capturing = false;
          _countdown = null;
          _capturedFrameProgress = 0;
          _error = error.message;
        });
      }
    } catch (_) {
      _rollbackCaptureAttempt(checkpoint);
      if (mounted && generation == _captureGeneration) {
        setState(() {
          _capturing = false;
          _countdown = null;
          _capturedFrameProgress = 0;
          _error = 'Ảnh chưa được ghi nhận. Hãy giữ yên và thử lại.';
        });
      }
    }
  }

  void _rollbackCaptureAttempt(int checkpoint) {
    if (checkpoint <= _captureBatch.length) {
      _captureBatch.rollbackTo(checkpoint);
    } else {
      _captureBatch.clear();
    }
  }

  void _ensureCaptureIsActive(int generation, CameraController controller) {
    if (!mounted ||
        generation != _captureGeneration ||
        !identical(controller, _controller) ||
        !controller.value.isInitialized) {
      throw const _CaptureInterruptedException();
    }
  }

  Future<CapturedFaceFrame> _prepareFrame(Uint8List bytes) async {
    try {
      FaceIdFramePayload.validateJpegBytes(bytes);
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
      try {
        final frameInfo = await codec.getNextFrame();
        try {
          final rgba = await frameInfo.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgba == null) {
            throw const FormatException('Could not decode camera frame.');
          }
          final quality = FaceImageQuality.fromRgba(
            rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
            width: frameInfo.image.width,
            height: frameInfo.image.height,
          );
          final rejectionMessage = quality.rejectionMessage;
          if (rejectionMessage != null) {
            throw _FaceCaptureQualityException(rejectionMessage);
          }
          return CapturedFaceFrame(
            payload: FaceIdFramePayload.encodeJpeg(bytes),
            quality: quality,
          );
        } finally {
          frameInfo.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } on _FaceCaptureQualityException {
      rethrow;
    } on FormatException {
      throw const _FaceCaptureQualityException(
        'Khung hình không hợp lệ. Hãy giữ yên và chụp lại.',
      );
    }
  }

  Future<void> _deleteTemporaryCapture(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      _pendingTemporaryFiles.remove(path);
    } catch (_) {
      _pendingTemporaryFiles.add(path);
    }
  }

  Future<void> _retryTemporaryFileDeletion() async {
    final paths = List<String>.of(_pendingTemporaryFiles);
    for (final path in paths) {
      await _deleteTemporaryCapture(path);
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Không thể truy cập camera. Hãy kiểm tra quyền Camera trong Cài đặt.';
      case 'frontCameraUnavailable':
        return 'Thiết bị không có camera trước để xác thực khuôn mặt.';
      default:
        return 'Camera chưa sẵn sàng. Vui lòng thử lại.';
    }
  }

  Future<void> _retryCamera() async {
    if (_capturing || _initializing) return;
    _captureBatch.clear();
    _step = 0;
    await _initializeCamera();
  }

  Future<void> _retryAfterError() async {
    final controller = _controller;
    if (controller?.value.isInitialized == true) {
      setState(() => _error = null);
      await _capture();
      return;
    }
    await _retryCamera();
  }

  Future<void> _close() async {
    if (_capturing) return;
    if (_captureBatch.isEmpty) {
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
    _cameraGeneration++;
    _captureGeneration++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_safelyDisposeController(controller));
    }
    _captureBatch.clear();
    unawaited(_retryTemporaryFileDeletion());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_capturing && _captureBatch.isEmpty,
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
                        if (_capturing && _countdown == null) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Đang ghi nhận $_capturedFrameProgress/'
                              '${FaceIdPolicy.transactionFrameCount}',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
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
                  label: _error != null
                      ? 'Thử lại'
                      : _isTransaction
                      ? 'Quét khuôn mặt'
                      : 'Chụp góc này',
                  icon: _error != null
                      ? Icons.refresh_rounded
                      : Icons.camera_alt_outlined,
                  loading: _capturing,
                  onPressed: _initializing
                      ? null
                      : _error != null
                      ? _retryAfterError
                      : _capture,
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
              if (_privacyCurtainVisible)
                const ColoredBox(
                  color: Color(0xFF111827),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white70,
                      size: 48,
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

class _CaptureInterruptedException implements Exception {
  const _CaptureInterruptedException();
}

class _FaceCaptureQualityException implements Exception {
  final String message;

  const _FaceCaptureQualityException(this.message);
}
