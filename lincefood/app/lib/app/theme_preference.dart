import 'package:flutter/material.dart';

enum ThemePreference { sistema, claro, oscuro }

extension ThemePreferenceX on ThemePreference {
  ThemeMode get themeMode => switch (this) {
    ThemePreference.sistema => ThemeMode.system,
    ThemePreference.claro => ThemeMode.light,
    ThemePreference.oscuro => ThemeMode.dark,
  };

  String get etiqueta => switch (this) {
    ThemePreference.sistema => 'Sistema',
    ThemePreference.claro => 'Claro',
    ThemePreference.oscuro => 'Oscuro',
  };
}
