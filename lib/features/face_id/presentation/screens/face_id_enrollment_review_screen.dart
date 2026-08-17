import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../data/face_id_service.dart';
import '../../domain/face_capture_pose.dart';
import 'face_id_permission_screen.dart';
import 'face_id_result_screen.dart';
import '../widgets/face_id_components.dart';

class FaceIdEnrollmentReviewScreen extends StatefulWidget {
  final List<String> images;

  const FaceIdEnrollmentReviewScreen({super.key, required this.images});

  @override
  State<FaceIdEnrollmentReviewScreen> createState() =>
      _FaceIdEnrollmentReviewScreenState();
}

class _FaceIdEnrollmentReviewScreenState
    extends State<FaceIdEnrollmentReviewScreen>
    with WidgetsBindingObserver {
  late final List<String> _images = List<String>.of(widget.images);
  late final List<Uint8List> _previewBytes;
  late final List<MemoryImage> _previewProviders;
  bool _submitting = false;
  bool _privacyCurtainVisible = false;
  CancelToken? _submissionCancelToken;
  Future<void>? _previewReleaseFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previewBytes = _images.map(_decodeImagePayload).toList(growable: true);
    _previewProviders = _previewBytes
        .map((bytes) => MemoryImage(bytes))
        .toList(growable: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldHide =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (mounted && shouldHide != _privacyCurtainVisible) {
      setState(() => _privacyCurtainVisible = shouldHide);
    }
  }

  Uint8List _decodeImagePayload(String image) {
    final comma = image.indexOf(',');
    final rawBase64 = comma >= 0 ? image.substring(comma + 1) : image;
    return base64Decode(rawBase64);
  }

  Future<void> _retake(int index) async {
    if (_submitting) return;
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => FaceIdPermissionScreen(
          request: FaceCaptureRequest.retake(FaceCapturePose.values[index]),
        ),
      ),
    );
    if (result == null) return;
    if (result.length != 1) {
      result.clear();
      return;
    }
    if (!mounted) {
      result.clear();
      return;
    }
    final newBytes = _decodeImagePayload(result.single);
    final oldProvider = _previewProviders[index];
    final oldBytes = _previewBytes[index];
    await oldProvider.evict();
    oldBytes.fillRange(0, oldBytes.length, 0);
    if (!mounted) {
      newBytes.fillRange(0, newBytes.length, 0);
      result.clear();
      return;
    }
    setState(() {
      _images[index] = result.single;
      _previewBytes[index] = newBytes;
      _previewProviders[index] = MemoryImage(newBytes);
      _error = null;
    });
    result.clear();
  }

  Future<void> _submit() async {
    if (_submitting || _images.length != 5) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final cancelToken = CancelToken();
    _submissionCancelToken = cancelToken;
    try {
      await FaceIdService.registerEnrollment(
        List<String>.of(_images),
        cancelToken: cancelToken,
      );
      _images.clear();
      await _evictAndWipePreviews();
      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const FaceIdResultScreen()),
      );
      if (mounted && completed == true) Navigator.of(context).pop(true);
    } on DioException catch (exception) {
      if (exception.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      final code = ApiService.parseErrorCode(exception);
      setState(() {
        _submitting = false;
        if (code == 'FACEID_SERVICE_UNAVAILABLE') {
          _error =
              'Dịch vụ xác thực khuôn mặt đang tạm thời không khả dụng. Hãy thử lại sau.';
        } else if (code == 'FACEID_VERIFICATION_FAILED') {
          _error =
              'Các ảnh chưa đạt yêu cầu sinh trắc học. Hãy chụp lại ở nơi đủ sáng.';
        } else {
          _error = ApiService.parseDioError(exception);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Không thể hoàn tất đăng ký. Vui lòng thử lại.';
        });
      }
    } finally {
      if (identical(_submissionCancelToken, cancelToken)) {
        _submissionCancelToken = null;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _submissionCancelToken?.cancel('Enrollment review disposed.');
    _images.clear();
    unawaited(_evictAndWipePreviews());
    super.dispose();
  }

  Future<void> _evictAndWipePreviews() =>
      _previewReleaseFuture ??= _releasePreviews();

  Future<void> _releasePreviews() async {
    for (var index = 0; index < _previewProviders.length; index++) {
      await _previewProviders[index].evict();
      final bytes = _previewBytes[index];
      bytes.fillRange(0, bytes.length, 0);
    }
    _previewProviders.clear();
    _previewBytes.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Kiểm tra ảnh khuôn mặt'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đảm bảo khuôn mặt rõ và đúng hướng ở cả 5 ảnh.',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              final pose = FaceCapturePose.values[index];
                              return _ImageReviewCard(
                                image: _previewProviders[index],
                                label: pose.title,
                                onRetake: _submitting
                                    ? null
                                    : () => _retake(index),
                              );
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            FaceIdBanner(
                              message: _error!,
                              icon: Icons.error_outline_rounded,
                              color: AppColors.error,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const FaceIdBanner(
                            message:
                                'Ảnh chỉ được dùng để tạo hồ sơ sinh trắc học và được xóa khỏi bộ nhớ ứng dụng khi hoàn tất.',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: FaceIdPrimaryButton(
                      label: 'Gửi 5 ảnh xác thực',
                      icon: Icons.verified_user_outlined,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ),
            if (_privacyCurtainVisible)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF111827),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageReviewCard extends StatelessWidget {
  final ImageProvider image;
  final String label;
  final VoidCallback? onRetake;

  const _ImageReviewCard({
    required this.image,
    required this.label,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Image(
              image: image,
              width: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'Ảnh khuôn mặt: $label',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Chụp lại $label',
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
