import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding_step.dart';
import 'onboarding_controller.dart';

const _iconos = [
  Icons.restaurant_menu_outlined,
  Icons.lock_outline,
  Icons.notifications_active_outlined,
];

class OnboardingScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pasos = OnboardingStep.steps;
    final indice = ref.watch(onboardingControllerProvider);
    final controlador = ref.read(onboardingControllerProvider.notifier);
    final paso = pasos[indice];
    final esUltimo = indice == pasos.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lincefood'),
        actions: [
          TextButton(onPressed: onCompleted, child: const Text('Saltar')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tu cafetería, a tu ritmo',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // El texto "Paso X de Y" de abajo ya lo anuncia.
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              for (var i = 0; i < pasos.length; i++)
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    height: 6,
                                    margin: EdgeInsets.only(
                                      right: i == pasos.length - 1 ? 0 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: i <= indice
                                          ? colors.primary
                                          : colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Paso ${indice + 1} de ${pasos.length}',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Card(
                            key: ValueKey(indice),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.onPrimaryContainer,
                                    child: Icon(_iconos[indice], size: 28),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    paso.title,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    paso.description,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.palette_outlined),
                            title: const Text('Tema'),
                            subtitle: const Text(
                              'Elige cómo quieres ver la aplicación.',
                            ),
                            trailing: Semantics(
                              label: 'Tema',
                              child: DropdownButton<ThemeMode>(
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
                        ),
                        if (esUltimo) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Puedes cambiar el tema después desde tu perfil.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      if (indice > 0) ...[
                        OutlinedButton.icon(
                          onPressed: controlador.anterior,
                          icon: const Icon(Icons.arrow_back, size: 20),
                          label: const Text('Anterior'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: esUltimo
                              ? onCompleted
                              : controlador.siguiente,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(esUltimo ? 'Comenzar' : 'Siguiente'),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
