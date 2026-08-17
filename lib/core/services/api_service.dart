import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction_flow_data.dart';

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

  static const String _invalidSessionMessage =
      'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
  static const String _demoHttpBaseUrl = 'http://13.213.32.9/fintech-service';
  static const String _demoFaceIdBaseUrl = 'http://47.129.142.105:5001';
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _demoHttpBaseUrl,
  );
  static const String _faceIdBaseUrl = String.fromEnvironment(
    'FACEID_API_BASE_URL',
    defaultValue: _demoFaceIdBaseUrl,
  );
  static const bool _useDirectFaceId = bool.fromEnvironment(
    'USE_DIRECT_FACEID',
    defaultValue: true,
  );
  static const bool _allowInsecureHttp = bool.fromEnvironment(
    'ALLOW_INSECURE_HTTP',
    defaultValue: false,
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenStorageKey = 'auth_access_token';
  static const String _phoneStorageKey = 'auth_phone_number';
  static final ValueNotifier<bool> authState = ValueNotifier<bool>(false);
  static bool _sessionInitialized = false;
  static bool _isConfigured = false;
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
  );
  static final Dio _faceIdDio = Dio(
    BaseOptions(
      baseUrl: _faceIdBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 90),
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  @visibleForTesting
  static HttpClientAdapter get httpClientAdapterForTesting =>
      _dio.httpClientAdapter;

  @visibleForTesting
  static set httpClientAdapterForTesting(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }

  @visibleForTesting
  static HttpClientAdapter get faceIdHttpClientAdapterForTesting =>
      _faceIdDio.httpClientAdapter;

  @visibleForTesting
  static set faceIdHttpClientAdapterForTesting(HttpClientAdapter adapter) {
    _faceIdDio.httpClientAdapter = adapter;
  }

  static bool get isAuthenticated =>
      authToken != null && !_isTokenExpired(authToken!);
  static bool get isSessionInitialized => _sessionInitialized;
  static bool get isDirectFaceIdDemo => _useDirectFaceId;

  static void _requireAuthentication() {
    if (!isAuthenticated) {
      throw StateError('Not authenticated');
    }
  }

  static String? authToken;
  static String? currentUserId;
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
        if (payload is Map<String, dynamic>) {
          currentUserId = payload['userId']?.toString();
          currentUserFullName = payload['fullName']?.toString();
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  static void configure() {
    if (_isConfigured) return;
    final apiUri = Uri.tryParse(_baseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      throw StateError(
        'Invalid API_BASE_URL. Pass a complete URL with --dart-define.',
      );
    }
    final isApprovedHttpDemo =
        _allowInsecureHttp && _baseUrl == _demoHttpBaseUrl;
    if (kReleaseMode && apiUri.scheme != 'https' && !isApprovedHttpDemo) {
      throw StateError(
        'Release builds require HTTPS unless the approved HTTP demo endpoint '
        'is enabled explicitly.',
      );
    }
    final faceIdUri = Uri.tryParse(_faceIdBaseUrl);
    if (_useDirectFaceId &&
        (faceIdUri == null || !faceIdUri.hasScheme || faceIdUri.host.isEmpty)) {
      throw StateError(
        'Invalid FACEID_API_BASE_URL. Pass a complete URL with --dart-define.',
      );
    }
    final isApprovedFaceIdHttpDemo =
        _allowInsecureHttp && _faceIdBaseUrl == _demoFaceIdBaseUrl;
    if (_useDirectFaceId &&
        kReleaseMode &&
        faceIdUri!.scheme != 'https' &&
        !isApprovedFaceIdHttpDemo) {
      throw StateError(
        'Direct Face ID release builds require HTTPS unless the approved '
        'HTTP demo endpoint is enabled explicitly.',
      );
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/private/')) {
            final token = authToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (_isPrivateAuthenticationFailure(error)) {
            await clearSession();
          }
          handler.next(error);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
          logPrint: (object) => debugPrint('[API] $object'),
        ),
      );
    }
    _isConfigured = true;
  }

  static Future<void> initializeSession() async {
    configure();
    try {
      final token = await _secureStorage.read(key: _tokenStorageKey);
      if (token != null && !_isTokenExpired(token)) {
        _parseAndSetToken(token);
        currentUserPhoneNumber = await _secureStorage.read(
          key: _phoneStorageKey,
        );
      } else {
        await clearSession(notify: false);
      }
    } catch (_) {
      authToken = null;
      currentUserId = null;
      currentUserFullName = null;
      currentUserPhoneNumber = null;
    } finally {
      _sessionInitialized = true;
      authState.value = isAuthenticated;
    }
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiry = payload is Map<String, dynamic> ? payload['exp'] : null;
      if (expiry is! num) return true;
      return DateTime.fromMillisecondsSinceEpoch(
        expiry.toInt() * 1000,
        isUtc: true,
      ).isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  static Future<void> _persistSession(String token, String phoneNumber) async {
    await _secureStorage.write(key: _tokenStorageKey, value: token);
    await _secureStorage.write(key: _phoneStorageKey, value: phoneNumber);
    authState.value = true;
  }

  static Future<void> clearSession({bool notify = true}) async {
    authToken = null;
    currentUserId = null;
    currentUserFullName = null;
    currentUserPhoneNumber = null;
    await _secureStorage.delete(key: _tokenStorageKey);
    await _secureStorage.delete(key: _phoneStorageKey);
    if (notify) authState.value = false;
  }

  static bool _isPrivateAuthenticationFailure(DioException exception) {
    final statusCode = exception.response?.statusCode;
    return exception.requestOptions.path.contains('/private/') &&
        (statusCode == 401 || statusCode == 403);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid wallet response');
  }

  static Future<List<dynamic>> getTransactions({
    String? type,
    String? status,
  }) async {
    _requireAuthentication();
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (status != null) data['status'] = status;

    final response = await _dio.post(
      '/private/api/v1/wallet/transactions/search',
      data: data,
    );
    if (response.data is Map<String, dynamic> &&
        response.data['content'] is List) {
      return response.data['content'] as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getLinkedBankAccounts() async {
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/bank-accounts');
    if (response.data is List) {
      return response.data as List<dynamic>;
    }
    return [];
  }

  static Future<List<dynamic>> getBanks() async {
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/banks');
    if (response.data is List) {
      return response.data as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>> getTransactionDetail(String id) async {
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/transactions/$id');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid transaction detail response');
  }

  static Future<List<String>> getTopUpMethods() async {
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/topup-methods');
    if (response.data is List) {
      return (response.data as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> linkBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    _requireAuthentication();
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-accounts',
      data: {'bankCode': bankCode, 'accountNumber': accountNumber},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid link response');
  }

  static Future<void> unlinkBankAccount(String id) async {
    _requireAuthentication();
    await _dio.delete('/private/api/v1/wallet/bank-accounts/$id');
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
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/auth/me');
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

  static Future<String> login({
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
              ? responseData['data']['token'] as String? ??
                    responseData['data']['accessToken'] as String?
              : null);
      final accessToken = token?.trim();
      if (accessToken != null && accessToken.isNotEmpty) {
        _parseAndSetToken(accessToken);
        if (!isAuthenticated) {
          await clearSession(notify: false);
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: _invalidSessionMessage,
          );
        }
        currentUserPhoneNumber = _normalizeVietnamPhoneNumber(phoneNumber);
        final responseUserId = responseData['userId']?.toString().trim();
        if (responseUserId != null && responseUserId.isNotEmpty) {
          currentUserId = responseUserId;
        }
        final responseFullName = responseData['fullName']?.toString().trim();
        if (responseFullName != null && responseFullName.isNotEmpty) {
          currentUserFullName = responseFullName;
        }
        await _persistSession(accessToken, currentUserPhoneNumber!);
        return accessToken;
      }
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Login response did not include an access token.',
    );
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
    try {
      if (token != null) {
        await _dio.post('/private/api/v1/auth/logout');
      }
    } catch (_) {
      // Local credentials must still be removed when the server is unreachable.
    } finally {
      await clearSession();
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
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/pin/status');
    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['hasPin'] == true;
    }
    return false;
  }

  static Future<void> requestCreatePin(String pin) async {
    _requireAuthentication();
    await _dio.post('/private/api/v1/wallet/pin/request', data: {'pin': pin});
  }

  static Future<void> confirmCreatePin(String otpCode) async {
    _requireAuthentication();
    await _dio.post(
      '/private/api/v1/wallet/pin/confirm',
      data: {'otpCode': otpCode},
    );
  }

  static Future<void> requestTransactionOtp() async {
    _requireAuthentication();
    await _dio.post('/private/api/v1/wallet/pin/request-transaction-otp');
  }

  // ── Face ID / remote facial verification ──

  static String _requireFaceIdUserId() {
    _requireAuthentication();
    final userId = currentUserId?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('Authenticated session does not contain a user ID.');
    }
    return userId;
  }

  static DioException _normalizeDirectFaceIdError(
    DioException exception, {
    required String fallbackCode,
  }) {
    final response = exception.response;
    final responseData = response?.data;
    final data = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    final message = data['message']?.toString() ?? exception.message;
    final lowerMessage = message?.toLowerCase() ?? '';
    final errorCode = response == null
        ? 'FACEID_SERVICE_UNAVAILABLE'
        : lowerMessage.contains('chưa đăng ký') ||
              lowerMessage.contains('chua dang ky')
        ? 'FACEID_NOT_REGISTERED'
        : fallbackCode;
    data['error'] = errorCode;
    data['message'] = message ?? 'Face ID request failed.';
    return DioException(
      requestOptions: exception.requestOptions,
      response: Response<dynamic>(
        requestOptions: exception.requestOptions,
        statusCode: response?.statusCode ?? 503,
        statusMessage: response?.statusMessage,
        headers: response?.headers,
        data: data,
      ),
      type: exception.type,
      error: exception.error,
      message: data['message']?.toString(),
    );
  }

  static DioException _directFaceIdRejection(
    Response<dynamic> response, {
    required String fallbackCode,
  }) {
    return _normalizeDirectFaceIdError(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ),
      fallbackCode: fallbackCode,
    );
  }

  static Future<Map<String, dynamic>> registerFaceIdEnrollment({
    required List<String> images,
  }) async {
    if (_useDirectFaceId) {
      final userId = _requireFaceIdUserId();
      try {
        final response = await _faceIdDio.post(
          '/api/register_ekyc',
          data: {'user_id': userId, 'images': images},
        );
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true) {
            return {...data, 'directDemo': true};
          }
          throw _directFaceIdRejection(
            response,
            fallbackCode: 'FACEID_VERIFICATION_FAILED',
          );
        }
        throw Exception('Invalid direct Face ID enrollment response');
      } on DioException catch (exception) {
        if (exception.response?.data is Map<String, dynamic> &&
            (exception.response!.data as Map<String, dynamic>)['error'] !=
                null) {
          rethrow;
        }
        throw _normalizeDirectFaceIdError(
          exception,
          fallbackCode: 'FACEID_VERIFICATION_FAILED',
        );
      }
    }

    _requireAuthentication();
    final response = await _dio.post(
      '/private/api/v1/wallet/faceid/register-ekyc',
      data: {'images': images},
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid Face ID enrollment response');
  }

  static Future<Map<String, dynamic>> verifyFaceId({
    required List<String> images,
  }) async {
    if (_useDirectFaceId) {
      final userId = _requireFaceIdUserId();
      try {
        final response = await _faceIdDio.post(
          '/api/verify_faceid',
          data: {
            'user_id': userId,
            'images': images,
            'active_liveness_passed': false,
          },
        );
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final transactionId = data['tx_id']?.toString();
          if (data['success'] == true &&
              transactionId != null &&
              transactionId.isNotEmpty) {
            return {
              ...data,
              'faceIdToken': transactionId,
              'expiresInSeconds': 300,
              'directDemo': true,
            };
          }
          throw _directFaceIdRejection(
            response,
            fallbackCode: 'FACEID_VERIFICATION_FAILED',
          );
        }
        throw Exception('Invalid direct Face ID verification response');
      } on DioException catch (exception) {
        if (exception.response?.data is Map<String, dynamic> &&
            (exception.response!.data as Map<String, dynamic>)['error'] !=
                null) {
          rethrow;
        }
        throw _normalizeDirectFaceIdError(
          exception,
          fallbackCode: 'FACEID_VERIFICATION_FAILED',
        );
      }
    }

    _requireAuthentication();
    final response = await _dio.post(
      '/private/api/v1/wallet/faceid/verify',
      data: {
        'images': images,
        // The app does not currently implement a trusted active-liveness test.
        'activeLivenessPassed': false,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid Face ID verification response');
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

  static Future<TransactionSubmissionResult> topUpFromBank({
    required String linkedBankAccountId,
    required int amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
    String? faceIdToken,
  }) async {
    _requireAuthentication();
    final body = <String, dynamic>{
      'linkedBankAccountId': linkedBankAccountId,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    if (faceIdToken != null) body['faceIdToken'] = faceIdToken;
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-topup',
      data: body,
    );
    if (response.data is Map<String, dynamic>) {
      return TransactionSubmissionResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw Exception('Invalid top-up response');
  }

  static Future<TransactionSubmissionResult> withdrawToBank({
    required String linkedBankAccountId,
    required int amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
    String? faceIdToken,
  }) async {
    _requireAuthentication();
    final body = <String, dynamic>{
      'linkedBankAccountId': linkedBankAccountId,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    if (faceIdToken != null) body['faceIdToken'] = faceIdToken;
    final response = await _dio.post(
      '/private/api/v1/wallet/bank-withdraw',
      data: body,
    );
    if (response.data is Map<String, dynamic>) {
      return TransactionSubmissionResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw Exception('Invalid withdraw response');
  }

  static Future<TransactionSubmissionResult> transferToWallet({
    required String recipientPhoneNumber,
    required int amount,
    required String idempotencyKey,
    String? pin,
    String? otpCode,
    String? faceIdToken,
  }) async {
    _requireAuthentication();
    final body = <String, dynamic>{
      'recipientPhoneNumber': _normalizeVietnamPhoneNumber(
        recipientPhoneNumber,
      ),
      'amount': amount,
      'idempotencyKey': idempotencyKey,
    };
    if (pin != null) body['pin'] = pin;
    if (otpCode != null) body['otpCode'] = otpCode;
    if (faceIdToken != null) body['faceIdToken'] = faceIdToken;
    final response = await _dio.post(
      '/private/api/v1/wallet/transfer',
      data: body,
    );
    if (response.data is Map<String, dynamic>) {
      return TransactionSubmissionResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw Exception('Invalid transfer response');
  }

  static Future<String> lookupTransferRecipient({
    required String recipientPhoneNumber,
  }) async {
    _requireAuthentication();
    final response = await _dio.get(
      '/private/api/v1/wallet/transfer/recipient',
      queryParameters: {
        'recipientPhoneNumber': _normalizeVietnamPhoneNumber(
          recipientPhoneNumber,
        ),
      },
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
    _requireAuthentication();
    final response = await _dio.get('/private/api/v1/wallet/qr');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Invalid QR response');
  }

  /// Decode a raw QR content string to get recipient info.
  /// [qrContent] is the raw text read from scanning a QR code.
  /// Returns a map with keys: phoneNumber, fullName.
  static Future<Map<String, dynamic>> decodeWalletQr(String qrContent) async {
    _requireAuthentication();
    final response = await _dio.post(
      '/private/api/v1/wallet/qr/decode',
      data: {'qrContent': qrContent},
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

    if (_isPrivateAuthenticationFailure(exception)) {
      return _invalidSessionMessage;
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
