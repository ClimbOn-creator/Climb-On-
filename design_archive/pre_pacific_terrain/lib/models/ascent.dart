class Ascent {
  const Ascent({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.routeName,
    required this.grade,
    required this.style,
    required this.sentAt,
  });

  final String id;
  final String userId;
  final String routeId;
  final String routeName;
  final String grade;
  final String style;
  final DateTime sentAt;
}
