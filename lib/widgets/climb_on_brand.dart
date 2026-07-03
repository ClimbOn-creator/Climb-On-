import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/climb_on_theme.dart';

class ClimbOnLogo extends StatelessWidget {
  const ClimbOnLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Climb On logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(size * 0.16),
        ),
        child: CustomPaint(
          painter: _ClimbOnMarkPainter(color: PacificTerrainColors.navy),
        ),
      ),
    );
  }
}

class _ClimbOnMarkPainter extends CustomPainter {
  const _ClimbOnMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mountain = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.072
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final peaks = Path()
      ..moveTo(size.width * 0.13, size.height * 0.72)
      ..lineTo(size.width * 0.37, size.height * 0.38)
      ..lineTo(size.width * 0.48, size.height * 0.52)
      ..lineTo(size.width * 0.64, size.height * 0.24)
      ..lineTo(size.width * 0.88, size.height * 0.72);
    canvas.drawPath(peaks, mountain);

    final snow = Path()
      ..moveTo(size.width * 0.55, size.height * 0.40)
      ..lineTo(size.width * 0.64, size.height * 0.24)
      ..lineTo(size.width * 0.72, size.height * 0.40)
      ..lineTo(size.width * 0.67, size.height * 0.37)
      ..lineTo(size.width * 0.63, size.height * 0.43)
      ..lineTo(size.width * 0.59, size.height * 0.36)
      ..close();
    canvas.drawPath(snow, mountain);

    final trail = Path()
      ..moveTo(size.width * 0.24, size.height * 0.78)
      ..cubicTo(
        size.width * 0.43,
        size.height * 0.67,
        size.width * 0.57,
        size.height * 0.88,
        size.width * 0.79,
        size.height * 0.72,
      );
    canvas.drawPath(trail, mountain);
  }

  @override
  bool shouldRepaint(covariant _ClimbOnMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ClimbOnBrand extends StatelessWidget {
  const ClimbOnBrand({super.key, this.showTagline = true});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ClimbOnLogo(),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CLIMB ON',
              style: GoogleFonts.manrope(
                color: PacificTerrainColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            if (showTagline)
              Text(
                'Built by Canadians for Canadians.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
