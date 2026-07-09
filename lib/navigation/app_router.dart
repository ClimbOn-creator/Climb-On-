import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/crags_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/main_shell.dart';
import '../screens/map_screen.dart';
import '../screens/offline_downloads_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/app_pictures_screen.dart';
import '../screens/submit_route_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/map',
  errorBuilder: (context, state) => const ProfileScreen(),
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/profile'),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/map',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const MapScreen()),
        ),
        GoRoute(
          path: '/offline',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const OfflineDownloadsScreen()),
        ),
        GoRoute(
          path: '/feed',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const FeedScreen()),
        ),
        GoRoute(
          path: '/crags',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const CragsScreen()),
        ),
        GoRoute(
          path: '/submit',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const SubmitRouteScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const ProfileScreen()),
        ),
        GoRoute(
          path: '/profile/setup',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const ProfileSetupScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/profile',
          pageBuilder: (context, state) => _appPage(
            state: state,
            child: const ProfileSetupScreen(settingsPage: true),
          ),
        ),
        GoRoute(
          path: '/settings/pictures',
          pageBuilder: (context, state) =>
              _appPage(state: state, child: const AppPicturesScreen()),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _appPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: ValueKey(state.uri.toString()),
    child: child,
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 90),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
