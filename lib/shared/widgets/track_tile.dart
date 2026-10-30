import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../features/player/domain/ui_track.dart';
import 'format_badge.dart';
import 'sonora_artwork.dart';

/// Reusable track tile for songs, albums, and search results.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isPlaying = false,
    this.showArtwork = true,
    this.trackIndex,
    this.onMoreOptions,
  });

  final UiTrack track;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool showArtwork;
  final int? trackIndex;
  final VoidCallback? onMoreOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (showArtwork) ...[
              SonoraArtwork(
                size: 48,
                primaryColor: track.artworkColor,
                accentColor: track.accentColor,
                artworkPath: track.artworkPath,
              ),
              const SizedBox(width: AppSpacing.md),
            ] else if (trackIndex != null) ...[
              SizedBox(
                width: 28,
                child: Text(
                  trackIndex.toString().padLeft(2, '0'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPlaying
                        ? AppColors.darkAccent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isPlaying
                                ? AppColors.darkAccent
                                : theme.colorScheme.onSurface,
                            fontWeight: isPlaying
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isPlaying) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.equalizer_rounded,
                          size: 16,
                          color: AppColors.darkAccent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      FormatBadge(label: track.audioFormat),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${track.artist} • ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              track.formattedDuration,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (onMoreOptions != null)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onMoreOptions,
              ),
          ],
        ),
      ),
    );
  }
}
