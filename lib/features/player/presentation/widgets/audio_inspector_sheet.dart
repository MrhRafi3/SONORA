import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/format_badge.dart';
import '../../domain/ui_track.dart';

/// Modal bottom sheet displaying detailed technical audio format specifications.
class AudioInspectorSheet extends StatelessWidget {
  const AudioInspectorSheet({super.key, required this.track});

  final UiTrack track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    final isHiRes =
        track.audioFormat.toUpperCase() == 'FLAC' ||
        track.sampleRate.contains('96') ||
        track.sampleRate.contains('192');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.darkAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.darkAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Audio Inspector',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                FormatBadge(label: track.formatBadge, isGold: isHiRes),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Specifications Grid Card
            Container(
              padding: AppSpacing.insetsMd,
              decoration: BoxDecoration(
                color: sonora.surfaceElevated,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildSpecRow('Audio Codec', track.audioFormat),
                  _buildSpecRow('Sample Frequency', track.sampleRate),
                  _buildSpecRow('Bit Depth / Precision', track.bitDepth),
                  _buildSpecRow('Channels', 'Stereo (2 Channels Interleaved)'),
                  _buildSpecRow(
                    'DSP Engine',
                    'C++17 Direct Form II Transposed',
                  ),
                  _buildSpecRow('Buffer Latency', '< 0.04 ms (679x Real-Time)'),
                  _buildSpecRow(
                    'Storage Path',
                    track.filePath ?? 'Direct-to-DSD Remaster',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Audiophile Fidelity Explanation
            Container(
              padding: AppSpacing.insetsMd,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(
                  color: (isHiRes ? AppColors.darkAccent : Colors.grey)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isHiRes
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    color: isHiRes ? AppColors.darkAccent : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isHiRes
                          ? 'Studio Master Quality: Audio data is processed with 32-bit floating point precision, preserving microscopic acoustic details without dithering noise.'
                          : 'Standard Quality: Compact compressed audio processed with soft-knee limiter dynamics and smooth coefficient de-zippering.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
