import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;
  final Widget? headerContent;
  final double headerHeight;

  const AuthLayout({
    super.key,
    required this.child,
    this.headerContent,
    this.headerHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Container(
          color: AppColors.surface,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Hero Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryNavy, AppColors.deepNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative orb
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.indigo.withOpacity(0.15),
                          ),
                        ),
                      ),
                      if (headerContent != null)
                        SafeArea(bottom: false, child: headerContent!),
                    ],
                  ),
                ),
              ),

              // Floating Card
              Positioned.fill(
                top: headerHeight - 24,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: AppColors.surface),
                    child: child,
                  ),
                ),
              ),

              // Notch (only on mobile)
              if (!kIsWeb)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
