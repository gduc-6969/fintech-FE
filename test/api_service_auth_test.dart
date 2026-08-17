import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintech_fe/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('API authentication errors', () {
    test('maps a private 401 to an expired-session message', () {
      final exception = _responseException(
        path: '/private/api/v1/wallet',
        statusCode: 401,
      );

      expect(
        ApiService.parseDioError(exception),
        'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
      );
    });

    test('maps the backend private 403 to an expired-session message', () {
      final exception = _responseException(
        path: '/private/api/v1/auth/me',
        statusCode: 403,
        data: {
          'status': 403,
          'error': 'Forbidden',
          'path': '/fintech-service/private/api/v1/auth/me',
        },
      );

      expect(
        ApiService.parseDioError(exception),
        'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
      );
    });

    test('does not reinterpret a public 403 as an expired session', () {
      final exception = _responseException(
        path: '/public/api/v1/auth/login',
        statusCode: 403,
        data: {'error': 'Forbidden'},
      );

      expect(ApiService.parseDioError(exception), 'Forbidden');
    });
  });

  group('API login', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      ApiService.configure();
      originalAdapter = ApiService.httpClientAdapterForTesting;
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() async {
      ApiService.httpClientAdapterForTesting = originalAdapter;
      await ApiService.clearSession(notify: false);
    });

    test(
      'persists the login response without requiring a profile request',
      () async {
        final token = _futureJwt();
        final adapter = _RecordingAdapter({
          'userId': '019eb516-8f96-7d99-9aa4-6b9715e152bc',
          'fullName': 'GIA DUC',
          'accessToken': token,
          'tokenType': 'Bearer',
        });
        ApiService.httpClientAdapterForTesting = adapter;

        final result = await ApiService.login(
          phoneNumber: '0666777711',
          password: 'test-password',
        );

        expect(result, token);
        expect(ApiService.isAuthenticated, isTrue);
        expect(ApiService.currentUserFullName, 'GIA DUC');
        expect(ApiService.currentUserPhoneNumber, '0666777711');
        expect(adapter.requestPaths, ['/public/api/v1/auth/login']);
        expect(adapter.authorizationHeaders, [isNull]);

        await ApiService.getWallet();

        expect(adapter.requestPaths, [
          '/public/api/v1/auth/login',
          '/private/api/v1/wallet',
        ]);
        expect(adapter.authorizationHeaders, [isNull, 'Bearer $token']);
      },
    );
  });
}

String _futureJwt() {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({
    'fullName': 'JWT NAME',
    'exp':
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.test-signature';
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseData);

  final Map<String, dynamic> responseData;
  final List<String> requestPaths = [];
  final List<String?> authorizationHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPaths.add(options.path);
    authorizationHeaders.add(options.headers['Authorization']?.toString());
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException _responseException({
  required String path,
  required int statusCode,
  Map<String, dynamic>? data,
}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}
