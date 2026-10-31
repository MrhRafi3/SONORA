import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Audiophile interactive waveform progress scrubber.
///
/// Visualizes track amplitude peaks across duration with touch-scrubbing,
/// glowing playhead, and played/unplayed gradient styling.
class WaveformProgressBar extends StatefulWidget {
  const WaveformProgressBar({
    super.key,
    required this.progress,
    required this.duration,
    required this.onSeek,
    this.barCount = 64,
    this.height = 36.0,
    this.seed = 42,
  });

  final double progress; // 0.0 to 1.0
  final Duration duration;
  final ValueChanged<double> onSeek;
  final int barCount;
  final double height;
  final int seed;

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar> {
  late List<double> _peaks;
  bool _isDragging = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _generatePeaks();
  }

  @override
  void didUpdateWidget(covariant WaveformProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed ||
        widget.barCount != oldWidget.barCount) {
      _generatePeaks();
    }
  }

  void _generatePeaks() {
    final rand = math.Random(widget.seed);
    _peaks = List.generate(widget.barCount, (i) {
      // Harmonic envelope shaping: softer start/end, dynamic variations in middle
      final envelope = math.sin(math.pi * (i + 1) / (widget.barCount + 1));
      final dynamicVariation = 0.35 + rand.nextDouble() * 0.65;
      return (envelope * dynamicVariation).clamp(0.12, 1.0);
    });
  }

  void _handleDrag(double localX, double width) {
    final clampedX = localX.clamp(0.0, width);
    final p = (clampedX / width).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeP = _isDragging
        ? _dragProgress
        : widget.progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
            });
            _handleDrag(details.localPosition.dx, w);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition.dx, w);
          },
          onHorizontalDragEnd: (_) {
            widget.onSeek(_dragProgress);
            setState(() {
              _isDragging = false;
            });
          },
          onTapDown: (details) {
            final p = (details.localPosition.dx / w).clamp(0.0, 1.0);
            widget.onSeek(p);
          },
          child: SizedBox(
            height: widget.height,
            width: w,
            child: CustomPaint(
              size: Size(w, widget.height),
              painter: _WaveformPainter(
                peaks: _peaks,
                progress: activeP,
                playedColor: AppColors.darkAccent,
                unplayedColor: Colors.white.withValues(alpha: 0.18),
                playheadColor: const Color(0xFFF9E79F),
                isDragging: _isDragging,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.playheadColor,
    required this.isDragging,
  });

  final List<double> peaks;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final Color playheadColor;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final count = peaks.length;

    const spacing = 2.0;
    final barWidth = math.max(1.5, (w - (count - 1) * spacing) / count);
    final playheadX = progress * w;

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    final playheadGlowPaint = Paint()
      ..color = playedColor.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final playheadLinePaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + spacing);
      final peakHeight = peaks[i] * h;
      final top = (h - peakHeight) / 2.0;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, peakHeight),
        Radius.circular(barWidth / 2.0),
      );

      final isPlayed = (x + barWidth / 2.0) <= playheadX;
      canvas.drawRRect(barRect, isPlayed ? playedPaint : unplayedPaint);
    }

    // Playhead vertical marker & glow
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, h),
      playheadGlowPaint,
    );
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, h),
      playheadLinePaint,
    );

    // Indicator head circle if dragging
    if (isDragging) {
      canvas.drawCircle(Offset(playheadX, h / 2), 5.0, playheadLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.peaks != peaks;
  }
}
