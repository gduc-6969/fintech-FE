import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 56,
          transform: Matrix4.translationValues(
            0,
            _isPressed ? 0 : (_isHovered && !isDisabled ? -1 : 0),
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isDisabled
                ? LinearGradient(
                    colors: [AppColors.border, AppColors.border],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryNavy, AppColors.deepNavy],
                  ),
            boxShadow: [
              if (!isDisabled && (_isHovered || _isPressed))
                BoxShadow(
                  color: const Color(0x590F172A),
                  blurRadius: _isPressed ? 14 : 20,
                  offset: Offset(0, _isPressed ? 4 : 8),
                )
              else if (!isDisabled)
                const BoxShadow(
                  color: Color(0x590F172A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
            ],
          ),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isPressed ? 0.9 : (isDisabled ? 0.5 : 1.0),
              child: Text(
                widget.text,
                style: AppTextStyles.buttonText.copyWith(
                  color: isDisabled ? AppColors.textSecondary : AppColors.textWhite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
