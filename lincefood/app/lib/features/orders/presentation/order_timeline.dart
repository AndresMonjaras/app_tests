import 'package:flutter/material.dart';

import '../domain/order_status.dart';

class _TimelineStep {
  const _TimelineStep(this.status, this.label);

  final OrderStatus status;
  final String label;
}

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.currentStatus});

  final OrderStatus currentStatus;

  static const List<_TimelineStep> _steps = [
    _TimelineStep(OrderStatus.paid, 'Pagado'),
    _TimelineStep(OrderStatus.confirmed, 'Confirmado'),
    _TimelineStep(OrderStatus.preparing, 'En preparación'),
    _TimelineStep(OrderStatus.ready, 'Listo para recoger'),
    _TimelineStep(OrderStatus.delivered, 'Entregado'),
  ];

  int get _currentIndex {
    for (var index = 0; index < _steps.length; index++) {
      if (_steps[index].status == currentStatus) return index;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentIndex = _currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _steps.length; index++)
          _buildStep(colors, _steps[index], index, currentIndex),
      ],
    );
  }

  Widget _buildStep(
    ColorScheme colors,
    _TimelineStep step,
    int index,
    int currentIndex,
  ) {
    final isComplete = currentIndex >= 0 && index < currentIndex;
    final isCurrent = index == currentIndex;

    final Color iconColor;
    final Color textColor;
    final IconData icon;
    final String stateLabel;

    if (isComplete) {
      iconColor = colors.primary;
      textColor = colors.onSurface;
      icon = Icons.check_circle;
      stateLabel = 'completado';
    } else if (isCurrent) {
      iconColor = colors.primary;
      textColor = colors.onSurface;
      icon = Icons.radio_button_checked;
      stateLabel = 'paso actual';
    } else {
      iconColor = colors.outline;
      textColor = colors.onSurfaceVariant;
      icon = Icons.radio_button_unchecked;
      stateLabel = 'pendiente';
    }

    return Semantics(
      label: '${step.label}, $stateLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(
              step.label,
              style: TextStyle(
                color: textColor,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
