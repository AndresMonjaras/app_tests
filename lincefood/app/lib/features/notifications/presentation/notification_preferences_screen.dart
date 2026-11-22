import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../domain/local_advice_frequency.dart';
import '../domain/notification_inbox_item.dart';
import '../domain/notification_topic_preferences.dart';
import 'notification_preferences_controller.dart';
import 'notification_section.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesControllerProvider);
    final frequency = ref.watch(localAdviceFrequencyProvider);
    final selectedFrequency = frequency.value;
    final inbox = ref.watch(notificationInboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: preferences.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Elige qué avisos de la cafetería quieres recibir.'),
            const SizedBox(height: 12),
            NotificationSection(
              title: 'Temas de avisos',
              children: [
                for (final topic in NotificationTopic.values)
                  SwitchListTile(
                    title: Text(topic.label),
                    value: state.preferences.isEnabled(topic),
                    onChanged: state.savingTopic == null
                        ? (enabled) => ref
                              .read(
                                notificationPreferencesControllerProvider
                                    .notifier,
                              )
                              .setTopic(topic, enabled)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            NotificationSection(
              title: 'Recordatorios',
              children: [
                SwitchListTile(
                  title: const Text('Recordatorio local de consejos'),
                  subtitle: const Text(
                    'Recibe consejos de la cafetería, incluso con la pantalla bloqueada.',
                  ),
                  value: state.preferences.localAdvice,
                  onChanged: state.savingTopic == null
                      ? (enabled) => ref
                            .read(
                              notificationPreferencesControllerProvider
                                  .notifier,
                            )
                            .setLocalAdvice(enabled)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Semantics(
                    label: 'Frecuencia del recordatorio',
                    child: SegmentedButton<LocalAdviceFrequency>(
                      segments: [
                        for (final option in LocalAdviceFrequency.values)
                          ButtonSegment(
                            value: option,
                            label: Text(option.label),
                          ),
                      ],
                      selected: {?selectedFrequency},
                      emptySelectionAllowed: selectedFrequency == null,
                      onSelectionChanged:
                          state.preferences.localAdvice &&
                              state.savingTopic == null &&
                              !frequency.isLoading
                          ? (selection) => ref
                                .read(
                                  notificationPreferencesControllerProvider
                                      .notifier,
                                )
                                .setLocalAdviceFrequency(selection.single)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            if (state.savingTopic != null)
              const Center(child: CircularProgressIndicator()),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            NotificationSection(
              title: 'Historial',
              children: [
                inbox.when(
                  data: (items) => items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text('Todavía no tienes notificaciones.'),
                        )
                      : Column(
                          children: [
                            for (final item in items)
                              NotificationHistoryTile(
                                icon: item.type.startsWith('pedido_')
                                    ? Icons.receipt_long_outlined
                                    : Icons.campaign_outlined,
                                item: item,
                                onTap: () => unawaited(
                                  _openInboxItem(context, ref, item),
                                ),
                              ),
                          ],
                        ),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No se pudo cargar el historial de notificaciones.',
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando historial',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is StateError
                  ? error.message
                  : 'No se pudieron cargar tus preferencias. Verifica tu '
                        'conexión e inténtalo de nuevo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Cargando preferencias',
          ),
        ),
      ),
    );
  }

  Future<void> _openInboxItem(
    BuildContext context,
    WidgetRef ref,
    NotificationInboxItem item,
  ) async {
    final uid = ref.read(notificationUserIdProvider);
    if (uid == null || uid.isEmpty) return;

    try {
      await ref.read(notificationInboxGatewayProvider).markAsRead(uid, item.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo marcar como leído.')),
        );
      }
    }
    if (!context.mounted) return;

    Navigator.of(context).pushNamed(
      item.type.startsWith('pedido_') ? AppRouter.orders : AppRouter.catalog,
      arguments: item.orderId == null ? null : {'orderId': item.orderId},
    );
  }
}
