import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
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
import '../domain/order_elapsed_time.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import 'order_cancellation_providers.dart';
import 'order_rejection_notice.dart';
import 'order_receipt_screen.dart';
import 'order_timeline.dart';
import 'orders_providers.dart';

// Evita que los tickets se estiren en escritorio.
const _anchoMaximo = 720.0;

final hiddenOrderIdsProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, uid) {
      if (Firebase.apps.isEmpty) return Stream.value(const <String>{});
      return FirebaseDatabase.instance
          .ref('hiddenOrders/$uid')
          .onValue
          .map(
            (event) => {
              for (final child in event.snapshot.children)
                if (child.value == true && child.key != null) child.key!,
            },
          );
    });

final setOrderHiddenProvider =
    Provider<Future<void> Function(String uid, String orderId, bool hidden)>((
      ref,
    ) {
      return (uid, orderId, hidden) {
        return FirebaseDatabase.instance
            .ref('hiddenOrders/$uid/$orderId')
            .set(hidden ? true : null);
      };
    });

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidActivoProvider);
    final hidden = uid == null ? null : ref.watch(hiddenOrderIdsProvider(uid));
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
              tooltip: 'Panel de cafetería',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.staffOrders),
              icon: const Icon(Icons.storefront_outlined),
            ),
        ],
      ),
      body: orders.when(
        data: (items) {
          final hiddenIds = hidden?.value ?? const <String>{};
          final visibleOrders = items.where((order) {
            return (orderId == null || order.id == orderId) &&
                (!_canHide(order) || !hiddenIds.contains(order.id));
          }).toList();
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
                itemBuilder: (itemContext, index) {
                  final order = sortedOrders[index];
                  final key = ValueKey(order.id);
                  final ticket = _TicketCard(key: key, order: order, now: now);
                  if (uid == null ||
                      !_canHide(order) ||
                      hidden?.hasValue != true) {
                    return ticket;
                  }
                  return Dismissible(
                    key: key,
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      color: Theme.of(itemContext)
                          .colorScheme
                          .secondaryContainer,
                      child: const Icon(Icons.visibility_off_outlined),
                    ),
                    confirmDismiss: (_) async {
                      await _confirmHide(context, ref, uid, order.id);
                      return false;
                    },
                    child: ticket,
                  );
                },
              ),
            ),
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar tus pedidos.'),
                TextButton(
                  onPressed: () => ref.invalidate(ordersStreamProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando pedidos'),
        ),
      ),
    );
  }

  bool _canHide(OrderRecord order) =>
      order.isCancelled ||
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.rejected;

  Future<void> _confirmHide(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String orderId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Ocultar pedido?'),
        content: const Text('Se quitará de tu historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(uidActivoProvider) != uid) {
      return;
    }

    final save = ref.read(setOrderHiddenProvider);
    try {
      await save(uid, orderId, true);
      if (!messenger.mounted ||
          !context.mounted ||
          ref.read(uidActivoProvider) != uid) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Pedido oculto.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              if (!context.mounted || ref.read(uidActivoProvider) != uid) {
                return;
              }
              try {
                await save(uid, orderId, false);
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo deshacer. Inténtalo de nuevo.'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo ocultar el pedido. Inténtalo de nuevo.'),
          ),
        );
      }
    }
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
      OrderStatus.cancelled => 'Pedido cancelado',
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TicketAccentBar(),
          const _FishLane(seed: 0),
          Padding(
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
                        avatar: Icon(
                          Icons.check_circle_outline,
                          color: success,
                        ),
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
                const _DashedDivider(),
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
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (!order.isCancelled &&
                    order.status == OrderStatus.delivered) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OrderReceiptScreen(order: order),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ticket'),
                  ),
                ],
                if (!order.isCancelled &&
                    (_canShowPickupQr(order.status) ||
                        canCustomerCancel(order.status))) ...[
                  const SizedBox(height: 12),
                  // Los dos botones comparten fila para ocupar menos alto.
                  Row(
                    children: [
                      if (_canShowPickupQr(order.status))
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pushNamed(
                              AppRouter.pickupQr,
                              arguments: {
                                'orderId': order.id,
                                'requireBiometrics': true,
                              },
                            ),
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Ver QR'),
                          ),
                        ),
                      if (_canShowPickupQr(order.status) &&
                          canCustomerCancel(order.status))
                        const SizedBox(width: 8),
                      if (canCustomerCancel(order.status))
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                              side: isCancelling
                                  ? null
                                  : BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                            ),
                            onPressed: isCancelling
                                ? null
                                : () => _confirmarCancelacion(context, ref),
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(
                              isCancelling
                                  ? 'Cancelando...'
                                  : 'Cancelar pedido',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                _TicketFooter(order: order),
              ],
            ),
          ),
          const _FishLane(seed: 1),
        ],
      ),
    );
  }

  bool _canShowPickupQr(OrderStatus status) => switch (status) {
    OrderStatus.paid ||
    OrderStatus.confirmed ||
    OrderStatus.preparing ||
    OrderStatus.ready => true,
    _ => false,
  };

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
          'Puedes cancelarlo mientras el pago siga pendiente. Cuando se '
          'confirme, ya no podrás cancelarlo desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
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
          productId: line.product.id,
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
                '${line.variant == null ? '' : ' (${line.variant!.label})'}'
                '${line.complements.isEmpty ? '' : ' · ${line.complements.map((item) => item.label).join(', ')}'}',
                style: text.titleSmall,
              ),
              Text(
                '$quantity $unitLabel · ${formatMoney(line.totalCents)}',
                style: text.bodySmall,
              ),
              if (quantity > 1)
                Text(
                  '${formatMoney(line.unitPriceCents)} c/u',
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Franja de color en la parte alta del ticket.
class _TicketAccentBar extends StatelessWidget {
  const _TicketAccentBar();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary, colors.secondary],
        ),
      ),
    );
  }
}

/// Linea punteada que imita el corte de un ticket de papel.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashes = (constraints.maxWidth / 10).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < dashes; i++)
                SizedBox(
                  width: 5,
                  height: 1.5,
                  child: ColoredBox(color: color),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Reloj compartido: todas las mojarritas leen la misma hora de arranque, asi
/// que al reconstruir la tarjeta o volver a la pantalla siguen donde iban en
/// lugar de empezar de cero.
final DateTime _fishEpoch = DateTime.now();

/// Franja libre (sin datos) arriba o abajo del ticket donde nadan mojarritas.
/// Nunca cruza texto importante y no recibe toques. La animacion es finita para
/// no dejar frames pendientes y se apaga si se pidio reducir movimiento.
class _FishLane extends StatefulWidget {
  const _FishLane({required this.seed});

  /// 0 = franja superior, 1 = franja inferior (distinto tamano y ritmo).
  final int seed;

  @override
  State<_FishLane> createState() => _FishLaneState();
}

class _FishLaneState extends State<_FishLane>
    with SingleTickerProviderStateMixin {
  static const _periodMs = 9000;
  static const _laneHeight = 38.0;

  // Tamano, fase inicial y vueltas por ciclo de cada mojarrita.
  static const _lanes = [
    [
      (size: 30.0, phase: 0.00, laps: 1.0),
      (size: 22.0, phase: 0.55, laps: 2.0),
    ],
    [
      (size: 24.0, phase: 0.30, laps: 2.0),
      (size: 28.0, phase: 0.80, laps: 1.0),
    ],
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _periodMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final elapsed = DateTime.now().difference(_fishEpoch).inMilliseconds;
    final resume = (elapsed % _periodMs) / _periodMs;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = resume;
    } else {
      // Retoma desde donde iba el reloj global y completa dos ciclos mas.
      _controller.forward(from: resume).then((_) {
        if (mounted) _controller.repeat(count: 1);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fish = _lanes[widget.seed % _lanes.length];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: _laneHeight,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, box) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Stack(
                    children: [
                      for (final f in fish) _positionedFish(box.maxWidth, f),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedFish(
    double width,
    ({double size, double phase, double laps}) fish,
  ) {
    final angle = 2 * math.pi * (_controller.value * fish.laps + fish.phase);
    final imageWidth = fish.size * 1.5;
    final x = (math.sin(angle) * 0.5 + 0.5) * (width - imageWidth);
    final goingRight = math.cos(angle) >= 0;
    final bob = math.sin(angle * 3) * 3;
    return Positioned(
      left: x,
      top: (_laneHeight - fish.size) / 2 + bob,
      child: Transform.flip(
        flipX: !goingRight,
        child: Image.asset(
          'assets/images/mojarra/mojarra_sola.png',
          width: imageWidth,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Detalle final del ticket: resumen, fecha, estado del pago y cardumen.
class _TicketFooter extends StatelessWidget {
  const _TicketFooter({required this.order});

  final OrderRecord order;

  String get _paymentLabel {
    if (order.isCancelled) return 'Cancelado';
    return switch (order.status) {
      OrderStatus.paymentPending => 'Pendiente',
      OrderStatus.rejected => 'Reembolsado',
      _ => 'Confirmado',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = order.lines.fold<int>(0, (sum, line) => sum + line.quantity);
    final created = order.createdAt?.toLocal();
    final date = created == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(created);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DashedDivider(),
        _TicketDetailRow(label: 'Artículos', value: '$items'),
        if (date != null) _TicketDetailRow(label: 'Fecha', value: date),
        _TicketDetailRow(label: 'Pago', value: _paymentLabel),
        const SizedBox(height: 8),
        Text(
          '¡Gracias por comer con Lincefood!',
          textAlign: TextAlign.center,
          style: text.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TicketDetailRow extends StatelessWidget {
  const _TicketDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
