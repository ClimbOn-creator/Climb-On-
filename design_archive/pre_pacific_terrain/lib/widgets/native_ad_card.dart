import 'package:flutter/material.dart';

import '../state/activity_mode_state.dart';

class NativeAdCard extends StatelessWidget {
  const NativeAdCard({super.key, required this.mode, this.compact = false});

  final ActivityMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSki = mode == ActivityMode.ski;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 16 : 24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSki ? Icons.ac_unit : Icons.storefront,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSki ? 'Sponsored: winter kit' : 'Sponsored: local gear',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSki
                        ? 'Avalanche tools, touring packs, and cold-weather layers from Canadian shops.'
                        : 'Ropes, draws, pads, and guidebooks from Canadian climbing shops.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              TextButton(onPressed: () {}, child: const Text('View')),
            ],
          ],
        ),
      ),
    );
  }
}
