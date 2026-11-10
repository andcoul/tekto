import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_service.g.dart';

const _tokenKey = 'supabase_access_token';

/// Provides the current auth state as a stream.
@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user);
}

class AuthService {
  AuthService(this._client, this._storage);

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(OAuthProvider.apple);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session != null) {
      await _storage.write(key: _tokenKey, value: response.session!.accessToken);
    }
    return response;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    if (response.session != null) {
      await _storage.write(key: _tokenKey, value: response.session!.accessToken);
    }
    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _storage.delete(key: _tokenKey);
  }
}

@riverpod
AuthService authService(AuthServiceRef ref) {
  final client = Supabase.instance.client;
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return AuthService(client, storage);
}
