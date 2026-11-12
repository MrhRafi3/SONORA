import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sonora/app/theme/app_colors.dart';
import 'package:sonora/app/theme/app_typography.dart';

/// Custom animated SONORA brand wordmark and minimal tagline.
///
/// Reveals each letter of "SONORA" with a staggered opacity and subtle vertical
/// glide while converging letter spacing smoothly into its final editorial
/// tracking, followed by a quiet fade-in of "FEEL EVERY FREQUENCY".
///
/// Uses [FadeTransition] for GPU-composited opacity without offscreen
/// `saveLayer` allocations, and caches static text children inside
/// [AnimatedBuilder] to avoid widget tree rebuilds during ticks.
class AnimatedSonoraWordmark extends StatelessWidget {
  const AnimatedSonoraWordmark({
    super.key,
    required this.timeline,
    required this.letterProgresses,
    required this.spacingProgress,
    required this.taglineProgress,
  }) : assert(letterProgresses.length == letters.length);

  static const List<String> letters = ['S', 'O', 'N', 'O', 'R', 'A'];
  static const String taglineText = 'FEEL EVERY FREQUENCY';

  /// Master timeline listenable driving per-frame positional transforms.
  final Listenable timeline;

  /// Staggered reveal progress `[0.0, 1.0]` for each letter of SONORA.
  final List<Animation<double>> letterProgresses;

  /// Smooth convergence progress `[0.0, 1.0]` for wordmark letter spacing.
  final Animation<double> spacingProgress;

  /// Fade-in progress `[0.0, 1.0]` for the optional minimal tagline.
  final Animation<double> taglineProgress;

  @override
  Widget build(BuildContext context) {
    final Size viewport = MediaQuery.sizeOf(context);
    final double minDim = math.min(viewport.width, viewport.height);

    // Responsive display typography sized for small phones through tablets
    final double fontSize = (minDim * 0.108).clamp(32.0, 58.0);
    final double finalGap = fontSize * 0.25;
    final double extraGap = fontSize * 0.24;
    final double verticalTravel = (fontSize * 0.26).clamp(8.0, 15.0);
    final double taglineSize = (fontSize * 0.25).clamp(10.0, 13.5);
    final double taglineSpacing = (fontSize * 0.075).clamp(2.4, 4.4);
    final double centerIndex = (letters.length - 1) / 2.0;

    final TextStyle letterStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.05,
      color: AppColors.darkTextPrimary,
    );

    final Color taglineColor = Color.lerp(
      AppColors.darkTextSecondary,
      AppColors.darkAccentGold,
      0.42,
    )!.withValues(alpha: 0.88);

    final TextStyle taglineStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: taglineSize,
      fontWeight: FontWeight.w500,
      letterSpacing: taglineSpacing,
      height: 1.2,
      color: taglineColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          label: 'SONORA',
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // Reserve horizontal room for the widest initial letter tracking
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: centerIndex * extraGap,
                ),
                child: Row(
                  key: const Key('splash_wordmark'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(letters.length, (index) {
                    final double offsetMultiplier = index - centerIndex;
                    final Widget glyph = Padding(
                      padding: EdgeInsets.only(
                        right: index < letters.length - 1 ? finalGap : 0.0,
                      ),
                      child: Text(
                        letters[index],
                        key: Key('splash_letter_$index'),
                        style: letterStyle,
                      ),
                    );

                    return FadeTransition(
                      key: Key('splash_letter_opacity_$index'),
                      opacity: letterProgresses[index],
                      child: AnimatedBuilder(
                        animation: timeline,
                        builder: (context, child) {
                          final double reveal = letterProgresses[index].value
                              .clamp(0.0, 1.0);
                          final double spacing = spacingProgress.value.clamp(
                            0.0,
                            1.0,
                          );
                          final double dx =
                              offsetMultiplier * extraGap * (1.0 - spacing);
                          final double dy = (1.0 - reveal) * verticalTravel;

                          return Transform.translate(
                            key: Key('splash_letter_transform_$index'),
                            offset: Offset(dx, dy),
                            child: child,
                          );
                        },
                        child: glyph,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: (fontSize * 0.42).clamp(12.0, 22.0)),
        FadeTransition(
          key: const Key('splash_tagline_opacity'),
          opacity: taglineProgress,
          child: AnimatedBuilder(
            animation: taglineProgress,
            builder: (context, child) {
              final double progress = taglineProgress.value.clamp(0.0, 1.0);
              final double dy = (1.0 - progress) * 6.0;

              return Transform.translate(
                key: const Key('splash_tagline_transform'),
                offset: Offset(0.0, dy),
                child: child,
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                taglineText,
                key: const Key('splash_tagline'),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: taglineStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
