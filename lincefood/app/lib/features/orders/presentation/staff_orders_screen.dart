import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/money/money.dart';
import '../../catalog/presentation/product_image.dart';
import '../../pickup_qr/presentation/pickup_scanner_screen.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import '../domain/order_elapsed_time.dart';
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFFBF5EC),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : const Color(0xFFFBF5EC),
        scrolledUnderElevation: 0,
        title: const Text('Pedidos de cafetería'),
        actions: [
          if (staffPermission.value == true)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PickupScannerScreen(),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR'),
              ),
            ),
        ],
      ),
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
    final now = ref.watch(orderClockProvider).value ?? DateTime.now();
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    if (actionState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          actionState.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    for (final order in items)
                      _StaffOrderCard(
                        order: order,
                        isWorking: actionState.isWorking,
                        isAdmin: isAdmin,
                        now: now,
                        onUpdate: (status) => controller.updateOrderStatus(
                          orderId: order.id,
                          status: status,
                        ),
                        onReject: () {
                          controller.clearError();
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                RejectOrderDialog(orderId: order.id),
                          );
                        },
                        onReportIncident: (reason) => controller.reportIncident(
                          orderId: order.id,
                          reason: reason,
                        ),
                        onResolveIncident: (resolution) =>
                            controller.resolveIncident(
                              orderId: order.id,
                              resolution: resolution,
                            ),
                      ),
                  ],
                ),
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
    required this.now,
    required this.onUpdate,
    required this.onReject,
    required this.onReportIncident,
    required this.onResolveIncident,
  });

  final OrderRecord order;
  final bool isWorking;
  final bool isAdmin;
  final DateTime now;
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _terracotta(context);
    final isReady = order.status == OrderStatus.ready;
    final isIncident = order.status == OrderStatus.incident;
    final badgeColor = isIncident
        ? scheme.error
        : isReady
        ? theme.brightness == Brightness.dark
              ? const Color(0xFF8FD0A6)
              : const Color(0xFF3F7D58)
        : accent;
    final cardColor = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : Colors.white;
    final muted = scheme.onSurfaceVariant;

    final actions = <Widget>[
      if (nextStatus != null && actionLabel != null)
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: theme.brightness == Brightness.dark
                ? scheme.surface
                : Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isWorking ? null : () => onUpdate(nextStatus),
          child: Text(actionLabel),
        ),
      if (order.status.allowsRejection && !order.isCancelled)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            minimumSize: const Size(0, 48),
            side: isWorking ? null : BorderSide(color: scheme.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isWorking ? null : onReject,
          child: const Text('Rechazar'),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folio ${order.displayFolio}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (order.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          formatElapsedTime(order.createdAt!, now: now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 18, color: accent),
              Text(
                'Modalidad: ${order.pickupMode.label}',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
          if (isReady) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.qr_code_scanner, color: badgeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pide al estudiante que muestre su QR y escanéalo para confirmar la entrega.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: accent.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    ProductImage(
                      imagePath: line.product.imagePath,
                      productId: line.product.id,
                      fallbackIcon: Icons.restaurant,
                      width: 40,
                      height: 40,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${line.quantity} × ${line.product.name}'
                        '${line.variant == null ? '' : ' · ${line.variant!.label}'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.bodyMedium),
              Text(
                formatMoney(order.totalCents),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (actions.length == 2 && constraints.maxWidth >= 300) {
                  return Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 10),
                      Expanded(child: actions[1]),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      actions[i],
                    ],
                  ],
                );
              },
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
    );
  }
}

Color _terracotta(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE59A78)
    : const Color(0xFFB4532F);

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
      popUpAnimationStyle: AppTheme.popupMenuAnimationStyle,
      enabled: enabled,
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, child: Text(option)),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: enabled
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}
