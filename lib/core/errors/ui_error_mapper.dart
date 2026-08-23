import 'package:dio/dio.dart';

/// Converts API/network failures into safe, localized messages for the UI.
///
/// Backend messages, error codes, response bodies, and exception strings must
/// never be rendered directly. They may contain implementation details and are
/// not guaranteed to be localized or suitable for customers.
class UiErrorMapper {
  UiErrorMapper._();

  static const String genericMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
  static const String sessionExpiredMessage =
      'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';

  static const Map<String, String> _messagesByCode = {
    // Authentication and registration.
    'EMAIL_ALREADY_EXISTS':
        'Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập.',
    'PHONE_NUMBER_ALREADY_EXISTS':
        'Số điện thoại này đã được đăng ký. Vui lòng dùng số khác hoặc đăng nhập.',
    'INVALID_PHONE_NUMBER':
        'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.',
    'DEFAULT_ROLE_NOT_FOUND':
        'Hệ thống đang tạm thời gián đoạn. Vui lòng thử lại sau.',
    'INVALID_CREDENTIALS':
        'Số điện thoại hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.',
    'EMAIL_NOT_VERIFIED':
        'Email chưa được xác thực. Vui lòng kiểm tra hộp thư để tiếp tục.',
    'ACCOUNT_LOCKED':
        'Tài khoản đã bị khóa. Vui lòng làm theo hướng dẫn được gửi tới email.',
    'INVALID_VERIFICATION_CODE':
        'Mã xác thực không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới.',
    'INVALID_UNLOCK_CODE':
        'Mã mở khóa không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới.',
    'INVALID_PASSWORD_RESET_CODE':
        'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng nhập lại.',
    'USER_NOT_FOUND':
        'Không tìm thấy tài khoản. Vui lòng kiểm tra lại thông tin.',
    'INVALID_TOKEN': sessionExpiredMessage,
    'UNAUTHORIZED': sessionExpiredMessage,
    'VERIFICATION_CODE_RATE_LIMITED':
        'Bạn đã yêu cầu mã quá nhiều lần. Vui lòng thử lại sau.',

    // Wallet, bank linking, and transactions.
    'WALLET_NOT_FOUND':
        'Không tìm thấy ví của bạn. Vui lòng liên hệ bộ phận hỗ trợ.',
    'BANK_NOT_FOUND':
        'Không tìm thấy ngân hàng hoặc số tài khoản. Vui lòng kiểm tra lại.',
    'BANK_ACCOUNT_NOT_FOUND': 'Không tìm thấy tài khoản ngân hàng đã liên kết.',
    'BANK_ACCOUNT_ALREADY_LINKED':
        'Tài khoản ngân hàng này đã được liên kết với một ví.',
    'INSUFFICIENT_WALLET_BALANCE': 'Số dư ví không đủ để thực hiện giao dịch.',
    'INSUFFICIENT_BANK_BALANCE':
        'Số dư tài khoản ngân hàng không đủ để thực hiện giao dịch.',
    'DUPLICATED_TRANSACTION': 'Giao dịch này đã được xử lý trước đó.',
    'IDEMPOTENCY_PAYLOAD_MISMATCH':
        'Thông tin giao dịch đã thay đổi. Vui lòng tạo giao dịch mới.',
    'TRANSACTION_NOT_FOUND': 'Không tìm thấy giao dịch.',
    'RECIPIENT_NOT_FOUND':
        'Không tìm thấy người nhận. Vui lòng kiểm tra lại số điện thoại.',
    'SELF_WALLET_TRANSFER': 'Bạn không thể chuyển tiền cho chính mình.',
    'USER_NOT_ACTIVE': 'Tài khoản chưa được kích hoạt hoặc đã bị khóa.',
    'WALLET_NOT_ACTIVE':
        'Ví của bạn hiện không hoạt động. Vui lòng liên hệ bộ phận hỗ trợ.',
    'RECIPIENT_WALLET_RISK':
        'Không thể chuyển tiền đến tài khoản này. Vui lòng chọn người nhận khác.',
    'NEW_ACCOUNT_AMOUNT_PER_TRANSACTION_EXCEEDED':
        'Tài khoản mới không thể giao dịch quá 10.000.000 ₫ mỗi lần trong 24 giờ đầu.',
    'NEW_ACCOUNT_DAILY_LIMIT_EXCEEDED':
        'Tài khoản mới đã đạt hạn mức 20.000.000 ₫ trong 24 giờ đầu.',
    'BANK_NOT_ACTIVE':
        'Ngân hàng này hiện không khả dụng. Vui lòng chọn ngân hàng khác.',
    'BANK_ACCOUNT_NOT_ACTIVE': 'Tài khoản ngân hàng này hiện không hoạt động.',
    'BANK_ACCOUNT_HAS_PENDING_TRANSACTION':
        'Không thể hủy liên kết khi đang có giao dịch chờ xử lý.',
    'WALLET_TRANSACTION_AMOUNT_LIMIT_EXCEEDED':
        'Số tiền vượt quá hạn mức giao dịch của ví.',

    // PIN and transaction OTP.
    'PIN_REQUIRED': 'Vui lòng nhập mã PIN để xác thực giao dịch.',
    'INVALID_PIN': 'Mã PIN chưa đúng. Vui lòng kiểm tra lại.',
    'PIN_LOCKED':
        'Mã PIN đã bị khóa do nhập sai quá nhiều lần. Vui lòng tạo lại mã PIN.',
    'INVALID_PIN_FORMAT': 'Mã PIN phải gồm đúng 6 chữ số.',
    'PIN_OTP_REQUIRED': 'Vui lòng yêu cầu và nhập mã OTP để tạo mã PIN.',
    'INVALID_PIN_OTP': 'Mã OTP xác nhận PIN không hợp lệ hoặc đã hết hạn.',
    'PIN_ALREADY_EXISTS': 'Bạn đã có mã PIN. Vui lòng dùng mã PIN hiện tại.',
    'TRANSACTION_OTP_REQUIRED':
        'Vui lòng yêu cầu và nhập mã OTP để xác thực giao dịch.',
    'INVALID_TRANSACTION_OTP': 'Mã OTP giao dịch không hợp lệ hoặc đã hết hạn.',

    // Face ID.
    'FACEID_REQUIRED':
        'Giao dịch này yêu cầu xác thực khuôn mặt. Vui lòng quét khuôn mặt để tiếp tục.',
    'FACEID_NOT_REGISTERED':
        'Bạn chưa thiết lập hồ sơ khuôn mặt. Vui lòng hoàn tất eKYC trước.',
    'FACEID_VERIFICATION_FAILED':
        'Khuôn mặt không khớp hoặc ảnh chưa đạt yêu cầu. Hãy thử lại ở nơi đủ sáng.',
    'FACEID_SERVICE_UNAVAILABLE':
        'Dịch vụ xác thực khuôn mặt đang tạm thời không khả dụng. Vui lòng thử lại sau.',
    'FACEID_TOKEN_INVALID':
        'Mã xác thực khuôn mặt đã hết hạn hoặc không còn hợp lệ. Vui lòng quét lại.',

    // Generic backend/gateway errors.
    'INVALID_REQUEST_PAYLOAD':
        'Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại.',
    'INVALID_ARGUMENT': 'Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại.',
    'VALIDATION_ERROR': 'Một số thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
    'DATA_INTEGRITY_VIOLATION':
        'Không thể lưu thông tin này. Vui lòng kiểm tra và thử lại.',
    'FORBIDDEN': 'Bạn không thể thực hiện thao tác này.',
    'METHOD_NOT_ALLOWED': 'Thao tác này hiện không được hỗ trợ.',
    'NOT_FOUND': 'Không tìm thấy thông tin được yêu cầu.',
    'INTERNAL_SERVER_ERROR':
        'Hệ thống đang tạm thời gián đoạn. Vui lòng thử lại sau.',
  };

  static String? errorCode(DioException exception) {
    final data = exception.response?.data;
    if (data is! Map) return null;

    final rawCode = data['error'] ?? data['code'];
    final code = rawCode?.toString().trim().toUpperCase();
    return code == null || code.isEmpty ? null : code;
  }

  static String fromDio(
    DioException exception, {
    bool isSessionExpired = false,
  }) {
    if (isSessionExpired) return sessionExpiredMessage;

    final code = errorCode(exception);
    final codeMessage = code == null ? null : _messagesByCode[code];
    if (codeMessage != null) return codeMessage;

    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Yêu cầu hết thời gian chờ. Vui lòng thử lại.',
      DioExceptionType.connectionError =>
        'Không thể kết nối đến hệ thống. Vui lòng kiểm tra kết nối mạng và thử lại.',
      DioExceptionType.badCertificate =>
        'Không thể thiết lập kết nối bảo mật. Vui lòng thử lại sau.',
      DioExceptionType.cancel => 'Yêu cầu đã được hủy.',
      DioExceptionType.badResponse => _messageForStatusCode(
        exception.response?.statusCode,
      ),
      DioExceptionType.unknown => genericMessage,
    };
  }

  static String _messageForStatusCode(int? statusCode) {
    if (statusCode == null) return genericMessage;
    if (statusCode >= 500) {
      return 'Hệ thống đang tạm thời gián đoạn. Vui lòng thử lại sau.';
    }

    return switch (statusCode) {
      400 || 422 => 'Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại.',
      401 => 'Thông tin xác thực không hợp lệ hoặc đã hết hạn.',
      403 => 'Bạn không thể thực hiện thao tác này.',
      404 => 'Không tìm thấy thông tin được yêu cầu.',
      408 => 'Yêu cầu hết thời gian chờ. Vui lòng thử lại.',
      409 => 'Yêu cầu này không thể hoàn tất. Vui lòng thử lại.',
      413 => 'Dữ liệu gửi lên quá lớn. Vui lòng thử lại.',
      429 => 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.',
      _ => genericMessage,
    };
  }
}
