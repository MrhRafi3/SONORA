import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/app/theme/app_spacing.dart';
import 'widgets/animated_sonora_wordmark.dart';
import 'widgets/macos_ambient_backdrop.dart';

/// Premium, macOS-inspired animated splash screen for SONORA.
///
/// Opens seamlessly from the native `#171717` charcoal launch surface, fades in
/// subtle organic amber/gold studio lighting and morphing fluid shapes, reveals
/// the custom "SONORA" wordmark letter by letter while converging letter spacing,
/// fades in the minimal "FEEL EVERY FREQUENCY" tagline, and crossfades smoothly
/// into the existing home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Solid charcoal base matching the native splash screen (`#171717`).
  static const Color _splashBackground = Color(0xFF171717);

  /// Choreographed splash timeline duration before transitioning to home.
  static const Duration _timelineDuration = Duration(milliseconds: 2400);

  /// Slow continuous loop period for organic fluid background motion.
  static const Duration _ambientCycleDuration = Duration(seconds: 16);

  /// Apple-style smooth deceleration curves without bounce or overshoot.
  static const Curve _macosRevealCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve _macosTrackingCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  late final AnimationController _timelineController;
  late final AnimationController _ambientController;

  late final CurvedAnimation _backgroundFade;
  late final List<CurvedAnimation> _letterProgresses;
  late final CurvedAnimation _spacingProgress;
  late final CurvedAnimation _taglineProgress;

  Timer? _reducedMotionTimer;
  bool _initialized = false;
  bool _isReducedMotion = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _timelineController = AnimationController(
      vsync: this,
      duration: _timelineDuration,
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: _ambientCycleDuration,
    );

    // 1. Ambient background fades in (0% - 30% of timeline)
    _backgroundFade = CurvedAnimation(
      parent: _timelineController,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
    );

    // 3. Staggered letter-by-letter reveal for SONORA (14% - 64%)
    _letterProgresses = List<CurvedAnimation>.generate(
      AnimatedSonoraWordmark.letters.length,
      (index) {
        final double start = 0.14 + (index * 0.05);
        final double end = start + 0.25;
        return CurvedAnimation(
          parent: _timelineController,
          curve: Interval(start, end, curve: _macosRevealCurve),
        );
      },
    );

    // 4. Letter spacing settles smoothly into final editorial tracking (20% - 72%)
    _spacingProgress = CurvedAnimation(
      parent: _timelineController,
      curve: const Interval(0.20, 0.72, curve: _macosTrackingCurve),
    );

    // 5. Minimal tagline fades in quietly after wordmark settles (56% - 78%)
    _taglineProgress = CurvedAnimation(
      parent: _timelineController,
      curve: const Interval(0.56, 0.78, curve: Curves.easeOutCubic),
    );

    _timelineController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isReducedMotion) {
        _navigateToHome();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissNativeSplash();
      if (!mounted) return;

      if (_isReducedMotion) {
        _reducedMotionTimer = Timer(
          const Duration(milliseconds: 250),
          _navigateToHome,
        );
      } else {
        // 2. Start continuous fluid organic background motion & master timeline
        if (!_ambientController.isAnimating) {
          _ambientController.repeat();
        }
        if (!_timelineController.isAnimating &&
            !_timelineController.isCompleted) {
          _timelineController.forward();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _isReducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_isReducedMotion) {
      _timelineController.value = 1.0;
    }
  }

  void _dismissNativeSplash() {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {
      // Safe fallback in test harnesses or when native splash is unattached.
    }
  }

  void _navigateToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/');
  }

  @override
  void dispose() {
    _reducedMotionTimer?.cancel();
    _backgroundFade.dispose();
    for (final animation in _letterProgresses) {
      animation.dispose();
    }
    _spacingProgress.dispose();
    _taglineProgress.dispose();
    _timelineController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: _splashBackground,
          body: Stack(
            fit: StackFit.expand,
            children: [
              MacosAmbientBackdrop(
                fadeProgress: _backgroundFade,
                driftProgress: _ambientController,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Center(
                    child: AnimatedSonoraWordmark(
                      timeline: _timelineController,
                      letterProgresses: _letterProgresses,
                      spacingProgress: _spacingProgress,
                      taglineProgress: _taglineProgress,
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
