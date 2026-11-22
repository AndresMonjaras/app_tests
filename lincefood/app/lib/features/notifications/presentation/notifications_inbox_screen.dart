import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../domain/notification_inbox_item.dart';
import 'notification_preferences_controller.dart';

/// Número de avisos sin leer del usuario activo.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationInboxProvider).value ?? const [];
  return items.where((item) => !item.isRead).length;
});

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationInboxProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllAsRead(context, ref),
              child: const Text('Marcar todos'),
            ),
        ],
      ),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('No se pudieron cargar los avisos.')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Todavía no tienes avisos.'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    unread == 0 ? 'Todo leído' : '$unread sin leer',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _AvisoTile(
                    item: items[index],
                    onTap: () => _open(context, ref, items[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    NotificationInboxItem item,
  ) async {
    final uid = ref.read(notificationUserIdProvider);
    if (uid != null && !item.isRead) {
      await _runSafely(
        context,
        () =>
            ref.read(notificationInboxGatewayProvider).markAsRead(uid, item.id),
      );
    }
    if (!context.mounted) return;
    if (item.orderId != null) {
      await Navigator.of(context).pushNamed(AppRouter.orders);
    }
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(notificationUserIdProvider);
    final items = ref.read(notificationInboxProvider).value ?? const [];
    final pendientes = items
        .where((item) => !item.isRead)
        .map((item) => item.id);
    if (uid == null) return;
    await _runSafely(
      context,
      () => ref
          .read(notificationInboxGatewayProvider)
          .markAllAsRead(uid, pendientes),
    );
  }

  Future<void> _runSafely(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el aviso.')),
      );
    }
  }
}

class _AvisoTile extends StatelessWidget {
  const _AvisoTile({required this.item, required this.onTap});

  final NotificationInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        item.orderId != null
            ? Icons.receipt_long_outlined
            : Icons.campaign_outlined,
      ),
      title: Text(
        item.title,
        style: item.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${item.body}\n${_formatearFecha(item.createdAt)}'),
      isThreeLine: true,
      trailing: item.isRead
          ? null
          : Icon(Icons.circle, size: 10, color: colors.primary),
    );
  }
}

String _formatearFecha(int milisegundos) {
  final fecha = DateTime.fromMillisecondsSinceEpoch(milisegundos).toLocal();
  String dosDigitos(int valor) => valor.toString().padLeft(2, '0');
  return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year}  '
      '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
}
