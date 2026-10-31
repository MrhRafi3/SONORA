import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/settings_tile.dart';

/// Subpage explaining privacy policies, zero tracking commitments, and device permissions.
class PrivacyPermissionsSettingsScreen extends StatelessWidget {
  const PrivacyPermissionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Permissions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                padding: AppSpacing.insetsMd,
                decoration: BoxDecoration(
                  color: sonora.surfaceElevated,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(
                    color: AppColors.darkAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.darkAccent,
                      size: 32,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100% Offline & Private',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SONORA does not collect, transmit, or monetize your listening habits or files. Zero analytics, zero ads, zero telemetry.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
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
            const SectionHeader(
              title: 'Device Permissions',
              subtitle: 'System capabilities required for music playback',
            ),
            SettingsTile(
              title: 'Storage & Audio Access',
              subtitle:
                  'Required to read audio files and embedded ID3/FLAC metadata from device storage',
              icon: Icons.folder_shared_rounded,
            ),
            SettingsTile(
              title: 'Notification Permissions',
              subtitle:
                  'Required on Android 13+ to render system media controls in the notification drawer',
              icon: Icons.notifications_none_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(
              title: 'Data & Processing',
              subtitle: 'On-device execution guarantee',
            ),
            SettingsTile(
              title: 'Local Signal Processing',
              subtitle:
                  'All C++ biquad filtering, EQ math, and FFT spectral analysis run entirely on CPU',
              icon: Icons.developer_board_rounded,
            ),
            SettingsTile(
              title: 'No Network Traffic',
              subtitle:
                  'Application operates fully air-gapped without an active internet connection',
              icon: Icons.wifi_off_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
