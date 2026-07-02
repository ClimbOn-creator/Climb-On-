import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/activity_mode_state.dart';
import '../theme/climb_on_theme.dart';
import '../widgets/climb_on_brand.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final mode = ref.watch(activityModeProvider);

    return Scaffold(
      backgroundColor: PacificTerrainColors.cloud,
      body: Column(
        children: [
          _AppHeader(compact: compact, mode: mode, path: path),
          Expanded(
            child: path == '/map'
                ? child
                : Stack(
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _ContourPainter()),
                        ),
                      ),
                      Positioned.fill(child: child),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: compact ? _MobileNavigation(path: path) : null,
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
          height: compact ? 64 : 76,
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
    return SegmentedButton<ActivityMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: ActivityMode.climb,
          label: Text(
            'Climb',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: compact ? 11 : null),
          ),
          icon: compact ? null : const Icon(Icons.landscape_outlined, size: 17),
        ),
        ButtonSegment(
          value: ActivityMode.ski,
          label: Text(
            'Ski',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: compact ? 11 : null),
          ),
          icon: compact ? null : const Icon(Icons.downhill_skiing, size: 17),
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
  const _DesktopNavItem({required this.destination, required this.selected});

  final _AppDestination destination;
  final bool selected;

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
        label: Text(destination.label),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? PacificTerrainColors.cedar
              : PacificTerrainColors.navy,
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
  const _MobileNavigation({required this.path});

  final String path;

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
          height: 68,
          child: Row(
            children: [
              for (final destination in _destinations)
                Expanded(
                  child: _MobileNavItem(
                    destination: destination,
                    selected: path == destination.path,
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
  const _MobileNavItem({required this.destination, required this.selected});

  final _AppDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isAdd = destination.path == '/submit';
    final color = selected
        ? PacificTerrainColors.cedar
        : PacificTerrainColors.navySoft;
    return InkWell(
      onTap: () => context.go(destination.path),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isAdd)
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: PacificTerrainColors.cedar,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 23),
            )
          else
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 21,
              color: color,
            ),
          if (!isAdd) ...[
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
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
    label: 'Feed',
    icon: Icons.dynamic_feed_outlined,
    selectedIcon: Icons.dynamic_feed,
  ),
  _AppDestination(
    path: '/crags',
    label: 'Crags',
    icon: Icons.landscape_outlined,
    selectedIcon: Icons.landscape,
  ),
  _AppDestination(
    path: '/submit',
    label: 'Add',
    icon: Icons.add,
    selectedIcon: Icons.add,
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
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _ContourPainter extends CustomPainter {
  const _ContourPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PacificTerrainColors.navy.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * 0.88, size.height * 0.16);
    for (var ring = 0; ring < 11; ring++) {
      final baseRadius = 56.0 + ring * 31;
      final path = Path();
      for (var step = 0; step <= 80; step++) {
        final angle = step / 80 * math.pi * 2;
        final ripple = math.sin(angle * 3 + ring * 0.7) * (5 + ring * 0.8);
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
