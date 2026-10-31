import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../settings_providers.dart';

/// Subpage for system media session notification controls and lock screen behavior.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & Media Session')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            const SectionHeader(
              title: 'System Media Controls',
              subtitle: 'Android notification shade and iOS Control Center',
            ),
            SettingsTile(
              title: 'System Media Session',
              subtitle:
                  'Enable lock screen, notification shade, and headset remote controls',
              icon: Icons.notifications_active_outlined,
              trailing: Switch.adaptive(
                value: settings.systemMediaControls,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setSystemMediaControls,
              ),
            ),
            SettingsTile(
              title: 'Lock Screen Album Artwork',
              subtitle:
                  'Broadcast high-resolution album cover to system lock screen',
              icon: Icons.image_outlined,
              trailing: Switch.adaptive(
                value: settings.lockScreenArtwork,
                activeTrackColor: AppColors.darkAccent,
                onChanged: notifier.setLockScreenArtwork,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(
              title: 'Notification Actions',
              subtitle: 'Compact media session layout',
            ),
            SettingsTile(
              title: 'Compact Control Actions',
              subtitle:
                  'Show Play/Pause, Previous, Next and Seek scrubber in notification shade',
              icon: Icons.smart_button_rounded,
            ),
            SettingsTile(
              title: 'Android 13+ Media Style',
              subtitle:
                  'Follow native dynamic Material You media player styling and waveform seek',
              icon: Icons.android_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
