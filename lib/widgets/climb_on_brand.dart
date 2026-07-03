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
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cliff = Path()
      ..moveTo(size.width * 0.24, size.height * 0.78)
      ..lineTo(size.width * 0.34, size.height * 0.24)
      ..lineTo(size.width * 0.64, size.height * 0.24)
      ..lineTo(size.width * 0.78, size.height * 0.40)
      ..lineTo(size.width * 0.64, size.height * 0.78)
      ..close();
    canvas.drawPath(cliff, stroke);

    final route = Path()
      ..moveTo(size.width * 0.38, size.height * 0.69)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.59,
        size.width * 0.48,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.36,
        size.width * 0.53,
        size.height * 0.31,
      );
    canvas.drawPath(route, stroke);

    final bolt = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.43),
      size.shortestSide * 0.045,
      bolt,
    );
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.69),
      size.shortestSide * 0.045,
      bolt,
    );
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
