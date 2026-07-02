import 'package:go_router/go_router.dart';

import '../screens/crags_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/main_shell.dart';
import '../screens/map_screen.dart';
import '../screens/offline_downloads_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/submit_route_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/map',
  errorBuilder: (context, state) => const ProfileScreen(),
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/profile'),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
        GoRoute(
          path: '/offline',
          builder: (context, state) => const OfflineDownloadsScreen(),
        ),
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(
          path: '/crags',
          builder: (context, state) => const CragsScreen(),
        ),
        GoRoute(
          path: '/submit',
          builder: (context, state) => const SubmitRouteScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/setup',
          builder: (context, state) => const ProfileSetupScreen(),
        ),
      ],
    ),
  ],
);
