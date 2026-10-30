import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonoraTheme = context.sonoraTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SONORA'),
        actions: [
          IconButton(
            tooltip: 'Equalizer',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/equalizer'),
          ),
          IconButton(
            tooltip: 'Now Playing',
            icon: const Icon(Icons.music_note_rounded),
            onPressed: () => context.push('/player'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'High-Resolution Audio Player',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Phase 01 architectural foundation active.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: AppSpacing.insetsMd,
                decoration: BoxDecoration(
                  gradient: sonoraTheme.cardGradient,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.darkBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: AppSpacing.insetsSm,
                          decoration: BoxDecoration(
                            color: sonoraTheme.accentGlow,
                            borderRadius: AppSpacing.roundedSm,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.darkAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'System Status',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Feature-based clean architecture initialized. Audio engine, persistent SQLite/Drift library indexer, and DSP pipeline will be configured in subsequent phases.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
