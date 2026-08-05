import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  // QR data state
  bool _isLoading = true;
  String? _error;
  String? _qrBase64;
  String? _phoneNumber;
  String? _fullName;

  // For screenshot-to-save
  final GlobalKey _qrCardKey = GlobalKey();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    try {
      final data = await ApiService.getWalletQr();
      if (!mounted) return;
      setState(() {
        _qrBase64 = data['qrBase64'] as String?;
        _phoneNumber = data['phoneNumber'] as String?;
        _fullName = data['fullName'] as String?;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.parseDioError(e);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải mã QR. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveQrToGallery() async {
    if (_isSaving) return;

    // Request photo library permission
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cần quyền truy cập thư viện ảnh để lưu mã QR.',
            style: GoogleFonts.dmSans(),
          ),
          action: SnackBarAction(
            label: 'Cài đặt',
            onPressed: openAppSettings,
          ),
          backgroundColor: AppColors.primaryNavy,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Capture the QR card as an image
      final boundary = _qrCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render object not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: 'WALLI_QR_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;

      final saved = result['isSuccess'] == true ||
          (result['filePath'] != null &&
              result['filePath'].toString().isNotEmpty);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Đã lưu mã QR vào thư viện ảnh!'
                : 'Không thể lưu ảnh. Vui lòng thử lại.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: saved ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/wallet'),
        ),
        title: Text(
          'Mã QR của tôi',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildQrCard(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: AppColors.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              'Không thể tải mã QR',
              style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style:
                  GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadQr();
              },
              child: Text('Thử lại',
                  style: GoogleFonts.dmSans(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    // Decode the QR base64 image
    Uint8List? qrBytes;
    if (_qrBase64 != null && _qrBase64!.isNotEmpty) {
      try {
        // Strip data URI prefix if present
        String b64 = _qrBase64!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        qrBytes = base64Decode(b64);
      } catch (_) {}
    }

    final displayName = _fullName ?? ApiService.currentUserFullName ?? 'User';
    final phone = _phoneNumber ?? ApiService.currentUserPhoneNumber ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'W';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        children: [
          // Instructional label
          Text(
            'Cho người khác quét để nhận tiền ngay lập tức',
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Hero QR card (captured for screenshot save)
          RepaintBoundary(
            key: _qrCardKey,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  // Identity row
                  Row(
                    children: [
                      // Gradient avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryNavy, AppColors.indigo],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.indigo.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + phone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.dmSans(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (phone.isNotEmpty)
                              Text(
                                '@$phone',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // WALLI badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryNavy, AppColors.indigo],
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'WALLI',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // QR code image
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.border.withOpacity(0.6), width: 1.5),
                    ),
                    child: qrBytes != null
                        ? Image.memory(
                            qrBytes,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          )
                        : Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.qr_code_2_rounded,
                                size: 80, color: AppColors.textSecondary),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Account number label
                  Text(
                    'Số tài khoản',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone.isNotEmpty ? phone : '—',
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Share + Save buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryNavy, width: 1.5),
                    foregroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (phone.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép số điện thoại!',
                              style: GoogleFonts.dmSans()),
                          backgroundColor: AppColors.primaryNavy,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text('Chia sẻ', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _saveQrToGallery,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu ảnh',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

