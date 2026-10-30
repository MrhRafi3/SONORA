import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Interactive play/pause toggle button with smooth micro-animation and haptic scale.
class AnimatedPlayPauseButton extends StatefulWidget {
  const AnimatedPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 56.0,
    this.iconSize = 30.0,
    this.backgroundColor,
    this.iconColor,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  State<AnimatedPlayPauseButton> createState() =>
      _AnimatedPlayPauseButtonState();
}

class _AnimatedPlayPauseButtonState extends State<AnimatedPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.backgroundColor ?? AppColors.darkAccent;
    final effectiveIconColor = widget.iconColor ?? Colors.black;

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed && !disableAnimations ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: effectiveBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: effectiveBg.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _controller,
              size: widget.iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
