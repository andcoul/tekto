import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

part 'user_profile_provider.g.dart';

/// The signed-in user's `users` row (null before onboarding saves it). Drives onboarding
/// entry and re-consent in the router. Kept out of app_router.dart so onboarding screens
/// do not import every route.
@riverpod
Future<Map<String, dynamic>?> userProfile(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return Supabase.instance.client.from('users').select('consent_version').eq('id', user.id).maybeSingle();
}
