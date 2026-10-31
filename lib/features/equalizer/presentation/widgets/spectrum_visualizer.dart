import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Real-time audio spectrum analyzer visualizer widget.
///
/// Animates 24 logarithmic frequency spectrum bars with peak-hold decay
/// driven by playback state.
class SpectrumVisualizerWidget extends StatefulWidget {
  const SpectrumVisualizerWidget({
    super.key,
    this.isPlaying = true,
    this.barCount = 24,
    this.height = 48.0,
    this.accentColor,
  });

  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? accentColor;

  @override
  State<SpectrumVisualizerWidget> createState() =>
      _SpectrumVisualizerWidgetState();
}

class _SpectrumVisualizerWidgetState extends State<SpectrumVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _currentHeights;
  late List<double> _peakHeights;
  final math.Random _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _currentHeights = List.filled(widget.barCount, 0.05);
    _peakHeights = List.filled(widget.barCount, 0.05);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    )..addListener(_tick);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpectrumVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _decayToRest();
      }
    }
  }

  void _decayToRest() {
    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        _currentHeights[i] = 0.05;
        _peakHeights[i] = 0.05;
      }
    });
  }

  void _tick() {
    if (!mounted || !widget.isPlaying) return;

    setState(() {
      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      for (int i = 0; i < widget.barCount; i++) {
        // Natural harmonic audio spectrum simulation based on logarithmic bins
        final harmonic1 = math.sin(t * 5.0 + i * 0.4);
        final harmonic2 = math.cos(t * 8.3 - i * 0.7);
        final harmonic3 = math.sin(t * 13.1 + i * 1.1);
        final noise = (_random.nextDouble() - 0.5) * 0.2;

        // Bass frequencies have slightly higher baseline energy
        final bassWeight = 1.0 - (i / widget.barCount) * 0.35;
        double target =
            ((harmonic1 * 0.4 + harmonic2 * 0.3 + harmonic3 * 0.3 + 1.0) / 2.0 +
                noise) *
            bassWeight;
        target = target.clamp(0.06, 0.98);

        // Smooth attack and release
        if (target > _currentHeights[i]) {
          _currentHeights[i] =
              _currentHeights[i] * 0.3 + target * 0.7; // Fast attack
        } else {
          _currentHeights[i] =
              _currentHeights[i] * 0.82 + target * 0.18; // Smooth release
        }

        // Peak hold with decay
        if (_currentHeights[i] > _peakHeights[i]) {
          _peakHeights[i] = _currentHeights[i];
        } else {
          _peakHeights[i] = math.max(0.06, _peakHeights[i] - 0.035);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.darkAccent;

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SpectrumPainter(
          currentHeights: _currentHeights,
          peakHeights: _peakHeights,
          accentColor: accent,
          barCount: widget.barCount,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.currentHeights,
    required this.peakHeights,
    required this.accentColor,
    required this.barCount,
  });

  final List<double> currentHeights;
  final List<double> peakHeights;
  final Color accentColor;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const spacing = 2.0;
    final barWidth = math.max(2.0, (w - (barCount - 1) * spacing) / barCount);

    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        accentColor.withValues(alpha: 0.6),
        accentColor,
        const Color(0xFFF9E79F),
      ],
      stops: const [0.0, 0.75, 1.0],
    );

    final barPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final peakPaint = Paint()
      ..color = const Color(0xFFF9E79F)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final barH = currentHeights[i] * h;
      final peakY = h - (peakHeights[i] * h);

      // Bar rect with rounded top corners
      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, h - barH, barWidth, barH),
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      );
      canvas.drawRRect(barRect, barPaint);

      // Peak line
      if (peakY < h - 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, peakY - 1.5, barWidth, 1.5),
            const Radius.circular(0.75),
          ),
          peakPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
