import 'package:fintech_fe/core/router/app_router.dart';
import 'package:fintech_fe/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/mock_wallet_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full wallet and bank navigation uses mocked API data', (
    tester,
  ) async {
    final mockSession = MockWalletApiSession.install();
    addTearDown(mockSession.restore);

    // Select the authenticated route before mounting so SplashScreen never
    // starts production session initialization and clears the fake token.
    AppRouter.router.go(AppRouter.wallet);
    await tester.pumpWidget(
      MaterialApp.router(
        title: 'Fintech Wallet device test',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
      ),
    );
    await _settle(tester);

    expect(find.text('Ngân hàng liên kết'), findsOneWidget);
    expect(find.text('Vietcombank'), findsWidgets);

    await tester.tap(find.text('Nạp tiền'));
    await _settle(tester);
    expect(find.text('Nạp tiền — Chọn ngân hàng'), findsOneWidget);
    await tester.tap(find.text('Vietcombank').first);
    await _settle(tester);
    expect(find.text('Nạp tiền'), findsOneWidget);

    AppRouter.router.go(AppRouter.wallet);
    await _settle(tester);
    await tester.tap(find.text('Rút tiền'));
    await _settle(tester);
    expect(find.text('Rút tiền'), findsOneWidget);
    await tester.tap(find.text('500K'));
    await tester.pump();
    await tester.tap(find.text('Chọn ngân hàng đích'));
    await _settle(tester);
    expect(find.text('Rút tiền — Chọn ngân hàng'), findsOneWidget);
    await tester.tap(find.text('Vietcombank').first);
    await _settle(tester);
    expect(find.text('Xác nhận rút tiền'), findsOneWidget);

    AppRouter.router.go(AppRouter.wallet);
    await _settle(tester);
    await tester.tap(find.text('Chuyển tiền'));
    await _settle(tester);
    expect(find.text('SỐ ĐIỆN THOẠI NGƯỜI NHẬN'), findsOneWidget);

    AppRouter.router.go(AppRouter.wallet);
    await _settle(tester);
    await tester.tap(find.text('Lịch sử').last);
    await _settle(tester);
    expect(find.text('Lịch sử giao dịch'), findsOneWidget);

    await tester.tap(find.text('Thẻ'));
    await _settle(tester);
    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
    await tester.tap(find.text('Thêm'));
    await _settle(tester);
    expect(find.text('Chọn ngân hàng'), findsOneWidget);
    await tester.tap(find.text('MBBank'));
    await _settle(tester);
    expect(find.text('Chi tiết tài khoản'), findsOneWidget);

    AppRouter.router.go(AppRouter.wallet);
    await _settle(tester);
    await tester.tap(find.text('Hồ sơ'));
    await _settle(tester);
    expect(find.text('Xác thực khuôn mặt'), findsOneWidget);

    expect(
      mockSession.adapter.requestPaths,
      containsAll(<String>[
        '/private/api/v1/wallet',
        '/private/api/v1/wallet/transactions/search',
        '/private/api/v1/wallet/bank-accounts',
        '/private/api/v1/auth/me',
      ]),
    );
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 750));
  await tester.pumpAndSettle();
}
