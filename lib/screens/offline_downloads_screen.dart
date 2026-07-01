import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/offline_map_config.dart';
import '../models/offline_bc_region.dart';
import '../state/offline_download_state.dart';

class OfflineDownloadsScreen extends ConsumerWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Offline BC downloads')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download before leaving service',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Each section saves climbing and ski information, routes, comments, pictures, and supported map layers. GPS location and saved recordings work without cell service.',
                  ),
                ],
              ),
            ),
          ),
          if (!OfflineMapConfig.allCoreMapsConfigured)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('Offline map provider setup required'),
                subtitle: Text(
                  'Data and pictures can download now. The self-hosted open map service must be connected to activate satellite, topo, and 3D packs.',
                ),
              ),
            ),
          if (OfflineMapConfig.allCoreMapsConfigured)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Open-data maps connected'),
                subtitle: Text(
                  'Street and topo maps use OpenStreetMap/Protomaps, terrain uses Mapterhorn, and satellite uses Copernicus Sentinel-2.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final region in offlineBcRegions)
            _RegionDownloadCard(
              region: region,
              status: downloads.statusFor(region.id),
              onDownload: () => downloads.download(region),
              onRemove: () => _confirmRemove(context, downloads, region),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    OfflineDownloadState downloads,
    OfflineBcRegion region,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${region.name}?'),
        content: const Text(
          'The downloaded map packs will be removed. Shared route pictures may remain cached if another section uses them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await downloads.remove(region);
  }
}

class _RegionDownloadCard extends StatelessWidget {
  const _RegionDownloadCard({
    required this.region,
    required this.status,
    required this.onDownload,
    required this.onRemove,
  });

  final OfflineBcRegion region;
  final OfflineRegionStatus status;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    region.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (status.ready)
                  const Chip(
                    avatar: Icon(Icons.offline_pin, size: 17),
                    label: Text('Offline ready'),
                  )
                else if (status.dataReady)
                  const Chip(
                    avatar: Icon(Icons.photo_library_outlined, size: 17),
                    label: Text('Info ready'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(region.description),
            if (status.downloading || status.progress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: status.progress.clamp(0, 1)),
            ],
            if (status.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                status.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: status.downloading ? null : onDownload,
                  icon: status.downloading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(status.dataReady ? Icons.sync : Icons.download),
                  label: Text(status.dataReady ? 'Update' : 'Download'),
                ),
                if (status.dataReady || status.mapsReady) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: status.downloading ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
