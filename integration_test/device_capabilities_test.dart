import 'package:camera/camera.dart';
import 'package:fintech_fe/features/face_id/domain/face_capture_pose.dart';
import 'package:fintech_fe/features/face_id/presentation/screens/face_capture_screen.dart';
import 'package:fintech_fe/features/wallet/presentation/screens/scan_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('camera permission denied shows QR recovery state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Cần quyền truy cập camera'), findsOneWidget);
    expect(find.text('Mở Cài đặt'), findsOneWidget);
  });

  testWidgets('granted camera initializes QR scanner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Hướng camera vào mã QR để thanh toán.'), findsOneWidget);
    expect(find.text('Cần quyền truy cập camera'), findsNothing);

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    final controller = scanner.controller;
    expect(controller, isNotNull);
    final qrController = controller!;
    for (
      var attempt = 0;
      attempt < 20 && !qrController.value.isInitialized;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(qrController.value.isInitialized, isTrue);

    // Unmount explicitly so the scanner child finishes native cleanup before
    // the parent screen disposes the shared controller.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('front camera initializes or reports hardware unavailable', (
    tester,
  ) async {
    final cameras = await availableCameras();
    final hasFrontCamera = cameras.any(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FaceCaptureScreen(request: FaceCaptureRequest.enrollment()),
      ),
    );
    expect(find.text('Bước 1/5'), findsOneWidget);
    expect(find.text('Quay mặt sang trái'), findsOneWidget);

    if (!hasFrontCamera) {
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Thiết bị không có camera trước để xác thực khuôn mặt.'),
        findsOneWidget,
      );
      return;
    }

    for (
      var attempt = 0;
      attempt < 30 && find.byType(CameraPreview).evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.textContaining('Không thể khởi tạo camera'), findsNothing);
    expect(find.textContaining('Thiết bị không có camera trước'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));
  });
}
