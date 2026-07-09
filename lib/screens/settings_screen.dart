import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/offline_map_config.dart';
import '../state/admin_state.dart';
import '../state/activity_mode_state.dart';
import '../state/app_settings_state.dart';
import '../widgets/side_banner_layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final mode = ref.watch(activityModeProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;
    final isCreator = ref.watch(isOwnerAccountProvider) || isAdmin;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 28 : 16,
            desktop ? 30 : 18,
            desktop ? 28 : 16,
            40,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to profile',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APP PREFERENCES',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SettingsCard(
              title: 'Profile',
              icon: Icons.person_outline,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.manage_accounts_outlined),
                ),
                title: const Text('Edit profile'),
                subtitle: const Text(
                  'Change your username, profile information, privacy, and profile picture.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/profile'),
              ),
            ),
            _SettingsCard(
              title: 'Activity',
              icon: Icons.swap_horiz,
              child: SegmentedButton<ActivityMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ActivityMode.climb,
                    icon: Icon(Icons.landscape_outlined),
                    label: Text('Climb'),
                  ),
                  ButtonSegment(
                    value: ActivityMode.ski,
                    icon: Icon(Icons.downhill_skiing),
                    label: Text('Ski'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  ref.read(activityModeProvider.notifier).state =
                      selection.first;
                },
              ),
            ),
            _SettingsCard(
              title: 'Map experience',
              icon: Icons.map_outlined,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.prefer3d,
                    onChanged: settings.setPrefer3d,
                    secondary: const Icon(Icons.view_in_ar_outlined),
                    title: const Text('Open maps in 3D'),
                    subtitle: Text(
                      OfflineMapConfig.terrainConfigured
                          ? 'Uses downloaded Canadian elevation terrain when available.'
                          : kIsWeb
                          ? 'Uses online elevation terrain. Offline 3D requires the native app and downloaded terrain pack.'
                          : 'Full elevation activates when the terrain service is connected.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.twoFingerRotation,
                    onChanged: settings.setTwoFingerRotation,
                    secondary: const Icon(Icons.rotate_90_degrees_ccw),
                    title: const Text('Two-finger map movement'),
                    subtitle: const Text(
                      'Twist two fingers to rotate. In 3D, drag two fingers vertically to tilt.',
                    ),
                  ),
                ],
              ),
            ),
            _SettingsCard(
              title: 'Offline maps',
              icon: Icons.download_for_offline_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.cloud_download_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text('Offline download packs'),
                    subtitle: const Text(
                      'Save routes, pictures, satellite maps, and optional 3D terrain before leaving service.',
                    ),
                    onTap: () => context.go('/offline'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.go('/offline'),
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('Download offline maps'),
                  ),
                ],
              ),
            ),
            _SettingsCard(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: settings.showTopoBackground,
                onChanged: settings.setShowTopoBackground,
                secondary: const Icon(Icons.gesture),
                title: const Text('Topographic background lines'),
                subtitle: const Text(
                  'Show faint contour lines behind the app screens.',
                ),
              ),
            ),
            if (isCreator)
              _SettingsCard(
                title: 'Creator tools',
                icon: Icons.admin_panel_settings_outlined,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Manage app pictures'),
                  subtitle: const Text(
                    'Change mountain-range pictures, backgrounds, and default catalogue artwork.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/pictures'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
