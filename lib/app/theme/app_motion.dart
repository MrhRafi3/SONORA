import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transition styles supported by the SONORA motion system.
enum AppTransitionType {
  /// Horizontal subtle slide and fade for peer and hierarchical screens.
  sharedAxis,

  /// Vertical slide-up with fade for modal screens (e.g. full Player).
  modalSlideUp,

  /// Scale and crossfade for tabs and content replacements.
  fadeThrough,

  /// Direct crossfade without positional displacement.
  fade,
}

/// Central motion system for SONORA, enforcing consistent durations,
/// easing curves, and accessibility-compliant screen transitions.
class AppMotion {
  const AppMotion._();

  // --- Standard Durations ---
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationPage = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // --- Standard Easing Curves ---
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEmphasis = Curves.fastOutSlowIn;
  static const Curve curveDecelerate = Curves.easeOutQuart;

  /// Creates a [CustomTransitionPage] with consistent easing, duration,
  /// and reduced-motion accessibility handling.
  static Page<dynamic> buildPage({
    required LocalKey key,
    required Widget child,
    AppTransitionType transitionType = AppTransitionType.sharedAxis,
    Duration duration = durationPage,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
        // Respect reduced motion accessibility setting
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return pageChild;
        }

        switch (transitionType) {
          case AppTransitionType.sharedAxis:
            final curved = CurvedAnimation(
              parent: animation,
              curve: curveStandard,
              reverseCurve: curveStandard.flipped,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0.0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: pageChild,
              ),
            );

          case AppTransitionType.modalSlideUp:
            final curved = CurvedAnimation(
              parent: animation,
              curve: curveEmphasis,
              reverseCurve: curveEmphasis.flipped,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: pageChild,
              ),
            );

          case AppTransitionType.fadeThrough:
            final curved = CurvedAnimation(
              parent: animation,
              curve: curveStandard,
              reverseCurve: curveStandard.flipped,
            );
            return ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: pageChild,
              ),
            );

          case AppTransitionType.fade:
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: curveStandard,
                reverseCurve: curveStandard.flipped,
              ),
              child: pageChild,
            );
        }
      },
    );
  }
}
