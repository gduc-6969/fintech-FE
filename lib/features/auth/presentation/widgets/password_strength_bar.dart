import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0 to 4

  const PasswordStrengthBar({
    super.key,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the color based on strength
    Color getColor() {
      if (strength <= 1) return AppColors.error; // Red
      if (strength == 2) return AppColors.warning; // Orange
      if (strength == 3) return AppColors.indigo; // Blue
      return AppColors.success; // Green
    }

    final activeColor = getColor();

    return Row(
      children: List.generate(4, (index) {
        final isActive = index < strength;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isActive ? activeColor : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
