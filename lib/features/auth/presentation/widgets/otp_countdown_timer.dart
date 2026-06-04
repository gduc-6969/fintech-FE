import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OtpCountdownTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onTimerComplete;

  const OtpCountdownTimer({
    super.key,
    required this.totalSeconds,
    required this.onTimerComplete,
  });

  @override
  State<OtpCountdownTimer> createState() => _OtpCountdownTimerState();
}

class _OtpCountdownTimerState extends State<OtpCountdownTimer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );

    _controller.reverse(from: 1.0);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onTimerComplete();
      }
    });
  }
  
  @override
  void didUpdateWidget(OtpCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalSeconds != oldWidget.totalSeconds) {
      _controller.duration = Duration(seconds: widget.totalSeconds);
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final secondsRemaining = (_controller.value * widget.totalSeconds).ceil();
        final isWarning = secondsRemaining <= 10;
        final color = isWarning ? AppColors.error : AppColors.primaryNavy;

        return SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _controller.value,
                strokeWidth: 3,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  '$secondsRemaining',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
