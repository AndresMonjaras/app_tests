import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/presentation/menu_image_providers.dart';

/// Foto remota con caché en disco, respaldada por el recurso local del menú.
class ProductImage extends ConsumerWidget {
  const ProductImage({
    super.key,
    required this.imagePath,
    required this.fallbackIcon,
    this.productId = '',
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  final String imagePath;
  final String productId;
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
    final remoteEnabled = ref.watch(menuImagesEnabledProvider);
    final localPath = menuImageAssetPath(productId);
    final local = localPath == null
        ? fallback
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              localPath,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
    if (!remoteEnabled || imagePath.isEmpty) return local;

    final file = ref.watch(menuImageFileProvider(imagePath));
    return file.when(
      loading: () => _Placeholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
      error: (_, _) => local,
      data: (imageFile) {
        if (imageFile == null) return local;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            imageFile,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => local,
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
    child: const ExcludeSemantics(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
