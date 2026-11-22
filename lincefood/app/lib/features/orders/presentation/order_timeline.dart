import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/order_status.dart';

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.currentStatus});

  final OrderStatus currentStatus;

  static const _steps = [
    (OrderStatus.confirmed, 'Recibido', Icons.assignment_turned_in),
    (OrderStatus.preparing, 'En cocina', Icons.soup_kitchen),
    (OrderStatus.ready, 'Listo', Icons.restaurant),
    (OrderStatus.delivered, 'Entregado', Icons.inventory_2),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final currentIndex = _steps.indexWhere((step) => step.$1 == currentStatus);
    final progress = switch (currentIndex) {
      -1 => 0.0,
      3 => 1.0,
      _ => (currentIndex + 0.5) / _steps.length,
    };
    final minimumWidth =
        math.max(64.0, MediaQuery.textScalerOf(context).scale(12) * 5.3) *
        _steps.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: math.max(constraints.maxWidth, minimumWidth),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < _steps.length; index++)
                    Expanded(
                      child: _StepIcon(
                        label: _steps[index].$2,
                        icon: _steps[index].$3,
                        isCurrent: index == currentIndex,
                        isComplete: index < currentIndex,
                        duration: duration,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                    trackGap: 0,
                    stopIndicatorRadius: 0,
                    backgroundColor: colors.outlineVariant,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth >= minimumWidth) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      },
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.label,
    required this.icon,
    required this.isCurrent,
    required this.isComplete,
    required this.duration,
  });

  final String label;
  final IconData icon;
  final bool isCurrent;
  final bool isComplete;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = AppTheme.successColor(theme.brightness);
    final color = isCurrent
        ? colors.primary
        : isComplete
        ? success
        : colors.onSurfaceVariant;
    final stateLabel = isCurrent
        ? 'paso actual'
        : isComplete
        ? 'completado'
        : 'pendiente';
    final isPending = !isCurrent && !isComplete;

    return Semantics(
      label: '$label, $stateLabel',
      excludeSemantics: true,
      child: Opacity(
        opacity: isPending ? 0.4 : 1,
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: isCurrent ? 1 : 0),
              duration: duration,
              builder: (context, value, child) => Transform.scale(
                scale: isCurrent ? 1 + 0.08 * math.sin(math.pi * value) : 1,
                child: child,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? colors.primaryContainer
                      : isComplete
                      ? success.withValues(alpha: 0.14)
                      : colors.surfaceContainerHighest,
                  border: isCurrent ? Border.all(color: color) : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.24),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Icon(isComplete ? Icons.check : icon, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: isPending ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
