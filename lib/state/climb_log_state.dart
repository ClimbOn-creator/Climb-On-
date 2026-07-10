import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/climb_route.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

final climbLogProvider = ChangeNotifierProvider<ClimbLogState>((ref) {
  final state = ClimbLogState();
  const authService = AuthService();
  if (authService.isConfigured) {
    unawaited(state.syncCompletedRoutes());
    final subscription = authService.authStateChanges.listen((_) {
      unawaited(state.syncCompletedRoutes());
    });
    ref.onDispose(subscription.cancel);
  }
  return state;
});

final focusedRouteProvider = StateProvider<ClimbRoute?>((ref) => null);

class Send {
  const Send({
    required this.routeId,
    required this.routeName,
    required this.grade,
    required this.style,
    required this.sentAt,
  });

  final String routeId;
  final String routeName;
  final String grade;
  final String style;
  final DateTime sentAt;

  Map<String, Object?> toJson() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'grade': grade,
      'style': style,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  static Send? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final routeId = value['routeId'];
    final routeName = value['routeName'];
    final grade = value['grade'];
    final style = value['style'];
    final sentAt = value['sentAt'];

    if (routeId is! String ||
        routeName is! String ||
        grade is! String ||
        style is! String ||
        sentAt is! String) {
      return null;
    }

    final parsedSentAt = DateTime.tryParse(sentAt);
    if (parsedSentAt == null) return null;

    return Send(
      routeId: routeId,
      routeName: routeName,
      grade: grade,
      style: style,
      sentAt: parsedSentAt,
    );
  }
}

class Attempt {
  const Attempt({
    required this.routeId,
    required this.routeName,
    required this.grade,
    required this.note,
    required this.attemptedAt,
  });

  final String routeId;
  final String routeName;
  final String grade;
  final String note;
  final DateTime attemptedAt;

  Map<String, Object?> toJson() => {
    'routeId': routeId,
    'routeName': routeName,
    'grade': grade,
    'note': note,
    'attemptedAt': attemptedAt.toIso8601String(),
  };

  static Attempt? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final attemptedAt = DateTime.tryParse(
      value['attemptedAt']?.toString() ?? '',
    );
    if (attemptedAt == null) return null;
    return Attempt(
      routeId: value['routeId']?.toString() ?? '',
      routeName: value['routeName']?.toString() ?? '',
      grade: value['grade']?.toString() ?? '',
      note: value['note']?.toString() ?? '',
      attemptedAt: attemptedAt,
    );
  }
}

class GradeOpinion {
  const GradeOpinion({
    required this.routeId,
    required this.routeName,
    required this.suggestedGrade,
    required this.createdAt,
  });

  final String routeId;
  final String routeName;
  final String suggestedGrade;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'routeId': routeId,
    'routeName': routeName,
    'suggestedGrade': suggestedGrade,
    'createdAt': createdAt.toIso8601String(),
  };

  static GradeOpinion? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (createdAt == null) return null;
    return GradeOpinion(
      routeId: value['routeId']?.toString() ?? '',
      routeName: value['routeName']?.toString() ?? '',
      suggestedGrade: value['suggestedGrade']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}

class LocalRouteComment {
  const LocalRouteComment({
    this.id = '',
    this.userId = '',
    required this.routeId,
    required this.body,
    this.parentCommentId = '',
    this.authorUsername = '',
    this.authorDisplayName = '',
    this.authorAvatarUrl = '',
    this.authorBio = '',
    this.authorHomeArea = '',
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String routeId;
  final String body;
  final String parentCommentId;
  final String authorUsername;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final String authorBio;
  final String authorHomeArea;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'routeId': routeId,
    'body': body,
    'parentCommentId': parentCommentId,
    'authorUsername': authorUsername,
    'authorDisplayName': authorDisplayName,
    'authorAvatarUrl': authorAvatarUrl,
    'authorBio': authorBio,
    'authorHomeArea': authorHomeArea,
    'createdAt': createdAt.toIso8601String(),
  };

  static LocalRouteComment? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (createdAt == null) return null;
    return LocalRouteComment(
      id: value['id']?.toString() ?? '',
      userId: value['userId']?.toString() ?? '',
      routeId: value['routeId']?.toString() ?? '',
      body: value['body']?.toString() ?? '',
      parentCommentId: value['parentCommentId']?.toString() ?? '',
      authorUsername: value['authorUsername']?.toString() ?? '',
      authorDisplayName: value['authorDisplayName']?.toString() ?? '',
      authorAvatarUrl: value['authorAvatarUrl']?.toString() ?? '',
      authorBio: value['authorBio']?.toString() ?? '',
      authorHomeArea: value['authorHomeArea']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  static LocalRouteComment? fromCloudJson(
    Map<String, dynamic> value, [
    Map<String, dynamic>? profile,
  ]) {
    final createdAt = DateTime.tryParse(value['created_at']?.toString() ?? '');
    if (createdAt == null) return null;
    return LocalRouteComment(
      id: value['id']?.toString() ?? '',
      userId: value['user_id']?.toString() ?? '',
      routeId: value['route_id']?.toString() ?? '',
      body: value['body']?.toString() ?? '',
      parentCommentId: value['parent_comment_id']?.toString() ?? '',
      authorUsername: profile?['username']?.toString() ?? '',
      authorDisplayName: profile?['display_name']?.toString() ?? '',
      authorAvatarUrl: profile?['avatar_url']?.toString() ?? '',
      authorBio: profile?['bio']?.toString() ?? '',
      authorHomeArea: profile?['home_area']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}

class LocalRoutePhoto {
  const LocalRoutePhoto({
    this.id = '',
    this.userId = '',
    required this.routeId,
    required this.url,
    this.storagePath = '',
    required this.caption,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String routeId;
  final String url;
  final String storagePath;
  final String caption;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'routeId': routeId,
    'url': url,
    'storagePath': storagePath,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
  };

  static LocalRoutePhoto? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (createdAt == null) return null;
    return LocalRoutePhoto(
      id: value['id']?.toString() ?? '',
      userId: value['userId']?.toString() ?? '',
      routeId: value['routeId']?.toString() ?? '',
      url: value['url']?.toString() ?? '',
      storagePath: value['storagePath']?.toString() ?? '',
      caption: value['caption']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  static LocalRoutePhoto? fromCloudJson(Map<String, dynamic> value) {
    final createdAt = DateTime.tryParse(value['created_at']?.toString() ?? '');
    if (createdAt == null) return null;
    return LocalRoutePhoto(
      id: value['id']?.toString() ?? '',
      userId: value['user_id']?.toString() ?? '',
      routeId: value['route_id']?.toString() ?? '',
      url: value['url']?.toString() ?? '',
      storagePath: value['storage_path']?.toString() ?? '',
      caption: value['caption']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}

class ClimbLogState extends ChangeNotifier {
  ClimbLogState({
    this.preferences,
    this.persistenceEnabled = true,
    this.databaseService = const DatabaseService(),
  }) {
    _restoreFuture = persistenceEnabled ? _restore() : Future<void>.value();
  }

  static const _storageKey = 'climb_on_sends_v1';

  final SharedPreferences? preferences;
  final bool persistenceEnabled;
  final DatabaseService databaseService;
  late final Future<void> _restoreFuture;
  final List<Send> _sends = [];
  final List<Attempt> _attempts = [];
  final List<GradeOpinion> _gradeOpinions = [];
  final List<LocalRouteComment> _comments = [];
  final List<LocalRoutePhoto> _photos = [];
  final Set<String> _projectRouteIds = {};
  final Set<String> _completedRoutes = {};
  final Set<String> _loadedPhotoRoutes = {};
  final Set<String> _loadingPhotoRoutes = {};
  final Set<String> _loadingCommentRoutes = {};
  bool _disposed = false;

  List<Send> get sends => List.unmodifiable(_sends);
  List<Attempt> get attempts => List.unmodifiable(_attempts);
  List<GradeOpinion> get gradeOpinions => List.unmodifiable(_gradeOpinions);
  Set<String> get projectRouteIds => Set.unmodifiable(_projectRouteIds);
  String? get currentUserId => databaseService.currentUserId;
  bool get canUploadPhotos => currentUserId != null;
  bool get canComment => !databaseService.isConfigured || currentUserId != null;

  bool isCompleted(ClimbRoute route) => _completedRoutes.contains(route.id);
  bool isProject(ClimbRoute route) => _projectRouteIds.contains(route.id);

  Future<void> syncCompletedRoutes() async {
    await _restoreFuture;
    if (!databaseService.isCloudReady || _disposed) return;

    try {
      for (final send in _sends) {
        await databaseService.saveCompletedRoute(send);
      }
      final cloudSends = await databaseService.loadCompletedRoutes();
      if (_disposed) return;

      final merged = <String, Send>{
        for (final send in cloudSends) send.routeId: send,
        for (final send in _sends) send.routeId: send,
      }.values.toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));
      _sends
        ..clear()
        ..addAll(merged);
      _completedRoutes
        ..clear()
        ..addAll(merged.map((send) => send.routeId));
      await _persist();
      notifyListeners();
    } catch (_) {
      // Local logbook data remains available while cloud sync is unavailable.
    }
  }

  List<Attempt> attemptsFor(ClimbRoute route) {
    return _attempts
        .where((attempt) => attempt.routeId == route.id)
        .toList(growable: false);
  }

  List<GradeOpinion> gradeOpinionsFor(ClimbRoute route) {
    return _gradeOpinions
        .where((opinion) => opinion.routeId == route.id)
        .toList(growable: false);
  }

  List<LocalRouteComment> commentsFor(ClimbRoute route) {
    return _comments
        .where((comment) => comment.routeId == route.id)
        .toList(growable: false);
  }

  Future<void> loadCommentsFor(ClimbRoute route) async {
    if (!databaseService.isConfigured || !_loadingCommentRoutes.add(route.id)) {
      return;
    }

    try {
      final comments = await databaseService.loadComments(route.id);
      _comments.removeWhere((comment) => comment.routeId == route.id);
      _comments.addAll(comments);
      await _persist();
      notifyListeners();
    } catch (_) {
      // Keep cached comments visible when the cloud is temporarily offline.
    } finally {
      _loadingCommentRoutes.remove(route.id);
    }
  }

  List<LocalRoutePhoto> photosFor(ClimbRoute route) {
    return _photos
        .where((photo) => photo.routeId == route.id)
        .toList(growable: false);
  }

  bool canDeletePhoto(LocalRoutePhoto photo) {
    final userId = currentUserId;
    return userId != null && photo.userId == userId;
  }

  Future<void> loadPhotosFor(ClimbRoute route) async {
    if (!databaseService.isConfigured ||
        _loadedPhotoRoutes.contains(route.id) ||
        !_loadingPhotoRoutes.add(route.id)) {
      return;
    }

    try {
      final photos = await databaseService.loadPhotos(route.id);
      _photos.removeWhere((photo) => photo.routeId == route.id);
      _photos.addAll(photos);
      _loadedPhotoRoutes.add(route.id);
      await _persist();
      notifyListeners();
    } catch (_) {
      // Keep any cached pictures visible when the cloud is temporarily offline.
    } finally {
      _loadingPhotoRoutes.remove(route.id);
    }
  }

  void toggleRoute(ClimbRoute route) {
    Send? savedSend;
    if (_completedRoutes.contains(route.id)) {
      _completedRoutes.remove(route.id);
      _sends.removeWhere((send) => send.routeId == route.id);
      unawaited(databaseService.deleteCompletedRoute(route.id));
    } else {
      _completedRoutes.add(route.id);
      savedSend = Send(
        routeId: route.id,
        routeName: route.name,
        grade: route.grade,
        style: 'Redpoint',
        sentAt: DateTime.now(),
      );
      _sends.insert(0, savedSend);
    }

    unawaited(_persist());
    if (savedSend != null) {
      unawaited(databaseService.saveCompletedRoute(savedSend));
    }
    notifyListeners();
  }

  void addAttempt(ClimbRoute route, {String note = 'Worked the route'}) {
    final attempt = Attempt(
      routeId: route.id,
      routeName: route.name,
      grade: route.grade,
      note: note,
      attemptedAt: DateTime.now(),
    );
    _attempts.insert(0, attempt);
    unawaited(_persist());
    unawaited(databaseService.saveAttempt(attempt));
    notifyListeners();
  }

  void addGradeOpinion(ClimbRoute route, String suggestedGrade) {
    final grade = suggestedGrade.trim();
    if (grade.isEmpty) return;

    _gradeOpinions.removeWhere((opinion) => opinion.routeId == route.id);
    final opinion = GradeOpinion(
      routeId: route.id,
      routeName: route.name,
      suggestedGrade: grade,
      createdAt: DateTime.now(),
    );
    _gradeOpinions.insert(0, opinion);
    unawaited(_persist());
    unawaited(databaseService.saveGradeOpinion(opinion));
    notifyListeners();
  }

  Future<void> addComment(
    ClimbRoute route,
    String body, {
    String parentCommentId = '',
  }) async {
    final comment = body.trim();
    if (comment.isEmpty) return;

    final savedComment = databaseService.isConfigured
        ? await databaseService.saveComment(
            route.id,
            comment,
            parentCommentId: parentCommentId,
          )
        : LocalRouteComment(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            routeId: route.id,
            body: comment,
            parentCommentId: parentCommentId,
            createdAt: DateTime.now(),
          );
    _comments.insert(0, savedComment);
    await _persist();
    notifyListeners();
  }

  void addPhoto(
    ClimbRoute route, {
    required String url,
    required String caption,
  }) {
    final photoUrl = url.trim();
    if (photoUrl.isEmpty) return;

    final photo = LocalRoutePhoto(
      routeId: route.id,
      url: photoUrl,
      caption: caption.trim(),
      createdAt: DateTime.now(),
    );
    _photos.insert(0, photo);
    unawaited(_persist());
    unawaited(databaseService.savePhoto(photo));
    notifyListeners();
  }

  Future<void> uploadPhoto(
    ClimbRoute route, {
    required List<int> bytes,
    required String fileName,
    required String contentType,
    required String caption,
  }) async {
    final photo = await databaseService.uploadPhoto(
      routeId: route.id,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      caption: caption.trim(),
    );
    _photos.insert(0, photo);
    _loadedPhotoRoutes.add(route.id);
    await _persist();
    notifyListeners();
  }

  Future<void> removePhoto(LocalRoutePhoto photo) async {
    if (!canDeletePhoto(photo)) {
      throw StateError('Only the person who added this picture can remove it.');
    }
    await databaseService.deletePhoto(photo);
    _photos.removeWhere((item) => item.id == photo.id);
    await _persist();
    notifyListeners();
  }

  void toggleProject(ClimbRoute route) {
    bool saved;
    if (_projectRouteIds.contains(route.id)) {
      _projectRouteIds.remove(route.id);
      saved = false;
    } else {
      _projectRouteIds.add(route.id);
      saved = true;
    }
    unawaited(_persist());
    unawaited(databaseService.setProject(route.id, saved));
    notifyListeners();
  }

  Future<void> _restore() async {
    final store = preferences ?? await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw);
    final payload = decoded is List<Object?>
        ? {'sends': decoded}
        : decoded is Map<String, Object?>
        ? decoded
        : null;
    if (payload == null) return;

    final restored = _jsonList(
      payload['sends'],
    ).map(Send.fromJson).whereType<Send>().toList(growable: false);

    if (_disposed) return;

    _sends
      ..clear()
      ..addAll(restored);
    _attempts
      ..clear()
      ..addAll(
        _jsonList(
          payload['attempts'],
        ).map(Attempt.fromJson).whereType<Attempt>(),
      );
    _gradeOpinions
      ..clear()
      ..addAll(
        _jsonList(
          payload['gradeOpinions'],
        ).map(GradeOpinion.fromJson).whereType<GradeOpinion>(),
      );
    _comments
      ..clear()
      ..addAll(
        _jsonList(
          payload['comments'],
        ).map(LocalRouteComment.fromJson).whereType<LocalRouteComment>(),
      );
    _photos
      ..clear()
      ..addAll(
        _jsonList(
          payload['photos'],
        ).map(LocalRoutePhoto.fromJson).whereType<LocalRoutePhoto>(),
      );
    _projectRouteIds
      ..clear()
      ..addAll(
        _jsonList(payload['projectRouteIds']).map((id) => id.toString()),
      );
    _completedRoutes
      ..clear()
      ..addAll(restored.map((send) => send.routeId));

    notifyListeners();
  }

  Future<void> _persist() async {
    if (!persistenceEnabled) return;

    final store = preferences ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'sends': _sends.map((send) => send.toJson()).toList(),
      'attempts': _attempts.map((attempt) => attempt.toJson()).toList(),
      'gradeOpinions': _gradeOpinions
          .map((opinion) => opinion.toJson())
          .toList(),
      'comments': _comments.map((comment) => comment.toJson()).toList(),
      'photos': _photos.map((photo) => photo.toJson()).toList(),
      'projectRouteIds': _projectRouteIds.toList(),
    });
    await store.setString(_storageKey, encoded);
  }

  List<Object?> _jsonList(Object? value) {
    return value is List<Object?> ? value : const [];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
