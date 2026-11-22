import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/presentation/menu_image_cache.dart';
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

    final url = ref.watch(menuImageUrlProvider(imagePath));
    return url.when(
      loading: () => _Placeholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
      error: (_, _) => fallback,
      data: (imageUrl) {
        if (imageUrl == null) return fallback;
        return _VisibleMenuImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          borderRadius: borderRadius,
          fallback: fallback,
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

class _VisibleMenuImage extends StatefulWidget {
  const _VisibleMenuImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.fallback,
  });

  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final Widget fallback;

  @override
  State<_VisibleMenuImage> createState() => _VisibleMenuImageState();
}

class _VisibleMenuImageState extends State<_VisibleMenuImage> {
  String? _preloadedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preloadedUrl == widget.imageUrl) return;
    _preloadedUrl = widget.imageUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        CachedNetworkImageProvider(
          widget.imageUrl,
          cacheManager: menuImageCacheManager,
        ),
        context,
        onError: (_, _) {},
      );
    });
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: CachedNetworkImage(
      imageUrl: widget.imageUrl,
      cacheManager: menuImageCacheManager,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      placeholder: (_, _) => _Placeholder(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
      ),
      errorWidget: (_, _, _) => widget.fallback,
    ),
  );
}
