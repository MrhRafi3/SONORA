import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../library/domain/entities.dart';
import '../../library/domain/smart_playlist.dart';
import '../../library/presentation/library_providers.dart';
import '../../player/domain/ui_track.dart';
import '../../player/presentation/player_state.dart';

/// Screen displaying the tracks within a custom or smart playlist.
/// Supports drag-and-drop reordering, track removal, renaming, and batch playback.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.initialTitle,
    this.isSmart = false,
  });

  final String playlistId;
  final String initialTitle;
  final bool isSmart;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
  }

  SmartPlaylistType? get _smartType {
    if (!widget.isSmart) return null;
    return SmartPlaylistType.values.cast<SmartPlaylistType?>().firstWhere(
      (t) => t?.id == widget.playlistId,
      orElse: () => null,
    );
  }

  Future<void> _showRenameDialog() async {
    final textController = TextEditingController(text: _title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.sonoraTheme.surfaceElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedLg,
          ),
          title: const Text('Rename Playlist'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New playlist name',
              prefixIcon: Icon(Icons.edit_rounded),
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
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && textController.text.trim().isNotEmpty) {
      final newName = textController.text.trim();
      final repo = ref.read(musicLibraryRepositoryProvider);
      await repo.renamePlaylist(widget.playlistId, newName);
      if (mounted) {
        setState(() => _title = newName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed playlist to "$newName"')),
        );
      }
    }
    textController.dispose();
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.sonoraTheme.surfaceElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedLg,
          ),
          title: const Text('Delete Playlist?'),
          content: Text(
            'Are you sure you want to delete "$_title"? Audio files on your device will remain intact.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkError,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(musicLibraryRepositoryProvider);
      await repo.deletePlaylist(widget.playlistId);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted playlist "$_title"')));
      }
    }
  }

  Future<void> _showAddTracksSheet(List<AudioTrack> currentTracks) async {
    final currentIds = currentTracks.map((t) => t.id).toSet();
    final allTracksAsync = ref.read(tracksStreamProvider);
    final availableTracks = (allTracksAsync.asData?.value ?? [])
        .where((t) => !currentIds.contains(t.id))
        .toList();

    if (availableTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All library tracks are already in this playlist.'),
        ),
      );
      return;
    }

    final selectedIds = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.sonoraTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.cornerLg),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Tracks (${selectedIds.length} selected)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        FilledButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => Navigator.pop(sheetContext),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkAccent,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Add Selected'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableTracks.length,
                        itemBuilder: (context, index) {
                          final track = availableTracks[index];
                          final isSelected = selectedIds.contains(track.id);

                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: AppColors.darkAccent,
                            checkColor: Colors.black,
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${track.displayArtist} • ${track.displayAlbum}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  selectedIds.add(track.id);
                                } else {
                                  selectedIds.remove(track.id);
                                }
                              });
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
      },
    );

    if (selectedIds.isNotEmpty) {
      final repo = ref.read(musicLibraryRepositoryProvider);
      for (final id in selectedIds) {
        await repo.addTrackToPlaylist(widget.playlistId, id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${selectedIds.length} track(s) to "$_title"'),
          ),
        );
      }
    }
  }

  void _playQueue(List<AudioTrack> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;
    final uiTracks = tracks.map((t) => t.toUiTrack()).toList();
    final queue = List<UiTrack>.from(uiTracks);
    if (shuffle) {
      queue.shuffle();
    }
    ref.read(playerProvider.notifier).playTrack(queue.first, queue: queue);
  }

  Widget _buildHeader(
    BuildContext context,
    SonoraThemeExtension sonora,
    ThemeData theme,
    List<AudioTrack> tracks,
    int minutes,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: AppSpacing.insetsLg,
      decoration: BoxDecoration(
        gradient: sonora.cardGradient,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (widget.isSmart
                              ? _smartType?.accentColor
                              : AppColors.darkAccent)!
                          .withValues(alpha: 0.18),
                ),
                child: Icon(
                  widget.isSmart
                      ? (_smartType?.icon ?? Icons.queue_music_rounded)
                      : Icons.queue_music_rounded,
                  color: widget.isSmart
                      ? _smartType?.accentColor
                      : AppColors.darkAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isSmart) ...[
                          const SizedBox(width: 8),
                          const FormatBadge(label: 'Smart', isGold: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tracks.length} track${tracks.length == 1 ? '' : 's'} • ~$minutes min total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _playQueue(tracks),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Play All',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _playQueue(tracks, shuffle: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkAccent,
                    side: const BorderSide(color: AppColors.darkAccent),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 20),
                  label: const Text(
                    'Shuffle',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final playerState = ref.watch(playerProvider);

    List<AudioTrack> tracks = [];
    bool isLoading = false;

    if (widget.isSmart && _smartType != null) {
      tracks = ref.watch(smartPlaylistTracksProvider(_smartType!));
    } else {
      final playlistAsync = ref.watch(
        playlistTracksStreamProvider(widget.playlistId),
      );
      tracks = playlistAsync.asData?.value ?? [];
      isLoading = playlistAsync.isLoading;
    }

    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + t.duration,
    );
    final minutes = totalDuration.inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (!widget.isSmart) ...[
            IconButton(
              tooltip: 'Add Tracks',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showAddTracksSheet(tracks),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'rename') {
                  _showRenameDialog();
                } else if (val == 'delete') {
                  _showDeleteDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Rename Playlist'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.darkError,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete Playlist',
                        style: TextStyle(color: AppColors.darkError),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tracks.isEmpty
          ? EmptyStateView(
              title: widget.isSmart
                  ? 'No Matching Tracks'
                  : 'Playlist is Empty',
              message: widget.isSmart
                  ? 'No audio files in your library currently meet the criteria for this smart collection.'
                  : 'Add your favorite master audio tracks to this playlist.',
              icon: widget.isSmart
                  ? (_smartType?.icon ?? Icons.queue_music_rounded)
                  : Icons.queue_music_rounded,
              actionLabel: widget.isSmart ? null : 'Add Tracks',
              onAction: widget.isSmart
                  ? null
                  : () => _showAddTracksSheet(tracks),
            )
          : !widget.isSmart
          ? ReorderableListView.builder(
              header: _buildHeader(context, sonora, theme, tracks, minutes),
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: tracks.length,
              onReorderItem: (oldIndex, newIndex) async {
                final reordered = List<AudioTrack>.from(tracks);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);

                final trackIds = reordered.map((t) => t.id).toList();
                final repo = ref.read(musicLibraryRepositoryProvider);
                await repo.reorderPlaylistTracks(widget.playlistId, trackIds);
              },
              itemBuilder: (context, index) {
                final track = tracks[index];
                final uiTrack = track.toUiTrack();
                final isPlaying =
                    playerState.track?.id == track.id && playerState.isPlaying;

                return Dismissible(
                  key: ValueKey(track.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.darkError,
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    final repo = ref.read(musicLibraryRepositoryProvider);
                    await repo.removeTrackFromPlaylist(
                      widget.playlistId,
                      track.id,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Removed "${track.title}" from playlist',
                          ),
                        ),
                      );
                    }
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Row(
                      key: ValueKey('row_${track.id}'),
                      children: [
                        Expanded(
                          child: TrackTile(
                            track: uiTrack,
                            isPlaying: isPlaying,
                            trackIndex: index + 1,
                            onTap: () => ref
                                .read(playerProvider.notifier)
                                .playTrack(
                                  uiTrack,
                                  queue: tracks
                                      .map((t) => t.toUiTrack())
                                      .toList(),
                                ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: AppColors.darkTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: tracks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(context, sonora, theme, tracks, minutes);
                }
                final track = tracks[index - 1];
                final uiTrack = track.toUiTrack();
                final isPlaying =
                    playerState.track?.id == track.id && playerState.isPlaying;

                return TrackTile(
                  track: uiTrack,
                  isPlaying: isPlaying,
                  trackIndex: index,
                  onTap: () => ref
                      .read(playerProvider.notifier)
                      .playTrack(
                        uiTrack,
                        queue: tracks.map((t) => t.toUiTrack()).toList(),
                      ),
                );
              },
            ),
    );
  }
}
