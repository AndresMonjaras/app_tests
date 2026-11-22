import 'package:flutter/material.dart';

/// Fondo con una fotografía de comida y un velo para mantener el contraste.
///
/// Si la imagen no existe en assets, muestra un degradado cálido.
class FoodBackground extends StatelessWidget {
  const FoodBackground({
    super.key,
    required this.child,
    this.assetPath = 'assets/images/food_background.jpg',
  });

  final Widget child;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primaryContainer, scheme.surface],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.82),
          ),
        ),
        child,
      ],
    );
  }
}
