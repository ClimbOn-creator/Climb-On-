import 'package:climb_on/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native auth redirect defaults to Climb On URL scheme', () {
    expect(SupabaseConfig.authRedirectUrl, 'climbon://login-callback');
    expect(
      SupabaseConfig.redirectUrl(path: '/profile'),
      'climbon://login-callback',
    );
  });
}
