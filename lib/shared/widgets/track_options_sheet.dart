import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../features/library/presentation/library_providers.dart';
import '../../features/metadata/presentation/widgets/artwork_selector_dialog.dart';
import '../../features/player/domain/ui_track.dart';
import '../../features/player/presentation/player_state.dart';
import 'sonora_artwork.dart';

/// Opens a context actions sheet for [track]: Play Next, Add to Queue,
/// Toggle Favorite, and Add to Playlist.
Future<void> showTrackOptionsSheet(
  BuildContext context,
  WidgetRef ref,
  UiTrack track,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sonoraTheme.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SonoraArtwork(
                    size: 48,
                    primaryColor: track.artworkColor,
                    accentColor: track.accentColor,
                    artworkPath: track.artworkPath,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${track.artist} • ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Play Next'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(playerProvider.notifier).playNext(track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Queued "${track.title}" to play next'),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue_rounded),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(playerProvider.notifier).addToQueue(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added "${track.title}" to queue')),
                );
              },
            ),
            ListTile(
              leading: Icon(
                track.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: track.isFavorite ? AppColors.darkAccent : null,
              ),
              title: Text(
                track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final newFav = !track.isFavorite;
                ref
                    .read(playerProvider.notifier)
                    .syncTrackFavorite(track.id, newFav);
                try {
                  await ref
                      .read(musicLibraryRepositoryProvider)
                      .toggleFavorite(track.id, newFav);
                } catch (_) {
                  // Ignore if showcase track is not stored in SQLite
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showPlaylistPicker(context, ref, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search_rounded),
              title: const Text('Find Album Artwork'),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog<void>(
                  context: context,
                  builder: (ctx) => ArtworkSelectorDialog(
                    artist: track.artist,
                    album: track.album,
                    trackTitle: track.title,
                    onArtworkApplied: (savedPath) {
                      ref
                          .read(playerProvider.notifier)
                          .updateArtworkForAlbum(
                            artist: track.artist,
                            album: track.album,
                            artworkPath: savedPath,
                          );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      );
    },
  );
}

Future<void> _showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  UiTrack track,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sonoraTheme.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
    ),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, modalRef, _) {
          final playlistsAsync = modalRef.watch(playlistsStreamProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add to Playlist',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _createAndAdd(context, ref, track);
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  playlistsAsync.when(
                    data: (playlists) {
                      if (playlists.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'No custom playlists yet. Tap "New" to create one.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        );
                      }
                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final pl = playlists[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.queue_music_rounded,
                                color: AppColors.darkAccent,
                              ),
                              title: Text(pl.name),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                try {
                                  await ref
                                      .read(musicLibraryRepositoryProvider)
                                      .addTrackToPlaylist(pl.id, track.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added "${track.title}" to "${pl.name}"',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not add track to playlist: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text('Error loading playlists: $e'),
                    ),
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

Future<void> _createAndAdd(
  BuildContext context,
  WidgetRef ref,
  UiTrack track,
) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: dialogContext.sonoraTheme.surfaceElevated,
        shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            prefixIcon: Icon(Icons.queue_music_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      );
    },
  );

  if (confirmed == true && controller.text.trim().isNotEmpty) {
    final name = controller.text.trim();
    final repo = ref.read(musicLibraryRepositoryProvider);
    final created = await repo.createPlaylist(name);
    try {
      await repo.addTrackToPlaylist(created.id, track.id);
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created "$name" and added "${track.title}"')),
      );
    }
  }
  controller.dispose();
}
