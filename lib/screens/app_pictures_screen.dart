import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_visuals.dart';
import '../services/database_service.dart';
import '../state/app_visuals_state.dart';
import '../utils/picked_upload_image.dart';
import '../widgets/side_banner_layout.dart';

class AppPicturesScreen extends ConsumerStatefulWidget {
  const AppPicturesScreen({super.key});

  @override
  ConsumerState<AppPicturesScreen> createState() => _AppPicturesScreenState();
}

class _AppPicturesScreenState extends ConsumerState<AppPicturesScreen> {
  String? uploadingKey;

  @override
  Widget build(BuildContext context) {
    final visuals =
        ref.watch(appVisualsProvider).valueOrNull ?? AppVisuals.defaults;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
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
                  tooltip: 'Back to settings',
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREATOR TOOLS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'App pictures',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Replace mountain-range cards, background banners, and the default crag picture.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    for (final definition in AppVisuals.definitions) ...[
                      _AppPictureRow(
                        definition: definition,
                        imageUrl: visuals.url(definition.key),
                        uploading: uploadingKey == definition.key,
                        onReplace: uploadingKey == null
                            ? () => _replacePicture(definition)
                            : null,
                      ),
                      if (definition != AppVisuals.definitions.last)
                        const Divider(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final compact = MediaQuery.sizeOf(context).width < 520;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: compact ? double.infinity : 112,
        height: compact ? 140 : 78,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const ColoredBox(
          color: Color(0xFFE1E8E5),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
    final details = Row(
      children: [
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, const SizedBox(height: 10), details],
            )
          : Row(
              children: [
                preview,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            ),
    );
  }
}
