import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/format_badge.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  bool _eqEnabled = true;
  String _activePreset = 'Flat';
  final Map<String, double> _bands = {
    '60 Hz': 0.0,
    '230 Hz': 0.0,
    '910 Hz': 0.0,
    '3.6 kHz': 0.0,
    '14 kHz': 0.0,
  };

  final List<String> _presets = [
    'Flat',
    'Acoustic',
    'Bass Boost',
    'Vocal Clarity',
    'Treble Air',
  ];

  void _applyPreset(String preset) {
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case 'Flat':
          _bands.updateAll((key, val) => 0.0);
        case 'Acoustic':
          _bands['60 Hz'] = 2.0;
          _bands['230 Hz'] = 1.0;
          _bands['910 Hz'] = 0.0;
          _bands['3.6 kHz'] = 2.5;
          _bands['14 kHz'] = 3.0;
        case 'Bass Boost':
          _bands['60 Hz'] = 5.5;
          _bands['230 Hz'] = 3.0;
          _bands['910 Hz'] = 0.0;
          _bands['3.6 kHz'] = -1.0;
          _bands['14 kHz'] = 0.5;
        case 'Vocal Clarity':
          _bands['60 Hz'] = -2.0;
          _bands['230 Hz'] = 0.5;
          _bands['910 Hz'] = 4.0;
          _bands['3.6 kHz'] = 3.5;
          _bands['14 kHz'] = 1.0;
        case 'Treble Air':
          _bands['60 Hz'] = 0.0;
          _bands['230 Hz'] = -1.0;
          _bands['910 Hz'] = 1.0;
          _bands['3.6 kHz'] = 4.0;
          _bands['14 kHz'] = 6.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer & DSP'),
        actions: [
          Switch.adaptive(
            value: _eqEnabled,
            activeTrackColor: AppColors.darkAccent,
            onChanged: (val) => setState(() => _eqEnabled = val),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                padding: AppSpacing.insetsMd,
                decoration: BoxDecoration(
                  color: sonora.surfaceElevated,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.darkAccent),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Parametric DSP Filter Graph',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              const FormatBadge(
                                label: 'FFI Ready',
                                isGold: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _eqEnabled
                                ? 'Active preset: $_activePreset'
                                : 'Hardware bypass active',
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

            // Presets Horizontal Row
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: _presets.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  final isSelected = _activePreset == preset && _eqEnabled;

                  return FilterChip(
                    selected: isSelected,
                    label: Text(preset),
                    selectedColor: AppColors.darkAccent.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.darkAccent,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.darkAccent
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: _eqEnabled ? (_) => _applyPreset(preset) : null,
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Vertical 5-Band Slider Deck
            Expanded(
              child: Opacity(
                opacity: _eqEnabled ? 1.0 : 0.35,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _bands.entries.map((entry) {
                      final bandName = entry.key;
                      final gain = entry.value;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: gain != 0.0
                                  ? AppColors.darkAccent
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: theme.sliderTheme.copyWith(
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                  trackHeight: 3.5,
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  divisions: 48,
                                  onChanged: _eqEnabled
                                      ? (newGain) {
                                          setState(() {
                                            _bands[bandName] = newGain;
                                            _activePreset = 'Custom';
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            bandName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
