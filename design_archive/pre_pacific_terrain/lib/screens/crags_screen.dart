import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/crag.dart';
import '../models/climb_route.dart';
import '../services/database_service.dart';
import '../state/activity_mode_state.dart';
import '../state/admin_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/ski_route_state.dart';
import '../models/wall.dart';
import '../widgets/side_banner_layout.dart';
import '../widgets/admin_route_editor.dart';

class CragsScreen extends ConsumerWidget {
  const CragsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTitleBar = MediaQuery.sizeOf(context).width >= 1024;
    final mode = ref.watch(activityModeProvider);
    final catalog = ref.watch(catalogProvider);
    final skiCatalog = ref.watch(skiRouteCatalogProvider);
    final skiRoutes = skiCatalog.valueOrNull ?? const [];
    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];

    return Scaffold(
      appBar: showTitleBar
          ? AppBar(
              title: Text(mode == ActivityMode.ski ? 'Ski Tours' : 'Crags'),
            )
          : null,
      body: SideBannerLayout(
        child: mode == ActivityMode.ski
            ? skiRoutes.isEmpty && skiCatalog.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: skiRoutes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final route = skiRoutes[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.downhill_skiing),
                            title: Text(route.name),
                            subtitle: Text(
                              '${route.area} - ${route.distanceKm} km - ${route.elevationGainMeters} m',
                            ),
                            trailing: Chip(label: Text(route.difficulty)),
                          ),
                        );
                      },
                    )
            : catalogCrags.isEmpty && catalog.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: catalogCrags.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final crag = catalogCrags[index];
                  final routeCount = crag.walls.fold<int>(
                    0,
                    (count, wall) => count + wall.routes.length,
                  );

                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _openCrag(context, ref, crag),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.terrain,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    crag.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    '${crag.region}, ${crag.province}',
                                  ),
                                ),
                                Chip(label: Text(crag.season)),
                                Chip(label: Text('$routeCount routes')),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(crag.accessNotes),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _openCrag(BuildContext context, WidgetRef ref, Crag crag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _CragRoutePicker(
          crag: crag,
          onRouteSelected: (route) {
            Navigator.pop(context);
            ref.read(focusedRouteProvider.notifier).state = route;
            context.go('/feed');
          },
        );
      },
    );
  }
}

class _CragRoutePicker extends ConsumerStatefulWidget {
  const _CragRoutePicker({required this.crag, required this.onRouteSelected});

  final Crag crag;
  final ValueChanged<ClimbRoute> onRouteSelected;

  @override
  ConsumerState<_CragRoutePicker> createState() => _CragRoutePickerState();
}

class _CragRoutePickerState extends ConsumerState<_CragRoutePicker> {
  Wall? selectedWall;
  late String dangerInfo;

  @override
  void initState() {
    super.initState();
    dangerInfo = widget.crag.dangerInfo;
  }

  @override
  Widget build(BuildContext context) {
    final walls = widget.crag.walls;
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.crag.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('${widget.crag.region}, ${widget.crag.province}'),
                ),
                Chip(label: Text(widget.crag.season)),
                Chip(label: Text('${widget.crag.walls.length} walls')),
              ],
            ),
            const SizedBox(height: 12),
            _CragNotice(
              icon: Icons.warning_amber,
              label: dangerInfo,
              color: Theme.of(context).colorScheme.error,
              onEdit:
                  isAdmin ||
                      const DatabaseService().currentUserId ==
                          widget.crag.createdBy
                  ? _editWarning
                  : null,
            ),
            const SizedBox(height: 8),
            _CragNotice(
              icon: Icons.hiking,
              label: widget.crag.approachTrail,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            _CragNotice(
              icon: Icons.lock_open,
              label: widget.crag.accessNotes,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Walls',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wall in walls)
                  ChoiceChip(
                    label: Text(wall.name),
                    selected: selectedWall == wall,
                    onSelected: (_) => setState(() => selectedWall = wall),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedWall == null ? 'Select a wall' : 'Routes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isAdmin && selectedWall != null)
                  FilledButton.icon(
                    onPressed: () => _openRouteEditor(selectedWall!),
                    icon: const Icon(Icons.add),
                    label: const Text('Add route'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (selectedWall == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Pick a wall to see its routes.'),
                ),
              )
            else if (selectedWall!.routes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isAdmin
                        ? 'No routes yet. Use Add route to create the first one.'
                        : 'No routes have been added to this wall yet.',
                  ),
                ),
              )
            else
              ...selectedWall!.routes.map(
                (route) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.route),
                      title: Text(route.name),
                      subtitle: Text(
                        '${route.grade} - ${route.typeLabel} - ${route.pitchLabel} - ${route.rating}/5',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin)
                            IconButton(
                              tooltip: 'Edit every route detail',
                              onPressed: () =>
                                  _openRouteEditor(selectedWall!, route: route),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => widget.onRouteSelected(route),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openRouteEditor(Wall wall, {ClimbRoute? route}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.94,
        child: AdminRouteEditor(wall: wall, route: route),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(catalogProvider);
    Navigator.pop(context);
  }

  Future<void> _editWarning() async {
    final controller = TextEditingController(text: dangerInfo);
    final warning = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit crag warning'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Safety warning'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (warning == null || warning.isEmpty || !mounted) return;
    try {
      await const DatabaseService().updateCreatorCragWarning(
        cragId: widget.crag.id,
        warning: warning,
      );
      if (!mounted) return;
      setState(() => dangerInfo = warning);
      ref.invalidate(catalogProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update warning: $error')),
      );
    }
  }
}

class _CragNotice extends StatelessWidget {
  const _CragNotice({
    required this.icon,
    required this.label,
    required this.color,
    this.onEdit,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onEdit;

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
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit warning',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
