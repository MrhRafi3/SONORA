import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/format_badge.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/settings_tile.dart';

/// Subpage providing application information, engine architecture, open source links,
/// and elegant developer credit for Mrh Rafi.
class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About SONORA')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            // App Header Hero Banner
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                decoration: BoxDecoration(
                  color: sonora.surfaceElevated,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(
                    color: AppColors.darkAccent.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkAccent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkAccent.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.darkAccent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.album_rounded,
                        color: AppColors.darkAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'SONORA',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        color: AppColors.darkAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Premium High-Resolution Offline Audio Player',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const FormatBadge(
                      label: 'v1.0.0 • Production Ready',
                      isGold: true,
                    ),
                  ],
                ),
              ),
            ),

            // Developer Credit Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
                padding: AppSpacing.insetsMd,
                decoration: BoxDecoration(
                  color: sonora.surfaceElevated,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkAccent.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppColors.darkAccent.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.darkAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEVELOPER & ARCHITECT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mrh Rafi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Audio Engineering, DSP & Flutter Architecture',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
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
            const SizedBox(height: AppSpacing.md),

            // Technical Architecture Section
            const SectionHeader(
              title: 'Engine Architecture',
              subtitle: 'Precision systems and native DSP pipeline',
            ),
            SettingsTile(
              title: 'C++17 DSP Core & Dart FFI',
              subtitle:
                  'Direct Form II Transposed Biquad IIR filters, soft-knee limiter & Cooley-Tukey FFT',
              icon: Icons.memory_rounded,
            ),
            SettingsTile(
              title: 'Clean Architecture & Reactive State',
              subtitle: 'Riverpod 3.4 • GoRouter 18 • Feature-driven layers',
              icon: Icons.architecture_rounded,
            ),
            SettingsTile(
              title: 'SQLite Database & B-Tree Indexing',
              subtitle:
                  'Drift 2.35 indexed store for 10,000+ tracks with < 150ms query benchmarks',
              icon: Icons.storage_rounded,
            ),
            SettingsTile(
              title: 'Supported Formats',
              subtitle:
                  'FLAC, WAV, MP3, M4A, AAC, OGG, OPUS (up to 24-bit / 192kHz)',
              icon: Icons.audio_file_rounded,
            ),
            const SizedBox(height: AppSpacing.md),

            // Open Source & Licensing
            const SectionHeader(
              title: 'Source Code & Project',
              subtitle: 'Official repository and community tracking',
            ),
            SettingsTile(
              title: 'GitHub Repository',
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
            SettingsTile(
              title: 'License',
              subtitle:
                  'MIT License • Created with dedication to pure high-fidelity sound',
              icon: Icons.policy_outlined,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
