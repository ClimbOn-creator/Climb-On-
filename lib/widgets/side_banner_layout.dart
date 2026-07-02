import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_visuals.dart';
import '../state/app_visuals_state.dart';

class SideBannerLayout extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals =
        ref.watch(appVisualsProvider).valueOrNull ?? AppVisuals.defaults;
    final leftImage = visuals.url('side_banner_left');
    final rightImage = visuals.url('side_banner_right');
    final width = MediaQuery.sizeOf(context).width;
    final showBanners = width >= 760;
    final bannerWidth = width >= 1180
        ? 150.0
        : width >= 900
        ? 96.0
        : 76.0;

    if (!showBanners) {
      if (showCompactBanners) {
        return Column(
          children: [
            _CompactMountainBanner(imageUrl: leftImage),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: child,
                ),
              ),
            ),
            _CompactMountainBanner(imageUrl: rightImage),
          ],
        );
      }
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
        _VerticalMountainBanner(imageUrl: leftImage, width: bannerWidth),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
        _VerticalMountainBanner(imageUrl: rightImage, width: bannerWidth),
      ],
    );
  }
}

class _CompactMountainBanner extends StatelessWidget {
  const _CompactMountainBanner({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover),
          ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  child: Text('Ad', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(14),
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
                        'SPONSORED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1,
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
