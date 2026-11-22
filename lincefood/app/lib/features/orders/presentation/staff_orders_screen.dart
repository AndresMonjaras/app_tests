import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import 'order_actions_controller.dart';
import 'orders_providers.dart';

class StaffOrdersScreen extends ConsumerWidget {
  const StaffOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffPermission = ref.watch(staffPermissionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de cafetería')),
      body: staffPermission.when(
        data: (isStaff) => isStaff
            ? const _StaffOrderList()
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Esta sección es solo para personal de cafetería.',
                  ),
                ),
              ),
        error: (_, _) => const Center(
          child: Text('No se pudo verificar el permiso de personal.'),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Verificando permiso',
          ),
        ),
      ),
    );
  }
}

class _StaffOrderList extends ConsumerWidget {
  const _StaffOrderList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(staffOrdersStreamProvider);
    final actionState = ref.watch(orderActionsProvider);

    return orders.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No hay pedidos pagados por atender.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (actionState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  actionState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (final order in items)
              _StaffOrderCard(
                order: order,
                isWorking: actionState.isWorking,
                onUpdate: (status) => ref
                    .read(orderActionsProvider.notifier)
                    .updateOrderStatus(orderId: order.id, status: status),
              ),
          ],
        );
      },
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No se pudieron cargar los pedidos del personal.'),
        ),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Cargando pedidos de cafetería',
        ),
      ),
    );
  }
}

class _StaffOrderCard extends StatelessWidget {
  const _StaffOrderCard({
    required this.order,
    required this.isWorking,
    required this.onUpdate,
  });

  final OrderRecord order;
  final bool isWorking;
  final ValueChanged<OrderStatus> onUpdate;

  @override
  Widget build(BuildContext context) {
    final nextStatus = switch (order.status) {
      OrderStatus.paid || OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      OrderStatus.ready => OrderStatus.delivered,
      _ => null,
    };
    final actionLabel = switch (nextStatus) {
      OrderStatus.preparing => 'En cocina',
      OrderStatus.ready => 'Listo',
      OrderStatus.delivered => 'Entregado',
      _ => null,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Folio ${order.displayFolio}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${order.status.label} · ${formatMoney(order.totalCents)}'),
            if (nextStatus != null && actionLabel != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: isWorking ? null : () => onUpdate(nextStatus),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
