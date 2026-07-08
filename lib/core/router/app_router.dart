import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
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

  static final GoRouter router = GoRouter(
    initialLocation: splash,
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
        path: '/select-bank',
        builder: (context, state) {
          final linkedCodes = state.extra as List<String>? ?? [];
          return SelectBankScreen(linkedBankCodes: linkedCodes);
        },
      ),
      GoRoute(
        path: '/account-details',
        builder: (context, state) {
          final bank = state.extra as Map<String, dynamic>;
          return AccountDetailsScreen(bank: bank);
        },
      ),
      GoRoute(
        path: '/bank-link-success',
        builder: (context, state) {
          final bank = state.extra as Map<String, dynamic>;
          return BankLinkSuccessScreen(bank: bank);
        },
      ),
      // ── Money Movement Routes ──
      GoRoute(path: '/deposit/select-bank', builder: (context, state) => const DepositSelectBankScreen()),
      GoRoute(
        path: '/deposit/amount',
        builder: (context, state) {
          final bank = state.extra as Map<String, dynamic>;
          return DepositAmountScreen(bank: bank);
        },
      ),
      GoRoute(path: '/withdraw/amount', builder: (context, state) => const WithdrawAmountScreen()),
      GoRoute(
        path: '/withdraw/select-bank',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return WithdrawSelectBankScreen(amount: (data['amount'] as num).toDouble());
        },
      ),
      GoRoute(path: '/transfer', builder: (context, state) => const TransferScreen()),
      GoRoute(
        path: '/transaction/review',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return TransactionReviewScreen(data: data);
        },
      ),
      GoRoute(
        path: '/transaction/success',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return TransactionSuccessScreen(data: data);
        },
      ),
      GoRoute(
        path: '/transaction/detail',
        builder: (context, state) {
          final tx = state.extra as Map<String, dynamic>;
          return TransactionDetailScreen(transaction: tx);
        },
      ),
    ],
  );
}