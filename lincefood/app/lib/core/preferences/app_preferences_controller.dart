import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.onboardingComplete = false,
  });

  final ThemeMode themeMode;
  final bool onboardingComplete;

  AppPreferences copyWith({ThemeMode? themeMode, bool? onboardingComplete}) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );
}

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  static const _themeKey = 'lincefood_theme_mode';
  static const _onboardingKey = 'lincefood_onboarding_complete';

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
