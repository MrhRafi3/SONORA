import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sonora_artwork.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../library/presentation/library_providers.dart';
import '../../player/domain/ui_track.dart';
import '../../player/presentation/player_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleScanImport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Starting audio scan...')),
    );

    if (Platform.isAndroid) {
      final summary = await ref
          .read(scanStatusProvider.notifier)
          .startAndroidScan();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.isSuccess
                ? 'Discovered ${summary.newlyAddedCount} tracks in MediaStore.'
                : (summary.errorMessage ?? 'Scan failed.'),
          ),
        ),
      );
    } else {
      final summary = await ref
          .read(scanStatusProvider.notifier)
          .startIosImport();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.isSuccess
                ? 'Imported ${summary.newlyAddedCount} audio files.'
                : (summary.errorMessage ?? 'Import failed.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final playerState = ref.watch(playerProvider);
    final isShowcaseActive = ref.watch(libraryEmptyStateProvider);

    final tracksAsync = ref.watch(tracksStreamProvider);
    final realTracks = tracksAsync.asData?.value ?? [];

    final hasRealMusic = realTracks.isNotEmpty;
    final displayShowcase = isShowcaseActive && !hasRealMusic;

    // Use real tracks if available, otherwise showcase tracks if enabled, or empty
    final activeTracks = hasRealMusic
        ? realTracks.map((t) => t.toUiTrack()).toList()
        : (displayShowcase ? kShowcaseTracks : <UiTrack>[]);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sonora.surfaceElevated,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(
                  color: AppColors.darkAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.album_rounded,
                    size: 16,
                    color: AppColors.darkAccent,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SONORA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.darkAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const FormatBadge(label: 'Hi-Res Engine', isGold: true),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Equalizer & DSP',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/equalizer'),
          ),
          IconButton(
            tooltip: 'Now Playing',
            icon: const Icon(Icons.music_note_rounded),
            onPressed: () => context.push('/player'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: (!hasRealMusic && !displayShowcase)
            ? EmptyStateView(
                title: 'Your Music Library is Quiet',
                message: Platform.isAndroid
                    ? 'SONORA discovers and indexes lossless audio stored in your Android MediaStore. Tap below to scan your device.'
                    : 'Import high-resolution MP3, FLAC, and WAV audio from the iOS Files app into your offline SONORA library.',
                icon: Icons.album_outlined,
                actionLabel: Platform.isAndroid
                    ? 'Scan Device Storage'
                    : 'Import Audio from Files',
                onAction: () => _handleScanImport(context, ref),
                secondaryActionLabel: 'View Showcase Preview',
                onSecondaryAction: () =>
                    ref.read(libraryEmptyStateProvider.notifier).toggle(),
              )
            : CustomScrollView(
                slivers: [
                  // Editorial Header & Toggle Pill
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasRealMusic
                                      ? 'Offline Library'
                                      : 'Master-Quality Audio',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasRealMusic
                                      ? '${realTracks.length} indexed lossless track${realTracks.length == 1 ? '' : 's'}'
                                      : 'Bit-perfect offline digital playback',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!hasRealMusic)
                            ActionChip(
                              avatar: const Icon(
                                Icons.visibility_outlined,
                                size: 14,
                              ),
                              label: const Text('Showcase Mode'),
                              visualDensity: VisualDensity.compact,
                              labelStyle: const TextStyle(fontSize: 11),
                              onPressed: () => ref
                                  .read(libraryEmptyStateProvider.notifier)
                                  .toggle(),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.sync_rounded),
                              tooltip: 'Rescan Audio Library',
                              onPressed: () => _handleScanImport(context, ref),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Featured Spotlight Card
                  if (activeTracks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Container(
                          padding: AppSpacing.insetsMd,
                          decoration: BoxDecoration(
                            gradient: sonora.cardGradient,
                            borderRadius: AppSpacing.roundedLg,
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              SonoraArtwork(
                                size: 96,
                                primaryColor: activeTracks.first.artworkColor,
                                accentColor: activeTracks.first.accentColor,
                                artworkPath: activeTracks.first.artworkPath,
                                showGlow: true,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FormatBadge(
                                      label: activeTracks.first.formatBadge,
                                      isGold: true,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      activeTracks.first.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${activeTracks.first.artist} • ${activeTracks.first.album}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    FilledButton.icon(
                                      onPressed: () => ref
                                          .read(playerProvider.notifier)
                                          .playTrack(
                                            activeTracks.first,
                                            queue: activeTracks,
                                          ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.darkAccent,
                                        foregroundColor: Colors.black,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.xs,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Play Spotlight',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Section: Recently Added / Played Carousel
                  if (activeTracks.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        title: hasRealMusic
                            ? 'Recently Added'
                            : 'Recently Played',
                        subtitle: hasRealMusic
                            ? 'Offline storage index'
                            : 'Direct hardware history',
                        actionLabel: 'See All',
                        onAction: () => context.go('/library'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 184,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          itemCount: activeTracks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final track = activeTracks[index];
                            final isCurrentlyActive =
                                playerState.track?.id == track.id;

                            return GestureDetector(
                              onTap: () => ref
                                  .read(playerProvider.notifier)
                                  .playTrack(track, queue: activeTracks),
                              child: SizedBox(
                                width: 124,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SonoraArtwork(
                                      size: 124,
                                      primaryColor: track.artworkColor,
                                      accentColor: track.accentColor,
                                      artworkPath: track.artworkPath,
                                      showGlow: isCurrentlyActive,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: isCurrentlyActive
                                                ? AppColors.darkAccent
                                                : theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                    ),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // Section: Curated Playlists
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sm),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Curated Playlists',
                      subtitle: 'Lossless collections',
                      actionLabel: 'New',
                      onAction: () => context.go('/library'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PlaylistCard(
                              title: 'Late Night Vinyl',
                              countText: 'Lossless Collection',
                              accentColor: const Color(0xFFE59866),
                              icon: Icons.graphic_eq_rounded,
                              onTap: () {
                                if (activeTracks.isNotEmpty) {
                                  ref
                                      .read(playerProvider.notifier)
                                      .playTrack(
                                        activeTracks.first,
                                        queue: activeTracks,
                                      );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _PlaylistCard(
                              title: 'High-Res Studio Masters',
                              countText: 'Direct DSD / FLAC',
                              accentColor: const Color(0xFFE5C07B),
                              icon: Icons.album_rounded,
                              onTap: () {
                                if (activeTracks.isNotEmpty) {
                                  ref
                                      .read(playerProvider.notifier)
                                      .playTrack(
                                        activeTracks.last,
                                        queue: activeTracks,
                                      );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Section: Library Track List
                  if (activeTracks.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        title: hasRealMusic
                            ? 'Indexed Tracks'
                            : 'Showcase Catalog',
                        subtitle: hasRealMusic
                            ? 'Saved in local SQLite database'
                            : 'Tap any track to preview player surface',
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final track = activeTracks[index];
                        final isSelected = playerState.track?.id == track.id;

                        return TrackTile(
                          track: track,
                          isPlaying: isSelected && playerState.isPlaying,
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playTrack(track, queue: activeTracks),
                        );
                      }, childCount: activeTracks.length),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.title,
    required this.countText,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String countText;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedMd,
        child: Container(
          padding: AppSpacing.insetsMd,
          decoration: BoxDecoration(
            color: sonora.surfaceElevated,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
