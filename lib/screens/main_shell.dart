import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/activity_mode_state.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 1024;
    final mode = ref.watch(activityModeProvider);

    if (compact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSwitch(mode: mode),
            NavigationBar(
              selectedIndex: _selectedIndex(path),
              onDestinationSelected: (index) {
                context.go(_destinations[index].path);
              },
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE1DDD1)),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Climb On',
                        style: GoogleFonts.bungee(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        'Built by Canadians for Canadians.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final destination in _destinations)
                            _NavButton(
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              label: destination.label,
                              selected: path == destination.path,
                              onTap: () => context.go(destination.path),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _ModeSwitch(mode: mode),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String path) {
    final index = _destinations.indexWhere((item) => item.path == path);
    return index < 0 ? 0 : index;
  }
}

class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch({required this.mode});

  final ActivityMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<ActivityMode>(
        segments: const [
          ButtonSegment(
            value: ActivityMode.climb,
            label: SizedBox(width: 54, child: Center(child: Text('Climb'))),
            icon: Icon(Icons.terrain),
          ),
          ButtonSegment(
            value: ActivityMode.ski,
            label: SizedBox(width: 44, child: Center(child: Text('Ski'))),
            icon: Icon(Icons.downhill_skiing),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          ref.read(activityModeProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

const _destinations = [
  _AppDestination(
    path: '/map',
    label: 'Map',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
  ),
  _AppDestination(
    path: '/feed',
    label: 'Feed',
    icon: Icons.dynamic_feed_outlined,
    selectedIcon: Icons.dynamic_feed,
  ),
  _AppDestination(
    path: '/crags',
    label: 'Crags',
    icon: Icons.terrain_outlined,
    selectedIcon: Icons.terrain,
  ),
  _AppDestination(
    path: '/submit',
    label: 'Add',
    icon: Icons.add_location_alt_outlined,
    selectedIcon: Icons.add_location_alt,
  ),
  _AppDestination(
    path: '/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

class _AppDestination {
  const _AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(selected ? selectedIcon : icon, size: 20),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          backgroundColor: selected ? const Color(0xFFE8EBDD) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
