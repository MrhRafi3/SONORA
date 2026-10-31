import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/theme/app_spacing.dart';

/// A premium artwork tile displaying real album art when cached on disk,
/// with procedural vinyl grooves and hardware finishes as an elegant fallback.
class SonoraArtwork extends StatelessWidget {
  const SonoraArtwork({
    super.key,
    required this.size,
    this.primaryColor = const Color(0xFF1E1E24),
    this.accentColor = const Color(0xFFE59866),
    this.borderRadius,
    this.showGlow = false,
    this.heroTag,
    this.artworkPath,
  });

  final double size;
  final Color primaryColor;
  final Color accentColor;
  final BorderRadius? borderRadius;
  final bool showGlow;
  final String? heroTag;
  final String? artworkPath;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppSpacing.roundedMd;
    final hasRealArtwork = artworkPath != null && artworkPath!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveSize = size.isInfinite
            ? (constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : (constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 160.0))
            : size;

        Widget content;
        if (hasRealArtwork) {
          final targetDimension = (effectiveSize * 2.0).round().clamp(64, 1024);
          content = ClipRRect(
            borderRadius: effectiveRadius,
            child: Image.file(
              File(artworkPath!),
              width: effectiveSize,
              height: effectiveSize,
              cacheWidth: targetDimension,
              cacheHeight: targetDimension,
              gaplessPlayback: true,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildProceduralVinyl(effectiveSize),
            ),
          );
        } else {
          content = _buildProceduralVinyl(effectiveSize);
        }

        Widget artwork = Container(
          width: size.isInfinite ? double.infinity : effectiveSize,
          height: size.isInfinite ? double.infinity : effectiveSize,
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: content,
        );

        if (heroTag != null) {
          artwork = Hero(tag: heroTag!, child: artwork);
        }

        return artwork;
      },
    );
  }

  Widget _buildProceduralVinyl(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.black, 0.4) ?? Colors.black,
          ],
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

    // Highlighted outer groove
    canvas.drawCircle(center, maxRadius * 0.92, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
