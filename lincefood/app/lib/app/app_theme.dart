import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF276749);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    useMaterial3: true,
    fontFamily: 'Jakarta',
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'Jakarta',
  );
}
