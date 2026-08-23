import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

// ── Constants shared by the overlay painter and MobileScanner scanWindow ──────
const double _kReticleSize = 270.0;
const double _kReticleRadius = 8.0;

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  MobileScannerController? _controller;

  // Permission state
  bool _cameraPermissionGranted = false;
  bool _permissionChecked = false;

  // Scan state
  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _torchOn = false;

  // Scan-window rect in screen pixels — computed once layout is known
  Rect? _scanWindow;

  // Animated scan-line
  late AnimationController _scanAnimCtrl;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanAnimCtrl, curve: Curves.linear),
    );
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _cameraPermissionGranted = true;
        _permissionChecked = true;
      });
      _initController();
    } else {
      setState(() {
        _cameraPermissionGranted = false;
        _permissionChecked = true;
      });
    }
  }

  void _initController() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  // ── Scan window: compute Rect from screen size ─────────────────────────────

  Rect _computeScanWindow(Size screenSize) {
    final cx = screenSize.width / 2;
    // Place the reticle slightly above center vertically
    final cy = screenSize.height * 0.42;
    final half = _kReticleSize / 2;
    return Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half);
  }

  // ── Detect ─────────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _controller?.stop();
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });
    _decodeQrContent(raw);
  }

  Future<void> _decodeQrContent(String rawContent) async {
    try {
      final result = await ApiService.decodeWalletQr(rawContent);
      if (!mounted) return;

      final phoneNumber = result['phoneNumber'] as String?;
      final fullName = result['fullName'] as String?;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        _showInvalidCodeSheet();
        return;
      }

      // Push transfer screen — when user pops back, reset scanner
      await context.push('/transfer', extra: {
        'initialPhone': phoneNumber,
        'initialRecipientName': fullName ?? '',
      });

      // ── FIX: reset scanner so user can scan again after returning ──
      if (mounted) {
        setState(() {
          _hasScanned = false;
          _isProcessing = false;
        });
        _controller?.start();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showInvalidCodeSheet(message: ApiService.parseDioError(e));
    } catch (_) {
      if (!mounted) return;
      _showInvalidCodeSheet();
    } finally {
      if (mounted && _hasScanned && _isProcessing) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInvalidCodeSheet({String? message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _InvalidCodeSheet(
        message: message,
        onRetry: () {
          Navigator.pop(ctx);
          if (mounted) {
            setState(() {
              _hasScanned = false;
              _isProcessing = false;
            });
            _controller?.start();
          }
        },
        onOpenMyQr: () {
          Navigator.pop(ctx);
          if (mounted) context.push('/my-qr');
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Compute scan window once per build — used by both overlay and MobileScanner
    _scanWindow = _computeScanWindow(size);
    final sw = _scanWindow!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera feed (restricted to scanWindow) ──
          if (_permissionChecked && _cameraPermissionGranted && _controller != null)
            MobileScanner(
              controller: _controller!,
              scanWindow: sw,
              onDetect: _onDetect,
            ),

          // ── Permission denied state ──
          if (_permissionChecked && !_cameraPermissionGranted)
            _buildPermissionDenied(),

          // ── Dark overlay with square cutout + scan-line + corners ──
          if (_cameraPermissionGranted)
            CustomPaint(
              size: size,
              painter: _ScanOverlayPainter(
                scanRect: sw,
                scanAnim: _scanAnim,
              ),
            ),

          // ── Top bar ──
          _buildTopBar(context),

          // ── Bottom actions (below reticle) ──
          if (_cameraPermissionGranted)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomActions(),
            ),

          // ── Processing spinner ──
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.indigo),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text('Đang xử lý...',
                        style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Close — circular dark pill matching reference image
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/wallet');
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Quét mã QR',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Torch toggle
              if (_cameraPermissionGranted && _controller != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () async {
                      await _controller!.toggleTorch();
                      if (mounted) setState(() => _torchOn = !_torchOn);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _torchOn ? Colors.amber : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 52),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hướng camera vào mã QR để thanh toán.',
            style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.image_outlined,
                  label: 'Tải từ thư viện',
                  onTap: () {/* gallery picker — future */},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PillButton(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Mã QR của tôi',
                  onTap: () => context.push('/my-qr'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF0F1629), Color(0xFF050810)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 20),
              Text(
                'Cần quyền truy cập camera',
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Vui lòng cấp quyền camera trong Cài đặt để quét mã QR.',
                style:
                    GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                onPressed: () async {
                  await openAppSettings();
                  if (mounted) await _requestCameraPermission();
                },
                child: Text('Mở Cài đặt',
                    style: GoogleFonts.dmSans(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay CustomPainter
// Draws:
//   1. Dark vignette covering entire screen EXCEPT the scan rectangle
//   2. Rounded rectangle border (corner brackets) around the scan area
//   3. Animated indigo scan-line inside the scan area
// ─────────────────────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final Animation<double> scanAnim;

  const _ScanOverlayPainter({
    required this.scanRect,
    required this.scanAnim,
  }) : super(repaint: scanAnim);

  static const double _bracketLen = 30.0;
  static const double _bracketStroke = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      scanRect,
      const Radius.circular(_kReticleRadius),
    );

    // 1. Dark vignette with punched-out scan window
    final vignetteP = Paint()..color = const Color(0xCC000000);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(rrect);
    final combined = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(combined, vignetteP);

    // 2. Corner brackets — white L-shapes at each corner of rrect
    _drawCornerBrackets(canvas, scanRect);

    // 3. Animated scan-line clipped to scan rect interior
    _drawScanLine(canvas, scanRect);
  }

  void _drawCornerBrackets(Canvas canvas, Rect r) {
    final bracketP = Paint()
      ..color = Colors.white
      ..strokeWidth = _bracketStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    const bl = _bracketLen;

    // Simple sharp ┌ ┐ └ ┘ brackets — two lines meeting at 90°
    void corner(Offset origin, double xDir, double yDir) {
      final path = Path()
        ..moveTo(origin.dx + xDir * bl, origin.dy)
        ..lineTo(origin.dx, origin.dy)
        ..lineTo(origin.dx, origin.dy + yDir * bl);
      canvas.drawPath(path, bracketP);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);
  }

  void _drawScanLine(Canvas canvas, Rect r) {
    final lineY = r.top + scanAnim.value * r.height;

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.indigo.withValues(alpha: 0),
          AppColors.indigo,
          AppColors.indigo.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(r.left, lineY, r.width, 3))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = AppColors.indigo.withValues(alpha: 0.45)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Clip to rounded scan rect so line doesn't bleed outside
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        r, const Radius.circular(_kReticleRadius)));
    canvas.drawLine(Offset(r.left, lineY), Offset(r.right, lineY), glowPaint);
    canvas.drawLine(Offset(r.left, lineY), Offset(r.right, lineY), linePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanRect != scanRect; // repaint driven by scanAnim via super(repaint:)
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Button
// ─────────────────────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invalid Code Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvalidCodeSheet extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onOpenMyQr;
  const _InvalidCodeSheet(
      {this.message, required this.onRetry, required this.onOpenMyQr});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_scanner,
                color: AppColors.error, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Không thể đọc mã QR',
            style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                'Mã QR không hợp lệ hoặc không phải mã thanh toán WALLI.',
            style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onOpenMyQr,
                  child: Text('Mã QR của tôi',
                      style: GoogleFonts.dmSans(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onRetry,
                  child: Text('Quét lại',
                      style: GoogleFonts.dmSans(fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
