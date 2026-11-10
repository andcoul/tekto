import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

/// Environment comes from `--dart-define-from-file=.env` (see mobile/.env.example).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY are not set. '
      'Run with: flutter run --dart-define-from-file=.env',
    );
  }
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  await _initCrashReporting();

  runApp(const ProviderScope(child: TektoApp()));
}

/// Crashlytics in release builds. Firebase config files (GoogleService-Info.plist,
/// google-services.json) are environment-specific and not committed; without them the app
/// still starts, just without crash reporting.
Future<void> _initCrashReporting() async {
  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    debugPrint('Crash reporting disabled: Firebase is not configured ($e)');
    return;
  }
  if (kDebugMode) return;
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
