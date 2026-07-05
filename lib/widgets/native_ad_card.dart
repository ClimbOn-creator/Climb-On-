import 'package:flutter/material.dart';

import '../state/activity_mode_state.dart';
import '../theme/climb_on_theme.dart';

class NativeAdCard extends StatelessWidget {
  const NativeAdCard({
    super.key,
    required this.mode,
    this.compact = false,
    this.persistent = false,
  });

  final ActivityMode mode;
  final bool compact;
  final bool persistent;

  @override
  Widget build(BuildContext context) {
    final isSki = mode == ActivityMode.ski;
    if (persistent) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              8,
              compact ? 16 : 28,
              8,
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: PacificTerrainColors.navySoft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
                child: SizedBox(
                  height: compact ? 42 : 50,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          isSki ? Icons.ac_unit : Icons.storefront,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSki
                                  ? 'SPONSORED · WINTER KIT'
                                  : 'SPONSORED · LOCAL GEAR',
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                            ),
                            Text(
                              isSki
                                  ? 'Touring essentials from Canadian shops.'
                                  : 'Climbing gear from Canadian shops.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
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
