class FriendProfile {
  const FriendProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.homeArea,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final String homeArea;

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      homeArea: json['home_area']?.toString() ?? '',
    );
  }
}

class FriendSendActivity {
  const FriendSendActivity({
    required this.user,
    required this.routeId,
    required this.grade,
    required this.style,
    required this.sentAt,
  });

  final FriendProfile user;
  final String routeId;
  final String grade;
  final String style;
  final DateTime sentAt;

  factory FriendSendActivity.fromJson(Map<String, dynamic> json) {
    return FriendSendActivity(
      user: FriendProfile.fromJson({
        'id': json['user_id'],
        'username': json['username'],
        'display_name': json['display_name'],
        'avatar_url': json['avatar_url'],
        'bio': json['bio'],
        'home_area': json['home_area'],
      }),
      routeId: json['route_id']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      style: json['style']?.toString() ?? '',
      sentAt:
          DateTime.tryParse(json['sent_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class UserRouteComment {
  const UserRouteComment({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String body;
  final DateTime createdAt;

  factory UserRouteComment.fromJson(Map<String, dynamic> json) {
    return UserRouteComment(
      id: json['id']?.toString() ?? '',
      routeId: json['route_id']?.toString() ?? '',
      routeName: json['route_name']?.toString() ?? 'Route',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
