import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/activity_mode_state.dart';
import '../state/app_settings_state.dart';
import '../theme/climb_on_theme.dart';
import '../widgets/climb_on_brand.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  String currentPath = '';

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (currentPath != path) {
      currentPath = path;
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final mode = ref.watch(activityModeProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: PacificTerrainColors.cloud,
      body: Column(
        children: [
          _AppHeader(compact: compact, mode: mode, path: path),
          Expanded(
            child: path == '/map'
                ? widget.child
                : Stack(
                    children: [
                      if (settings.showTopoBackground)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _ContourPainter()),
                          ),
                        ),
                      Positioned.fill(child: widget.child),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? _MobileNavigation(path: path, mode: mode)
          : null,
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.compact,
    required this.mode,
    required this.path,
  });

  final bool compact;
  final ActivityMode mode;
  final String path;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PacificTerrainColors.cloud,
        border: Border(bottom: BorderSide(color: PacificTerrainColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: compact ? 70 : 76,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
            child: Row(
              children: [
                ClimbOnBrand(showTagline: !compact),
                if (!compact) ...[
                  const SizedBox(width: 36),
                  Expanded(
                    child: Row(
                      children: [
                        for (final destination in _destinations)
                          _DesktopNavItem(
                            destination: destination,
                            selected: path == destination.path,
                            mode: mode,
                          ),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
                _ModeSwitch(mode: mode, compact: compact),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch({required this.mode, required this.compact});

  final ActivityMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compactTextStyle = TextStyle(
      fontSize: compact ? 13 : null,
      fontWeight: compact ? FontWeight.w800 : null,
    );
    return SegmentedButton<ActivityMode>(
      showSelectedIcon: false,
      style: compact
          ? const ButtonStyle(
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            )
          : null,
      segments: [
        ButtonSegment(
          value: ActivityMode.climb,
          label: Text(
            'Climb',
            maxLines: 1,
            softWrap: false,
            style: compactTextStyle,
          ),
          icon: Icon(Icons.landscape_outlined, size: compact ? 16 : 17),
        ),
        ButtonSegment(
          value: ActivityMode.ski,
          label: Text(
            'Ski',
            maxLines: 1,
            softWrap: false,
            style: compactTextStyle,
          ),
          icon: Icon(Icons.downhill_skiing, size: compact ? 16 : 17),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        ref.read(activityModeProvider.notifier).state = selection.first;
      },
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.destination,
    required this.selected,
    required this.mode,
  });

  final _AppDestination destination;
  final bool selected;
  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: () => context.go(destination.path),
        icon: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 19,
        ),
        label: Text(destination.labelFor(mode)),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : PacificTerrainColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.path, required this.mode});

  final String path;
  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PacificTerrainColors.cloud,
        border: Border(top: BorderSide(color: PacificTerrainColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14112D3B),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (final destination in _destinations)
                Expanded(
                  child: _MobileNavItem(
                    destination: destination,
                    selected: path == destination.path,
                    mode: mode,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.destination,
    required this.selected,
    required this.mode,
  });

  final _AppDestination destination;
  final bool selected;
  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    final isAdd = destination.path == '/submit';
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF9AA5A1);
    return InkWell(
      onTap: () => context.go(_resetLocation(destination.path)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isAdd)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: PacificTerrainColors.navy,
                size: 27,
              ),
            )
          else
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 24,
              color: color,
            ),
          if (!isAdd) ...[
            const SizedBox(height: 4),
            Text(
              destination.labelFor(mode),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _resetLocation(String path) {
    return Uri(
      path: path,
      queryParameters: {
        'reset': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    ).toString();
  }
}

const _destinations = [
  _AppDestination(
    path: '/map',
    label: 'Map',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
  ),
  _AppDestination(
    path: '/feed',
    label: 'Guide',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  _AppDestination(
    path: '/submit',
    label: 'Add',
    icon: Icons.add,
    selectedIcon: Icons.add,
  ),
  _AppDestination(
    path: '/crags',
    label: 'Crags',
    skiLabel: 'Tours',
    icon: Icons.landscape_outlined,
    selectedIcon: Icons.landscape,
  ),
  _AppDestination(
    path: '/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

class _AppDestination {
  const _AppDestination({
    required this.path,
    required this.label,
    this.skiLabel,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final String? skiLabel;
  final IconData icon;
  final IconData selectedIcon;

  String labelFor(ActivityMode mode) {
    return mode == ActivityMode.ski ? skiLabel ?? label : label;
  }
}

class _ContourPainter extends CustomPainter {
  const _ContourPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawCluster({
      required Offset center,
      required double scale,
      required double phase,
    }) {
      for (var ring = 0; ring < 12; ring++) {
        final baseRadius = (48.0 + ring * 29) * scale;
        final path = Path();
        for (var step = 0; step <= 88; step++) {
          final angle = step / 88 * math.pi * 2;
          final ripple =
              math.sin(angle * 3 + ring * 0.7 + phase) *
              (5 + ring * 0.75) *
              scale;
          final radius = baseRadius + ripple;
          final point = Offset(
            center.dx + math.cos(angle) * radius * 1.35,
            center.dy + math.sin(angle) * radius * 0.72,
          );
          if (step == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    drawCluster(
      center: Offset(size.width * 0.86, size.height * 0.12),
      scale: 1,
      phase: 0,
    );
    drawCluster(
      center: Offset(size.width * 0.08, size.height * 0.82),
      scale: 0.72,
      phase: 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
