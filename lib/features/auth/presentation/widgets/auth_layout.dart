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
      backgroundColor: AppColors.primaryNavy,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Hero Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryNavy, AppColors.deepNavy],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: headerContent!,
                      ),
                  ],
                ),
              ),
            ),

            // White Card Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
