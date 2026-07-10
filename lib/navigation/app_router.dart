import 'package:flutter/widgets.dart';
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
              _noTransitionPage(state, const MapScreen()),
        ),
        GoRoute(
          path: '/offline',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const OfflineDownloadsScreen()),
        ),
        GoRoute(
          path: '/feed',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const FeedScreen()),
        ),
        GoRoute(
          path: '/crags',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const CragsScreen()),
        ),
        GoRoute(
          path: '/submit',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const SubmitRouteScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const ProfileScreen()),
        ),
        GoRoute(
          path: '/profile/setup',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const ProfileSetupScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/profile',
          pageBuilder: (context, state) => _noTransitionPage(
            state,
            const ProfileSetupScreen(settingsPage: true),
          ),
        ),
        GoRoute(
          path: '/settings/pictures',
          pageBuilder: (context, state) =>
              _noTransitionPage(state, const AppPicturesScreen()),
        ),
      ],
    ),
  ],
);

NoTransitionPage<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
