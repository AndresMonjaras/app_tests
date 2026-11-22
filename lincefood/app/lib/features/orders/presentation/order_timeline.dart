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

  static const double _stepExtent = 56;
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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: currentIndex < 0 ? 0 : currentIndex.toDouble(),
      ),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) {
        return CustomPaint(
          key: const Key('order-timeline-painter'),
          painter: _OrderTimelinePainter(
            progress: progress,
            currentIndex: currentIndex,
            colors: colors,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _steps.length; index++)
                _buildStep(context, colors, _steps[index], index, currentIndex),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(
    BuildContext context,
    ColorScheme colors,
    _TimelineStep step,
    int index,
    int currentIndex,
  ) {
    final isComplete = currentIndex >= 0 && index < currentIndex;
    final isCurrent = index == currentIndex;
    final stateLabel = isComplete
        ? 'completado'
        : isCurrent
        ? 'paso actual'
        : 'pendiente';

    return Semantics(
      label: '${step.label}, $stateLabel',
      excludeSemantics: true,
      child: SizedBox(
        height: _stepExtent,
        child: Padding(
          padding: const EdgeInsets.only(left: 54),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              step.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isCurrent ? colors.onSurface : colors.onSurfaceVariant,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTimelinePainter extends CustomPainter {
  const _OrderTimelinePainter({
    required this.progress,
    required this.currentIndex,
    required this.colors,
  });

  final double progress;
  final int currentIndex;
  final ColorScheme colors;

  static const double _stepExtent = OrderTimeline._stepExtent;
  static const double _centerX = 22;
  static const double _nodeRadius = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final firstY = _stepExtent / 2;
    final lastY = firstY + _stepExtent * (OrderTimeline._steps.length - 1);
    final trackPaint = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(_centerX, firstY),
      Offset(_centerX, lastY),
      trackPaint,
    );

    if (currentIndex > 0) {
      final progressY =
          firstY + _stepExtent * progress.clamp(0, currentIndex).toDouble();
      final activeTrackPaint = Paint()
        ..color = colors.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(_centerX, firstY),
        Offset(_centerX, progressY),
        activeTrackPaint,
      );
    }

    for (var index = 0; index < OrderTimeline._steps.length; index++) {
      final y = firstY + _stepExtent * index;
      final isComplete = currentIndex >= 0 && index < currentIndex;
      final isCurrent = index == currentIndex;
      final circlePaint = Paint()
        ..color = isComplete ? colors.primary : colors.surface
        ..style = isComplete ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = isCurrent ? 3 : 2;

      if (isCurrent) {
        circlePaint.color = colors.primary;
      } else if (!isComplete) {
        circlePaint.color = colors.outline;
      }
      canvas.drawCircle(Offset(_centerX, y), _nodeRadius, circlePaint);

      if (isComplete) {
        _drawCheck(canvas, Offset(_centerX, y), colors.onPrimary);
      } else if (isCurrent) {
        canvas.drawCircle(
          Offset(_centerX, y),
          4,
          Paint()..color = colors.primary,
        );
      }
    }
  }

  void _drawCheck(Canvas canvas, Offset center, Color color) {
    final check = Path()
      ..moveTo(center.dx - 4, center.dy)
      ..lineTo(center.dx - 1, center.dy + 3)
      ..lineTo(center.dx + 5, center.dy - 4);
    canvas.drawPath(
      check,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OrderTimelinePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        currentIndex != oldDelegate.currentIndex ||
        colors != oldDelegate.colors;
  }
}
