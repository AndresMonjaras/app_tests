import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/theme_preference.dart';

void main() {
  test('convierte las preferencias al modo de tema de Flutter', () {
    expect(ThemePreference.sistema.themeMode, ThemeMode.system);
    expect(ThemePreference.claro.themeMode, ThemeMode.light);
    expect(ThemePreference.oscuro.themeMode, ThemeMode.dark);
  });

  test('devuelve etiquetas en español', () {
    expect(ThemePreference.sistema.etiqueta, 'Sistema');
    expect(ThemePreference.claro.etiqueta, 'Claro');
    expect(ThemePreference.oscuro.etiqueta, 'Oscuro');
  });
}
