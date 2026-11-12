import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/library/domain/entities.dart';

/// Displays consistent, actionable feedback after an Android scan or iOS import.
void showScanFeedback(
  BuildContext context,
  ScanSummary summary, {
  bool isIosImport = false,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  if (summary.isSuccess) {
    final String text;
    if (isIosImport) {
      text = 'Import complete: added ${summary.newlyAddedCount} audio files.';
    } else if (summary.scannedCount == 0) {
      text = 'No supported audio tracks found on device.';
    } else if (summary.newlyAddedCount == 0) {
      text = 'Library up to date (${summary.scannedCount} tracks indexed).';
    } else {
      text =
          'Scan complete: ${summary.newlyAddedCount} new (${summary.scannedCount} total).';
    }
    messenger.showSnackBar(SnackBar(content: Text(text)));
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(summary.errorMessage ?? 'Audio scan failed.'),
      action: summary.permissionPermanentlyDenied
          ? SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            )
          : null,
      duration: summary.permissionPermanentlyDenied
          ? const Duration(seconds: 6)
          : const Duration(seconds: 4),
    ),
  );
}
