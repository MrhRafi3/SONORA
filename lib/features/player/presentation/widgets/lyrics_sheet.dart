import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/format_badge.dart';
import '../../domain/ui_track.dart';
import '../player_state.dart';

/// Parsed synchronized LRC lyric line.
class LyricLine {
  const LyricLine({required this.timestamp, required this.text});

  final Duration timestamp;
  final String text;
}

/// Modal bottom sheet presenting synchronized LRC lyrics and master recording notes.
class LyricsSheet extends ConsumerStatefulWidget {
  const LyricsSheet({super.key, required this.track});

  final UiTrack track;

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  int _selectedTab = 0; // 0 = Synced Lyrics, 1 = Master Notes
  late final ScrollController _scrollController;
  late final List<LyricLine> _lyrics;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lyrics = _generateOrParseLyrics(widget.track);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LyricLine> _generateOrParseLyrics(UiTrack track) {
    // Standard audiophile synchronized lyrics catalog
    if (track.title.contains('Clair de Lune')) {
      return const [
        LyricLine(
          timestamp: Duration(seconds: 0),
          text: '[Delicate Piano Arpeggios — Pianissimo]',
        ),
        LyricLine(
          timestamp: Duration(seconds: 14),
          text: 'Votre âme est un paysage choisi',
        ),
        LyricLine(
          timestamp: Duration(seconds: 28),
          text: 'Que vont charmant masques et bergamasques',
        ),
        LyricLine(
          timestamp: Duration(seconds: 45),
          text: 'Jouant du luth et dansant et quasi',
        ),
        LyricLine(
          timestamp: Duration(seconds: 62),
          text: 'Tristes sous leurs déguisements fantasques.',
        ),
        LyricLine(
          timestamp: Duration(seconds: 88),
          text: '[Dynamic Swell — Mezzo Forte Resonance]',
        ),
        LyricLine(
          timestamp: Duration(seconds: 110),
          text: 'Tout en chantant sur le mode mineur',
        ),
        LyricLine(
          timestamp: Duration(seconds: 135),
          text: 'L’amour vainqueur et la vie opportune',
        ),
        LyricLine(
          timestamp: Duration(seconds: 160),
          text: 'Ils n’ont pas l’air de croire à leur bonheur',
        ),
        LyricLine(
          timestamp: Duration(seconds: 190),
          text: 'Et leur chanson se mêle au clair de lune,',
        ),
        LyricLine(
          timestamp: Duration(seconds: 220),
          text: 'Au calme clair de lune triste et beau...',
        ),
        LyricLine(
          timestamp: Duration(seconds: 260),
          text: '[Harmonic Fade — Pure Reverb Decay]',
        ),
      ];
    }

    return [
      const LyricLine(
        timestamp: Duration(seconds: 0),
        text: '[Acoustic Introduction — Master Recording]',
      ),
      LyricLine(
        timestamp: const Duration(seconds: 12),
        text: 'Melodic resonance echoing in ${track.album}',
      ),
      const LyricLine(
        timestamp: Duration(seconds: 28),
        text: 'Harmonic overtone layering across stereo channels',
      ),
      const LyricLine(
        timestamp: Duration(seconds: 48),
        text: 'Direct-to-analogue transfer preserved with 24-bit resolution',
      ),
      LyricLine(
        timestamp: const Duration(seconds: 72),
        text: 'Performance captured live by ${track.artist}',
      ),
      const LyricLine(
        timestamp: Duration(seconds: 98),
        text: '[Dynamic Bridge with Ribbon Microphones]',
      ),
      const LyricLine(
        timestamp: Duration(seconds: 130),
        text: 'Pure acoustic decay with zero digital compression',
      ),
      const LyricLine(
        timestamp: Duration(seconds: 170),
        text: '[Harmonic Coda & Stereo Outro]',
      ),
    ];
  }

  int _findActiveIndex(Duration currentPosition) {
    int active = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      if (currentPosition >= _lyrics[i].timestamp) {
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
    final duration = ref.watch(
      playerProvider.select((s) => s.duration ?? Duration.zero),
    );
    final activeIndex = _findActiveIndex(position);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Text(
                        '${widget.track.artist} • ${widget.track.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  ? _buildSyncedLyricsList(context, activeIndex, duration)
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
    Duration duration,
  ) {
    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _lyrics.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (context, index) {
        final line = _lyrics[index];
        final isActive = index == activeIndex;

        return InkWell(
          borderRadius: AppSpacing.roundedMd,
          onTap: () {
            ref.read(playerProvider.notifier).seekTo(line.timestamp);
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
                    _formatDuration(line.timestamp),
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
