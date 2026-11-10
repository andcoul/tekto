import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_service.dart';

class TektoApp extends ConsumerWidget {
  const TektoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Keep RevenueCat's customer ID equal to the Supabase user ID (contracts/ai-services.md §4).
    ref.listen(authStateProvider, (_, next) {
      final revenueCat = ref.read(revenueCatServiceProvider);
      final user = next.value;
      if (user != null) {
        revenueCat.identify(user.id);
      } else if (next.hasValue) {
        revenueCat.reset();
      }
    });

    return MaterialApp.router(
      title: 'Tekto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: ref.watch(appLocaleProvider),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
    );
  }
}
