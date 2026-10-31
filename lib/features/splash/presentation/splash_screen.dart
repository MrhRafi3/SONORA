import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';

/// Premium, minimal animated splash screen for SONORA.
///
/// Features a solid dark `#171717` canvas providing seamless continuity
/// from native launch splash to Flutter canvas, with a subtle scale-and-opacity
/// entrance, refined acoustic resonance motion, and a smooth settling transition
/// into the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Solid background color matching the exact RGB values (23, 23, 23)
  /// of the sonora_logo.png background and native launch screen.
  static const Color _splashBackground = Color(0xFF171717);

  /// Total duration: 1700ms (~600ms entrance + ~750ms pulse + ~350ms settle).
  static const Duration _totalDuration = Duration(milliseconds: 1700);

  late final AnimationController _controller;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _resonancePulse;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    // 1. Entrance: 0.0 - 0.35 (~600ms) - Subtle scale and opacity rise
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Main Motion: 0.35 - 0.79 (~750ms) - Refined acoustic wave pulse
    _resonancePulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.045)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.045, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.79),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    // Schedule post-frame execution for native splash dismissal and animation start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {
        // Fallback for tests or environments where native splash is unattached
      }

      if (!mounted) return;
      final bool reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        // Accessibility: skip animation for reduced-motion preference
        _controller.value = 1.0;
        Future.delayed(const Duration(milliseconds: 250), _navigateToHome);
      } else if (!_controller.isAnimating && !_controller.isCompleted) {
        _controller.forward();
      }
    });
  }

  void _navigateToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Responsive sizing keeping logo comfortable across small phones and large tablets
    final logoDimension =
        (math.min(size.width, size.height) * 0.42).clamp(140.0, 220.0);

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: _splashBackground,
          body: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Combined scale: entrance zoom * acoustic pulse resonance
                final double currentScale =
                    _entranceScale.value * _resonancePulse.value;
                final double currentOpacity = _entranceOpacity.value;

                return Opacity(
                  key: const Key('splash_logo_opacity'),
                  opacity: currentOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    key: const Key('splash_logo_transform'),
                    scale: currentScale,
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: logoDimension,
                height: logoDimension,
                child: Image.asset(
                  'assets/branding/sonora_logo.png',
                  width: logoDimension,
                  height: logoDimension,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
