import 'package:flutter/material.dart';

/// Barra fija al pie de una pantalla, para resumen y acción principal.
/// Respeta la zona segura del dispositivo y se adapta al tema claro u oscuro.
class FixedBottomBar extends StatelessWidget {
  const FixedBottomBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}
