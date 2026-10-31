import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../../../library/presentation/library_providers.dart';

/// Subpage for music library scanning, SQLite database stats, and local storage.
class LibraryStorageSettingsScreen extends ConsumerWidget {
  const LibraryStorageSettingsScreen({super.key});

  Future<void> _handleRescan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Starting audio library scan...')),
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
                ? 'Scan complete: discovered ${summary.newlyAddedCount} new tracks.'
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);
    final isScanning = ref.watch(scanStatusProvider).isScanning;

    return Scaffold(
      appBar: AppBar(title: const Text('Library & Storage')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            const SectionHeader(
              title: 'Database Statistics',
              subtitle: 'Indexed SQLite collection metrics',
            ),
            SettingsTile(
              title: 'Indexed Library Stats',
              subtitle:
                  '${stats.trackCount} tracks • ${stats.albumCount} albums • ${stats.formattedStorageSize}',
              icon: Icons.analytics_outlined,
            ),
            SettingsTile(
              title: 'Database Architecture',
              subtitle:
                  'Drift 2.35 • SQLite with Title, Artist, Date & Duration B-Tree indexes',
              icon: Icons.table_chart_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(
              title: 'Local Storage & Discovery',
              subtitle: 'Platform-specific storage integration',
            ),
            SettingsTile(
              title: 'Music Folders & Platform Storage',
              subtitle: Platform.isAndroid
                  ? 'Android MediaStore & Scoped Storage (/Music, /Audio)'
                  : 'iOS Sandboxed Documents Directory & File Picker',
              icon: Icons.folder_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      Platform.isAndroid
                          ? 'Android MediaStore discovers tracks in standard Music and Audio directories.'
                          : 'iOS stores imported audio tracks in the sandboxed Documents directory.',
                    ),
                  ),
                );
              },
            ),
            SettingsTile(
              title: 'Rescan Audio Library',
              subtitle: isScanning
                  ? 'Indexing in progress...'
                  : 'Scan for modified ID3/FLAC tags and newly arrived tracks',
              icon: isScanning
                  ? Icons.hourglass_top_rounded
                  : Icons.sync_rounded,
              onTap: isScanning ? null : () => _handleRescan(context, ref),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
