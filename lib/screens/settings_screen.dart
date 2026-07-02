import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/offline_map_config.dart';
import '../models/app_visuals.dart';
import '../services/database_service.dart';
import '../state/admin_state.dart';
import '../state/activity_mode_state.dart';
import '../state/app_settings_state.dart';
import '../state/app_visuals_state.dart';
import '../utils/picked_upload_image.dart';
import '../widgets/side_banner_layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final mode = ref.watch(activityModeProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;

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
              child: ListTile(
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
                title: const Text('Manage map downloads'),
                subtitle: const Text(
                  'Download routes, pictures, satellite maps, and optional 3D terrain before leaving service.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/offline'),
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
            if (isAdmin) const _AppPicturesSettings(),
          ],
        ),
      ),
    );
  }
}

class _AppPicturesSettings extends ConsumerStatefulWidget {
  const _AppPicturesSettings();

  @override
  ConsumerState<_AppPicturesSettings> createState() =>
      _AppPicturesSettingsState();
}

class _AppPicturesSettingsState extends ConsumerState<_AppPicturesSettings> {
  String? uploadingKey;

  @override
  Widget build(BuildContext context) {
    final visuals =
        ref.watch(appVisualsProvider).valueOrNull ?? AppVisuals.defaults;
    return _SettingsCard(
      title: 'App pictures',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These pictures appear throughout the catalogue and app background. Only creator accounts can replace them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          for (final definition in AppVisuals.definitions) ...[
            _AppPictureRow(
              definition: definition,
              imageUrl: visuals.url(definition.key),
              uploading: uploadingKey == definition.key,
              onReplace: uploadingKey == null
                  ? () => _replacePicture(definition)
                  : null,
            ),
            if (definition != AppVisuals.definitions.last) const Divider(),
          ],
        ],
      ),
    );
  }

  Future<void> _replacePicture(AppVisualDefinition definition) async {
    final image = await pickUploadImage();
    if (image == null || !mounted) return;
    setState(() => uploadingKey = definition.key);
    try {
      await const DatabaseService().adminReplaceAppVisual(
        visualKey: definition.key,
        imageBytes: image.bytes,
        imageName: image.fileName,
        imageContentType: image.contentType,
      );
      ref.invalidate(appVisualsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${definition.label} updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update picture: $error')),
      );
    } finally {
      if (mounted) setState(() => uploadingKey = null);
    }
  }
}

class _AppPictureRow extends StatelessWidget {
  const _AppPictureRow({
    required this.definition,
    required this.imageUrl,
    required this.uploading,
    required this.onReplace,
  });

  final AppVisualDefinition definition;
  final String imageUrl;
  final bool uploading;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 92,
              height: 68,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox(
                width: 92,
                height: 68,
                child: ColoredBox(
                  color: Color(0xFFE1E8E5),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              definition.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onReplace,
            icon: uploading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_outlined),
            label: Text(uploading ? 'Uploading' : 'Replace'),
          ),
        ],
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
