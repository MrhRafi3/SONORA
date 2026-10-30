import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Small chip displaying audio resolution / format metadata.
class FormatBadge extends StatelessWidget {
  const FormatBadge({super.key, required this.label, this.isGold = false});

  final String label;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final borderColor = isGold
        ? AppColors.darkAccentGold.withValues(alpha: 0.4)
        : AppColors.darkAccent.withValues(alpha: 0.35);

    final textColor = isGold ? AppColors.darkAccentGold : AppColors.darkAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: AppSpacing.roundedXs,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: textColor,
        ),
      ),
    );
  }
}
