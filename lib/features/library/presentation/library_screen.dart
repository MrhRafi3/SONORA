import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../../shared/widgets/sonora_artwork.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../player/presentation/player_state.dart';

enum LibrarySortOption {
  title('Title (A–Z)'),
  artist('Artist'),
  dateAdded('Date Added'),
  duration('Duration'),
  sampleRate('Sample Rate / Bitrate');

  const LibrarySortOption(this.label);
  final String label;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  LibrarySortOption _selectedSort = LibrarySortOption.title;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort Library By',
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
                const SizedBox(height: AppSpacing.sm),
                ...LibrarySortOption.values.map(
                  (option) => ListTile(
                    title: Text(option.label),
                    selected: _selectedSort == option,
                    selectedColor: AppColors.darkAccent,
                    trailing: _selectedSort == option
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.darkAccent,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedSort = option);
                      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final isLibraryEmpty = ref.watch(libraryEmptyStateProvider);
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Library'),
        actions: [
          IconButton(
            tooltip: 'Search Library',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            tooltip: 'Sort Options',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
          IconButton(
            tooltip: 'Toggle Empty State',
            icon: Icon(
              isLibraryEmpty
                  ? Icons.check_box_outline_blank_rounded
                  : Icons.check_box_rounded,
            ),
            onPressed: () =>
                ref.read(libraryEmptyStateProvider.notifier).toggle(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.darkAccent,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.darkAccent,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.5,
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Playlists'),
          ],
        ),
      ),
      body: isLibraryEmpty
          ? EmptyStateView(
              title: 'No Audio Files Found',
              message:
                  'No tracks have been imported. Once device scanning is activated in Phase 03, all supported audio formats will populate here.',
              icon: Icons.library_music_outlined,
              actionLabel: 'Scan Device Storage',
              onAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Storage indexer will be wired in Phase 03.'),
                  ),
                );
              },
              secondaryActionLabel: 'Return to Showcase Mode',
              onSecondaryAction: () =>
                  ref.read(libraryEmptyStateProvider.notifier).toggle(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Songs Tab
                ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: kShowcaseTracks.length,
                  itemBuilder: (context, index) {
                    final track = kShowcaseTracks[index];
                    final isPlaying =
                        playerState.track?.id == track.id &&
                        playerState.isPlaying;

                    return TrackTile(
                      track: track,
                      isPlaying: isPlaying,
                      trackIndex: index + 1,
                      onTap: () =>
                          ref.read(playerProvider.notifier).playTrack(track),
                    );
                  },
                ),

                // 2. Albums Tab
                GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: kShowcaseTracks.length,
                  itemBuilder: (context, index) {
                    final track = kShowcaseTracks[index];
                    return GestureDetector(
                      onTap: () =>
                          ref.read(playerProvider.notifier).playTrack(track),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SonoraArtwork(
                              size: double.infinity,
                              primaryColor: track.artworkColor,
                              accentColor: track.accentColor,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            track.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FormatBadge(label: track.audioFormat),
                        ],
                      ),
                    );
                  },
                ),

                // 3. Artists Tab
                ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: kShowcaseTracks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final track = kShowcaseTracks[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            ref.read(playerProvider.notifier).playTrack(track),
                        borderRadius: AppSpacing.roundedMd,
                        child: Container(
                          padding: AppSpacing.insetsMd,
                          decoration: BoxDecoration(
                            color: sonora.surfaceElevated,
                            borderRadius: AppSpacing.roundedMd,
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: track.artworkColor,
                                  border: Border.all(
                                    color: track.accentColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: track.accentColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.artist,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      'Master Audio Collection',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 4. Playlists Tab
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Custom playlist creator will be integrated in Phase 03.',
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: sonora.surfaceElevated,
                        foregroundColor: AppColors.darkAccent,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppSpacing.roundedMd,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create New Lossless Playlist'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...kShowcaseTracks.take(3).map((track) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TrackTile(
                          track: track,
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playTrack(track),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }
}
