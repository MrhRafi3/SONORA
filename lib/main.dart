import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/player/data/sonora_audio_handler.dart';
import 'features/player/presentation/player_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure edge-to-edge transparent system navigation and status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SonoraAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => SonoraAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mrhrafi3.sonora.channel.audio',
        androidNotificationChannelName: 'SONORA Audio Playback',
        androidNotificationChannelDescription:
            'SONORA Audiophile Music Playback Controls',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFFE59866),
      ),
    );
    await audioHandler.initAudioSession();
  } catch (e) {
    debugPrint('AudioService.init initialization fallback: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (audioHandler != null)
          audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const SonoraApp(),
    ),
  );
}
