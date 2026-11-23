import '../../../core/errors/domain_exception.dart';

class ProductVariant {
  ProductVariant({
    required String label,
    required this.priceCents,
    this.isAvailable = true,
  }) : label = label.trim() {
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
  final bool isAvailable;

  static ProductVariant? tryFromMap(Map<dynamic, dynamic> map) {
    final label = (map['label'] ?? '').toString().trim();
    final price = map['priceCents'];
    if (label.isEmpty || label.length > 40) return null;
    if (price is! int || price < 0) return null;

    return ProductVariant(
      label: label,
      priceCents: price,
      isAvailable: map['available'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProductVariant &&
      other.label == label &&
      other.priceCents == priceCents &&
      other.isAvailable == isAvailable;

  @override
  int get hashCode => Object.hash(label, priceCents, isAvailable);
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
    this.description = '',
    this.archived = false,
    this.demo = false,
    this.portionAmount,
    this.portionUnit,
    List<String> ingredients = const [],
    List<ProductVariant> complements = const [],
    List<ProductVariant> variants = const [],
  }) : variants = List.unmodifiable(variants),
       ingredients = List.unmodifiable(ingredients),
       complements = List.unmodifiable(complements) {
    if (priceCents < 0) {
      throw const DomainException('El precio no puede ser negativo.');
    }
    if (this.complements.length > 6) {
      throw const DomainException(
        'Un producto puede tener hasta 6 complementos.',
      );
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
  final List<ProductVariant> complements;
  final String description;
  final List<String> ingredients;
  final bool archived;
  final bool demo;
  final int? portionAmount;
  final String? portionUnit;

  bool get canOrder =>
      isAvailable &&
      !archived &&
      (variants.isEmpty || variants.any((variant) => variant.isAvailable));

  /// Ruta del objeto en Storage (bajo `menu/`). Vacía si no hay foto.
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
      variants: _readOptions(map['variants']),
      complements: _readOptions(map['complements']),
      description: map['description'] is String
          ? map['description'] as String
          : '',
      ingredients: _databaseList(map['ingredients'])
          .whereType<String>()
          .toList(),
      archived: map['archived'] == true,
      demo: map['demo'] == true,
      portionAmount: map['portionAmount'] is int && map['portionAmount'] > 0
          ? map['portionAmount'] as int
          : null,
      portionUnit: const {'g', 'ml', 'pz'}.contains(map['portionUnit'])
          ? map['portionUnit'] as String
          : null,
    );
  }
}

Iterable<dynamic> _databaseList(Object? value) {
  if (value is List) return value;
  if (value is Map) return value.values;
  return const [];
}

List<ProductVariant> _readOptions(Object? value) =>
    _databaseList(value)
        .whereType<Map>()
        .map(ProductVariant.tryFromMap)
        .whereType<ProductVariant>()
        .take(6)
        .toList();

/// Acepta solo rutas bajo `menu/` sin segmentos de navegación.
String _safeMenuImagePath(Object? raw) {
  if (raw is! String) return '';
  final path = raw.trim();
  final isMenuPath = path.startsWith('menu/') && !path.contains('..');
  return isMenuPath && !path.contains('//') ? path : '';
}
