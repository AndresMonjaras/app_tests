import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/money/money.dart';
import '../../cart/domain/cart.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/product_image.dart';
import '../../media/presentation/menu_image_providers.dart';
import '../../notifications/presentation/notifications_inbox_screen.dart';
import '../../pickup_qr/presentation/pickup_scanner_screen.dart';
import '../domain/order_elapsed_time.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import 'order_cancellation_providers.dart';
import 'order_rejection_notice.dart';
import 'order_timeline.dart';
import 'orders_providers.dart';

// Evita que los tickets se estiren en escritorio.
const _anchoMaximo = 720.0;

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
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.staffOrders),
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
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _anchoMaximo),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sortedOrders.length,
                findItemIndexCallback: (key) {
                  final index = sortedOrders.indexWhere(
                    (order) => ValueKey(order.id) == key,
                  );
                  return index < 0 ? null : index;
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = sortedOrders[index];
                  return _TicketCard(
                    key: ValueKey(order.id),
                    order: order,
                    now: now,
                  );
                },
              ),
            ),
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
  const _TicketCard({super.key, required this.order, required this.now});

  final OrderRecord order;
  final DateTime now;

  String get _title {
    if (order.isCancelled) return 'Pedido cancelado';
    return switch (order.status) {
      OrderStatus.paymentPending => 'Pago pendiente',
      OrderStatus.paid => 'Pedido pagado',
      OrderStatus.confirmed => 'Pedido recibido',
      OrderStatus.preparing => 'Pedido en preparación',
      OrderStatus.ready => 'Pedido listo para recoger',
      OrderStatus.delivered => 'Pedido entregado',
      OrderStatus.incident => 'Pedido en revisión',
      OrderStatus.rejected => order.status.label,
    };
  }

  bool get _paymentConfirmed =>
      !order.isCancelled &&
      order.status != OrderStatus.paymentPending &&
      order.status != OrderStatus.rejected;

  String? get _productStatus {
    if (order.isCancelled) return null;
    return switch (order.status) {
      OrderStatus.paid => 'Esperando confirmación de la cafetería',
      OrderStatus.preparing => 'Preparando tus alimentos',
      OrderStatus.ready => 'Puedes pasar a recogerlo',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final success = AppTheme.successColor(theme.brightness);
    final isCancelling = ref.watch(cancellingOrdersProvider).contains(order.id);
    final needsCatalogImages =
        order.lines.any((line) => line.product.imagePath.isEmpty) &&
        ref.watch(menuImagesEnabledProvider);
    final catalogImages = {
      if (needsCatalogImages)
        for (final product
            in ref.watch(catalogProductsProvider).value ?? const [])
          product.id: product.imagePath,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (order.status == OrderStatus.rejected) ...[
                  Icon(Icons.error_outline, color: colors.error),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  order.displayFolio,
                  semanticsLabel: 'Folio ${order.displayFolio}',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_paymentConfirmed)
                  Chip(
                    avatar: Icon(Icons.check_circle_outline, color: success),
                    label: const Text('Pago confirmado'),
                    backgroundColor: success.withValues(alpha: 0.12),
                    side: BorderSide.none,
                    labelStyle: text.labelLarge?.copyWith(
                      color: success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (order.status == OrderStatus.rejected)
              OrderRejectionNotice(order: order),
            if (!order.isCancelled) ...[
              OrderTimeline(currentStatus: order.status),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  for (final line in order.lines)
                    _TicketProduct(
                      line: line,
                      imagePath: line.product.imagePath.isNotEmpty
                          ? line.product.imagePath
                          : catalogImages[line.product.id] ?? '',
                    ),
                  if (order.lines.isEmpty)
                    const Text('No hay detalle de productos disponible.'),
                  if (_productStatus case final status?)
                    Text(
                      status,
                      style: text.bodyMedium?.copyWith(
                        color: success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('Total'),
                Text(
                  formatMoney(order.totalCents),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: TextStyle(color: colors.onSurfaceVariant),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(order.pickupMode.label),
                  if (order.createdAt case final createdAt?) ...[
                    Text(_orderTime(context, createdAt)),
                    Text(formatElapsedTime(createdAt, now: now)),
                  ],
                ],
              ),
            ),
            if (!order.isCancelled &&
                (order.status == OrderStatus.confirmed ||
                    order.status == OrderStatus.preparing)) ...[
              const SizedBox(height: 12),
              Text(
                'Te avisaremos cuando tu comida esté lista.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            if (!order.isCancelled && order.status == OrderStatus.ready) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRouter.pickupQr,
                  arguments: {'orderId': order.id},
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

  String _orderTime(BuildContext context, DateTime createdAt) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(createdAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return 'Pedido a las $time';
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

class _TicketProduct extends StatelessWidget {
  const _TicketProduct({required this.line, required this.imagePath});

  final CartLine line;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final quantity = line.quantity;
    final unitLabel = quantity == 1 ? 'unidad' : 'unidades';
    return Row(
      children: [
        ProductImage(
          imagePath: imagePath,
          fallbackIcon: Icons.restaurant,
          width: 54,
          height: 54,
          borderRadius: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${line.product.name}'
                '${line.variant == null ? '' : ' (${line.variant!.label})'}',
                style: text.titleSmall,
              ),
              Text(
                '$quantity $unitLabel · ${formatMoney(line.totalCents)}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
