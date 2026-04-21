import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  String _resolveWebRedirectUrl() {
    final configuredRedirectUrl =
        const String.fromEnvironment('WEB_AUTH_REDIRECT_URL').isNotEmpty
            ? const String.fromEnvironment('WEB_AUTH_REDIRECT_URL')
            : dotenv.get('WEB_AUTH_REDIRECT_URL', fallback: '');

    if (configuredRedirectUrl.isNotEmpty) {
      return configuredRedirectUrl;
    }

    var path = Uri.base.path;
    if (path.endsWith('/index.html')) {
      path = path.substring(0, path.length - 'index.html'.length);
    }
    if (path.isEmpty) {
      path = '/';
    } else if (!path.endsWith('/')) {
      path = '$path/';
    }

    return Uri(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: Uri.base.hasPort ? Uri.base.port : null,
      path: path,
    ).toString();
  }
  
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Sign in error: $e");
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // GitHub Pages and Supabase both expect an exact redirect URL match.
        final redirectUrl = _resolveWebRedirectUrl();
        print("AuthService: Web OAuth initiated with redirectTo: $redirectUrl");
        
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );
        return;
      }

      final webClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID').isNotEmpty
          ? const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID')
          : dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
          
      final iosClientId = const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID').isNotEmpty
          ? const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID')
          : dotenv.get('GOOGLE_IOS_CLIENT_ID', fallback: '');

      final googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
        scopes: [
          'email',
          'profile',
          'openid',
        ],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google Sign-In was cancelled.';
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found. Please ensure you are not in Incognito mode and have allowed popups.';
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      print("Google sign in error: $e");
      rethrow;
    }
  }

  Future<void> signInAnonymously() async {
    try {
      await _client.auth.signInAnonymously();
    } catch (e) {
      print("Guest sign in error (Detailed): $e");
      if (e is AuthException) {
        print("Auth Error Code: ${e.statusCode}, Message: ${e.message}");
      }
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, {String? displayName}) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
    } catch (e) {
      print("Sign up error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      print("Sign out error: $e");
    }
  }
  
  bool get isAuthenticated => _client.auth.currentSession != null;
  
  User? get currentUser => _client.auth.currentUser;
  
  String? get userId => _client.auth.currentUser?.id;
}
