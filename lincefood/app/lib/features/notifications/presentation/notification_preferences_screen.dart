import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../domain/notification_inbox_item.dart';
import '../domain/notification_topic_preferences.dart';
import 'notification_preferences_controller.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesControllerProvider);
    final inbox = ref.watch(notificationInboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: preferences.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Elige qué avisos de la cafetería quieres recibir.'),
            const SizedBox(height: 12),
            for (final topic in NotificationTopic.values)
              SwitchListTile(
                title: Text(topic.label),
                value: state.preferences.isEnabled(topic),
                onChanged: state.savingTopic == null
                    ? (enabled) => ref
                          .read(
                            notificationPreferencesControllerProvider.notifier,
                          )
                          .setTopic(topic, enabled)
                    : null,
              ),
            SwitchListTile(
              title: const Text('Consejos de cafetería'),
              subtitle: const Text(
                'Recibe un consejo local cada hora, incluso con la pantalla bloqueada.',
              ),
              value: state.preferences.localAdvice,
              onChanged: state.savingTopic == null
                  ? (enabled) => ref
                        .read(
                          notificationPreferencesControllerProvider.notifier,
                        )
                        .setLocalAdvice(enabled)
                  : null,
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
            const Divider(height: 32),
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            inbox.when(
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Todavía no tienes notificaciones.'),
                    )
                  : Column(
                      children: [
                        for (final item in items)
                          _InboxTile(
                            item: item,
                            onTap: () =>
                                unawaited(_openInboxItem(context, ref, item)),
                          ),
                      ],
                    ),
              error: (_, _) => const Text(
                'No se pudo cargar el historial de notificaciones.',
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Cargando historial',
                ),
              ),
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

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final NotificationInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(item.createdAt)
        .toLocal();
    final timestamp =
        '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}  '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.type.startsWith('pedido_')
            ? Icons.receipt_long_outlined
            : Icons.campaign_outlined,
      ),
      title: Text(
        item.title,
        style: item.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${item.body}\n$timestamp'),
      isThreeLine: true,
      trailing: item.isRead
          ? null
          : Icon(
              Icons.circle,
              size: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
      onTap: onTap,
    );
  }
}
