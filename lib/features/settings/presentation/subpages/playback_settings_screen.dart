import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../settings_providers.dart';

/// Subpage for audio hardware output, gapless transitions, and playback behaviors.
class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  void _showCrossfadeDialog(
    BuildContext context,
    WidgetRef ref,
    double initialSeconds,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        double currentVal = initialSeconds;
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
                      ref.read(settingsProvider.notifier).setCrossfade(val);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Playback & Audio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            const SectionHeader(
              title: 'Audiophile Signal Path',
              subtitle: 'Bit-perfect direct audio routing',
            ),
            SettingsTile(
              title: 'Bit-Perfect Direct Output',
              subtitle:
                  'Bypass platform OS audio mixer for lossless DAC streaming',
              icon: Icons.graphic_eq_rounded,
              trailing: Switch.adaptive(
                value: settings.bitPerfectOutput,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setBitPerfect,
              ),
            ),
            SettingsTile(
              title: 'High-Res DAC Streaming',
              subtitle:
                  'Route 24-bit / 192kHz streams directly without downsampling',
              icon: Icons.high_quality_rounded,
              trailing: Switch.adaptive(
                value: settings.highResDirectDac,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setHighResDirectDac,
              ),
            ),
            SettingsTile(
              title: 'ReplayGain Normalization',
              subtitle:
                  'Preserve dynamic range while matching loudness across tracks',
              icon: Icons.volume_up_rounded,
              trailing: Switch.adaptive(
                value: settings.replayGain,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setReplayGain,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(
              title: 'Track Transitions & Hardware',
              subtitle: 'Gapless flow and accessory behavior',
            ),
            SettingsTile(
              title: 'Gapless Playback',
              subtitle:
                  'Zero silence transition between continuous tracks and live albums',
              icon: Icons.all_inclusive_rounded,
              trailing: Switch.adaptive(
                value: settings.gaplessPlayback,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setGapless,
              ),
            ),
            SettingsTile(
              title: 'Crossfade Transition',
              subtitle:
                  '${settings.crossfadeSeconds.toStringAsFixed(1)} seconds between tracks',
              icon: Icons.alt_route_rounded,
              onTap: () =>
                  _showCrossfadeDialog(context, ref, settings.crossfadeSeconds),
            ),
            SettingsTile(
              title: 'Pause on Disconnect',
              subtitle:
                  'Auto-pause playback when headphones or Bluetooth devices disconnect',
              icon: Icons.headphones_outlined,
              trailing: Switch.adaptive(
                value: settings.pauseOnDisconnect,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setPauseOnDisconnect,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
