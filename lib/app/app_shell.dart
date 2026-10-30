import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';
import '../app/theme/app_theme.dart';
import '../shared/widgets/mini_player.dart';

/// Responsive root application shell supporting both phone and tablet/desktop layouts.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideScreen = screenWidth >= 720;
    final theme = Theme.of(context);
    final sonora = context.sonoraTheme;

    if (isWideScreen) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
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
                    Expanded(child: navigationShell),
                    const MiniPlayer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone layout with bottom navigation bar and floating/docked mini player
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
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
}
