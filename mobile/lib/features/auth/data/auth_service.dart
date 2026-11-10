import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_service.g.dart';

/// OAuth returns to the app through this deep link (AndroidManifest / Info.plist).
const _redirect = 'tekto://auth/callback';

/// Provides the current auth state as a stream.
@riverpod
Stream<User?> authState(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user);
}

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(OAuthProvider.apple, redirectTo: _redirect);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

@riverpod
AuthService authService(Ref ref) => AuthService(Supabase.instance.client);
