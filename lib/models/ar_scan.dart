import 'ar_beta_overlay.dart';

class ARScan {
  const ARScan({
    required this.id,
    required this.routeId,
    required this.assetUrl,
    this.anchorImageUrl = '',
    this.instructions = '',
    this.scaleHintMeters,
    this.displayPriority = 100,
    this.betaOverlay,
    this.enabled = true,
    this.createdByUserId = '',
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String routeId;
  final String assetUrl;
  final String anchorImageUrl;
  final String instructions;
  final double? scaleHintMeters;
  final int displayPriority;
  final ARBetaOverlay? betaOverlay;
  final bool enabled;
  final String createdByUserId;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isAvailable => enabled && assetUrl.trim().isNotEmpty;
  bool get hasBetaOverlay => betaOverlay?.isNotEmpty ?? false;
}
