class Validators {
  Validators._();

  static const Map<String, String> _vietnameseLetterGroups = {
    'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴàáạảãâầấậẩẫăằắặẳẵ',
    'E': 'ÈÉẸẺẼÊỀẾỆỂỄèéẹẻẽêềếệểễ',
    'I': 'ÌÍỊỈĨìíịỉĩ',
    'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠòóọỏõôồốộổỗơờớợởỡ',
    'U': 'ÙÚỤỦŨƯỪỨỰỬỮùúụủũưừứựửữ',
    'Y': 'ỲÝỴỶỸỳýỵỷỹ',
    'D': 'Đđ',
  };

  /// Converts Vietnamese names to the registration format while preserving a
  /// single trailing space so users can continue typing the next name part.
  /// Only ASCII letters and single internal spaces are retained.
  static String normalizeRegistrationName(String input) {
    final output = StringBuffer();
    var previousWasSpace = false;

    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      final isWhitespace = RegExp(r'\s').hasMatch(character);
      if (isWhitespace) {
        if (output.isNotEmpty && !previousWasSpace) {
          output.write(' ');
          previousWasSpace = true;
        }
        continue;
      }

      final upper = character.toUpperCase();
      if (RegExp(r'^[A-Z]$').hasMatch(upper)) {
        output.write(upper);
        previousWasSpace = false;
        continue;
      }

      String? replacement;
      for (final entry in _vietnameseLetterGroups.entries) {
        if (entry.value.contains(character)) {
          replacement = entry.key;
          break;
        }
      }
      if (replacement != null) {
        output.write(replacement);
        previousWasSpace = false;
      }
    }

    return output.toString();
  }

  /// Validates phone number based on wireframe criteria:
  /// - 10 digits total for 0xxxxxxxxx (e.g. 0901234567)
  /// - Or +84 followed by 9 digits (e.g. +84901234567)
  /// - Numbers only, matching format.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final phone = value.trim();
    // Regex for 0 + 9 digits or +84 + 9 digits
    final phoneRegex = RegExp(r'^(0\d{9}|\+84\d{9})$');

    if (!phoneRegex.hasMatch(phone)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  /// Checks if password meets all specific criteria:
  /// - At least 8 characters
  /// - Contains a number
  /// - Contains an uppercase letter
  /// - Contains a special character
  static List<String> checkPasswordCriteria(String password) {
    final errors = <String>[];
    if (password.length < 8) {
      errors.add('At least 8 characters');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Contains a number');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Contains an uppercase letter');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Contains a special character');
    }
    return errors;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    final criteria = checkPasswordCriteria(value);
    if (criteria.isNotEmpty) {
      return 'Password does not meet requirements';
    }
    return null;
  }

  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Confirm password is required';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (value.startsWith(' ')) {
      return 'Họ và tên không được bắt đầu bằng khoảng trắng';
    }
    if (value.contains('  ')) {
      return 'Chỉ được dùng một khoảng trắng giữa các từ';
    }
    if (value != value.toUpperCase() ||
        !RegExp(r'^[A-Z]+(?: [A-Z]+)+$').hasMatch(value)) {
      return 'Dùng chữ IN HOA không dấu, chỉ gồm A–Z và khoảng trắng';
    }
    return null;
  }
}
