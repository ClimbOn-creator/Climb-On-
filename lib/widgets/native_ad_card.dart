import 'package:flutter/material.dart';

import '../state/activity_mode_state.dart';
import '../theme/climb_on_theme.dart';

class NativeAdCard extends StatelessWidget {
  const NativeAdCard({super.key, required this.mode, this.compact = false});

  final ActivityMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSki = mode == ActivityMode.ski;
    return Card(
      margin: EdgeInsets.only(bottom: compact ? 16 : 24),
      color: PacificTerrainColors.navySoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSki ? Icons.ac_unit : Icons.storefront,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSki ? 'SPONSORED · WINTER KIT' : 'SPONSORED · LOCAL GEAR',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.1,
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
