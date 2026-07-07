import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/object_storage_config.dart';

enum ObjectStorageArea {
  routePhotos('route-photos', 'route-photos'),
  profileAvatars('profile-avatars', 'profile-avatars'),
  submissionPhotos('submission-photos', 'submission-photos'),
  appVisuals('app-visuals', 'submission-photos'),
  offlineMapPacks('offline-map-packs', 'offline-map-packs');

  const ObjectStorageArea(this.key, this.bucketName);

  final String key;
  final String bucketName;
}

class StoredObject {
  const StoredObject({required this.path, required this.url});

  final String path;
  final String url;
}

class ObjectStorageService {
  const ObjectStorageService();

  Future<StoredObject> upload({
    required ObjectStorageArea area,
    required String path,
    required List<int> bytes,
    required String contentType,
    bool upsert = false,
  }) {
    if (ObjectStorageConfig.usesExternalStorage) {
      return _uploadExternal(
        area: area,
        path: path,
        bytes: bytes,
        contentType: contentType,
        upsert: upsert,
      );
    }
    return _uploadSupabase(
      area: area,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
  }

  Future<void> remove({
    required ObjectStorageArea area,
    required List<String> paths,
  }) async {
    final cleanPaths = paths.where((path) => path.isNotEmpty).toList();
    if (cleanPaths.isEmpty) return;

    if (ObjectStorageConfig.usesExternalStorage) {
      if (!ObjectStorageConfig.canDeleteExternalObjects) return;
      await _deleteExternal(area: area, paths: cleanPaths);
      return;
    }

    await Supabase.instance.client.storage
        .from(area.bucketName)
        .remove(cleanPaths);
  }

  Future<StoredObject> _uploadSupabase({
    required ObjectStorageArea area,
    required String path,
    required List<int> bytes,
    required String contentType,
    required bool upsert,
  }) async {
    final bucket = Supabase.instance.client.storage.from(area.bucketName);
    await bucket.uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: contentType, upsert: upsert),
    );
    return StoredObject(path: path, url: bucket.getPublicUrl(path));
  }

  Future<StoredObject> _uploadExternal({
    required ObjectStorageArea area,
    required String path,
    required List<int> bytes,
    required String contentType,
    required bool upsert,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(ObjectStorageConfig.uploadEndpoint),
          )
          ..fields['area'] = area.key
          ..fields['path'] = path
          ..fields['upsert'] = upsert.toString()
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: path.split('/').last,
              contentType: _mediaType(contentType),
            ),
          );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException(
        'Object storage upload failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = response.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(response.body);
    final body = decoded is Map ? Map<String, Object?>.from(decoded) : {};
    final returnedPath = body['path']?.toString();
    final returnedUrl = body['url']?.toString();
    final finalPath = returnedPath == null || returnedPath.isEmpty
        ? path
        : returnedPath;
    final finalUrl = returnedUrl == null || returnedUrl.isEmpty
        ? ObjectStorageConfig.publicUrlFor(finalPath)
        : returnedUrl;
    if (finalUrl.isEmpty) {
      throw const StorageException(
        'Object storage upload succeeded but did not return a public URL.',
      );
    }
    return StoredObject(path: finalPath, url: finalUrl);
  }

  Future<void> _deleteExternal({
    required ObjectStorageArea area,
    required List<String> paths,
  }) async {
    final response = await http.delete(
      Uri.parse(ObjectStorageConfig.deleteEndpoint),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'area': area.key, 'paths': paths}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException(
        'Object storage delete failed with HTTP ${response.statusCode}.',
      );
    }
  }

  MediaType _mediaType(String contentType) {
    final parts = contentType.split('/');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return MediaType('application', 'octet-stream');
    }
    return MediaType(parts.first, parts.last);
  }
}
