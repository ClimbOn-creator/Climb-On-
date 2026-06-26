import 'package:flutter/material.dart';

class SideBannerLayout extends StatelessWidget {
  const SideBannerLayout({
    super.key,
    required this.child,
    this.maxContentWidth = 860,
  });

  final Widget child;
  final double maxContentWidth;

  static const _leftImage =
      'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5';
  static const _rightImage =
      'https://images.unsplash.com/photo-1519681393784-d120267933ba';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showBanners = width >= 760;
    final bannerWidth = width >= 1180
        ? 150.0
        : width >= 900
        ? 96.0
        : 76.0;

    if (!showBanners) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerticalMountainBanner(imageUrl: _leftImage, width: bannerWidth),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
        _VerticalMountainBanner(imageUrl: _rightImage, width: bannerWidth),
      ],
    );
  }
}

class _VerticalMountainBanner extends StatelessWidget {
  const _VerticalMountainBanner({required this.imageUrl, required this.width});

  final String imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width >= 120 ? 12 : 6,
          16,
          width >= 120 ? 12 : 6,
          16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(imageUrl, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.26),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        'Ad',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
