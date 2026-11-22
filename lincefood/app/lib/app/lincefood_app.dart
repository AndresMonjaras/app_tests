import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'app_theme.dart';
import 'firebase_bootstrap_screen.dart';
import '../core/preferences/app_preferences_controller.dart';
import '../core/navigation/app_navigation_keys.dart';

class LincefoodApp extends ConsumerWidget {
  const LincefoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).asData?.value;
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: 'Lincefood',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: preferences?.themeMode ?? ThemeMode.system,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const FirebaseBootstrapScreen(),
    );
  }
}
