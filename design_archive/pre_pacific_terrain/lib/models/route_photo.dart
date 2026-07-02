class RoutePhoto {
  const RoutePhoto({
    required this.id,
    required this.url,
    required this.caption,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String caption;
  final DateTime createdAt;
}
