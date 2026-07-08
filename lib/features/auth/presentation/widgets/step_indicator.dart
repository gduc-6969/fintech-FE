import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// A compact 2-step progress indicator for the registration wizard.
/// [currentStep] is 1-indexed: 1 = Account, 2 = Identity.
class StepIndicator extends StatelessWidget {
  final int currentStep;

  const StepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepCircle(stepNumber: 1, currentStep: currentStep, label: 'Tài khoản'),
        _ConnectorLine(isCompleted: currentStep > 1),
        _StepCircle(stepNumber: 2, currentStep: currentStep, label: 'Danh tính'),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int stepNumber;
  final int currentStep;
  final String label;

  const _StepCircle({
    required this.stepNumber,
    required this.currentStep,
    required this.label,
  });

  bool get _isCompleted => stepNumber < currentStep;
  bool get _isActive => stepNumber == currentStep;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = (_isCompleted || _isActive)
        ? AppColors.primaryNavy
        : Colors.transparent;
    final Color borderColor = (_isCompleted || _isActive)
        ? AppColors.primaryNavy
        : AppColors.border;
    final Color textColor = (_isCompleted || _isActive)
        ? AppColors.textWhite
        : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Center(
            child: _isCompleted
                ? Icon(Icons.check, size: 14, color: textColor)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: _isActive ? FontWeight.w600 : FontWeight.normal,
            color: (_isCompleted || _isActive)
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  final bool isCompleted;

  const _ConnectorLine({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 1.5,
        color: isCompleted ? AppColors.primaryNavy : AppColors.border,
      ),
    );
  }
}
