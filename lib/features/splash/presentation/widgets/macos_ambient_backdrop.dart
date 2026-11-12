import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sonora/app/theme/app_colors.dart';

/// Lightweight, GPU-friendly macOS-inspired ambient charcoal backdrop.
///
/// Renders a solid charcoal `#171717` canvas with slow-moving, morphing
/// fluid organic shapes, soft warm amber/gold radial lighting, and delicate
/// specular rim highlights—without expensive Gaussian blur filters or 3D meshes.
class MacosAmbientBackdrop extends StatelessWidget {
  const MacosAmbientBackdrop({
    super.key,
    required this.fadeProgress,
    required this.driftProgress,
  });

  /// Controls the initial entrance fade-in of lighting and organic forms.
  final Animation<double> fadeProgress;

  /// Continuous periodic progress `[0.0, 1.0)` driving slow organic morphing.
  final Animation<double> driftProgress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('splash_background_boundary'),
      child: CustomPaint(
        key: const Key('splash_background_canvas'),
        painter: _MacosAmbientPainter(
          fadeProgress: fadeProgress,
          driftProgress: driftProgress,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MacosAmbientPainter extends CustomPainter {
  _MacosAmbientPainter({
    required this.fadeProgress,
    required this.driftProgress,
  }) : super(repaint: Listenable.merge([fadeProgress, driftProgress]));

  final Animation<double> fadeProgress;
  final Animation<double> driftProgress;

  /// Matches the native launch splash background `#171717` for seamless handoff.
  static const Color _baseCharcoal = Color(0xFF171717);
  static const Color _deepVignette = Color(0xFF101013);

  static const int _blobPointCount = 8;
  static const List<double> _vignetteStops = [0.35, 1.0];
  static const List<double> _amberStops = [0.0, 0.36, 0.70, 1.0];
  static const List<double> _goldStops = [0.0, 0.48, 1.0];
  static const List<double> _blobStops = [0.0, 0.55, 1.0];
  static const List<double> _rimStops = [0.0, 0.45, 0.92];
  static const List<double> _ribbonStops = [0.0, 0.48, 1.0];
  static const List<double> _ribbonRimStops = [0.05, 0.35, 0.68, 0.95];

  final Paint _basePaint = Paint()..color = _baseCharcoal;
  final Paint _shaderPaint = Paint()..style = PaintingStyle.fill;
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Pre-allocated buffers to avoid per-frame GC churn during 60/120Hz ticks.
  final List<Offset> _blobPoints = List<Offset>.filled(
    _blobPointCount,
    Offset.zero,
  );
  final Path _primaryBlobPath = Path();
  final Path _secondaryBlobPath = Path();
  final Path _ribbonTopPath = Path();
  final Path _ribbonAreaPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    // Always paint solid charcoal base immediately on frame 0
    canvas.drawRect(rect, _basePaint);

    final double fade = fadeProgress.value.clamp(0.0, 1.0);
    if (fade <= 0.001) return;

    final double theta = driftProgress.value * math.pi * 2.0;
    final double minDim = math.min(size.width, size.height);
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);

    // 1. Subtle edge vignette to add quiet studio depth while keeping charcoal base
    _shaderPaint.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.95,
      colors: [
        Colors.transparent,
        _deepVignette.withValues(alpha: 0.42 * fade),
      ],
      stops: _vignetteStops,
    ).createShader(rect);
    canvas.drawRect(rect, _shaderPaint);

    // 2. Soft drifting warm amber ambient light field (upper-center left drift)
    final Offset amberCenter = Offset(
      center.dx + math.sin(theta) * size.width * 0.09,
      center.dy -
          size.height * 0.04 +
          math.cos(theta * 0.8 + 0.5) * size.height * 0.05,
    );
    final double amberRadius = minDim * 0.85;
    _shaderPaint.shader = RadialGradient(
      colors: [
        AppColors.darkAccent.withValues(alpha: 0.115 * fade),
        AppColors.darkAccent.withValues(alpha: 0.055 * fade),
        AppColors.darkAccent.withValues(alpha: 0.015 * fade),
        Colors.transparent,
      ],
      stops: _amberStops,
    ).createShader(Rect.fromCircle(center: amberCenter, radius: amberRadius));
    canvas.drawCircle(amberCenter, amberRadius, _shaderPaint);

    // 3. Soft counter-drifting champagne gold highlight field
    final Offset goldCenter = Offset(
      center.dx - math.cos(theta + 1.1) * size.width * 0.11,
      center.dy +
          size.height * 0.06 +
          math.sin(theta + 2.0) * size.height * 0.06,
    );
    final double goldRadius = minDim * 0.72;
    _shaderPaint.shader = RadialGradient(
      colors: [
        AppColors.darkAccentGold.withValues(alpha: 0.08 * fade),
        AppColors.darkAccentLight.withValues(alpha: 0.03 * fade),
        Colors.transparent,
      ],
      stops: _goldStops,
    ).createShader(Rect.fromCircle(center: goldCenter, radius: goldRadius));
    canvas.drawCircle(goldCenter, goldRadius, _shaderPaint);

    // 4. Morphing fluid organic form (central-upper silk contour)
    _paintOrganicBlob(
      canvas: canvas,
      path: _primaryBlobPath,
      center: Offset(
        size.width * (0.48 + 0.05 * math.sin(theta)),
        size.height * (0.44 + 0.035 * math.cos(theta + 0.7)),
      ),
      rx: minDim * 0.56,
      ry: minDim * 0.34,
      theta: theta,
      phaseOffset: 0.0,
      fillColors: [
        AppColors.darkAccentLight.withValues(alpha: 0.055 * fade),
        AppColors.darkAccent.withValues(alpha: 0.025 * fade),
        Colors.transparent,
      ],
      rimColor: AppColors.darkAccentGold.withValues(alpha: 0.095 * fade),
      rimWidth: 1.0,
    );

    // 5. Secondary counter-morphing organic form (lower-right fluid veil)
    _paintOrganicBlob(
      canvas: canvas,
      path: _secondaryBlobPath,
      center: Offset(
        size.width * (0.55 - 0.06 * math.cos(theta + 0.4)),
        size.height * (0.58 - 0.04 * math.sin(theta + 1.3)),
      ),
      rx: minDim * 0.62,
      ry: minDim * 0.32,
      theta: -theta,
      phaseOffset: 2.1,
      fillColors: [
        AppColors.darkAccentGold.withValues(alpha: 0.045 * fade),
        AppColors.darkAccent.withValues(alpha: 0.018 * fade),
        Colors.transparent,
      ],
      rimColor: AppColors.darkAccentLight.withValues(alpha: 0.075 * fade),
      rimWidth: 0.9,
    );

    // 6. Sweeping macOS-style acoustic silk ribbon across the lower-mid horizon
    _paintFluidRibbon(
      canvas: canvas,
      size: size,
      theta: theta,
      fade: fade,
      verticalAnchor: 0.54,
      amplitude: minDim * 0.09,
      thickness: minDim * 0.18,
      phase: 0.3,
    );
  }

  void _paintOrganicBlob({
    required Canvas canvas,
    required Path path,
    required Offset center,
    required double rx,
    required double ry,
    required double theta,
    required double phaseOffset,
    required List<Color> fillColors,
    required Color rimColor,
    required double rimWidth,
  }) {
    if (rx <= 0 || ry <= 0) return;

    for (int i = 0; i < _blobPointCount; i++) {
      final double baseAngle = (i / _blobPointCount) * math.pi * 2.0;
      final double harmonic =
          1.0 +
          0.13 * math.sin(theta + baseAngle * 2.0 + phaseOffset) +
          0.07 * math.cos(theta * 2.0 - baseAngle * 3.0 + phaseOffset * 1.4);
      final double angleDrift =
          baseAngle + 0.08 * math.sin(theta + i * 0.9 + phaseOffset);
      _blobPoints[i] = Offset(
        center.dx + math.cos(angleDrift) * rx * harmonic,
        center.dy + math.sin(angleDrift) * ry * harmonic,
      );
    }

    _populateClosedCatmullRomPath(path, _blobPoints);
    final Rect bounds = Rect.fromCenter(
      center: center,
      width: rx * 2.4,
      height: ry * 2.4,
    );

    _shaderPaint.shader = RadialGradient(
      center: Alignment(
        0.25 * math.sin(theta + phaseOffset),
        -0.25 * math.cos(theta + phaseOffset),
      ),
      radius: 0.85,
      colors: fillColors,
      stops: _blobStops,
    ).createShader(bounds);
    canvas.drawPath(path, _shaderPaint);

    // Delicate specular rim highlight along one soft arc of the organic form
    _rimPaint
      ..strokeWidth = rimWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          rimColor,
          rimColor.withValues(alpha: rimColor.a * 0.18),
          Colors.transparent,
        ],
        stops: _rimStops,
      ).createShader(bounds);
    canvas.drawPath(path, _rimPaint);
  }

  void _paintFluidRibbon({
    required Canvas canvas,
    required Size size,
    required double theta,
    required double fade,
    required double verticalAnchor,
    required double amplitude,
    required double thickness,
    required double phase,
  }) {
    final double w = size.width;
    final double yBase = size.height * verticalAnchor;

    final double dy1 = math.sin(theta + phase) * amplitude;
    final double dy2 = math.cos(theta + phase * 1.6) * amplitude * 0.85;
    final double dy3 = math.sin(theta - phase * 0.9) * amplitude * 0.6;

    final Offset p0 = Offset(-w * 0.08, yBase + dy1 * 0.6);
    final Offset c1 = Offset(w * 0.28, yBase - amplitude * 0.9 + dy2);
    final Offset c2 = Offset(w * 0.68, yBase + amplitude * 0.85 + dy3);
    final Offset p1 = Offset(w * 1.08, yBase - dy1 * 0.5);

    _ribbonTopPath
      ..reset()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);

    _ribbonAreaPath
      ..reset()
      ..addPath(_ribbonTopPath, Offset.zero)
      ..lineTo(p1.dx, p1.dy + thickness)
      ..cubicTo(
        c2.dx,
        c2.dy + thickness * 1.25,
        c1.dx,
        c1.dy + thickness * 0.75,
        p0.dx,
        p0.dy + thickness,
      )
      ..close();

    final Rect ribbonBounds = Rect.fromLTWH(
      0,
      yBase - amplitude * 1.9,
      w,
      amplitude * 3.8 + thickness * 1.35,
    );
    if (ribbonBounds.isEmpty) return;

    _shaderPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.darkAccent.withValues(alpha: 0.048 * fade),
        AppColors.darkAccentGold.withValues(alpha: 0.016 * fade),
        Colors.transparent,
      ],
      stops: _ribbonStops,
    ).createShader(ribbonBounds);
    canvas.drawPath(_ribbonAreaPath, _shaderPaint);

    // Subtle specular silk thread along the crest of the organic wave
    _rimPaint
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          AppColors.darkAccentLight.withValues(alpha: 0.13 * fade),
          AppColors.darkAccentGold.withValues(alpha: 0.10 * fade),
          Colors.transparent,
        ],
        stops: _ribbonRimStops,
      ).createShader(ribbonBounds);
    canvas.drawPath(_ribbonTopPath, _rimPaint);
  }

  /// Populates [path] with a C1-continuous closed cubic Bézier spline through [points].
  void _populateClosedCatmullRomPath(Path path, List<Offset> points) {
    final int n = points.length;
    path
      ..reset()
      ..moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < n; i++) {
      final Offset p0 = points[(i - 1 + n) % n];
      final Offset p1 = points[i];
      final Offset p2 = points[(i + 1) % n];
      final Offset p3 = points[(i + 2) % n];

      final Offset cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final Offset cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
  }

  @override
  bool shouldRepaint(covariant _MacosAmbientPainter oldDelegate) {
    return oldDelegate.fadeProgress != fadeProgress ||
        oldDelegate.driftProgress != driftProgress;
  }
}
