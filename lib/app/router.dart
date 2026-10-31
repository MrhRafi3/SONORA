import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/equalizer/presentation/equalizer_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/player/presentation/player_screen.dart';
import '../features/playlists/presentation/playlist_detail_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/subpages/about_settings_screen.dart';
import '../features/settings/presentation/subpages/appearance_settings_screen.dart';
import '../features/settings/presentation/subpages/library_storage_settings_screen.dart';
import '../features/settings/presentation/subpages/notifications_settings_screen.dart';
import '../features/settings/presentation/subpages/playback_settings_screen.dart';
import '../features/settings/presentation/subpages/privacy_settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';
import 'theme/app_motion.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNav',
);

/// Riverpod provider delivering the application's [GoRouter] configuration
/// with unified fluid transitions across pages and modals.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionType: AppTransitionType.fade,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => AppMotion.buildPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                  transitionType: AppTransitionType.fade,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                pageBuilder: (context, state) => AppMotion.buildPage(
                  key: state.pageKey,
                  child: const LibraryScreen(),
                  transitionType: AppTransitionType.fade,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                pageBuilder: (context, state) => AppMotion.buildPage(
                  key: state.pageKey,
                  child: const SearchScreen(),
                  transitionType: AppTransitionType.fade,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => AppMotion.buildPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                  transitionType: AppTransitionType.fade,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const PlayerScreen(),
          transitionType: AppTransitionType.modalSlideUp,
        ),
      ),
      GoRoute(
        path: '/equalizer',
        name: 'equalizer',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const EqualizerScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        name: 'playlist_detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final playlistId = state.pathParameters['id'] ?? '';
          final title = state.uri.queryParameters['name'] ?? 'Playlist';
          final isSmart = state.uri.queryParameters['smart'] == 'true';
          return AppMotion.buildPage(
            key: state.pageKey,
            child: PlaylistDetailScreen(
              playlistId: playlistId,
              initialTitle: title,
              isSmart: isSmart,
            ),
            transitionType: AppTransitionType.sharedAxis,
          );
        },
      ),

      // --- Settings Subpage Routes ---
      GoRoute(
        path: '/settings/playback',
        name: 'settings_playback',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const PlaybackSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/settings/appearance',
        name: 'settings_appearance',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const AppearanceSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/settings/library',
        name: 'settings_library',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const LibraryStorageSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: 'settings_notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const NotificationsSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/settings/privacy',
        name: 'settings_privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const PrivacyPermissionsSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
      GoRoute(
        path: '/settings/about',
        name: 'settings_about',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppMotion.buildPage(
          key: state.pageKey,
          child: const AboutSettingsScreen(),
          transitionType: AppTransitionType.sharedAxis,
        ),
      ),
    ],
  );
});
