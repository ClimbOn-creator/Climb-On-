class ARScan {
  const ARScan({
    required this.id,
    required this.routeId,
    required this.createdByUserId,
    required this.assetUrl,
    required this.createdAt,
  });

  final String id;
  final String routeId;
  final String createdByUserId;
  final String assetUrl;
  final DateTime createdAt;
}
