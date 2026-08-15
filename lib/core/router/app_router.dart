import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/models/transaction_flow_data.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_identity_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/success_screen.dart';
import '../../features/auth/presentation/screens/password_reset_success_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/wallet/presentation/screens/deposit_select_bank_screen.dart';
import '../../features/wallet/presentation/screens/deposit_amount_screen.dart';
import '../../features/wallet/presentation/screens/withdraw_amount_screen.dart';
import '../../features/wallet/presentation/screens/withdraw_select_bank_screen.dart';
import '../../features/wallet/presentation/screens/transfer_screen.dart';
import '../../features/wallet/presentation/screens/transaction_review_screen.dart';
import '../../features/wallet/presentation/screens/transaction_success_screen.dart';
import '../../features/wallet/presentation/screens/transaction_detail_screen.dart';
import '../../features/bank_link/presentation/screens/select_bank_screen.dart';
import '../../features/bank_link/presentation/screens/account_details_screen.dart';
import '../../features/bank_link/presentation/screens/bank_link_success_screen.dart';
import '../../features/wallet/presentation/screens/verify_transaction_screen.dart';
import '../../features/wallet/presentation/screens/scan_qr_screen.dart';
import '../../features/wallet/presentation/screens/my_qr_screen.dart';
import '../../features/face_id/domain/transaction_face_authorization.dart';
import '../../features/face_id/presentation/screens/face_id_enrollment_intro_screen.dart';
import '../../features/face_id/presentation/screens/transaction_face_id_screen.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerIdentity = '/register-identity';
  static const String otpVerify = '/verify-phone';
  static const String resetPassword = '/reset-password';
  static const String resetPasswordSuccess = '/reset-password-success';
  static const String success = '/success';
  static const String wallet = '/wallet';
  static const String scanQr = '/scan-qr';
  static const String myQr = '/my-qr';
  static const String faceIdEnrollment = '/face-id/enroll';
  static const String transactionFaceId = '/transaction/face-id';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    refreshListenable: ApiService.authState,
    redirect: (context, state) {
      if (!ApiService.isSessionInitialized || state.matchedLocation == splash) {
        return null;
      }
      const publicRoutes = {
        login,
        register,
        registerIdentity,
        otpVerify,
        resetPassword,
        resetPasswordSuccess,
        success,
      };
      final isPublic = publicRoutes.contains(state.matchedLocation);
      if (!ApiService.isAuthenticated && !isPublic) return login;
      if (ApiService.isAuthenticated && state.matchedLocation == login) {
        return wallet;
      }
      return null;
    },
    errorBuilder: (context, state) => _RouteErrorScreen(
      message: state.error?.toString() ?? 'Không thể mở màn hình này.',
    ),
    routes: [
      GoRoute(path: splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: register,
        builder: (context, state) {
          final payload = state.extra;
          return RegisterScreen(
            initialData: payload is RegisterPayload ? payload : null,
          );
        },
      ),
      GoRoute(
        path: registerIdentity,
        builder: (context, state) {
          final payload = state.extra;
          if (payload is! RegisterPayload) {
            return const RegisterScreen();
          }
          return RegisterIdentityScreen(step1Data: payload);
        },
      ),
      GoRoute(
        path: otpVerify,
        builder: (context, state) {
          final payload = state.extra;
          if (payload is! RegisterPayload) {
            return const RegisterScreen();
          }
          return OtpVerificationScreen(registerData: payload);
        },
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: resetPasswordSuccess,
        builder: (context, state) => const PasswordResetSuccessScreen(),
      ),
      GoRoute(
        path: success,
        builder: (context, state) => const SuccessScreen(),
      ),
      GoRoute(path: wallet, builder: (context, state) => const WalletScreen()),
      GoRoute(
        path: faceIdEnrollment,
        builder: (context, state) => const FaceIdEnrollmentIntroScreen(),
      ),
      GoRoute(
        path: '/select-bank',
        builder: (context, state) {
          final linkedCodes = state.extra is List
              ? (state.extra as List).whereType<String>().toList()
              : <String>[];
          return SelectBankScreen(linkedBankCodes: linkedCodes);
        },
      ),
      GoRoute(
        path: '/account-details',
        builder: (context, state) {
          final bank = _mapExtra(state.extra);
          if (bank == null) return const _RouteErrorScreen();
          return AccountDetailsScreen(bank: bank);
        },
      ),
      GoRoute(
        path: '/bank-link-success',
        builder: (context, state) {
          final bank = _mapExtra(state.extra);
          if (bank == null) return const _RouteErrorScreen();
          return BankLinkSuccessScreen(bank: bank);
        },
      ),
      // ── Money Movement Routes ──
      GoRoute(
        path: '/deposit/select-bank',
        builder: (context, state) => const DepositSelectBankScreen(),
      ),
      GoRoute(
        path: '/deposit/amount',
        builder: (context, state) {
          final bank = _mapExtra(state.extra);
          if (bank == null) return const _RouteErrorScreen();
          return DepositAmountScreen(bank: bank);
        },
      ),
      GoRoute(
        path: '/withdraw/amount',
        builder: (context, state) => const WithdrawAmountScreen(),
      ),
      GoRoute(
        path: '/withdraw/select-bank',
        builder: (context, state) {
          final amount = state.extra;
          if (amount is! int) return const _RouteErrorScreen();
          return WithdrawSelectBankScreen(amount: amount);
        },
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return TransferScreen(
              initialPhone: extra['initialPhone']?.toString(),
              initialRecipientName: extra['initialRecipientName']?.toString(),
            );
          }
          return const TransferScreen();
        },
      ),
      GoRoute(
        path: '/transaction/review',
        builder: (context, state) {
          final data = state.extra;
          if (data is! TransactionFlowData) return const _RouteErrorScreen();
          return TransactionReviewScreen(data: data);
        },
      ),
      GoRoute(
        path: '/transaction/success',
        builder: (context, state) {
          final data = state.extra;
          if (data is! TransactionFlowData) return const _RouteErrorScreen();
          return TransactionSuccessScreen(data: data);
        },
      ),
      GoRoute(
        path: '/transaction/detail',
        builder: (context, state) {
          final tx = _mapExtra(state.extra);
          if (tx == null) return const _RouteErrorScreen();
          return TransactionDetailScreen(transaction: tx);
        },
      ),
      GoRoute(
        path: transactionFaceId,
        builder: (context, state) {
          final data = state.extra;
          if (data is! TransactionFlowData) return const _RouteErrorScreen();
          return TransactionFaceIdScreen(transaction: data);
        },
      ),
      GoRoute(
        path: '/transaction/verify',
        builder: (context, state) {
          final data = state.extra;
          if (data is! TransactionAuthorizationData) {
            return const _RouteErrorScreen();
          }
          return VerifyTransactionScreen(
            data: data.transaction,
            faceIdToken: data.faceIdToken,
          );
        },
      ),
      GoRoute(
        path: '/scan-qr',
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(path: '/my-qr', builder: (context, state) => const MyQrScreen()),
    ],
  );

  static Map<String, dynamic>? _mapExtra(Object? extra) {
    if (extra is Map<String, dynamic>) return extra;
    return null;
  }
}

class _RouteErrorScreen extends StatelessWidget {
  final String message;

  const _RouteErrorScreen({this.message = 'Dữ liệu điều hướng không hợp lệ.'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không thể mở trang')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(
                  ApiService.isAuthenticated
                      ? AppRouter.wallet
                      : AppRouter.login,
                ),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
