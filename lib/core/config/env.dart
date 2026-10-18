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

  /// Where links in emails (confirm sign-up, reset password) land. A web page that hands the one-time code to the app,
  /// because email apps often refuse to open custom app links directly. Google sign-in keeps using [oauthRedirect].
  static const String emailRedirect =
      String.fromEnvironment('EMAIL_REDIRECT', defaultValue: 'https://budget-phone-wala-admin.vercel.app/open-app');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Public product photos (bucket is public by design).
  static String productImageUrl(String path) => '$supabaseUrl/storage/v1/object/public/product-images/$path';
}
