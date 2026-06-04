import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/success_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String otpVerify = '/verify-phone';
  static const String success = '/success';
  static const String wallet = '/wallet';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: otpVerify,
        builder: (context, state) {
          // Pass phone number to the OTP verification screen if needed
          final phone = state.extra as String? ?? '090****567';
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: success,
        builder: (context, state) => const SuccessScreen(),
      ),
      GoRoute(
        path: wallet,
        builder: (context, state) => const WalletScreen(),
      ),
    ],
  );
}
