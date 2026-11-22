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
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    protectPickupQrWithBiometrics:
        protectPickupQrWithBiometrics ?? this.protectPickupQrWithBiometrics,
  );
}

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  static const _themeKey = 'lincefood_theme_mode';
  static const _onboardingKey = 'lincefood_onboarding_complete';
  static const _biometricQrKey = 'lincefood_protect_pickup_qr';

  @override
  Future<AppPreferences> build() async {
    final preferences = await SharedPreferences.getInstance();
    final mode = switch (preferences.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppPreferences(
      themeMode: mode,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      protectPickupQrWithBiometrics:
          preferences.getBool(_biometricQrKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    final current = state.asData?.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  Future<void> finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    final current = state.asData?.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(onboardingComplete: true));
  }

  Future<void> setPickupQrBiometrics(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_biometricQrKey, enabled);
    final current = state.asData?.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(protectPickupQrWithBiometrics: enabled));
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

final onboardingPageProvider = NotifierProvider<OnboardingPageController, int>(
  OnboardingPageController.new,
);

class OnboardingPageController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int page) => state = page.clamp(0, 2).toInt();
}
