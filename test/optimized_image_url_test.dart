import 'package:climb_on/utils/optimized_image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cloudinary images get variant transforms', () {
    final url = optimizedImageUrl(
      'https://res.cloudinary.com/demo/image/upload/v1/routes/photo.jpg',
      ImageVariant.thumbnail,
    );

    expect(
      url,
      contains('/image/upload/f_auto,q_auto:eco,c_fill,w_480,h_320/'),
    );
    expect(url, endsWith('/v1/routes/photo.jpg'));
  });

  test('Unknown providers are left unchanged', () {
    const url = 'https://media.example.com/routes/photo.jpg';
    expect(optimizedImageUrl(url, ImageVariant.card), url);
  });
}
