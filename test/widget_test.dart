import 'package:fintech_fe/features/face_id/presentation/screens/face_id_enrollment_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Face ID enrollment requires explicit consent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FaceIdEnrollmentIntroScreen()),
    );

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tôi đồng ý — Tiếp tục'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tôi đồng ý — Tiếp tục'),
    );
    expect(enabledButton.onPressed, isNotNull);
  });
}
