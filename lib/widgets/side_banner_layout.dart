import 'package:flutter/material.dart';

class SideBannerLayout extends StatelessWidget {
  const SideBannerLayout({
    super.key,
    required this.child,
    this.maxContentWidth = 860,
    this.showCompactBanners = false,
  });

  final Widget child;
  final double maxContentWidth;
  final bool showCompactBanners;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
