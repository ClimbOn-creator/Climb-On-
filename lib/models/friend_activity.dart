class FriendActivity {
  const FriendActivity({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String routeId;
  final String summary;
  final DateTime createdAt;
}
