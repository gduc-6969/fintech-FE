import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fintech_fe/core/services/api_service.dart';
import 'package:fintech_fe/features/wallet/presentation/screens/scan_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FakeImagePicker extends ImagePicker {
  final XFile? imageToReturn;
  final Exception? exceptionToThrow;
  int pickImageCallCount = 0;
  ImageSource? lastSource;

  FakeImagePicker({this.imageToReturn, this.exceptionToThrow});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCallCount++;
    lastSource = source;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return imageToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.authToken = 'mock_test_token';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return {0: 1}; // PermissionStatus.granted
        }
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        }
        return null;
      },
    );
  });

  group('ScanQrScreen - Upload QR from gallery', () {
    testWidgets('renders "Tải từ thư viện" button on screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanQrScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tải từ thư viện'), findsOneWidget);
    });

    testWidgets('user cancels picking does nothing', (tester) async {
      final fakePicker = FakeImagePicker(imageToReturn: null);
      int analyzerCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScanQrScreen(
            imagePicker: fakePicker,
            imageAnalyzer: (path) async {
              analyzerCallCount++;
              return null;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Tải từ thư viện'));
      await tester.pump();

      expect(fakePicker.pickImageCallCount, 1);
      expect(fakePicker.lastSource, ImageSource.gallery);
      expect(analyzerCallCount, 0);
    });

    testWidgets('shows message when selected image has no QR code', (
      tester,
    ) async {
      final fakePicker = FakeImagePicker(imageToReturn: XFile('test_no_qr.png'));
      int analyzerCallCount = 0;
      String? analyzedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: ScanQrScreen(
            imagePicker: fakePicker,
            imageAnalyzer: (path) async {
              analyzerCallCount++;
              analyzedPath = path;
              return const BarcodeCapture(barcodes: []);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Tải từ thư viện'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakePicker.pickImageCallCount, 1);
      expect(analyzerCallCount, 1);
      expect(analyzedPath, 'test_no_qr.png');
      expect(
        find.text('Không tìm thấy mã QR trong hình ảnh đã chọn.'),
        findsOneWidget,
      );
    });

    testWidgets('shows snackbar when photo access is denied', (tester) async {
      final fakePicker = FakeImagePicker(
        exceptionToThrow: PlatformException(
          code: 'photo_access_denied',
          message: 'Access denied',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanQrScreen(
              imagePicker: fakePicker,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Tải từ thư viện'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Cần quyền truy cập thư viện ảnh để chọn mã QR.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'allows picking from gallery even when camera permission is denied',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'requestPermissions') {
              return {0: 0}; // PermissionStatus.denied
            }
            if (methodCall.method == 'checkPermissionStatus') {
              return 0; // PermissionStatus.denied
            }
            return null;
          },
        );

        final fakePicker = FakeImagePicker(imageToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: ScanQrScreen(
              imagePicker: fakePicker,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Cần quyền truy cập camera'), findsOneWidget);
        expect(find.text('Tải từ thư viện'), findsOneWidget);

        await tester.tap(find.text('Tải từ thư viện'));
        await tester.pump();

        expect(fakePicker.pickImageCallCount, 1);
        expect(fakePicker.lastSource, ImageSource.gallery);
      },
    );
  });
}
