import 'package:flutter/material.dart';

import '../domain/onboarding_step.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    this.themeMode = ThemeMode.system,
    this.onThemeChanged,
    this.onCompleted,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lincefood'),
        actions: [
          TextButton(onPressed: onCompleted, child: const Text('Saltar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tu cafetería, a tu ritmo',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 20),
          for (final step in OnboardingStep.steps)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: const Icon(Icons.check),
                ),
                title: Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(step.description),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema'),
              subtitle: const Text('Elige cómo quieres ver la aplicación.'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (mode) {
                  if (mode != null) onThemeChanged?.call(mode);
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Sistema'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Claro'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Oscuro'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onCompleted,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Comenzar'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Puedes cambiar el tema después desde tu perfil.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
