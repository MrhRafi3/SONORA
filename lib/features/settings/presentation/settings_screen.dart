import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/settings_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _bitPerfect = true;
  bool _replayGain = true;
  bool _gapless = true;
  bool _pauseOnUnplug = true;
  double _crossfade = 2.0;

  void _showCrossfadeDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        double currentVal = _crossfade;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.sonoraTheme.surfaceElevated,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedLg,
              ),
              title: const Text('Crossfade Duration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentVal.toStringAsFixed(1)} seconds',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkAccent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Slider(
                    value: currentVal,
                    min: 0.0,
                    max: 8.0,
                    divisions: 16,
                    label: '${currentVal.toStringAsFixed(1)}s',
                    onChanged: (val) {
                      setDialogState(() => currentVal = val);
                      setState(() => _crossfade = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            // Section: Appearance
            const SectionHeader(title: 'Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Dark'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Light'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('System'),
                  ),
                ],
                selected: {currentThemeMode},
                onSelectionChanged: (newSelection) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(newSelection.first);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Section: Audio & Equalizer
            const SectionHeader(
              title: 'Audio & Hardware Engine',
              subtitle: 'Bit-perfect signal path settings',
            ),
            SettingsTile(
              title: 'Parametric Equalizer',
              subtitle: '5-band frequency tuning & DSP presets',
              icon: Icons.tune_rounded,
              onTap: () => context.push('/equalizer'),
            ),
            SettingsTile(
              title: 'Bit-Perfect Direct Output',
              subtitle: 'Bypass platform mixer for lossless DAC streaming',
              icon: Icons.graphic_eq_rounded,
              trailing: Switch.adaptive(
                value: _bitPerfect,
                activeTrackColor: AppColors.darkAccent,
                onChanged: (val) => setState(() => _bitPerfect = val),
              ),
            ),
            SettingsTile(
              title: 'ReplayGain Normalization',
              subtitle: 'Preserve dynamic range while matching loudness',
              icon: Icons.volume_up_rounded,
              trailing: Switch.adaptive(
                value: _replayGain,
                activeTrackColor: AppColors.darkAccent,
                onChanged: (val) => setState(() => _replayGain = val),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Section: Playback
            const SectionHeader(title: 'Playback Behavior'),
            SettingsTile(
              title: 'Gapless Playback',
              subtitle: 'Zero silence transition between continuous tracks',
              icon: Icons.all_inclusive_rounded,
              trailing: Switch.adaptive(
                value: _gapless,
                activeTrackColor: AppColors.darkAccent,
                onChanged: (val) => setState(() => _gapless = val),
              ),
            ),
            SettingsTile(
              title: 'Crossfade Transition',
              subtitle:
                  '${_crossfade.toStringAsFixed(1)} seconds between tracks',
              icon: Icons.alt_route_rounded,
              onTap: _showCrossfadeDialog,
            ),
            SettingsTile(
              title: 'Pause on Disconnect',
              subtitle: 'Auto-pause playback when headphones are removed',
              icon: Icons.headphones_outlined,
              trailing: Switch.adaptive(
                value: _pauseOnUnplug,
                activeTrackColor: AppColors.darkAccent,
                onChanged: (val) => setState(() => _pauseOnUnplug = val),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Section: Library & Storage
            const SectionHeader(title: 'Storage & Indexing'),
            SettingsTile(
              title: 'Music Folders',
              subtitle: 'Android MediaStore & Scoped Storage',
              icon: Icons.folder_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Folder selector activates with Drift scanner in Phase 03.',
                    ),
                  ),
                );
              },
            ),
            SettingsTile(
              title: 'Rescan Audio Library',
              subtitle: 'Scan for modified ID3 tags and new files',
              icon: Icons.sync_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Offline indexer ready for Phase 03 scan integration.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Section: About SONORA
            const SectionHeader(title: 'About SONORA'),
            SettingsTile(
              title: 'Version & Build',
              subtitle: 'v1.0.0 (Phase 02 UI Foundation)',
              icon: Icons.info_outline_rounded,
              trailing: const FormatBadge(label: 'Phase 02', isGold: true),
            ),
            SettingsTile(
              title: 'Engine Architecture',
              subtitle:
                  'Clean Architecture • Riverpod • GoRouter • C++ FFI Ready',
              icon: Icons.memory_rounded,
            ),
            SettingsTile(
              title: 'Source Code Repository',
              subtitle: 'https://github.com/MrhRafi3/SONORA',
              icon: Icons.code_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Repository: https://github.com/MrhRafi3/SONORA',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
