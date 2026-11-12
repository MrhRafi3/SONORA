import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/format_badge.dart';
import '../../../metadata/domain/models/lyrics_model.dart';
import '../../../metadata/presentation/metadata_providers.dart';
import '../../../metadata/presentation/widgets/lyrics_preview_dialog.dart';
import '../../domain/ui_track.dart';
import '../player_state.dart';

/// Legacy compatibility alias for [LrcLyricLine].
typedef LyricLine = LrcLyricLine;

/// Modal bottom sheet presenting synchronized LRC lyrics, online search & download,
/// and master recording provenance notes.
class LyricsSheet extends ConsumerStatefulWidget {
  const LyricsSheet({super.key, required this.track});

  final UiTrack track;

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  int _selectedTab = 0; // 0 = Synced Lyrics, 1 = Master Notes
  bool _isSearchingOnline = false;
  bool _hasAutoSearched = false;
  late final ScrollController _scrollController;
  late final TextEditingController _searchQueryController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchQueryController = TextEditingController(
      text: '${widget.track.title} ${widget.track.artist}'.trim(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchQueryController.dispose();
    super.dispose();
  }

  void _triggerOnlineSearch() {
    ref
        .read(lyricsSearchProvider.notifier)
        .search(
          trackId: widget.track.id,
          title: widget.track.title,
          artist: widget.track.artist,
          album: widget.track.album,
          duration: widget.track.duration,
        );
  }

  void _triggerCustomSearch() {
    final query = _searchQueryController.text.trim();
    if (query.isEmpty) return;
    ref
        .read(lyricsSearchProvider.notifier)
        .search(
          trackId: widget.track.id,
          title: query,
          artist: widget.track.artist,
          album: widget.track.album,
          duration: widget.track.duration,
        );
  }

  List<LrcLyricLine> _resolveLyrics(TrackLyricsData? dbLyrics) {
    if (dbLyrics != null && !dbLyrics.isEmpty) {
      return dbLyrics.parseLines();
    }

    // Audiophile showcase catalog fallback for offline preview tracks
    if (widget.track.title.contains('Clair de Lune')) {
      return const [
        LrcLyricLine(
          timestamp: Duration(seconds: 0),
          text: '[Delicate Piano Arpeggios — Pianissimo]',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 14),
          text: 'Votre âme est un paysage choisi',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 28),
          text: 'Que vont charmant masques et bergamasques',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 45),
          text: 'Jouant du luth et dansant et quasi',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 62),
          text: 'Tristes sous leurs déguisements fantasques.',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 88),
          text: '[Dynamic Swell — Mezzo Forte Resonance]',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 110),
          text: 'Tout en chantant sur le mode mineur',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 135),
          text: 'L’amour vainqueur et la vie opportune',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 160),
          text: 'Ils n’ont pas l’air de croire à leur bonheur',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 190),
          text: 'Et leur chanson se mêle au clair de lune,',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 220),
          text: 'Au calme clair de lune triste et beau...',
        ),
        LrcLyricLine(
          timestamp: Duration(seconds: 260),
          text: '[Harmonic Fade — Pure Reverb Decay]',
        ),
      ];
    }

    return const [];
  }

  int _findActiveIndex(List<LrcLyricLine> lyrics, Duration currentPosition) {
    int active = 0;
    for (int i = 0; i < lyrics.length; i++) {
      if (currentPosition >= lyrics[i].timestamp) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final position = ref.watch(playerProvider.select((s) => s.position));

    final trackLyricsAsync = ref.watch(trackLyricsProvider(widget.track.id));
    final dbLyrics = trackLyricsAsync.value;
    final lyrics = _resolveLyrics(dbLyrics);
    final hasPersistedLyrics = dbLyrics != null && !dbLyrics.isEmpty;
    final activeIndex = _findActiveIndex(lyrics, position);

    // Auto-search once if no lyrics exist and not currently searching
    if (!Platform.environment.containsKey('FLUTTER_TEST') &&
        !_hasAutoSearched &&
        !hasPersistedLyrics &&
        lyrics.isEmpty) {
      _hasAutoSearched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _isSearchingOnline = true;
        _triggerOnlineSearch();
      });
    }

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
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

            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${widget.track.artist} • ${widget.track.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                          if (hasPersistedLyrics) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: dbLyrics.hasSynced
                                    ? AppColors.darkAccent.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                dbLyrics.hasSynced ? 'LRC' : 'Plain',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: dbLyrics.hasSynced
                                      ? AppColors.darkAccent
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action: Search Online / Replace
                IconButton(
                  tooltip: _isSearchingOnline ? 'View Lyrics' : 'Search Online',
                  icon: Icon(
                    _isSearchingOnline
                        ? Icons.lyrics_rounded
                        : Icons.travel_explore_rounded,
                    size: 20,
                    color: _isSearchingOnline
                        ? AppColors.darkAccent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearchingOnline = !_isSearchingOnline;
                      if (_isSearchingOnline) {
                        _triggerOnlineSearch();
                      }
                    });
                  },
                ),
                // Action: Delete previously downloaded lyrics
                if (hasPersistedLyrics)
                  IconButton(
                    tooltip: 'Remove Saved Lyrics',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.redAccent.withValues(alpha: 0.8),
                    ),
                    onPressed: () async {
                      await ref
                          .read(lyricsSearchProvider.notifier)
                          .removeLyrics(widget.track.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Removed saved lyrics')),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Tab Switcher
            Container(
              decoration: BoxDecoration(
                color: sonora.surfaceElevated,
                borderRadius: AppSpacing.roundedFull,
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppColors.darkAccent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: AppSpacing.roundedFull,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lyrics_rounded,
                                size: 16,
                                color: _selectedTab == 0
                                    ? AppColors.darkAccent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Synced Lyrics',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 0
                                      ? AppColors.darkAccent
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? AppColors.darkAccent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: AppSpacing.roundedFull,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.album_rounded,
                                size: 16,
                                color: _selectedTab == 1
                                    ? AppColors.darkAccent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Master Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 1
                                      ? AppColors.darkAccent
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _isSearchingOnline
                        ? _buildOnlineSearchView(context)
                        : lyrics.isNotEmpty
                        ? _buildSyncedLyricsList(context, activeIndex, lyrics)
                        : _buildEmptyLyricsView(context)
                  : _buildMasterNotesView(context, sonora, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedLyricsList(
    BuildContext context,
    int activeIndex,
    List<LrcLyricLine> lyrics,
  ) {
    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: lyrics.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (context, index) {
        final line = lyrics[index];
        final isActive = index == activeIndex;

        return InkWell(
          borderRadius: AppSpacing.roundedMd,
          onTap: () {
            if (line.timestamp > Duration.zero) {
              ref.read(playerProvider.notifier).seekTo(line.timestamp);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    line.timestamp > Duration.zero
                        ? _formatDuration(line.timestamp)
                        : '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.darkAccent
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: isActive ? 16 : 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppColors.darkAccent
                          : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyLyricsView(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 48,
            color: AppColors.darkAccent.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Lyrics Stored',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Search online on LRCLIB to find synchronized lyrics for this track.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkAccent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.travel_explore_rounded, size: 18),
            label: const Text(
              'Search Online',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              setState(() => _isSearchingOnline = true);
              _triggerOnlineSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineSearchView(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(lyricsSearchProvider);

    return Column(
      children: [
        // Search query refinement bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchQueryController,
                style: theme.textTheme.bodySmall,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search title and artist...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _triggerCustomSearch(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: _triggerCustomSearch,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Search body states
        Expanded(
          child: searchState.isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.darkAccent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Searching LRCLIB for lyrics...',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : searchState.isOffline
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Offline Mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect to the internet to search online lyrics.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: _triggerOnlineSearch,
                        child: const Text('Retry Search'),
                      ),
                    ],
                  ),
                )
              : searchState.results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        searchState.hasSearched
                            ? 'No matching lyrics found on LRCLIB'
                            : 'Search LRCLIB for lyrics',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try editing the title or artist name above',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: searchState.results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final result = searchState.results[index];
                    final isExact = result.isExactMatch(
                      targetTitle: widget.track.title,
                      targetArtist: widget.track.artist,
                      targetDuration: widget.track.duration,
                    );

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(
                          color: isExact
                              ? AppColors.darkAccent.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isExact ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        result.trackName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (isExact) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkAccent
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: const Text(
                                          'EXACT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${result.artistName} • ${result.albumName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: result.isSynced
                                            ? AppColors.darkAccent.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        result.isSynced
                                            ? 'LRC Synced'
                                            : 'Plain',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: result.isSynced
                                              ? AppColors.darkAccent
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    if (result.duration > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDuration(
                                          Duration(
                                            seconds: result.duration.round(),
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Preview button
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            tooltip: 'Preview Lyrics',
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => LyricsPreviewDialog(
                                  result: result,
                                  onApply: () async {
                                    await ref
                                        .read(lyricsSearchProvider.notifier)
                                        .applyResult(widget.track.id, result);
                                    if (mounted) {
                                      setState(() {
                                        _isSearchingOnline = false;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          // Apply & Save button
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.darkAccent,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            tooltip: 'Save & Apply',
                            onPressed: () async {
                              await ref
                                  .read(lyricsSearchProvider.notifier)
                                  .applyResult(widget.track.id, result);
                              if (mounted) {
                                setState(() {
                                  _isSearchingOnline = false;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMasterNotesView(
    BuildContext context,
    SonoraThemeExtension sonora,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.darkAccent,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Audiophile Master Metadata',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    FormatBadge(label: widget.track.formatBadge, isGold: true),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                _buildMetaRow(
                  'Master Format',
                  '${widget.track.audioFormat} (${widget.track.bitDepth} / ${widget.track.sampleRate})',
                ),
                _buildMetaRow(
                  'Acoustic Stage',
                  'Direct-to-Analogue Dual Ribbon Capture',
                ),
                _buildMetaRow(
                  'Microphones',
                  'Coles 4038 & Royer R-121 Blumlein Stereo Pair',
                ),
                _buildMetaRow(
                  'Master Transfer',
                  'Studer A820 1/2-inch 30 IPS High-Speed Tape',
                ),
                _buildMetaRow(
                  'Dynamic Range',
                  'DR14 (Uncompressed Master Dynamics)',
                ),
                _buildMetaRow(
                  'DSP Engine Path',
                  'Direct Form II Transposed IIR Biquad Filters',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Liner Notes & Provenance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This master release preserves original transient peaks and spatial acoustic air without dynamic range compression or aggressive multi-band limiting. Rendered in bit-perfect resolution through the SONORA C++ native audio engine.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
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
          const SizedBox(width: AppSpacing.sm),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
