import 'package:flutter/material.dart';

// Identidad cálida de cafetería: rojo-naranja de marca, amarillo de acento y
// superficies crema (claro) o marrón oscuro (oscuro).
class AppTheme {
  static const _cafe = Color(0xFFB94716);
  static const _cafeOscuro = Color(0xFF2B1D15);
  static const _crema = Color(0xFFFFF8F2);
  static const _amarilloCalido = Color(0xFFF2B632);
  static const _verdeHoja = Color(0xFF8C3658);

  static const _radioTarjeta = 20.0;
  static const _radioControl = 16.0;
  static const _alturaBoton = 52.0;

  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: _cafe,
      brightness: Brightness.light,
      primary: _cafe,
      secondary: _verdeHoja,
      tertiary: _amarilloCalido,
      onTertiary: const Color(0xFF3E2A1C),
      tertiaryContainer: const Color(0xFFFFDF86),
      onTertiaryContainer: const Color(0xFF3F2919),
      surface: _crema,
    ),
  );

  static final dark = _build(
    ColorScheme.fromSeed(
      seedColor: _cafe,
      brightness: Brightness.dark,
      primary: const Color(0xFFFFB08A),
      onPrimary: const Color(0xFF4A1C06),
      secondary: const Color(0xFF9CC9A6),
      tertiary: const Color(0xFFF2C56B),
      onTertiary: const Color(0xFF3E2A1C),
      tertiaryContainer: const Color(0xFF5A4316),
      onTertiaryContainer: const Color(0xFFFFE7AE),
      surface: _cafeOscuro,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final esClaro = scheme.brightness == Brightness.light;
    final radioTarjeta = BorderRadius.circular(_radioTarjeta);
    final radioControl = BorderRadius.circular(_radioControl);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: esClaro ? Colors.white : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: radioTarjeta,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: esClaro ? 0.6 : 0.3),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, _alturaBoton),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radioControl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, _alturaBoton),
          shape: RoundedRectangleBorder(borderRadius: radioControl),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esClaro ? Colors.white : scheme.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: radioControl),
        enabledBorder: OutlineInputBorder(
          borderRadius: radioControl,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radioControl),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esClaro ? Colors.white : scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
