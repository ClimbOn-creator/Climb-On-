class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'climbon://login-callback',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static List<String> get missingValues {
    return [
      if (url.isEmpty) 'SUPABASE_URL',
      if (publishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
  }

  static String get setupMessage {
    if (isConfigured) return 'Supabase is configured.';
    return 'Missing ${missingValues.join(', ')}. Add them with --dart-define when running or building.';
  }

  static String redirectUrl({String? path}) {
    if (path == null ||
        path.isEmpty ||
        authRedirectUrl.startsWith('climbon://')) {
      return authRedirectUrl;
    }

    final base = Uri.parse(authRedirectUrl);
    return base.replace(path: path).toString();
  }
}
