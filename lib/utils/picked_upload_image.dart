import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedUploadImage {
  const PickedUploadImage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class UnsupportedUploadImageError implements Exception {
  const UnsupportedUploadImageError(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<PickedUploadImage?> pickUploadImage({
  ImageSource source = ImageSource.gallery,
  int imageQuality = 78,
  double maxWidth = 1600,
}) async {
  final image = await ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  return normalizePickedUploadImage(
    bytes: bytes,
    originalName: image.name,
    pickerMimeType: image.mimeType,
  );
}

Future<List<PickedUploadImage>> pickUploadImages({
  int imageQuality = 78,
  double maxWidth = 1600,
}) async {
  final images = await ImagePicker().pickMultiImage(
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  final uploads = <PickedUploadImage>[];
  for (final image in images) {
    final bytes = await image.readAsBytes();
    uploads.add(
      normalizePickedUploadImage(
        bytes: bytes,
        originalName: image.name,
        pickerMimeType: image.mimeType,
      ),
    );
  }
  return uploads;
}

PickedUploadImage normalizePickedUploadImage({
  required Uint8List bytes,
  required String originalName,
  String? pickerMimeType,
}) {
  final fallbackName = originalName.trim().isEmpty ? 'photo.jpg' : originalName;
  final extension = _extensionFor(fallbackName);
  final detectedType = _detectContentType(bytes);

  if (detectedType != null) {
    return PickedUploadImage(
      bytes: bytes,
      fileName: _withExtension(
        fallbackName,
        _extensionForContentType(detectedType),
      ),
      contentType: detectedType,
    );
  }

  final lowerMime = pickerMimeType?.toLowerCase() ?? '';
  final isHeic =
      extension == 'heic' ||
      extension == 'heif' ||
      lowerMime.contains('heic') ||
      lowerMime.contains('heif');

  if (isHeic) {
    if (kIsWeb) {
      throw const UnsupportedUploadImageError(
        'That is an iPhone HEIC photo. The iPhone app will handle these automatically, but the web app cannot reliably display HEIC yet. For now, choose JPG, PNG, or WebP so the picture shows in the feed.',
      );
    }

    // The native iOS image picker exports selected HEIC photos through the
    // quality/resize path as a display-safe image. Store it as JPG so the same
    // upload works later in the web feed, route page, and map.
    return PickedUploadImage(
      bytes: bytes,
      fileName: _withExtension(fallbackName, 'jpg'),
      contentType: 'image/jpeg',
    );
  }

  final contentType = switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  return PickedUploadImage(
    bytes: bytes,
    fileName: _withExtension(
      fallbackName,
      _extensionForContentType(contentType),
    ),
    contentType: contentType,
  );
}

String _extensionFor(String fileName) {
  return fileName.contains('.')
      ? fileName
            .split('.')
            .last
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
      : 'jpg';
}

String _withExtension(String fileName, String extension) {
  final cleanExtension = extension.replaceAll(RegExp(r'[^a-z0-9]'), '');
  final baseName = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  final cleanBaseName = baseName.trim().isEmpty ? 'photo' : baseName.trim();
  return '$cleanBaseName.$cleanExtension';
}

String _extensionForContentType(String contentType) {
  return switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

String? _detectContentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
