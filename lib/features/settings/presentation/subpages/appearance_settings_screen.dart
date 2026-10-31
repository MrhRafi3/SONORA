import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_accent.dart';
import '../../../../shared/widgets/section_header.dart';

/// Subpage for app theme mode and audiophile accent palette customization.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(themeAccentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance & Personalization')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            const SectionHeader(
              title: 'Interface Theme',
              subtitle: 'Select visual appearance mode',
            ),
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
            const SectionHeader(
              title: 'Audiophile Accents',
              subtitle:
                  'Precision-tuned palettes inspired by high-end analog audio',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: ThemeAccent.values.map((accent) {
                  final isSelected = currentAccent == accent;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: InkWell(
                      onTap: () => ref
                          .read(themeAccentProvider.notifier)
                          .setAccent(accent),
                      borderRadius: AppSpacing.roundedMd,
                      child: Container(
                        padding: AppSpacing.insetsMd,
                        decoration: BoxDecoration(
                          color: sonora.surfaceElevated,
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(
                            color: isSelected
                                ? accent.accentColor
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.15,
                                  ),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: accent.accentColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.accentColor,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accent.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? accent.accentColor
                                              : theme.colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getAccentDescription(accent),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _getAccentDescription(ThemeAccent accent) {
    switch (accent) {
      case ThemeAccent.amberWarmth:
        return 'Classic vacuum tube glow and warm acoustic tonality';
      case ThemeAccent.roseCopper:
        return 'Oxygen-free copper conductor and rose gold warmth';
      case ThemeAccent.champagneGold:
        return 'High-fidelity Japanese reference hi-fi chassis';
      case ThemeAccent.emeraldVelvet:
        return 'Studio analog tape reel and balanced acoustic depth';
      case ThemeAccent.sapphireTube:
        return 'Precision oscilloscope glow and bit-perfect digital clarity';
    }
  }
}
