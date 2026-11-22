import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';
import 'firebase_bootstrap_screen.dart';

class LincefoodApp extends StatelessWidget {
  const LincefoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lincefood',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const FirebaseBootstrapScreen(),
    );
  }
}
