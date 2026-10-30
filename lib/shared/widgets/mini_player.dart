import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../features/player/presentation/player_state.dart';
import 'animated_play_pause_button.dart';
import 'format_badge.dart';
import 'sonora_artwork.dart';

/// Refined mini-player docked above navigation.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.track;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/player'),
          borderRadius: AppSpacing.roundedLg,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: sonora.surfaceElevated,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppSpacing.roundedLg,
              child: Stack(
                children: [
                  // Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        SonoraArtwork(
                          size: 46,
                          primaryColor: track.artworkColor,
                          accentColor: track.accentColor,
                          borderRadius: AppSpacing.roundedSm,
                          heroTag: 'now-playing-art',
                          artworkPath: track.artworkPath,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  FormatBadge(label: track.audioFormat),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          tooltip: 'Previous',
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 22,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              ref.read(playerProvider.notifier).previousTrack(),
                        ),
                        AnimatedPlayPauseButton(
                          size: 38,
                          iconSize: 20,
                          isPlaying: playerState.isPlaying,
                          onPressed: () => ref
                              .read(playerProvider.notifier)
                              .togglePlayPause(),
                        ),
                        IconButton(
                          tooltip: 'Next',
                          icon: const Icon(Icons.skip_next_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              ref.read(playerProvider.notifier).nextTrack(),
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator bar along the bottom edge
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: playerState.progress,
                      minHeight: 2.2,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.darkAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
