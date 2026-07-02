import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/crag.dart';
import 'models/climb_route.dart';
import 'state/climb_log_state.dart';
import 'models/wall.dart';

class CragSidebar extends ConsumerWidget {
  const CragSidebar({
    super.key,
    required this.crag,
    required this.selectedWall,
    required this.onWallSelected,
    this.onRouteSelected,
    this.scrollController,
  });

  final Crag crag;
  final Wall? selectedWall;
  final ValueChanged<Wall> onWallSelected;
  final ValueChanged<ClimbRoute>? onRouteSelected;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final climbLog = ref.watch(climbLogProvider);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: climbLog,
        builder: (context, _) {
          final routes = selectedWall?.routes ?? const <ClimbRoute>[];

          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _CragHeader(crag: crag)),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Boulders and walls',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 78,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: crag.walls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final wall = crag.walls[index];

                      return ChoiceChip(
                        label: Text(wall.name),
                        selected: wall == selectedWall,
                        onSelected: (_) => onWallSelected(wall),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              if (selectedWall == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Pick a boulder or wall.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList.separated(
                    itemCount: routes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      final completed = climbLog.isCompleted(route);

                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: completed,
                            onChanged: (_) => climbLog.toggleRoute(route),
                          ),
                          title: Text(route.name),
                          subtitle: Text(
                            '${route.grade} - ${route.typeLabel} - ${route.pitchLabel} - ${route.rating}/5',
                          ),
                          trailing: onRouteSelected == null
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: onRouteSelected == null
                              ? null
                              : () => onRouteSelected!(route),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CragHeader extends StatelessWidget {
  const _CragHeader({required this.crag});

  final Crag crag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  crag.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.terrain),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.place,
                label: '${crag.region}, ${crag.province}',
              ),
              _InfoChip(icon: Icons.wb_sunny, label: crag.season),
            ],
          ),
          const SizedBox(height: 12),
          _NoticeBand(
            icon: Icons.warning_amber,
            label: crag.dangerInfo,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          _NoticeBand(
            icon: Icons.hiking,
            label: crag.approachTrail,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 8),
          _NoticeBand(
            icon: Icons.lock_open,
            label: crag.accessNotes,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: const Color(0xFFFFF0C2),
    );
  }
}

class _NoticeBand extends StatelessWidget {
  const _NoticeBand({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
