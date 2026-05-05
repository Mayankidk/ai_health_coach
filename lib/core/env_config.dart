import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const webAuthRedirectUrl =
      String.fromEnvironment('WEB_AUTH_REDIRECT_URL');

  static String getSupabaseUrl() => _value(supabaseUrl, 'SUPABASE_URL');

  static String getSupabaseAnonKey() =>
      _value(supabaseAnonKey, 'SUPABASE_ANON_KEY');

  static String getGoogleWebClientId() =>
      _value(googleWebClientId, 'GOOGLE_WEB_CLIENT_ID');

  static String getGoogleIosClientId() =>
      _value(googleIosClientId, 'GOOGLE_IOS_CLIENT_ID');

  static String getWebAuthRedirectUrl() =>
      _value(webAuthRedirectUrl, 'WEB_AUTH_REDIRECT_URL');

  static String _value(String dartDefineValue, String dotenvKey) {
    if (dartDefineValue.isNotEmpty) return dartDefineValue;
    return _dotenvValue(dotenvKey);
  }

  static String _dotenvValue(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }
}
