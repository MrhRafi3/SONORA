import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/models/artwork_match.dart';
import '../metadata_providers.dart';

/// Modal dialog allowing the user to search and manually select missing album artwork
/// across online metadata providers (iTunes, Deezer, MusicBrainz).
class ArtworkSelectorDialog extends ConsumerStatefulWidget {
  const ArtworkSelectorDialog({
    super.key,
    required this.artist,
    required this.album,
    this.trackTitle,
    this.initialMatches = const [],
    required this.onArtworkApplied,
  });

  final String artist;
  final String album;
  final String? trackTitle;
  final List<ArtworkMatch> initialMatches;
  final ValueChanged<String> onArtworkApplied;

  @override
  ConsumerState<ArtworkSelectorDialog> createState() =>
      _ArtworkSelectorDialogState();
}

class _ArtworkSelectorDialogState extends ConsumerState<ArtworkSelectorDialog> {
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _artistController = TextEditingController(text: widget.artist);
    _albumController = TextEditingController(text: widget.album);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMatches.isEmpty) {
        _triggerSearch();
      }
    });
  }

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    ref
        .read(artworkSearchProvider.notifier)
        .search(
          artist: _artistController.text.trim(),
          album: _albumController.text.trim(),
          trackTitle: widget.trackTitle,
        );
  }

  Future<void> _selectMatch(ArtworkMatch match) async {
    setState(() => _isDownloading = true);
    try {
      final savedPath = await ref
          .read(artworkSearchProvider.notifier)
          .applyMatch(artist: widget.artist, album: widget.album, match: match);

      if (mounted) {
        setState(() => _isDownloading = false);
        if (savedPath != null) {
          widget.onArtworkApplied(savedPath);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Applied artwork from ${match.providerDisplayName}',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download artwork image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final searchState = ref.watch(artworkSearchProvider);

    final displayMatches =
        widget.initialMatches.isNotEmpty && !searchState.hasSearched
        ? widget.initialMatches
        : searchState.matches;

    return Dialog(
      backgroundColor: sonora.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.image_search_rounded,
                        color: AppColors.darkAccent,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Select Album Artwork',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Search query fields
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _artistController,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Artist',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _albumController,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Album',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.search_rounded, size: 20),
                    onPressed: _triggerSearch,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),

              // Content Area
              Expanded(
                child: _isDownloading
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
                              'Downloading and caching artwork...',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : searchState.isLoading
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
                              'Searching iTunes, Deezer & MusicBrainz...',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : displayMatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No artwork found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting the artist or album name above',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.82,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                        itemCount: displayMatches.length,
                        itemBuilder: (context, index) {
                          final match = displayMatches[index];
                          final confidencePct = (match.confidence * 100)
                              .round();

                          return InkWell(
                            borderRadius: AppSpacing.roundedMd,
                            onTap: () => _selectMatch(match),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: AppSpacing.roundedMd,
                                border: Border.all(
                                  color: match.isHighConfidence
                                      ? AppColors.darkAccent.withValues(
                                          alpha: 0.6,
                                        )
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: match.isHighConfidence ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                      child: Image.network(
                                        match.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Icon(
                                            Icons.album_rounded,
                                            size: 40,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(AppColors.darkAccent),
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          match.album,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          match.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              match.providerDisplayName,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: AppColors.darkAccent
                                                    .withValues(alpha: 0.8),
                                              ),
                                            ),
                                            Text(
                                              '$confidencePct% match',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: match.isHighConfidence
                                                    ? Colors.green
                                                    : Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
