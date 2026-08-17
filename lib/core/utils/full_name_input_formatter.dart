import 'package:flutter/services.dart';

import 'validators.dart';

class FullNameInputFormatter extends TextInputFormatter {
  const FullNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = Validators.normalizeRegistrationName(newValue.text);
    final rawSelectionEnd = newValue.selection.end.clamp(
      0,
      newValue.text.length,
    );
    final normalizedBeforeCursor = Validators.normalizeRegistrationName(
      newValue.text.substring(0, rawSelectionEnd),
    );

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(
        offset: normalizedBeforeCursor.length.clamp(0, normalized.length),
      ),
    );
  }
}
