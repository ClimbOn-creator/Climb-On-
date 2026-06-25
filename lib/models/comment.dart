class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String body;
  final DateTime createdAt;
}
