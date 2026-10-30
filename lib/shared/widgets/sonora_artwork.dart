import 'package:flutter/material.dart';
import '../../app/theme/app_spacing.dart';

/// A premium procedural artwork tile evoking vinyl grooves and high-end hardware finishes.
class SonoraArtwork extends StatelessWidget {
  const SonoraArtwork({
    super.key,
    required this.size,
    this.primaryColor = const Color(0xFF1E1E24),
    this.accentColor = const Color(0xFFE59866),
    this.borderRadius,
    this.showGlow = false,
    this.heroTag,
  });

  final double size;
  final Color primaryColor;
  final Color accentColor;
  final BorderRadius? borderRadius;
  final bool showGlow;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppSpacing.roundedMd;

    Widget artwork = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.black, 0.4) ?? Colors.black,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric circular grooved rings (Audiophile vinyl aesthetic)
          CustomPaint(
            size: Size(size, size),
            painter: _VinylGroovesPainter(
              accentColor: accentColor.withValues(alpha: 0.35),
            ),
          ),
          // Center spindle / icon badge
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: size * 0.16,
              color: accentColor,
            ),
          ),
        ],
      ),
    );

    if (heroTag != null) {
      artwork = Hero(tag: heroTag!, child: artwork);
    }

    return artwork;
  }
}

class _VinylGroovesPainter extends CustomPainter {
  const _VinylGroovesPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) * 0.88;

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.04);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor;

    for (double r = maxRadius * 0.45; r <= maxRadius; r += 5.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Subtle highlighted outer groove
    canvas.drawCircle(center, maxRadius * 0.92, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
