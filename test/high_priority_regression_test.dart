import 'package:fintech_fe/core/router/app_router.dart';
import 'package:fintech_fe/core/theme/app_theme.dart';
import 'package:fintech_fe/features/auth/presentation/screens/success_screen.dart';
import 'package:fintech_fe/features/bank_link/presentation/screens/bank_link_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wallet_api.dart';

void main() {
  testWidgets('wallet bank-management actions open the bank accounts tab', (
    tester,
  ) async {
    final mockSession = MockWalletApiSession.install();
    addTearDown(mockSession.restore);

    AppRouter.router.go(AppRouter.wallet);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Quản lý'));
    await _settle(tester);
    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
    expect(find.text('Thêm'), findsOneWidget);

    AppRouter.router.go(AppRouter.wallet);
    await _settle(tester);
    await tester.tap(find.text('Hồ sơ'));
    await _settle(tester);
    await tester.tap(find.text('Tài khoản ngân hàng'));
    await _settle(tester);
    expect(find.text('Thêm'), findsOneWidget);
  });

  testWidgets('pending transaction polling stops after six attempts', (
    tester,
  ) async {
    final mockSession = MockWalletApiSession.install(
      state: MockWalletApiState.pending,
    );
    addTearDown(mockSession.restore);

    AppRouter.router.go(AppRouter.wallet);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
    await _settle(tester);

    final initialTransactionRequests = mockSession.adapter.requestPaths
        .where((path) => path == '/private/api/v1/wallet/transactions/search')
        .length;
    final initialWalletRequests = mockSession.adapter.requestPaths
        .where((path) => path == '/private/api/v1/wallet')
        .length;

    for (var attempt = 0; attempt < 8; attempt++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }

    final transactionRequests = mockSession.adapter.requestPaths
        .where((path) => path == '/private/api/v1/wallet/transactions/search')
        .length;
    final walletRequests = mockSession.adapter.requestPaths
        .where((path) => path == '/private/api/v1/wallet')
        .length;

    expect(transactionRequests, initialTransactionRequests + 6);
    expect(walletRequests, initialWalletRequests + 6);
  });

  testWidgets('bank-link success displays the provided account holder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BankLinkSuccessScreen(
          bank: <String, dynamic>{
            'code': 'VCB',
            'name': 'Vietcombank',
            'color': const Color(0xFF007B40),
            'holder': 'NGUYEN MINH ANH',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('NGUYEN MINH ANH'), findsOneWidget);
    expect(find.text('LE HAI DUC'), findsNothing);
  });

  testWidgets('registration success does not navigate back to OTP', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SuccessScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Đi đến Đăng nhập'), findsOneWidget);
    expect(find.text('Quay lại màn hình OTP'), findsNothing);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 750));
  await tester.pumpAndSettle();
}
