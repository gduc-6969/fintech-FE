import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintech_fe/core/models/transaction_flow_data.dart';
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

    test('maps a public 403 to a safe authorization message', () {
      final exception = _responseException(
        path: '/public/api/v1/auth/login',
        statusCode: 403,
        data: {'error': 'Forbidden'},
      );

      expect(
        ApiService.parseDioError(exception),
        'Bạn không thể thực hiện thao tác này.',
      );
    });

    test('maps backend error codes to localized UX messages', () {
      final exception = _responseException(
        path: '/private/api/v1/wallet/transfer',
        statusCode: 400,
        data: {'error': 'INVALID_PIN', 'message': 'Ma PIN khong dung.'},
      );

      expect(ApiService.parseErrorCode(exception), 'INVALID_PIN');
      expect(
        ApiService.parseDioError(exception),
        'Mã PIN chưa đúng. Vui lòng kiểm tra lại.',
      );
    });

    test('does not expose unknown backend codes or technical details', () {
      final exception = _responseException(
        path: '/public/api/v1/auth/login',
        statusCode: 500,
        data: {
          'error': 'DATABASE_CONNECTION_STACK_TRACE',
          'message': 'org.hibernate.JDBCConnectionException',
          'detail': 'jdbc:postgresql://internal-host:5432/fintech',
        },
      );

      final message = ApiService.parseDioError(exception);
      expect(
        message,
        'Hệ thống đang tạm thời gián đoạn. Vui lòng thử lại sau.',
      );
      expect(message, isNot(contains('DATABASE_CONNECTION_STACK_TRACE')));
      expect(message, isNot(contains('hibernate')));
      expect(message, isNot(contains('postgresql')));
    });

    test('does not expose connection exception details', () {
      final requestOptions = RequestOptions(path: '/public/api/v1/auth/login');
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
        message: 'SocketException: Failed host lookup: internal-api.local',
      );

      final message = ApiService.parseDioError(exception);
      expect(
        message,
        'Không thể kết nối đến hệ thống. Vui lòng kiểm tra kết nối mạng và thử lại.',
      );
      expect(message, isNot(contains('internal-api.local')));
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
        expect(
          ApiService.currentUserId,
          '019eb516-8f96-7d99-9aa4-6b9715e152bc',
        );
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

  group('backend Face ID verification', () {
    late HttpClientAdapter originalApiAdapter;

    setUp(() {
      ApiService.configure();
      originalApiAdapter = ApiService.httpClientAdapterForTesting;
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() async {
      ApiService.httpClientAdapterForTesting = originalApiAdapter;
      await ApiService.clearSession(notify: false);
    });

    test(
      'sends transfer context and bearer token to the fintech API',
      () async {
        await _loginTestUser();
        final token = ApiService.authToken;
        final adapter = _RecordingAdapter({
          'faceIdToken': 'server-one-time-token',
          'expiresInSeconds': 300,
        });
        ApiService.httpClientAdapterForTesting = adapter;

        final frames = List<String>.generate(5, (index) => 'frame-$index');
        final result = await ApiService.verifyFaceId(
          images: frames,
          transaction: _transferTransaction(),
        );

        expect(result['faceIdToken'], 'server-one-time-token');
        expect(adapter.requestPaths, ['/private/api/v1/wallet/faceid/verify']);
        expect(adapter.authorizationHeaders, ['Bearer $token']);
        expect(adapter.requestData.single, {
          'images': frames,
          'activeLivenessPassed': false,
          'correlationId': 'wallet-transfer-test-id',
          'referenceCode': 'wallet-transfer-test-id',
          'amount': 10000000,
          'transactionType': 'TRANSFER',
        });
      },
    );

    test(
      'maps every transaction type into the backend Face ID contract',
      () async {
        await _loginTestUser();
        final adapter = _RecordingAdapter({
          'faceIdToken': 'server-one-time-token',
          'expiresInSeconds': 300,
        });
        ApiService.httpClientAdapterForTesting = adapter;
        final frames = List<String>.generate(5, (index) => 'frame-$index');

        for (final entry in const <TransactionType, String>{
          TransactionType.deposit: 'TOPUP',
          TransactionType.withdraw: 'CASHOUT',
          TransactionType.transfer: 'TRANSFER',
        }.entries) {
          await ApiService.verifyFaceId(
            images: frames,
            transaction: _transaction(entry.key),
          );
        }

        expect(
          adapter.requestData.map(
            (request) => (request as Map<String, dynamic>)['transactionType'],
          ),
          ['TOPUP', 'CASHOUT', 'TRANSFER'],
        );
      },
    );

    test(
      'rejects verification without a transaction idempotency key',
      () async {
        await _loginTestUser();
        final adapter = _RecordingAdapter({
          'faceIdToken': 'server-one-time-token',
          'expiresInSeconds': 300,
        });
        ApiService.httpClientAdapterForTesting = adapter;

        await expectLater(
          ApiService.verifyFaceId(
            images: List<String>.filled(5, 'frame'),
            transaction: const TransactionFlowData(
              type: TransactionType.transfer,
              fromName: 'Sender',
              toName: 'Recipient',
              amount: 10000000,
            ),
          ),
          throwsStateError,
        );
        expect(adapter.requestPaths, isEmpty);
      },
    );

    test('sends the Face ID token with bank operations', () async {
      await _loginTestUser();
      final adapter = _RecordingAdapter({
        'id': 'transaction-id',
        'referenceCode': 'reference-code',
        'status': 'SUCCESS',
      });
      ApiService.httpClientAdapterForTesting = adapter;

      await ApiService.topUpFromBank(
        linkedBankAccountId: 'bank-account-id',
        amount: 10000000,
        idempotencyKey: 'topup-test-id',
        pin: '123456',
        faceIdToken: 'topup-face-token',
      );
      await ApiService.withdrawToBank(
        linkedBankAccountId: 'bank-account-id',
        amount: 10000001,
        idempotencyKey: 'withdraw-test-id',
        pin: '123456',
        faceIdToken: 'withdraw-face-token',
      );

      expect(adapter.requestPaths, [
        '/private/api/v1/wallet/bank-topup',
        '/private/api/v1/wallet/bank-withdraw',
      ]);
      expect(adapter.requestData, [
        {
          'linkedBankAccountId': 'bank-account-id',
          'amount': 10000000,
          'idempotencyKey': 'topup-test-id',
          'pin': '123456',
          'faceIdToken': 'topup-face-token',
        },
        {
          'linkedBankAccountId': 'bank-account-id',
          'amount': 10000001,
          'idempotencyKey': 'withdraw-test-id',
          'pin': '123456',
          'faceIdToken': 'withdraw-face-token',
        },
      ]);
    });
  });
}

TransactionFlowData _transferTransaction() => _transaction(
  TransactionType.transfer,
  idempotencyKey: 'wallet-transfer-test-id',
);

TransactionFlowData _transaction(
  TransactionType type, {
  String? idempotencyKey,
}) => TransactionFlowData(
  type: type,
  fromName: 'Sender',
  toName: 'Recipient',
  amount: 10000000,
  idempotencyKey: idempotencyKey ?? '${type.name}-face-id-test-id',
);

Future<void> _loginTestUser() async {
  final token = _futureJwt();
  ApiService.httpClientAdapterForTesting = _RecordingAdapter({
    'userId': '019eb516-8f96-7d99-9aa4-6b9715e152bc',
    'fullName': 'GIA DUC',
    'accessToken': token,
    'tokenType': 'Bearer',
  });
  await ApiService.login(phoneNumber: '0666777711', password: 'test-password');
}

String _futureJwt() {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({
    'userId': '019eb516-8f96-7d99-9aa4-6b9715e152bc',
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
  final List<dynamic> requestData = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPaths.add(options.path);
    authorizationHeaders.add(options.headers['Authorization']?.toString());
    requestData.add(options.data);
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
