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
    final rope = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final knot = Path()
      ..moveTo(size.width * 0.31, size.height * 0.82)
      ..lineTo(size.width * 0.49, size.height * 0.87)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.91,
        size.width * 0.80,
        size.height * 0.72,
        size.width * 0.61,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.49,
        size.height * 0.49,
        size.width * 0.31,
        size.height * 0.42,
        size.width * 0.32,
        size.height * 0.29,
      )
      ..cubicTo(
        size.width * 0.33,
        size.height * 0.15,
        size.width * 0.52,
        size.height * 0.10,
        size.width * 0.65,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.32,
        size.width * 0.69,
        size.height * 0.45,
        size.width * 0.52,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.31,
        size.height * 0.67,
        size.width * 0.24,
        size.height * 0.78,
        size.width * 0.31,
        size.height * 0.82,
      )
      ..moveTo(size.width * 0.65, size.height * 0.20)
      ..lineTo(size.width * 0.76, size.height * 0.13);
    canvas.drawPath(knot, rope);
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
