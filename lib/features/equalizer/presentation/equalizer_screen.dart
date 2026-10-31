import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/format_badge.dart';
import '../../player/presentation/player_state.dart';
import '../domain/equalizer_preset.dart';
import 'equalizer_providers.dart';
import 'widgets/frequency_response_graph.dart';
import 'widgets/spectrum_visualizer.dart';

/// Full-featured audiophile equalizer and native DSP control screen.
///
/// Provides 5-band and 10-band ISO standard graphic EQ modes, real-time
/// frequency curve visualization, spectrum analyzer, preamp staging,
/// sub-bass enhancement, and custom preset saving.
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  final TextEditingController _customPresetController = TextEditingController();

  @override
  void dispose() {
    _customPresetController.dispose();
    super.dispose();
  }

  void _showSavePresetDialog(BuildContext context, WidgetRef ref) {
    _customPresetController.clear();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.sonoraTheme.surfaceElevated,
          title: const Text('Save Custom Preset'),
          content: TextField(
            controller: _customPresetController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              hintText: 'e.g., My Audiophile Warmth',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = _customPresetController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(equalizerProvider.notifier).saveCustomPreset(name);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));

    final allPresets = [
      ...EqualizerPreset.builtInPresets.map((p) => p.name),
      ...eqState.customPresets.map((p) => p.name),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer & DSP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset to Flat (0 dB)',
            onPressed: eqState.isEnabled
                ? () => eqNotifier.resetAllToFlat()
                : null,
          ),
          Switch.adaptive(
            value: eqState.isEnabled,
            activeTrackColor: AppColors.darkAccent,
            onChanged: (val) => eqNotifier.toggleEnabled(),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Engine Status Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
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
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color:
                              (eqState.isEnabled
                                      ? AppColors.darkAccent
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: eqState.isEnabled
                              ? AppColors.darkAccent
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'C++17 Biquad DSP Core',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                FormatBadge(
                                  label: eqState.isNativeEngineConnected
                                      ? 'FFI Active'
                                      : 'FFI Ready',
                                  isGold: eqState.isNativeEngineConnected,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              eqState.isEnabled
                                  ? 'Active Preset: ${eqState.activePreset} • Direct Form II Transposed'
                                  : 'Hardware Bypass Active (Pure Bit-Perfect)',
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

              const SizedBox(height: AppSpacing.sm),

              // Frequency Response Curve Visualization
              FrequencyResponseGraph(state: eqState, height: 140.0),

              const SizedBox(height: AppSpacing.md),

              // Band Mode Toggle (5-Band vs 10-Band ISO)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BAND ARCHITECTURE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5 Bands')),
                        ButtonSegment(value: 10, label: Text('10 Bands ISO')),
                      ],
                      selected: {eqState.bandCount},
                      onSelectionChanged: eqState.isEnabled
                          ? (selected) =>
                                eqNotifier.setBandCount(selected.first)
                          : null,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Presets Horizontal Row
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: allPresets.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == allPresets.length) {
                      return ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Save Preset'),
                        onPressed: eqState.isEnabled
                            ? () => _showSavePresetDialog(context, ref)
                            : null,
                      );
                    }

                    final presetName = allPresets[index];
                    final isSelected =
                        eqState.activePreset == presetName && eqState.isEnabled;

                    return FilterChip(
                      selected: isSelected,
                      label: Text(presetName),
                      selectedColor: AppColors.darkAccent.withValues(
                        alpha: 0.2,
                      ),
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
                      onSelected: eqState.isEnabled
                          ? (_) => eqNotifier.applyPreset(presetName)
                          : null,
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Equalizer Slider Deck
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: SizedBox(
                  height: 220,
                  child: Opacity(
                    opacity: eqState.isEnabled ? 1.0 : 0.35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: eqState.bands.map((band) {
                        return _EqualizerSliderColumn(
                          band: band,
                          isEnabled: eqState.isEnabled,
                          onGainChanged: (val) =>
                              eqNotifier.setBandGain(band.index, val),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Preamp, Bass Enhancement & Limiter Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: AppColors.darkAccent,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Acoustic Processing & Dynamics',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Soft Limiter',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Switch.adaptive(
                                value: eqState.isLimiterActive,
                                activeTrackColor: AppColors.darkAccent,
                                onChanged: eqState.isEnabled
                                    ? (_) => eqNotifier.toggleLimiter()
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Master Preamp Slider
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              'Preamp Gain',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: theme.sliderTheme.copyWith(
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: eqState.preampGain,
                                min: -12.0,
                                max: 12.0,
                                divisions: 48,
                                onChanged: eqState.isEnabled
                                    ? (val) => eqNotifier.setPreampGain(val)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${eqState.preampGain >= 0 ? '+' : ''}${eqState.preampGain.toStringAsFixed(1)}dB',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: eqState.preampGain != 0.0
                                    ? AppColors.darkAccent
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Sub-bass Enhancement Slider
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              'Bass Enhancement',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: theme.sliderTheme.copyWith(
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: eqState.bassEnhancement,
                                min: 0.0,
                                max: 10.0,
                                divisions: 20,
                                onChanged: eqState.isEnabled
                                    ? (val) =>
                                          eqNotifier.setBassEnhancement(val)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '+${eqState.bassEnhancement.toStringAsFixed(1)}dB',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: eqState.bassEnhancement > 0.0
                                    ? AppColors.darkAccent
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Real-Time Spectrum Visualizer Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LIVE FREQUENCY SPECTRUM (32 BANDS)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            isPlaying ? 'MONITORING' : 'IDLE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isPlaying
                                  ? AppColors.darkAccent
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SpectrumVisualizerWidget(
                        isPlaying: isPlaying,
                        barCount: 32,
                        height: 52.0,
                        accentColor: AppColors.darkAccent,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _EqualizerSliderColumn extends StatelessWidget {
  const _EqualizerSliderColumn({
    required this.band,
    required this.isEnabled,
    required this.onGainChanged,
  });

  final EqualizerBand band;
  final bool isEnabled;
  final ValueChanged<double> onGainChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gain = band.gain;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onDoubleTap: isEnabled ? () => onGainChanged(0.0) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: gain.abs() > 0.05
                  ? AppColors.darkAccent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: gain.abs() > 0.05
                    ? AppColors.darkAccent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: theme.sliderTheme.copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3.0,
              ),
              child: Slider(
                value: gain,
                min: -12.0,
                max: 12.0,
                divisions: 48,
                onChanged: isEnabled ? onGainChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          band.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
