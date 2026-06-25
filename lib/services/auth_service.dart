import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class AuthService {
  const AuthService();

  bool get isConfigured => SupabaseConfig.isConfigured;

  User? get currentUser {
    if (!isConfigured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges {
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  Future<void> signInWithGoogle({String? redirectPath}) async {
    if (!isConfigured) {
      throw AuthException(SupabaseConfig.setupMessage);
    }

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.redirectUrl(path: redirectPath),
    );
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await Supabase.instance.client.auth.signOut();
  }
}
