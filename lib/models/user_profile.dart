class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bio = '',
    this.homeArea = '',
    this.climbingStyle = '',
    this.isPublic = false,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String bio;
  final String homeArea;
  final String climbingStyle;
  final bool isPublic;

  bool get isComplete =>
      displayName.trim().isNotEmpty && username.trim().isNotEmpty;

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString() ?? '',
      homeArea: json['home_area']?.toString() ?? '',
      climbingStyle: json['climbing_style']?.toString() ?? '',
      isPublic: json['is_public'] == true,
    );
  }
}
