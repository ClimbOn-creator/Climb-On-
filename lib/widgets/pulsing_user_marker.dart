import 'package:flutter/material.dart';

class PulsingUserMarker extends StatefulWidget {
  const PulsingUserMarker({super.key});

  @override
  State<PulsingUserMarker> createState() => _PulsingUserMarkerState();
}

class _PulsingUserMarkerState extends State<PulsingUserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = controller.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16 + (t * 22),
              height: 16 + (t * 22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 1 - t),
              ),
            ),
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }
}
