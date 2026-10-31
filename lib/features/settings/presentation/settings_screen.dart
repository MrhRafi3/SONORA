import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_accent.dart';
import '../../../shared/widgets/section_header.dart';

/// Clean, consolidated, and responsive Settings root screen.
///
/// Provides quick appearance controls at the top and delegates detailed
/// configurations to dedicated subpages for an uncluttered experience.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(themeAccentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          children: [
            // Quick Appearance Section
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Quick theme & accent controls',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Audiophile Accent',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currentAccent.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: currentAccent.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ThemeAccent.values.map((accent) {
                    final isSelected = currentAccent == accent;
                    return GestureDetector(
                      onTap: () => ref
                          .read(themeAccentProvider.notifier)
                          .setAccent(accent),
                      child: Tooltip(
                        message: accent.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.accentColor,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: accent.accentColor.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 24,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Consolidated Category Navigation Cards
            const SectionHeader(
              title: 'Configuration Categories',
              subtitle: 'Fine-tune playback, audio hardware & storage',
            ),
            _SettingsCategoryCard(
              title: 'Playback & Audio',
              subtitle:
                  'Bit-perfect output, gapless playback, crossfade & pause on disconnect',
              icon: Icons.play_circle_outline_rounded,
              iconColor: currentAccent.accentColor,
              onTap: () => context.push('/settings/playback'),
            ),
            _SettingsCategoryCard(
              title: 'Equalizer & Sound',
              subtitle:
                  '10-band ISO standard graphic EQ, C++17 DSP core, presets & live spectrum',
              icon: Icons.tune_rounded,
              iconColor: currentAccent.accentColor,
              badgeText: 'Parametric Equalizer',
              onTap: () => context.push('/equalizer'),
            ),
            _SettingsCategoryCard(
              title: 'Appearance & Personalization',
              subtitle:
                  'Detailed palette descriptions, contrast tuning & visual theme options',
              icon: Icons.palette_outlined,
              iconColor: currentAccent.accentColor,
              onTap: () => context.push('/settings/appearance'),
            ),
            _SettingsCategoryCard(
              title: 'Library & Storage',
              subtitle:
                  'Indexed collection statistics, platform storage paths & library rescanning',
              icon: Icons.folder_outlined,
              iconColor: currentAccent.accentColor,
              onTap: () => context.push('/settings/library'),
            ),
            _SettingsCategoryCard(
              title: 'Notifications & Media Session',
              subtitle:
                  'System lock screen controls, album artwork broadcast & notification style',
              icon: Icons.notifications_none_rounded,
              iconColor: currentAccent.accentColor,
              onTap: () => context.push('/settings/notifications'),
            ),
            _SettingsCategoryCard(
              title: 'Privacy & Permissions',
              subtitle:
                  '100% offline commitment, local signal processing & storage access',
              icon: Icons.security_rounded,
              iconColor: currentAccent.accentColor,
              onTap: () => context.push('/settings/privacy'),
            ),
            _SettingsCategoryCard(
              title: 'About SONORA',
              subtitle:
                  'v1.0.0 • Developer: Mrh Rafi • Engine architecture & source repository',
              icon: Icons.info_outline_rounded,
              iconColor: currentAccent.accentColor,
              badgeText: 'Mrh Rafi',
              onTap: () => context.push('/settings/about'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// An elegant, animated category card for navigating to settings subpages.
class _SettingsCategoryCard extends StatefulWidget {
  const _SettingsCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  State<_SettingsCategoryCard> createState() => _SettingsCategoryCardState();
}

class _SettingsCategoryCardState extends State<_SettingsCategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: sonora.surfaceElevated,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.14),
                    borderRadius: AppSpacing.roundedSm,
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(widget.icon, size: 22, color: widget.iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (widget.badgeText != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.iconColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.badgeText!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: widget.iconColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
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
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
