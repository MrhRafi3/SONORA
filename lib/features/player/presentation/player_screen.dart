import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/animated_play_pause_button.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../../shared/widgets/sonora_artwork.dart';
import '../../../shared/widgets/track_tile.dart';
import '../domain/ui_track.dart';
import 'player_state.dart';
import 'widgets/audio_inspector_sheet.dart';
import 'widgets/lyrics_sheet.dart';
import 'widgets/waveform_progress_bar.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  void _showQueueSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (context) {
        final playerState = ref.watch(playerProvider);
        final queueTracks = playerState.queue.isNotEmpty
            ? playerState.queue
            : kShowcaseTracks;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Up Next In Queue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: queueTracks.length,
                    itemBuilder: (context, index) {
                      final track = queueTracks[index];
                      final isCurrent = playerState.track?.id == track.id;

                      return TrackTile(
                        track: track,
                        isPlaying: isCurrent && playerState.isPlaying,
                        onTap: () {
                          ref
                              .read(playerProvider.notifier)
                              .playQueueIndex(index);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLyricsSheet(BuildContext context, UiTrack track) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (context) => LyricsSheet(track: track),
    );
  }

  void _showInspectorSheet(BuildContext context, UiTrack track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (context) => AudioInspectorSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final playerState = ref.watch(playerProvider);
    final track = playerState.track ?? kShowcaseTracks.first;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Responsive artwork sizing avoiding overflow on constrained/compact screens
    final artworkSize = screenHeight > 700
        ? (screenWidth * 0.72).clamp(200.0, 300.0)
        : (screenHeight * 0.32).clamp(140.0, 200.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              track.artworkColor.withValues(alpha: 0.35),
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 30,
                              ),
                              tooltip: 'Collapse Player',
                              onPressed: () => context.pop(),
                            ),
                            Column(
                              children: [
                                Text(
                                  'NOW PLAYING',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FormatBadge(
                                  label: track.formatBadge,
                                  isGold: true,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_horiz_rounded),
                              tooltip: 'Track Info',
                              onPressed: () =>
                                  _showInspectorSheet(context, track),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Center Artwork with glow and hero transition
                        SonoraArtwork(
                          size: artworkSize,
                          primaryColor: track.artworkColor,
                          accentColor: track.accentColor,
                          borderRadius: AppSpacing.roundedXl,
                          showGlow: true,
                          heroTag: 'now-playing-art',
                          artworkPath: track.artworkPath,
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Title, Artist, and Favorite
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${track.artist} • ${track.album}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                track.isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: track.isFavorite
                                    ? AppColors.darkAccent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              tooltip: 'Favorite',
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .toggleFavorite(),
                            ),
                          ],
                        ),

                        SizedBox(
                          height: screenHeight > 700
                              ? AppSpacing.md
                              : AppSpacing.xs,
                        ),

                        // Progress Scrubber & Labels
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              child: WaveformProgressBar(
                                height: screenHeight > 700 ? 32.0 : 20.0,
                                progress: playerState.progress,
                                duration: playerState.duration ?? Duration.zero,
                                seed: track.id.hashCode,
                                onSeek: (val) =>
                                    ref.read(playerProvider.notifier).seek(val),
                              ),
                            ),
                            SliderTheme(
                              data: theme.sliderTheme.copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                              ),
                              child: Slider(
                                value: playerState.progress,
                                onChanged: (val) =>
                                    ref.read(playerProvider.notifier).seek(val),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    playerState.formattedPosition,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  Text(
                                    playerState.formattedRemaining,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Control Deck (Shuffle, Prev, Play/Pause, Next, Repeat)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: playerState.isShuffle
                                    ? AppColors.darkAccent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                              tooltip: 'Shuffle',
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .toggleShuffle(),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 36,
                              ),
                              tooltip: 'Previous',
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .previousTrack(),
                            ),
                            AnimatedPlayPauseButton(
                              size: 68,
                              iconSize: 34,
                              isPlaying: playerState.isPlaying,
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .togglePlayPause(),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 36,
                              ),
                              tooltip: 'Next',
                              onPressed: () =>
                                  ref.read(playerProvider.notifier).nextTrack(),
                            ),
                            IconButton(
                              icon: Icon(
                                switch (playerState.repeatMode) {
                                  PlaybackRepeatMode.off =>
                                    Icons.repeat_rounded,
                                  PlaybackRepeatMode.all =>
                                    Icons.repeat_rounded,
                                  PlaybackRepeatMode.one =>
                                    Icons.repeat_one_rounded,
                                },
                                color:
                                    playerState.repeatMode !=
                                        PlaybackRepeatMode.off
                                    ? AppColors.darkAccent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                              tooltip: 'Repeat',
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .toggleRepeat(),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Bottom Action Dock: Equalizer, Lyrics, Queue
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sonora.surfaceElevated,
                            borderRadius: AppSpacing.roundedFull,
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => context.push('/equalizer'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onSurface,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text(
                                  'EQ & DSP',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              TextButton.icon(
                                onPressed: () =>
                                    _showLyricsSheet(context, track),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onSurface,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.lyrics_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Notes',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              TextButton.icon(
                                onPressed: () => _showQueueSheet(context, ref),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onSurface,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.queue_music_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Queue',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
