import '../../../core/errors/domain_exception.dart';

class ProductVariant {
  ProductVariant({required String label, required this.priceCents})
    : label = label.trim() {
    if (this.label.isEmpty || this.label.length > 40) {
      throw const DomainException(
        'La variante debe tener entre 1 y 40 caracteres.',
      );
    }
    if (priceCents < 0) {
      throw const DomainException('El precio no puede ser negativo.');
    }
  }

  final String label;
  final int priceCents;

  static ProductVariant? tryFromMap(Map<dynamic, dynamic> map) {
    final label = (map['label'] ?? '').toString().trim();
    final price = map['priceCents'];
    if (label.isEmpty || label.length > 40) return null;
    if (price is! int || price < 0) return null;

    return ProductVariant(label: label, priceCents: price);
  }

  @override
  bool operator ==(Object other) =>
      other is ProductVariant &&
      other.label == label &&
      other.priceCents == priceCents;

  @override
  int get hashCode => Object.hash(label, priceCents);
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.categoryId = '',
    this.isAvailable = true,
    this.prepMinutes = 0,
    this.imagePath = '',
    List<ProductVariant> variants = const [],
  }) : variants = List.unmodifiable(variants) {
    if (priceCents < 0) {
      throw const DomainException('El precio no puede ser negativo.');
    }
    if (this.variants.length > 6) {
      throw const DomainException('Un producto puede tener hasta 6 variantes.');
    }
  }

  final String id;
  final String name;
  final String categoryId;
  final bool isAvailable;
  final int prepMinutes;
  final int priceCents;
  final List<ProductVariant> variants;

  /// Ruta del objeto en Storage (`menu/{productId}/...`). Vacía si no hay foto.
  final String imagePath;

  int get displayPriceCents {
    if (variants.isEmpty) return priceCents;

    var lowestPrice = variants.first.priceCents;
    for (final variant in variants.skip(1)) {
      if (variant.priceCents < lowestPrice) {
        lowestPrice = variant.priceCents;
      }
    }
    return lowestPrice;
  }

  factory Product.fromMap(String id, Map<dynamic, dynamic> map) {
    final variants = <ProductVariant>[];
    final rawVariants = map['variants'];
    final Iterable<dynamic> variantItems;

    if (rawVariants is List) {
      variantItems = rawVariants;
    } else if (rawVariants is Map) {
      variantItems = rawVariants.values;
    } else {
      variantItems = const [];
    }

    for (final item in variantItems) {
      if (variants.length == 6) break;
      if (item is! Map) continue;

      final variant = ProductVariant.tryFromMap(item);
      if (variant != null) variants.add(variant);
    }

    final rawPrice = map['priceCents'];
    final price = rawPrice is int && rawPrice >= 0 ? rawPrice : 0;
    final rawPrepMinutes = map['prepMinutes'];
    final prepMinutes =
        rawPrepMinutes is int && rawPrepMinutes >= 0 && rawPrepMinutes <= 240
        ? rawPrepMinutes
        : 0;

    return Product(
      id: id,
      name: (map['name'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? '').toString(),
      isAvailable: map['available'] == true,
      prepMinutes: prepMinutes,
      priceCents: price,
      imagePath: _safeMenuImagePath(map['imagePath']),
      variants: variants,
    );
  }
}

/// Acepta solo rutas bajo `menu/` sin segmentos de navegación.
String _safeMenuImagePath(Object? raw) {
  if (raw is! String) return '';
  final path = raw.trim();
  final isMenuPath = path.startsWith('menu/') && !path.contains('..');
  return isMenuPath && !path.contains('//') ? path : '';
}
