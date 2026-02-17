import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  
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
        // Supabase's native OAuth flow is often more reliable on Web
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:5000',
        );
        return;
      }

      final webClientId = dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
      final iosClientId = dotenv.get('GOOGLE_IOS_CLIENT_ID', fallback: '');

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
      print("Guest sign in error: $e");
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Sign up error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print("Sign out error: $e");
    }
  }
  
  bool get isAuthenticated => _client.auth.currentSession != null;
  
  User? get currentUser => _client.auth.currentUser;
  
  String? get userId => _client.auth.currentUser?.id;
}
