/// Build-time configuration injected with `--dart-define-from-file=env/<name>.json`.
/// Nothing secret lives here: the Supabase anon key is public by design and protected by Row Level Security.
/// Service-role keys and Razorpay secrets must never be added to the app.
class AppEnv {
  const AppEnv._();

  static const String name = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String oauthRedirect =
      String.fromEnvironment('OAUTH_REDIRECT', defaultValue: 'in.budgetphonewala.app://login-callback');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Public product photos (bucket is public by design).
  static String productImageUrl(String path) => '$supabaseUrl/storage/v1/object/public/product-images/$path';
}
