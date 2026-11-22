import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/app_preferences_controller.dart';
import '../../auth/presentation/auth_screen.dart';
import '../domain/onboarding_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.previewMode = false});

  final bool previewMode;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(onboardingPageProvider);
    final colors = Theme.of(context).colorScheme;
    final isLastPage = page == OnboardingStep.steps.length - 1;

    Future<void> finishOnboarding() async {
      await ref.read(appPreferencesProvider.notifier).finishOnboarding();
      if (widget.previewMode && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AuthScreen(previewOnly: true),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lincefood'),
        actions: [
          TextButton(onPressed: finishOnboarding, child: const Text('Saltar')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: OnboardingStep.steps.length,
                onPageChanged: (index) {
                  ref.read(onboardingPageProvider.notifier).select(index);
                },
                itemBuilder: (context, index) {
                  final step = OnboardingStep.steps[index];
                  final icon = switch (index) {
                    0 => Icons.restaurant_menu,
                    1 => Icons.lock_outline,
                    _ => Icons.shopping_bag_outlined,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 144,
                          height: 144,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 68,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                OnboardingStep.steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == page
                        ? colors.primary
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLastPage) {
                      finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(isLastPage ? 'Comenzar' : 'Continuar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
