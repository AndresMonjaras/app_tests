import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../domain/cafeteria_tips.dart';
import '../domain/notification_inbox_item.dart';
import 'notification_preferences_controller.dart';
import 'notification_section.dart';

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
    final dismissed =
        ref.watch(dismissedTipIdsProvider).value ?? const <String>{};
    final tips = visibleCafeteriaTips(dismissed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllAsRead(context, ref),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Marcar todos'),
            ),
        ],
      ),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('No se pudieron cargar los avisos.')),
        data: (items) {
          if (items.isEmpty && tips.isEmpty) {
            return const Center(child: Text('Todavía no tienes avisos.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (tips.isNotEmpty) ...[
                NotificationSection(
                  title: 'Consejos de la cafetería',
                  children: [
                    for (final tip in tips)
                      _TipTile(
                        tip: tip,
                        onDismiss: () => _dismissTip(context, ref, tip),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              NotificationSection(
                title: unread == 0 ? 'Todo leído' : '$unread sin leer',
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text('Todavía no tienes avisos de pedidos.'),
                    ),
                  for (final item in items)
                    NotificationHistoryTile(
                      item: item,
                      icon: item.orderId != null
                          ? Icons.receipt_long_outlined
                          : Icons.campaign_outlined,
                      onTap: () => _open(context, ref, item),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _dismissTip(
    BuildContext context,
    WidgetRef ref,
    CafeteriaTip tip,
  ) async {
    final uid = ref.read(notificationUserIdProvider);
    if (uid == null) return;
    await _runSafely(
      context,
      () => ref
          .read(notificationTipDismissalsGatewayProvider)
          .dismiss(uid, tip.id),
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
    final orderId = item.orderId;
    if (orderId == null) return;
    await Navigator.of(context).pushNamed(
      item.type == 'pedido_listo' ? AppRouter.pickupQr : AppRouter.orders,
      arguments: {'orderId': orderId},
    );
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

class _TipTile extends StatelessWidget {
  const _TipTile({required this.tip, required this.onDismiss});

  final CafeteriaTip tip;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(tip.text),
      trailing: IconButton(
        tooltip: 'Eliminar consejo',
        icon: const Icon(Icons.close),
        onPressed: onDismiss,
      ),
    );
  }
}
