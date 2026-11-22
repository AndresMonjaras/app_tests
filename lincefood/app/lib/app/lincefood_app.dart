import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'app_theme.dart';
import 'firebase_bootstrap_screen.dart';
import '../core/preferences/app_preferences_controller.dart';
import '../features/notifications/data/notification_service.dart';

class LincefoodApp extends ConsumerWidget {
  const LincefoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationStartupProvider);
    final themeMode = ref.watch(appPreferencesProvider).asData?.value.themeMode;

    return MaterialApp(
      title: 'Lincefood',
      navigatorKey: notificationNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode ?? ThemeMode.system,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const FirebaseBootstrapScreen(),
    );
  }
}
