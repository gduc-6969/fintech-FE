import 'package:fintech_fe/core/utils/full_name_input_formatter.dart';
import 'package:fintech_fe/core/utils/validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registration full-name rules', () {
    test('normalizes Vietnamese accents, casing, spacing, and symbols', () {
      expect(
        Validators.normalizeRegistrationName(' Đức  Nguyễn!23'),
        'DUC NGUYEN',
      );
      expect(
        Validators.normalizeRegistrationName('Trần Thị Bích Ngọc'),
        'TRAN THI BICH NGOC',
      );
    });

    test('formatter applies the same rules to typed and pasted text', () {
      const formatter = FullNameInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '  Nguyễn  Văn Đức@',
          selection: TextSelection.collapsed(offset: 17),
        ),
      );

      expect(result.text, 'NGUYEN VAN DUC');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('accepts only a complete uppercase ASCII full name', () {
      expect(Validators.validateFullName('NGUYEN VAN DUC'), isNull);
      expect(Validators.validateFullName(' JOHN DOE'), isNotNull);
      expect(Validators.validateFullName('JOHN  DOE'), isNotNull);
      expect(Validators.validateFullName('John Doe'), isNotNull);
      expect(Validators.validateFullName('ĐỨC NGUYỄN'), isNotNull);
      expect(Validators.validateFullName('JOHN-DOE'), isNotNull);
      expect(Validators.validateFullName('JOHN'), isNotNull);
    });
  });
}
