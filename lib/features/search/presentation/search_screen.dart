import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/search_bar_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../library/presentation/library_providers.dart';
import '../../player/domain/ui_track.dart';
import '../../player/presentation/player_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _recentSearches = [
    'Debussy',
    'Direct DSD Master',
    'Acoustic Guitar',
    'FLAC 24-bit',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value.trim());
  }

  void _applyRecentSearch(String term) {
    _searchController.text = term;
    ref.read(searchQueryProvider.notifier).setQuery(term.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final activeQuery = ref.watch(searchQueryProvider);
    final isShowcaseActive = ref.watch(libraryEmptyStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: SearchBarField(
                controller: _searchController,
                hintText: 'Search songs, albums, artists, or audio format...',
                onChanged: _onSearch,
                onClear: _clearSearch,
              ),
            ),
            Expanded(
              child: activeQuery.isNotEmpty
                  ? _SearchResultsView(
                      query: activeQuery,
                      isShowcaseActive: isShowcaseActive,
                      playerState: playerState,
                      onClear: _clearSearch,
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        // Recent Searches
                        if (_recentSearches.isNotEmpty) ...[
                          SectionHeader(
                            title: 'Recent Searches',
                            actionLabel: 'Clear',
                            onAction: () =>
                                setState(() => _recentSearches = []),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: _recentSearches.map((term) {
                                return ActionChip(
                                  avatar: const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                  ),
                                  label: Text(term),
                                  onPressed: () => _applyRecentSearch(term),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Audiophile Categories / Formats
                        const SectionHeader(
                          title: 'Explore High-Resolution Formats',
                          subtitle: 'Quick filters for audiophile indexing',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 2.4,
                            children: [
                              _CategoryCard(
                                title: 'Lossless FLAC',
                                subtitle: '24-bit / 96–192 kHz',
                                icon: Icons.graphic_eq_rounded,
                                color: AppColors.darkAccent,
                                onTap: () => _applyRecentSearch('FLAC'),
                              ),
                              _CategoryCard(
                                title: 'Direct DSD',
                                subtitle: 'Super Audio CD masters',
                                icon: Icons.album_rounded,
                                color: AppColors.darkAccentGold,
                                onTap: () => _applyRecentSearch('DSD'),
                              ),
                              _CategoryCard(
                                title: 'Chamber & Classical',
                                subtitle: 'Dynamic range recordings',
                                icon: Icons.music_note_rounded,
                                color: const Color(0xFF5DADE2),
                                onTap: () => _applyRecentSearch('Debussy'),
                              ),
                              _CategoryCard(
                                title: 'Acoustic Guitar',
                                subtitle: 'Ribbon microphone captures',
                                icon: Icons.audiotrack_rounded,
                                color: const Color(0xFF4EBA6F),
                                onTap: () => _applyRecentSearch('Acoustic'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({
    required this.query,
    required this.isShowcaseActive,
    required this.playerState,
    required this.onClear,
  });

  final String query;
  final bool isShowcaseActive;
  final PlayerState playerState;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return searchResultsAsync.when(
      data: (tracks) {
        List<UiTrack> uiTracks = tracks.map((t) => t.toUiTrack()).toList();

        // If real DB has no matches and showcase is active, filter showcase tracks
        if (uiTracks.isEmpty && isShowcaseActive) {
          final q = query.toLowerCase();
          uiTracks = kShowcaseTracks.where((t) {
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q) ||
                t.audioFormat.toLowerCase().contains(q);
          }).toList();
        }

        if (uiTracks.isEmpty) {
          return EmptyStateView(
            title: 'No Matching Audio',
            message:
                'We could not find any tracks matching "$query". Try searching for artist, genre, or format.',
            icon: Icons.search_off_rounded,
            actionLabel: 'Clear Search',
            onAction: onClear,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: uiTracks.length,
          itemBuilder: (context, index) {
            final track = uiTracks[index];
            final isPlaying =
                playerState.track?.id == track.id && playerState.isPlaying;

            return TrackTile(
              track: track,
              isPlaying: isPlaying,
              onTap: () => ref
                  .read(playerProvider.notifier)
                  .playTrack(track, queue: uiTracks),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Search error: $err')),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: sonora.surfaceElevated,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
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
    );
  }
}
