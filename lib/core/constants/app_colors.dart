import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Role - Value - Used for
  static const Color deepNavy = Color(0xFF0F172A);   // Gradient dark stop, text
  static const Color primaryNavy = Color(0xFF1E293B); // Buttons, border frame, header gradient
  static const Color midNavy = Color(0xFF243550);    // Gradient light stop
  static const Color indigo = Color(0xFF4F46E5);     // Decorative glow orbs in headers

  // Status colors
  static const Color success = Color(0xFF22C55E); // Success / Verified state
  static const Color error = Color(0xFFEF4444);   // Error borders, messages
  static const Color warning = Color(0xFFF59E0B); // Warning, locked account banner

  // Background and neutral colors
  static const Color background = Color(0xFFE2E8F0); // Outer wrapper background slate
  static const Color surface = Color(0xFFF8FAFC);    // Screen background (light slate)
  static const Color inputFill = Color(0xFFF1F5F9);  // Resting state of all inputs
  static const Color border = Color(0xFFE5E7EB);     // Borders

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF94A3B8); // Muted text
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Fallbacks to prevent build errors while refactoring
  static const Color primary = primaryNavy;
  static const Color accent = indigo;
}
