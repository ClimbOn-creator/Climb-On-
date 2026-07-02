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
        child: Icon(
          Icons.landscape_outlined,
          color: PacificTerrainColors.navy,
          size: size * 0.66,
        ),
      ),
    );
  }
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
