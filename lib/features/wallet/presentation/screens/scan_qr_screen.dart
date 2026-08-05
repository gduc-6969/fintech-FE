import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  // Camera controller
  MobileScannerController? _controller;

  // Permission & camera state
  bool _cameraPermissionGranted = false;
  bool _permissionChecked = false;

  // Scan state
  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _torchOn = false;

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

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _cameraPermissionGranted = true;
        _permissionChecked = true;
      });
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
    } else {
      setState(() {
        _cameraPermissionGranted = false;
        _permissionChecked = true;
      });
    }
  }

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

      if (mounted) {
        context.push('/transfer', extra: {
          'initialPhone': phoneNumber,
          'initialRecipientName': fullName ?? '',
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showInvalidCodeSheet(message: ApiService.parseDioError(e));
    } catch (_) {
      if (!mounted) return;
      _showInvalidCodeSheet();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showInvalidCodeSheet({String? message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvalidCodeSheet(
        message: message,
        onRetry: () {
          Navigator.pop(ctx);
          setState(() => _hasScanned = false);
          _controller?.start();
        },
        onOpenMyQr: () {
          Navigator.pop(ctx);
          context.push('/my-qr');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Radial dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF0F1629), Color(0xFF050810)],
              ),
            ),
          ),

          // Camera feed / permission gate
          if (_permissionChecked)
            _cameraPermissionGranted
                ? _buildCameraLayer()
                : _buildPermissionDenied(),

          // Reticle + scan-line overlay
          if (_cameraPermissionGranted) _buildScanOverlay(context),

          // Top bar
          _buildTopBar(context),

          // Processing spinner
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_controller == null) return const SizedBox.shrink();
    return MobileScanner(controller: _controller!, onDetect: _onDetect);
  }

  Widget _buildScanOverlay(BuildContext context) {
    const reticleSize = 260.0;
    final screenW = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Vignette outside reticle
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: reticleSize,
                  height: reticleSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Animated scan-line
        Center(
          child: SizedBox(
            width: reticleSize,
            height: reticleSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: _scanAnim,
                builder: (_, __) => Stack(
                  children: [
                    Positioned(
                      top: _scanAnim.value * (reticleSize - 3),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.indigo.withOpacity(0),
                              AppColors.indigo,
                              AppColors.indigo.withOpacity(0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.indigo.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Corner-bracket reticle
        Center(
          child: SizedBox(
            width: reticleSize,
            height: reticleSize,
            child: CustomPaint(painter: _CornerBracketPainter()),
          ),
        ),

        // Helper text + bottom actions
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomActions(screenW),
        ),
      ],
    );
  }

  Widget _buildBottomActions(double screenW) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hướng camera vào mã QR để thanh toán',
            style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _PillButton(
            icon: Icons.qr_code_rounded,
            label: 'Mã QR của tôi',
            onTap: () => context.push('/my-qr'),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/wallet');
                  }
                },
              ),
              Expanded(
                child: Text(
                  'Quét mã QR',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_cameraPermissionGranted && _controller != null)
                IconButton(
                  icon: Icon(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? Colors.amber : Colors.white54,
                    size: 24,
                  ),
                  onPressed: () async {
                    await _controller!.toggleTorch();
                    if (mounted) setState(() => _torchOn = !_torchOn);
                  },
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
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
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: () async {
                await openAppSettings();
                if (mounted) await _requestCameraPermission();
              },
              child:
                  Text('Mở Cài đặt', style: GoogleFonts.dmSans(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.indigo),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text('Đang xử lý...',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─── Corner-bracket CustomPainter ─────────────────────────────────────────────

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bracketLen = 32.0;
    const radius = 20.0;
    const strokeW = 3.5;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = strokeW + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    void drawCorner(Offset origin, double xDir, double yDir) {
      final path = Path()
        ..moveTo(origin.dx + xDir * bracketLen, origin.dy)
        ..lineTo(origin.dx + xDir * radius, origin.dy)
        ..arcToPoint(
          Offset(origin.dx, origin.dy + yDir * radius),
          radius: const Radius.circular(radius),
          clockwise: xDir > 0 ? yDir > 0 : yDir < 0,
        )
        ..lineTo(origin.dx, origin.dy + yDir * bracketLen);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }

    drawCorner(Offset.zero, 1, 1);
    drawCorner(Offset(size.width, 0), -1, 1);
    drawCorner(Offset(0, size.height), 1, -1);
    drawCorner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => false;
}

// ─── Pill Button ──────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Invalid Code Sheet ────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
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
              color: AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_scanner,
                color: AppColors.error, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Không thể đọc mã QR',
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
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
