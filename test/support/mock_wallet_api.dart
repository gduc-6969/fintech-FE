import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fintech_fe/core/services/api_service.dart';

enum MockWalletApiState { loaded, empty, pending, error }

class MockWalletApiSession {
  MockWalletApiSession._({
    required this.adapter,
    required HttpClientAdapter previousAdapter,
    required String? previousToken,
    required String? previousUserId,
    required String? previousFullName,
    required String? previousPhoneNumber,
  }) : _previousAdapter = previousAdapter,
       _previousToken = previousToken,
       _previousUserId = previousUserId,
       _previousFullName = previousFullName,
       _previousPhoneNumber = previousPhoneNumber;

  final MockWalletApiAdapter adapter;
  final HttpClientAdapter _previousAdapter;
  final String? _previousToken;
  final String? _previousUserId;
  final String? _previousFullName;
  final String? _previousPhoneNumber;

  static MockWalletApiSession install({
    MockWalletApiState state = MockWalletApiState.loaded,
  }) {
    final previousAdapter = ApiService.httpClientAdapterForTesting;
    final adapter = MockWalletApiAdapter(state: state);
    final session = MockWalletApiSession._(
      adapter: adapter,
      previousAdapter: previousAdapter,
      previousToken: ApiService.authToken,
      previousUserId: ApiService.currentUserId,
      previousFullName: ApiService.currentUserFullName,
      previousPhoneNumber: ApiService.currentUserPhoneNumber,
    );

    ApiService.httpClientAdapterForTesting = adapter;
    ApiService.authToken = _futureJwt();
    ApiService.currentUserId = 'mock-user-001';
    ApiService.currentUserFullName = 'Nguyen Minh Anh';
    ApiService.currentUserPhoneNumber = '0912345678';
    return session;
  }

  void restore() {
    ApiService.httpClientAdapterForTesting = _previousAdapter;
    ApiService.authToken = _previousToken;
    ApiService.currentUserId = _previousUserId;
    ApiService.currentUserFullName = _previousFullName;
    ApiService.currentUserPhoneNumber = _previousPhoneNumber;
  }
}

class MockWalletApiAdapter implements HttpClientAdapter {
  MockWalletApiAdapter({this.state = MockWalletApiState.loaded});

  final MockWalletApiState state;
  final List<String> requestPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPaths.add(options.path);
    if (state == MockWalletApiState.error &&
        _isStatefulEndpoint(options.path)) {
      return _jsonResponse(<String, dynamic>{
        'message': 'Dịch vụ tạm thời không khả dụng',
      }, statusCode: 503);
    }

    final data = switch (options.path) {
      '/private/api/v1/wallet' => <String, dynamic>{
        'id': 'mock-wallet-001',
        'availableBalance': state == MockWalletApiState.empty ? 0 : 12850000,
        'currency': 'VND',
      },
      '/private/api/v1/wallet/transactions/search' => <String, dynamic>{
        'content': switch (state) {
          MockWalletApiState.empty => <dynamic>[],
          MockWalletApiState.pending => _pendingTransactions,
          _ => _transactions,
        },
      },
      '/private/api/v1/wallet/bank-accounts' =>
        state == MockWalletApiState.empty ? <dynamic>[] : _linkedBanks,
      '/private/api/v1/wallet/banks' => _banks,
      '/private/api/v1/wallet/topup-methods' => <String>['VCB', 'TCB', 'MB'],
      '/private/api/v1/auth/me' => _profile,
      '/private/api/v1/wallet/pin/status' => <String, dynamic>{'hasPin': true},
      '/private/api/v1/wallet/qr' => <String, dynamic>{
        'qrBase64': '',
        'phoneNumber': '0912345678',
        'fullName': 'Nguyen Minh Anh',
      },
      '/private/api/v1/wallet/transfer/recipient' => <String, dynamic>{
        'phoneNumber':
            options.queryParameters['recipientPhoneNumber'] ?? '0987654321',
        'fullName': 'Tran Gia Bao',
      },
      '/private/api/v1/wallet/qr/decode' => <String, dynamic>{
        'phoneNumber': '0987654321',
        'fullName': 'Tran Gia Bao',
      },
      _ => <String, dynamic>{'success': true},
    };

    return _jsonResponse(data);
  }

  bool _isStatefulEndpoint(String path) =>
      path == '/private/api/v1/wallet' ||
      path == '/private/api/v1/wallet/transactions/search' ||
      path == '/private/api/v1/wallet/bank-accounts' ||
      path == '/private/api/v1/wallet/topup-methods';

  ResponseBody _jsonResponse(Object? data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _futureJwt() {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final header = encode(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode(<String, dynamic>{
    'userId': 'mock-user-001',
    'fullName': 'Nguyen Minh Anh',
    'exp':
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 8))
            .millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.test-signature';
}

const List<Map<String, dynamic>> _linkedBanks = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'mock-bank-vcb',
    'bankCode': 'VCB',
    'bankName': 'Vietcombank',
    'accountNumber': '0123456789',
    'accountHolderName': 'NGUYEN MINH ANH',
  },
  <String, dynamic>{
    'id': 'mock-bank-tcb',
    'bankCode': 'TCB',
    'bankName': 'Techcombank',
    'accountNumber': '19031234567890',
    'accountHolderName': 'NGUYEN MINH ANH',
  },
];

const List<Map<String, dynamic>> _banks = <Map<String, dynamic>>[
  <String, dynamic>{'id': '1', 'code': 'VCB', 'name': 'Vietcombank'},
  <String, dynamic>{'id': '2', 'code': 'TCB', 'name': 'Techcombank'},
  <String, dynamic>{'id': '3', 'code': 'MB', 'name': 'MBBank'},
];

const List<Map<String, dynamic>> _transactions = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'mock-tx-001',
    'type': 'BANK_TO_WALLET',
    'status': 'SUCCESS',
    'amount': 2000000,
    'updatedAt': '2026-08-20T09:30:00Z',
    'createdAt': '2026-08-20T09:30:00Z',
    'referenceCode': 'MOCK-DEPOSIT-001',
  },
  <String, dynamic>{
    'id': 'mock-tx-002',
    'type': 'WALLET_TRANSFER_OUT',
    'status': 'SUCCESS',
    'amount': 750000,
    'updatedAt': '2026-08-19T14:15:00Z',
    'createdAt': '2026-08-19T14:15:00Z',
    'counterpartyFullName': 'Tran Gia Bao',
    'counterpartyPhoneNumber': '0987654321',
    'referenceCode': 'MOCK-TRANSFER-001',
  },
];

const List<Map<String, dynamic>> _pendingTransactions = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'mock-tx-pending-001',
    'type': 'WALLET_TRANSFER_OUT',
    'status': 'PENDING',
    'amount': 750000,
    'updatedAt': '2026-08-23T09:30:00Z',
    'createdAt': '2026-08-23T09:30:00Z',
    'referenceCode': 'MOCK-PENDING-001',
  },
];

const Map<String, dynamic> _profile = <String, dynamic>{
  'id': 'mock-user-001',
  'fullName': 'Nguyen Minh Anh',
  'phoneNumber': '0912345678',
  'email': 'minh.anh@example.com',
  'identityNumber': '012345678901',
  'dob': '1998-06-15',
  'hometown': 'Ho Chi Minh City',
};
