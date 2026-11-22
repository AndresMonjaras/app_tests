import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../../core/money/money.dart';
import '../../../app/app_router.dart';
import '../../notifications/presentation/notifications_inbox_screen.dart';
import '../../pickup_qr/presentation/pickup_qr_screen.dart';
import '../../pickup_qr/presentation/pickup_scanner_screen.dart';
import '../domain/order_elapsed_time.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import 'order_cancellation_providers.dart';
import 'order_timeline.dart';
import 'orders_providers.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersStreamProvider);
    final now = ref.watch(orderClockProvider).value ?? DateTime.now();
    final isStaff = ref.watch(staffPermissionProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi ticket'),
        actions: [
          _AvisosButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.notifications),
          ),
          if (isStaff)
            IconButton(
              tooltip: 'Escanear QR de entrega',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PickupScannerScreen()),
              ),
              icon: const Icon(Icons.qr_code_scanner),
            ),
          if (isStaff)
            IconButton(
              tooltip: 'Panel de cafetería',
              onPressed: () => Navigator.of(context).pushNamed('/orders/staff'),
              icon: const Icon(Icons.storefront_outlined),
            ),
        ],
      ),
      body: orders.when(
        data: (items) {
          final visibleOrders = orderId == null
              ? items
              : items.where((order) => order.id == orderId).toList();
          if (visibleOrders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no tienes pedidos.'),
              ),
            );
          }

          final sortedOrders = [...visibleOrders]
            ..sort((first, second) {
              return (second.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  );
            });
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _TicketCard(order: sortedOrders[index], now: now),
          );
        },
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus pedidos. Inténtalo de nuevo.',
            ),
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando pedidos'),
        ),
      ),
    );
  }
}

class _AvisosButton extends ConsumerWidget {
  const _AvisosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: 'Avisos',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.order, required this.now});

  final OrderRecord order;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isCancelling = ref.watch(cancellingOrdersProvider).contains(order.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Folio ${order.displayFolio}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.quantity} × ${line.product.name}'
                        '${line.variant == null ? '' : ' (${line.variant!.label})'}',
                      ),
                    ),
                    Text(formatMoney(line.totalCents)),
                  ],
                ),
              ),
            if (order.lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No hay detalle de productos disponible.'),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total'),
                Text(
                  formatMoney(order.totalCents),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Modalidad: ${order.pickupMode.label}'),
            if (order.createdAt case final createdAt?) ...[
              const SizedBox(height: 4),
              Text(formatElapsedTime(createdAt, now: now)),
            ],
            const SizedBox(height: 12),
            Text(
              'Estado: ${order.isCancelled ? 'Cancelado' : order.status.label}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (!order.isCancelled) OrderTimeline(currentStatus: order.status),
            if (order.status == OrderStatus.ready) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupQrScreen(orderId: order.id),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Mostrar QR de recogida'),
              ),
            ],
            if (!order.isCancelled && canCustomerCancel(order.status)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isCancelling
                    ? null
                    : () => _confirmarCancelacion(context, ref),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(isCancelling ? 'Cancelando...' : 'Cancelar pedido'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCancelacion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: const Text(
          'Si el pedido no ha entrado a cocina, se cancelará y se solicitará '
          'el reembolso del pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final cancelling = ref.read(cancellingOrdersProvider.notifier);
    cancelling.start(order.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderCancellationGatewayProvider).cancel(order.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pedido cancelado.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is DomainException
                ? error.message
                : 'No se pudo cancelar el pedido.',
          ),
        ),
      );
    } finally {
      cancelling.finish(order.id);
    }
  }
}
