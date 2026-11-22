import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/presentation/menu_image_providers.dart';

/// Foto del producto con caché en disco. Sin foto, sin URL o con error,
/// muestra el icono de categoría.
class ProductImage extends ConsumerWidget {
  const ProductImage({
    super.key,
    required this.imagePath,
    required this.fallbackIcon,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  final String imagePath;
  final IconData fallbackIcon;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = _IconBox(
      icon: fallbackIcon,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
    if (imagePath.isEmpty || !ref.watch(menuImagesEnabledProvider)) {
      return fallback;
    }

    final file = ref.watch(menuImageFileProvider(imagePath));
    return file.when(
      loading: () => _Placeholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
      error: (_, _) => fallback,
      data: (imageFile) {
        if (imageFile == null) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            imageFile,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final IconData icon;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: colors.onPrimaryContainer),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
