import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fintech_fe/core/services/api_service.dart';
import 'package:fintech_fe/features/auth/presentation/screens/login_screen.dart';
import 'package:fintech_fe/features/auth/presentation/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLoginHttpClientAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString(
      jsonEncode({'error': 'NOT_FOUND'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLoginHttpClientAdapter mockAdapter;

  setUp(() {
    mockAdapter = MockLoginHttpClientAdapter();
    ApiService.httpClientAdapterForTesting = mockAdapter;
    ApiService.configure();
  });

  group('LoginScreen - Account Locked & OTP popup', () {
    testWidgets(
      'displays remaining attempts on INVALID_CREDENTIALS',
      (tester) async {
        mockAdapter.handler = (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'error': 'INVALID_CREDENTIALS',
              'message': 'So dien thoai hoac mat khau khong dung.',
              'details': {'remainingLoginAttempts': 3},
            }),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final phoneFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0xxxxxxxxx hoặc +84xxxxxxxxx',
        );
        final passwordFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mật khẩu của bạn',
        );

        await tester.enterText(phoneFinder, '0901234567');
        await tester.enterText(passwordFinder, 'WrongPass123!');
        await tester.tap(find.widgetWithText(GradientButton, 'Đăng nhập'));
        await tester.pumpAndSettle();

        expect(
          find.text('Số điện thoại hoặc mật khẩu không chính xác (còn 3 lần thử)'),
          findsOneWidget,
        );
        expect(find.text('MÃ OTP MỞ KHÓA *'), findsNothing);
      },
    );

    testWidgets(
      'shows OTP field when ACCOUNT_LOCKED is returned',
      (tester) async {
        mockAdapter.handler = (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'error': 'ACCOUNT_LOCKED',
              'message': 'Tai khoan bi khoa do nhap sai mat khau qua nhieu lan.',
              'details': {'remainingLoginAttempts': 0},
            }),
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final phoneFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0xxxxxxxxx hoặc +84xxxxxxxxx',
        );
        final passwordFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mật khẩu của bạn',
        );

        await tester.enterText(phoneFinder, '0901234567');
        await tester.enterText(passwordFinder, 'WrongPass123!');
        await tester.tap(find.widgetWithText(GradientButton, 'Đăng nhập'));
        await tester.pumpAndSettle();

        // OTP section should now be visible
        expect(find.text('Tài khoản đang bị tạm khóa'), findsOneWidget);
        expect(find.text('MÃ OTP MỞ KHÓA *'), findsOneWidget);
        expect(find.text('Mở khóa & Đăng nhập'), findsOneWidget);
      },
    );

    testWidgets(
      'validates 6 digits OTP requirement when account is locked',
      (tester) async {
        mockAdapter.handler = (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'error': 'ACCOUNT_LOCKED',
              'message': 'Tai khoan bi khoa.',
              'details': {'remainingLoginAttempts': 0},
            }),
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final phoneFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0xxxxxxxxx hoặc +84xxxxxxxxx',
        );
        final passwordFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mật khẩu của bạn',
        );

        await tester.enterText(phoneFinder, '0901234567');
        await tester.enterText(passwordFinder, 'Password123!');
        await tester.tap(find.widgetWithText(GradientButton, 'Đăng nhập'));
        await tester.pumpAndSettle();

        // Scroll down to make button fully visible
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
        await tester.pumpAndSettle();

        // Try submitting with empty OTP
        await tester.tap(find.widgetWithText(GradientButton, 'Mở khóa & Đăng nhập'));
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập mã OTP mở khóa'), findsOneWidget);

        // Try submitting with short OTP
        final otpFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mã OTP 6 chữ số',
        );
        await tester.enterText(otpFinder, '123');
        await tester.tap(find.widgetWithText(GradientButton, 'Mở khóa & Đăng nhập'));
        await tester.pumpAndSettle();

        expect(find.text('Mã OTP phải gồm đúng 6 chữ số'), findsOneWidget);
      },
    );

    testWidgets(
      'submits correct password and OTP to unlock and log in',
      (tester) async {
        Map<String, dynamic>? lastLoginBody;

        mockAdapter.handler = (options) {
          if (options.path.endsWith('/public/api/v1/auth/login')) {
            lastLoginBody = options.data is Map<String, dynamic>
                ? options.data as Map<String, dynamic>
                : jsonDecode(options.data.toString());

            if (lastLoginBody?['verificationCode'] == '123456') {
              return ResponseBody.fromString(
                jsonEncode({
                  'accessToken':
                      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjM0NSIsImZ1bGxOYW1lIjoiVGVzdCBVc2VyIiwiZXhwIjo5OTk5OTk5OTk5fQ.signature',
                  'userId': '12345',
                  'fullName': 'Test User',
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }

            return ResponseBody.fromString(
              jsonEncode({
                'error': 'ACCOUNT_LOCKED',
                'message': 'Tai khoan bi khoa.',
                'details': {'remainingLoginAttempts': 0},
              }),
              400,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(jsonEncode({}), 404);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final phoneFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0xxxxxxxxx hoặc +84xxxxxxxxx',
        );
        final passwordFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mật khẩu của bạn',
        );

        // Step 1: Initial failed attempt -> triggers ACCOUNT_LOCKED
        await tester.enterText(phoneFinder, '0901234567');
        await tester.enterText(passwordFinder, 'CorrectPass123!');
        await tester.tap(find.widgetWithText(GradientButton, 'Đăng nhập'));
        await tester.pumpAndSettle();

        expect(find.text('MÃ OTP MỞ KHÓA *'), findsOneWidget);

        // Step 2: Enter correct OTP and submit
        final otpFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Nhập mã OTP 6 chữ số',
        );
        await tester.enterText(otpFinder, '123456');

        // Scroll down to make button fully visible
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(GradientButton, 'Mở khóa & Đăng nhập'));
        await tester.pumpAndSettle();

        expect(lastLoginBody?['phoneNumber'], '0901234567');
        expect(lastLoginBody?['password'], 'CorrectPass123!');
        expect(lastLoginBody?['verificationCode'], '123456');
      },
    );
  });
}
