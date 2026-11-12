import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';
import '../app/theme/app_theme.dart';
import '../features/library/domain/entities.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/player/presentation/player_state.dart';
import '../features/settings/presentation/settings_providers.dart';
import '../shared/widgets/mini_player.dart';

/// Responsive root application shell supporting both phone and tablet/desktop layouts
/// with reliable Android back-navigation hierarchy.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<int> _branchHistory = [0];
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => ref.read(playerProvider.notifier).saveCurrentSession(),
      onInactive: () => ref.read(playerProvider.notifier).saveCurrentSession(),
      onDetach: () => ref.read(playerProvider.notifier).saveCurrentSession(),
      onHide: () => ref.read(playerProvider.notifier).saveCurrentSession(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index != widget.navigationShell.currentIndex) {
      _branchHistory.remove(index);
      _branchHistory.add(index);
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _handleBackNavigation() {
    if (_branchHistory.isNotEmpty &&
        _branchHistory.last == widget.navigationShell.currentIndex) {
      _branchHistory.removeLast();
    }
    final targetBranch = _branchHistory.isNotEmpty ? _branchHistory.last : 0;
    widget.navigationShell.goBranch(targetBranch);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.navigationShell.currentIndex;
    if (_branchHistory.isEmpty || _branchHistory.last != current) {
      _branchHistory.remove(current);
      _branchHistory.add(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.listen<String?>(playerProvider.select((s) => s.playbackError), (
      _,
      nextError,
    ) {
      if (nextError == null || nextError.isEmpty) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(nextError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      Future.microtask(() {
        ref.read(playerProvider.notifier).clearPlaybackError();
      });
    });

    final initialTracks = ref.read(tracksStreamProvider).asData?.value;
    if (initialTracks != null && initialTracks.isNotEmpty) {
      Future.microtask(() {
        if (!context.mounted) return;
        ref
            .read(playerProvider.notifier)
            .syncRealLibrary(initialTracks.map((t) => t.toUiTrack()).toList());
      });
    }

    ref.listen<AsyncValue<List<AudioTrack>>>(tracksStreamProvider, (_, next) {
      final tracks = next.asData?.value;
      if (tracks == null || tracks.isEmpty) return;
      Future.microtask(() {
        if (!context.mounted) return;
        ref
            .read(playerProvider.notifier)
            .syncRealLibrary(tracks.map((t) => t.toUiTrack()).toList());
      });
    });

    final pauseOnDisconnect = ref.read(
      settingsProvider.select((s) => s.pauseOnDisconnect),
    );
    ref.read(audioHandlerProvider)?.setPauseOnBecomingNoisy(pauseOnDisconnect);
    ref.listen<bool>(settingsProvider.select((s) => s.pauseOnDisconnect), (
      _,
      enabled,
    ) {
      ref.read(audioHandlerProvider)?.setPauseOnBecomingNoisy(enabled);
    });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideScreen = screenWidth >= 720;
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;
    final navShell = widget.navigationShell;

    final canPop =
        navShell.currentIndex == 0 &&
        (_branchHistory.isEmpty ||
            (_branchHistory.length == 1 && _branchHistory.first == 0));

    final Widget shellLayout;

    if (isWideScreen) {
      shellLayout = Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: navShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                backgroundColor: sonora.surfaceElevated,
                labelType: NavigationRailLabelType.all,
                indicatorColor: sonora.surfaceOverlay,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.darkAccent.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.darkAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.album_rounded,
                          color: AppColors.darkAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'SONORA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.darkAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: Text('Library'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search_rounded),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: Text('Settings'),
                  ),
                ],
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: navShell),
                    const MiniPlayer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Phone layout with bottom navigation bar and floating/docked mini player
      shellLayout = Scaffold(
        body: Column(
          children: [
            Expanded(child: navShell),
            const MiniPlayer(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
    }

    return PopScope(
      key: const Key('app_shell_pop_scope'),
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: shellLayout,
    );
  }
}
