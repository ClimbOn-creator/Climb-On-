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
      ..style = PaintingStyle.fill;

    // Three interlocking ridge ribbons keep the mark crisp at app-icon size.
    final leftRidge = Path()
      ..moveTo(size.width * 0.10, size.height * 0.72)
      ..lineTo(size.width * 0.39, size.height * 0.37)
      ..lineTo(size.width * 0.53, size.height * 0.51)
      ..lineTo(size.width * 0.46, size.height * 0.58)
      ..lineTo(size.width * 0.39, size.height * 0.49)
      ..lineTo(size.width * 0.25, size.height * 0.66)
      ..close();
    canvas.drawPath(leftRidge, mountain);

    final centerRidge = Path()
      ..moveTo(size.width * 0.30, size.height * 0.70)
      ..lineTo(size.width * 0.63, size.height * 0.24)
      ..lineTo(size.width * 0.87, size.height * 0.68)
      ..lineTo(size.width * 0.70, size.height * 0.55)
      ..lineTo(size.width * 0.63, size.height * 0.61)
      ..lineTo(size.width * 0.53, size.height * 0.49)
      ..lineTo(size.width * 0.39, size.height * 0.66)
      ..close();
    canvas.drawPath(centerRidge, mountain);

    final rightRidge = Path()
      ..moveTo(size.width * 0.56, size.height * 0.53)
      ..lineTo(size.width * 0.67, size.height * 0.40)
      ..lineTo(size.width * 0.74, size.height * 0.50)
      ..lineTo(size.width * 0.79, size.height * 0.45)
      ..lineTo(size.width * 0.91, size.height * 0.70)
      ..lineTo(size.width * 0.73, size.height * 0.58)
      ..lineTo(size.width * 0.65, size.height * 0.64)
      ..close();
    canvas.drawPath(rightRidge, mountain);
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
