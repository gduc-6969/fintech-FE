import 'package:fintech_fe/core/services/api_service.dart';
import 'package:fintech_fe/core/utils/validators.dart';
import 'package:fintech_fe/features/auth/presentation/screens/register_identity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Citizen ID (CMND/CCCD) Validators', () {
    test('requires non-empty input', () {
      expect(Validators.validateCitizenId(null), 'Vui lòng nhập số CMND/CCCD');
      expect(Validators.validateCitizenId(''), 'Vui lòng nhập số CMND/CCCD');
      expect(Validators.validateCitizenId('   '), 'Vui lòng nhập số CMND/CCCD');
    });

    test('rejects non-numeric characters', () {
      expect(
        Validators.validateCitizenId('01234567890a'),
        'Số CMND/CCCD chỉ được chứa chữ số',
      );
      expect(
        Validators.validateCitizenId('abcdefghijkl'),
        'Số CMND/CCCD chỉ được chứa chữ số',
      );
      expect(
        Validators.validateCitizenId('01234-567890'),
        'Số CMND/CCCD chỉ được chứa chữ số',
      );
    });

    test('rejects length not equal to 12 digits', () {
      expect(
        Validators.validateCitizenId('123456789'),
        'Số CMND/CCCD phải có đúng 12 chữ số',
      );
      expect(
        Validators.validateCitizenId('0123456789012'),
        'Số CMND/CCCD phải có đúng 12 chữ số',
      );
    });

    test('accepts exactly 12 numeric digits', () {
      expect(Validators.validateCitizenId('001202012345'), isNull);
      expect(Validators.validateCitizenId('123456789012'), isNull);
    });
  });

  group('RegisterIdentityScreen citizen ID input behavior', () {
    const step1Data = RegisterPayload(
      fullName: 'NGUYEN VAN A',
      email: 'test@example.com',
      phoneNumber: '0901234567',
      password: 'Password123!',
    );

    testWidgets('enforces digits-only and maximum 12 digits formatters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RegisterIdentityScreen(step1Data: step1Data),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the specific TextField for citizen ID
      final cccdFieldFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          return widget.decoration?.hintText == 'Số CMND / CCCD';
        }
        return false;
      });
      expect(cccdFieldFinder, findsOneWidget);

      // Enter alphanumeric and symbols with length > 12
      await tester.enterText(cccdFieldFinder, '001202abc456789012345');
      await tester.pump();

      // Only the first 12 digits should be accepted
      expect(find.text('001202456789'), findsOneWidget);
    });

    testWidgets('shows validation error when length is less than 12 digits', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RegisterIdentityScreen(step1Data: step1Data),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cccdFieldFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          return widget.decoration?.hintText == 'Số CMND / CCCD';
        }
        return false;
      });

      // Enter 9 digits and trigger validation via typing
      await tester.enterText(cccdFieldFinder, '123456789');
      await tester.pump();

      expect(find.text('Số CMND/CCCD phải có đúng 12 chữ số'), findsOneWidget);
    });
  });
}
