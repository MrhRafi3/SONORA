import 'dart:io';
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
import '../../player/domain/ui_track.dart';
import '../../player/presentation/player_state.dart';
import 'library_providers.dart';

enum LibrarySortOption {
  title('Title', 'title'),
  artist('Artist', 'artist'),
  album('Album', 'album'),
  dateAdded('Date Added', 'dateAdded'),
  duration('Duration', 'duration');

  const LibrarySortOption(this.label, this.key);
  final String label;
  final String key;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  Future<void> _handleScanImport() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Starting audio discovery...')),
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
                ? 'Scan complete: discovered ${summary.newlyAddedCount} tracks.'
                : (summary.errorMessage ?? 'Audio scan failed.'),
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
                ? 'Import complete: added ${summary.newlyAddedCount} audio files.'
                : (summary.errorMessage ?? 'Audio import failed.'),
          ),
        ),
      );
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final textController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.sonoraTheme.surfaceElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedLg,
          ),
          title: const Text('Create New Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              prefixIcon: Icon(Icons.queue_music_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created == true && textController.text.trim().isNotEmpty) {
      final name = textController.text.trim();
      final repo = ref.read(musicLibraryRepositoryProvider);
      await repo.createPlaylist(name);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Created playlist "$name"')));
      }
    }
    textController.dispose();
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final activeSort = ref.watch(librarySortProvider);
            final activeAsc = ref.watch(librarySortAscendingProvider);

            return SafeArea(
              child: SingleChildScrollView(
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...LibrarySortOption.values.map(
                      (option) => ListTile(
                        title: Text(option.label),
                        selected: activeSort == option.key,
                        selectedColor: AppColors.darkAccent,
                        trailing: activeSort == option.key
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.darkAccent,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(librarySortProvider.notifier)
                              .setSort(option.key);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      title: const Text('Ascending Order'),
                      value: activeAsc,
                      activeTrackColor: AppColors.darkAccent,
                      onChanged: (val) {
                        ref
                            .read(librarySortAscendingProvider.notifier)
                            .setAscending(val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShowcaseActive = ref.watch(libraryEmptyStateProvider);
    final playerState = ref.watch(playerProvider);

    final tracksAsync = ref.watch(tracksStreamProvider);
    final realTracks = tracksAsync.asData?.value ?? [];
    final hasRealMusic = realTracks.isNotEmpty;
    final displayShowcase = isShowcaseActive && !hasRealMusic;

    final activeUiTracks = hasRealMusic
        ? realTracks.map((t) => t.toUiTrack()).toList()
        : (displayShowcase ? kShowcaseTracks : <UiTrack>[]);

    final isScanning = ref.watch(scanStatusProvider).isScanning;

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
            tooltip: Platform.isAndroid ? 'Scan MediaStore' : 'Import Audio',
            icon: isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: isScanning ? null : _handleScanImport,
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
      body: activeUiTracks.isEmpty
          ? EmptyStateView(
              title: 'No Audio Files Found',
              message:
                  'No tracks have been imported. Scan your device storage or import audio files to begin listening in bit-perfect fidelity.',
              icon: Icons.library_music_outlined,
              actionLabel: Platform.isAndroid
                  ? 'Scan Device Storage'
                  : 'Import Audio Files',
              onAction: _handleScanImport,
              secondaryActionLabel: isShowcaseActive
                  ? 'Hide Sample Music'
                  : 'Show Sample Music',
              onSecondaryAction: () =>
                  ref.read(libraryEmptyStateProvider.notifier).toggle(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Songs Tab
                ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: activeUiTracks.length,
                  itemBuilder: (context, index) {
                    final track = activeUiTracks[index];
                    final isPlaying =
                        playerState.track?.id == track.id &&
                        playerState.isPlaying;

                    return TrackTile(
                      track: track,
                      isPlaying: isPlaying,
                      trackIndex: index + 1,
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .playTrack(track, queue: activeUiTracks),
                    );
                  },
                ),

                // 2. Albums Tab
                _AlbumsView(
                  hasRealMusic: hasRealMusic,
                  showcaseTracks: activeUiTracks,
                ),

                // 3. Artists Tab
                _ArtistsView(
                  hasRealMusic: hasRealMusic,
                  showcaseTracks: activeUiTracks,
                ),

                // 4. Playlists Tab
                _PlaylistsView(onCreatePlaylist: _showCreatePlaylistDialog),
              ],
            ),
    );
  }
}

class _AlbumsView extends ConsumerWidget {
  const _AlbumsView({required this.hasRealMusic, required this.showcaseTracks});

  final bool hasRealMusic;
  final List<UiTrack> showcaseTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (hasRealMusic) {
      final albumsAsync = ref.watch(albumsProvider);
      return albumsAsync.when(
        data: (albums) {
          if (albums.isEmpty) {
            return const Center(child: Text('No albums indexed.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.76,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SonoraArtwork(
                      size: double.infinity,
                      artworkPath: album.artworkPath,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FormatBadge(label: '${album.trackCount} tracks'),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading albums: $err')),
      );
    }

    // Showcase fallback
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.76,
      ),
      itemCount: showcaseTracks.length,
      itemBuilder: (context, index) {
        final track = showcaseTracks[index];
        return GestureDetector(
          onTap: () => ref
              .read(playerProvider.notifier)
              .playTrack(track, queue: showcaseTracks),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SonoraArtwork(
                  size: double.infinity,
                  artworkPath: track.artworkPath,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              FormatBadge(label: track.audioFormat),
            ],
          ),
        );
      },
    );
  }
}

class _ArtistsView extends ConsumerWidget {
  const _ArtistsView({
    required this.hasRealMusic,
    required this.showcaseTracks,
  });

  final bool hasRealMusic;
  final List<UiTrack> showcaseTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    if (hasRealMusic) {
      final artistsAsync = ref.watch(artistsProvider);
      return artistsAsync.when(
        data: (artists) {
          if (artists.isEmpty) {
            return const Center(child: Text('No artists indexed.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: artists.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Container(
                padding: AppSpacing.insetsMd,
                decoration: BoxDecoration(
                  color: sonora.surfaceElevated,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
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
                        color: AppColors.darkSurfaceElevated,
                        border: Border.all(
                          color: AppColors.darkAccent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.darkAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artist.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${artist.trackCount} tracks • ${artist.albumCount} albums',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading artists: $err')),
      );
    }

    // Showcase fallback
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: showcaseTracks.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final track = showcaseTracks[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ref
                .read(playerProvider.notifier)
                .playTrack(track, queue: showcaseTracks),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: track.artworkColor,
                      border: Border.all(
                        color: track.accentColor.withValues(alpha: 0.5),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Master Audio Collection',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
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
    );
  }
}

class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView({required this.onCreatePlaylist});

  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final playlistsAsync = ref.watch(playlistsStreamProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        FilledButton.tonalIcon(
          onPressed: onCreatePlaylist,
          style: FilledButton.styleFrom(
            backgroundColor: sonora.surfaceElevated,
            foregroundColor: AppColors.darkAccent,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.roundedMd,
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create New Playlist'),
        ),
        const SizedBox(height: AppSpacing.md),
        playlistsAsync.when(
          data: (playlists) {
            if (playlists.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'No custom playlists yet.\nTap above to create one.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  tileColor: sonora.surfaceElevated,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.darkAccent.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: AppColors.darkAccent,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Created ${_formatDate(playlist.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () async {
                      await ref
                          .read(musicLibraryRepositoryProvider)
                          .deletePlaylist(playlist.id);
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading playlists: $err'),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
