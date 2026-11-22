import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding_step.dart';

class OnboardingController extends Notifier<int> {
  static final int _ultimo = OnboardingStep.steps.length - 1;

  @override
  int build() => 0;

  void siguiente() {
    if (state < _ultimo) state = state + 1;
  }

  void anterior() {
    if (state > 0) state = state - 1;
  }
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, int>(
      OnboardingController.new,
    );
