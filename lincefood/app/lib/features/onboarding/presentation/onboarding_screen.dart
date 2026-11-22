import 'package:flutter/material.dart';

import '../domain/onboarding_step.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lincefood')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tu cafetería, a tu ritmo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final step in OnboardingStep.steps)
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(step.title),
                subtitle: Text(step.description),
              ),
            ),
        ],
      ),
    );
  }
}
