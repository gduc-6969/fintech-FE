import 'package:flutter/material.dart';

class FadeUpAnimation extends StatefulWidget {
  final Widget child;
  final int delayInMilliseconds;

  const FadeUpAnimation({
    super.key,
    required this.child,
    this.delayInMilliseconds = 0,
  });

  @override
  State<FadeUpAnimation> createState() => _FadeUpAnimationState();
}

class _FadeUpAnimationState extends State<FadeUpAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450), // 0.45s from style.md
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // translateY(16 -> 0)
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.delayInMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: widget.delayInMilliseconds), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
