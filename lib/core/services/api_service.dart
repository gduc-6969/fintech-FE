import 'dart:convert';
import 'package:dio/dio.dart';

class RegisterPayload {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String? emailServerError;
  final String? phoneServerError;

  const RegisterPayload({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.emailServerError,
    this.phoneServerError,
  });

  RegisterPayload copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? emailServerError,
    String? phoneServerError,
  }) {
    return RegisterPayload(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      emailServerError: emailServerError ?? this.emailServerError,
      phoneServerError: phoneServerError ?? this.phoneServerError,
    );
  }
}

class ApiService {
  ApiService._();

  static const String _baseUrl = 'http://10.0.2.2:8082/fintech-service';
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static String? authToken;
  static String? currentUserFullName;

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

  static Future<List<dynamic>> getTransactions() async {
    final token = authToken;
    if (token == null) throw Exception('Not authenticated');
    final response = await _dio.get(
      '/private/api/v1/wallet/transactions',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic> && response.data['content'] is List) {
      return response.data['content'] as List<dynamic>;
    }
    return [];
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
      final message = parseDioError(exception).toLowerCase();
      if (message.contains('verification code')) {
        return;
      }
      rethrow;
    }
  }

  static Future<void> register({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String password,
    required String verificationCode,
  }) async {
    await _dio.post(
      '/public/api/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'verificationCode': verificationCode,
        'fullName': fullName,
        'phoneNumber': _normalizeVietnamPhoneNumber(phoneNumber),
      },
    );
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

  static String parseDioError(DioException exception) {
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please try again.';
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
