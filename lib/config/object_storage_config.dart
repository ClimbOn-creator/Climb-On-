class ObjectStorageConfig {
  const ObjectStorageConfig._();

  static const uploadEndpoint = String.fromEnvironment(
    'OBJECT_STORAGE_UPLOAD_ENDPOINT',
  );
  static const deleteEndpoint = String.fromEnvironment(
    'OBJECT_STORAGE_DELETE_ENDPOINT',
  );
  static const publicBaseUrl = String.fromEnvironment(
    'OBJECT_STORAGE_PUBLIC_BASE_URL',
  );

  static bool get usesExternalStorage => uploadEndpoint.isNotEmpty;
  static bool get canDeleteExternalObjects => deleteEndpoint.isNotEmpty;

  static String publicUrlFor(String path) {
    final base = publicBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) return '';
    return '$base/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
