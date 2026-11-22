import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import 'order_actions_controller.dart';
import 'orders_providers.dart';
import 'reject_order_dialog.dart';

// Motivos fijos: el personal no escribe texto libre en una incidencia.
const _incidentReasons = [
  'Problema operativo',
  'Cobro inconsistente',
  'Producto agotado',
  'Cierre de cafetería',
];

const _resolutionNotes = [
  'Reembolso manual',
  'Pedido corregido',
  'Sin acción necesaria',
];

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
    final isAdmin = ref.watch(adminPermissionProvider).value ?? false;
    final controller = ref.read(orderActionsProvider.notifier);

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
                isAdmin: isAdmin,
                onUpdate: (status) => controller.updateOrderStatus(
                  orderId: order.id,
                  status: status,
                ),
                onReject: () {
                  controller.clearError();
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => RejectOrderDialog(orderId: order.id),
                  );
                },
                onReportIncident: (reason) => controller.reportIncident(
                  orderId: order.id,
                  reason: reason,
                ),
                onResolveIncident: (resolution) => controller.resolveIncident(
                  orderId: order.id,
                  resolution: resolution,
                ),
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
    required this.isAdmin,
    required this.onUpdate,
    required this.onReject,
    required this.onReportIncident,
    required this.onResolveIncident,
  });

  final OrderRecord order;
  final bool isWorking;
  final bool isAdmin;
  final ValueChanged<OrderStatus> onUpdate;
  final VoidCallback onReject;
  final ValueChanged<String> onReportIncident;
  final ValueChanged<String> onResolveIncident;

  @override
  Widget build(BuildContext context) {
    final nextStatus = order.status.nextStaffStep;
    final actionLabel = switch (nextStatus) {
      OrderStatus.confirmed => 'Confirmar',
      OrderStatus.preparing => 'En cocina',
      OrderStatus.ready => 'Listo',
      _ => null,
    };
    final canReportIncident = isAdmin && order.status.allowsIncident;
    final canResolveIncident = isAdmin && order.status == OrderStatus.incident;

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
            if (order.status.allowsRejection && !order.isCancelled) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: isWorking
                      ? null
                      : BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: isWorking ? null : onReject,
                child: const Text('Rechazar'),
              ),
            ],
            if (canReportIncident) ...[
              const SizedBox(height: 8),
              _IncidentMenu(
                label: 'Marcar incidencia',
                options: _incidentReasons,
                enabled: !isWorking,
                onSelected: onReportIncident,
              ),
            ],
            if (canResolveIncident) ...[
              const SizedBox(height: 8),
              _IncidentMenu(
                label: 'Resolver incidencia',
                options: _resolutionNotes,
                enabled: !isWorking,
                onSelected: onResolveIncident,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncidentMenu extends StatelessWidget {
  const _IncidentMenu({
    required this.label,
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, child: Text(option)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}
