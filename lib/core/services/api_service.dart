import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class RegisterPayload {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String? emailServerError;
  final String? phoneServerError;
  // Identity fields (Step 2)
  final String? identityNumber;
  final DateTime? dob;
  final String? hometown;

  const RegisterPayload({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.emailServerError,
    this.phoneServerError,
    this.identityNumber,
    this.dob,
    this.hometown,
  });

  RegisterPayload copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? emailServerError,
    String? phoneServerError,
    String? identityNumber,
    DateTime? dob,
    String? hometown,
  }) {
    return RegisterPayload(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      emailServerError: emailServerError ?? this.emailServerError,
      phoneServerError: phoneServerError ?? this.phoneServerError,
      identityNumber: identityNumber ?? this.identityNumber,
      dob: dob ?? this.dob,
      hometown: hometown ?? this.hometown,
    );
  }
}

class ApiService {
  ApiService._();

  static const String _baseUrl = 'http://13.213.32.9/fintech-service';
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint('[API] $object'),
      ),
    );

  static String? authToken;
  static String? currentUserFullName;
  static String? currentUserPhoneNumber;

  static void _parseAndSetToken(String token) {
    authToken = token;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payloadStr = parts[1];
        final normalized = base64Url.normalize(payloadStr);
        final payloadJson = utf8.decode(base64Url.decode(normalized));
        final payload = jsonDecode(payloadJson);
        if (payload is Map<String, dynamic> && payload.containsKey('fullName')) {
          currentUserFullName = payload['fullName'] as String?;
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid wallet response');
  }

  static Future<List<dynamic>> getTransactions({String? type, String? status}) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (status != null) data['status'] = status;
    
    final response = await _dio.post(
      '/private/api/v1/wallet/transactions/search',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic> && response.data['content'] is List) {
      return response.data['content'] as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getLinkedBankAccounts() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/bank-accounts',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is List) {
      return response.data as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getBanks() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/banks',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is List) {
      return response.data as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>> getTransactionDetail(String id) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/transactions/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid transaction detail response');
  }

  static Future<List<String>> getTopUpMethods() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/topup-methods',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is List) {
      return (response.data as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> linkBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-accounts',
      data: {'bankCode': bankCode, 'accountNumber': accountNumber},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid link response');
  }

  static Future<void> unlinkBankAccount(String id) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    await _dio.delete(
      '/private/api/v1/wallet/bank-accounts/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<void> requestOtp({
    required String email,
    required String fullName,
  }) async {
    await _dio.post(
      '/public/api/v1/auth/verify-otp-code',
      data: {'email': email, 'fullName': fullName},
    );
  }

  static Future<void> precheckRegistration({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      await register(
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        password: password,
        verificationCode: '__REGISTRATION_PRECHECK__',
      );
    } on DioException catch (exception) {
      final errorCode = parseErrorCode(exception);
      final message = parseDioError(exception).toLowerCase();
      if (errorCode == 'INVALID_VERIFICATION_CODE' ||
          message.contains('verification code') ||
          message.contains('xac thuc') ||
          message.contains('xác thực') ||
          message.contains('verification')) {
        return;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid profile response');
  }

  static Future<void> register({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String password,
    required String verificationCode,
    String? identityNumber,
    DateTime? dob,
    String? hometown,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'verificationCode': verificationCode,
      'fullName': fullName,
      'phoneNumber': _normalizeVietnamPhoneNumber(phoneNumber),
    };
    if (identityNumber != null && identityNumber.isNotEmpty) {
      body['identityNumber'] = identityNumber;
    }
    if (dob != null) {
      body['dob'] =
          '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    }
    if (hometown != null && hometown.isNotEmpty) {
      body['hometown'] = hometown;
    }
    await _dio.post('/public/api/v1/auth/register', data: body);
  }

  static Future<String?> login({
    required String phoneNumber,
    required String password,
    String? verificationCode,
  }) async {
    final data = <String, String>{
      'phoneNumber': _normalizeVietnamPhoneNumber(phoneNumber),
      'password': password,
    };
    if (verificationCode != null) {
      data['verificationCode'] = verificationCode;
    }

    final response = await _dio.post('/public/api/v1/auth/login', data: data);

    final responseData = response.data;
    if (responseData is Map<String, dynamic>) {
      final token =
          responseData['token'] as String? ??
          responseData['accessToken'] as String? ??
          (responseData['data'] is Map<String, dynamic>
              ? responseData['data']['token'] as String?
              : null);
      if (token != null) {
        _parseAndSetToken(token);
        currentUserPhoneNumber = _normalizeVietnamPhoneNumber(phoneNumber);
      }
      return token;
    }
    return null;
  }

  static Future<void> forgotPassword({required String email}) async {
    await _dio.post(
      '/public/api/v1/auth/forgot-password',
      data: {'email': email},
    );
  }

  static Future<void> resetPassword({
    required String email,
    required String verificationCode,
    required String newPassword,
  }) async {
    await _dio.post(
      '/public/api/v1/auth/reset-password',
      data: {
        'email': email,
        'verificationCode': verificationCode,
        'newPassword': newPassword,
      },
    );
  }

  static Future<void> logout() async {
    final token = authToken;
    if (token == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/private/api/v1/auth/logout'),
        message: 'No auth token available',
      );
    }

    await _dio.post(
      '/private/api/v1/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (authToken == token) {
      authToken = null;
    }
  }

  static String _normalizeVietnamPhoneNumber(String phoneNumber) {
    final trimmedPhoneNumber = phoneNumber.trim();
    if (trimmedPhoneNumber.startsWith('+84')) {
      return '0${trimmedPhoneNumber.substring(3)}';
    }
    return trimmedPhoneNumber;
  }

  // ── Transaction APIs ──────────────────────────────────────────────────────

  // ── Wallet PIN & OTP ──────────────────────────────────────────────────────

  static Future<bool> getPinStatus() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/pin/status',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['hasPin'] == true;
    }
    return false;
  }

  static Future<void> requestCreatePin(String pin) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    await _dio.post(
      '/private/api/v1/wallet/pin/request',
      data: {'pin': pin},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<void> confirmCreatePin(String otpCode) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    await _dio.post(
      '/private/api/v1/wallet/pin/confirm',
      data: {'otpCode': otpCode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<void> requestTransactionOtp() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    await _dio.post(
      '/private/api/v1/wallet/pin/request-transaction-otp',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Returns the backend error-code string (e.g. 'INVALID_PIN', 'PIN_LOCKED').
  static String? parseErrorCode(DioException exception) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['error']?.toString();
    }
    return null;
  }

  // ── Transaction APIs ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> topUpFromBank({
    required String linkedBankAccountId,
    required double amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
  }) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final body = <String, dynamic>{
      'linkedBankAccountId': linkedBankAccountId,
      'amount': amount.truncate(),
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-topup',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid top-up response');
  }

  static Future<Map<String, dynamic>> withdrawToBank({
    required String linkedBankAccountId,
    required double amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
  }) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final body = <String, dynamic>{
      'linkedBankAccountId': linkedBankAccountId,
      'amount': amount.truncate(),
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-withdraw',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid withdraw response');
  }

  static Future<Map<String, dynamic>> transferToWallet({
    required String recipientPhoneNumber,
    required double amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
  }) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final body = <String, dynamic>{
      'recipientPhoneNumber': _normalizeVietnamPhoneNumber(recipientPhoneNumber),
      'amount': amount.truncate(),
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    final response = await _dio.post(
      '/private/api/v1/wallet/transfer',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid transfer response');
  }

  static Future<String> lookupTransferRecipient({
    required String recipientPhoneNumber,
  }) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/transfer/recipient',
      queryParameters: {
        'recipientPhoneNumber': _normalizeVietnamPhoneNumber(recipientPhoneNumber),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return data['fullName']?.toString() ?? 'Wallet User';
    }
    throw Exception('Invalid recipient lookup response');
  }

  /// Fetch the current user's own QR code (PNG as Base64).
  /// Returns a map with keys: qrBase64, phoneNumber, fullName.
  static Future<Map<String, dynamic>> getWalletQr() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/qr',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid QR response');
  }

  /// Decode a raw QR content string to get recipient info.
  /// [qrContent] is the raw text read from scanning a QR code.
  /// Returns a map with keys: phoneNumber, fullName.
  static Future<Map<String, dynamic>> decodeWalletQr(String qrContent) async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.post(
      '/private/api/v1/wallet/qr/decode',
      data: {'qrContent': qrContent},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid QR decode response');
  }

  static String parseDioError(DioException exception) {
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout) {
      return 'Yêu cầu hết thời gian chờ. Vui lòng thử lại.';
    }

    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['message']?.toString() ??
          responseData['error']?.toString() ??
          responseData['detail']?.toString() ??
          exception.message?.toString() ??
          'Unknown error';
    }

    return exception.message?.toString() ?? 'Unknown error';
  }
}
