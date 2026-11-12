import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/models/lyrics_model.dart';

/// Modal dialog allowing the user to inspect synchronized or plain lyrics
/// before downloading and persisting them locally.
class LyricsPreviewDialog extends StatelessWidget {
  const LyricsPreviewDialog({
    super.key,
    required this.result,
    required this.onApply,
  });

  final LrclibSearchResult result;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    final parsedLines = TrackLyricsData.parseLrcString(
      result.syncedLyrics ?? '',
    );

    return Dialog(
      backgroundColor: sonora.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 480,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${result.artistName} • ${result.albumName.isNotEmpty ? result.albumName : "Single"}',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: result.isSynced
                          ? AppColors.darkAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.isSynced ? 'LRC Synced' : 'Plain Text',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: result.isSynced
                            ? AppColors.darkAccent
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Lyrics body
              Expanded(
                child: result.isSynced && parsedLines.isNotEmpty
                    ? ListView.builder(
                        itemCount: parsedLines.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final line = parsedLines[index];
                          final min = line.timestamp.inMinutes;
                          final sec = line.timestamp.inSeconds % 60;
                          final timeStr =
                              '$min:${sec.toString().padLeft(2, '0')}';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppColors.darkAccent.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    line.text,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          result.plainLyrics ??
                              (result.instrumental
                                  ? '[Instrumental Track]'
                                  : 'No text preview available'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.6,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkAccent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Save & Apply',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onApply();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
