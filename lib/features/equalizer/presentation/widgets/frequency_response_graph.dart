import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../equalizer_providers.dart';

/// Interactive audiophile frequency response curve graph.
///
/// Plots composite filter gain in decibels across the audio spectrum (20 Hz - 20 kHz)
/// using logarithmic horizontal scaling and decibel vertical axis.
class FrequencyResponseGraph extends StatelessWidget {
  const FrequencyResponseGraph({
    super.key,
    required this.state,
    this.height = 160.0,
  });

  final EqualizerState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: sonora.surfaceElevated,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.roundedMd,
        child: CustomPaint(
          size: Size.infinite,
          painter: _FrequencyResponsePainter(
            state: state,
            accentColor: AppColors.darkAccent,
            gridColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            textColor: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            baselineColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _FrequencyResponsePainter extends CustomPainter {
  _FrequencyResponsePainter({
    required this.state,
    required this.accentColor,
    required this.gridColor,
    required this.textColor,
    required this.baselineColor,
  });

  final EqualizerState state;
  final Color accentColor;
  final Color gridColor;
  final Color textColor;
  final Color baselineColor;

  static const double minFreq = 20.0;
  static const double maxFreq = 20000.0;
  static const double minDb = -15.0;
  static const double maxDb = 15.0;

  // Convert Hz to normalized horizontal coordinate (0.0 to 1.0) logarithmically
  double _freqToX(double freq, double width) {
    final logMin = math.log(minFreq);
    final logMax = math.log(maxFreq);
    final logFreq = math.log(freq.clamp(minFreq, maxFreq));
    return ((logFreq - logMin) / (logMax - logMin)) * width;
  }

  // Convert dB to vertical coordinate (0.0 at top, height at bottom)
  double _dbToY(double db, double height) {
    final clampedDb = db.clamp(minDb, maxDb);
    final normalized = (maxDb - clampedDb) / (maxDb - minDb);
    return normalized * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Grid Lines
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final baselinePaint = Paint()
      ..color = baselineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    // Horizontal dB grid lines (+12, +6, 0, -6, -12)
    final dbLevels = [12.0, 6.0, 0.0, -6.0, -12.0];
    for (final db in dbLevels) {
      final y = _dbToY(db, h);
      final isZero = db == 0.0;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        isZero ? baselinePaint : gridPaint,
      );

      // Label at left
      final textSpan = TextSpan(
        text: '${db > 0 ? '+' : ''}${db.toInt()}dB',
        style: textStyle,
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(4, y - tp.height / 2));
    }

    // Vertical Frequency grid lines (100 Hz, 1 kHz, 10 kHz)
    final freqMarkers = [
      (100.0, '100Hz'),
      (1000.0, '1kHz'),
      (10000.0, '10kHz'),
    ];

    for (final (freq, label) in freqMarkers) {
      final x = _freqToX(freq, w);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);

      final textSpan = TextSpan(text: label, style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, h - tp.height - 2));
    }

    // 2. Compute Frequency Response Path
    final path = Path();
    final fillPath = Path();

    const samplePoints = 120;
    final zeroY = _dbToY(0.0, h);

    fillPath.moveTo(0, zeroY);

    for (int i = 0; i <= samplePoints; i++) {
      final t = i / samplePoints;
      // Logarithmic interpolation for sampling frequency
      final logMin = math.log(minFreq);
      final logMax = math.log(maxFreq);
      final freq = math.exp(logMin + t * (logMax - logMin));

      final gainDb = state.calculateResponseAt(freq);
      final x = t * w;
      final y = _dbToY(gainDb, h);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, zeroY);
    fillPath.close();

    // 3. Draw Gradient Shading under response curve
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        accentColor.withValues(alpha: state.isEnabled ? 0.35 : 0.08),
        accentColor.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 4. Draw Smooth Response Curve
    final curvePaint = Paint()
      ..color = state.isEnabled
          ? accentColor
          : accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, curvePaint);

    // 5. Draw Band Nodes on top of curve
    if (state.isEnabled) {
      final nodePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;

      final nodeBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (final band in state.bands) {
        final x = _freqToX(band.frequency, w);
        final y = _dbToY(state.calculateResponseAt(band.frequency), h);

        canvas.drawCircle(Offset(x, y), 3.5, nodePaint);
        if (band.gain.abs() > 0.1) {
          canvas.drawCircle(Offset(x, y), 3.5, nodeBorderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyResponsePainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
