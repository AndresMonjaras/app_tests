import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.onboardingComplete = false,
    this.protectPickupQrWithBiometrics = false,
  });

  final ThemeMode themeMode;
  final bool onboardingComplete;
  final bool protectPickupQrWithBiometrics;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? onboardingComplete,
    bool? protectPickupQrWithBiometrics,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      protectPickupQrWithBiometrics:
          protectPickupQrWithBiometrics ?? this.protectPickupQrWithBiometrics,
    );
  }
}

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  static const _themeKey = 'lincefood_theme_mode';
  static const _onboardingKey = 'lincefood_onboarding_complete';
  static const _biometricQrKey = 'lincefood_protect_pickup_qr';

  @override
  Future<AppPreferences> build() async {
    final preferences = await SharedPreferences.getInstance();
    final themeMode = switch (preferences.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return AppPreferences(
      themeMode: themeMode,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      protectPickupQrWithBiometrics:
          preferences.getBool(_biometricQrKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    if (!saved) throw StateError('No se pudo guardar el tema.');
    if (!ref.mounted) return;

    state = AsyncData(_currentPreferences().copyWith(themeMode: mode));
  }

  Future<void> finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_onboardingKey, true);
    if (!saved) throw StateError('No se pudo guardar el onboarding.');
    if (!ref.mounted) return;

    state = AsyncData(_currentPreferences().copyWith(onboardingComplete: true));
  }

  Future<void> setPickupQrBiometrics(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_biometricQrKey, enabled);
    if (!saved) {
      throw StateError('No se pudo guardar la protección biométrica.');
    }
    if (!ref.mounted) {
      return;
    }

    state = AsyncData(
      _currentPreferences().copyWith(protectPickupQrWithBiometrics: enabled),
    );
  }

  AppPreferences _currentPreferences() {
    return state.asData?.value ?? const AppPreferences();
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );
