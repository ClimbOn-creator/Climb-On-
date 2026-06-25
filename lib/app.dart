import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import 'state/activity_mode_state.dart';
import 'theme/climb_on_theme.dart';

class ClimbOnApp extends StatelessWidget {
  const ClimbOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _ClimbOnMaterialApp());
  }
}

class _ClimbOnMaterialApp extends ConsumerWidget {
  const _ClimbOnMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activityModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Climb On',
      theme: mode == ActivityMode.ski
          ? ClimbOnTheme.ski()
          : ClimbOnTheme.light(),
      routerConfig: appRouter,
    );
  }
}
