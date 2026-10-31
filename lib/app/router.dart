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
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNav',
);

/// Riverpod provider delivering the application's [GoRouter] configuration.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
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
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlayerScreen(),
      ),
      GoRoute(
        path: '/equalizer',
        name: 'equalizer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EqualizerScreen(),
      ),
      GoRoute(
        path: '/playlist/:id',
        name: 'playlist_detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final playlistId = state.pathParameters['id'] ?? '';
          final title = state.uri.queryParameters['name'] ?? 'Playlist';
          final isSmart = state.uri.queryParameters['smart'] == 'true';
          return PlaylistDetailScreen(
            playlistId: playlistId,
            initialTitle: title,
            isSmart: isSmart,
          );
        },
      ),
    ],
  );
});
