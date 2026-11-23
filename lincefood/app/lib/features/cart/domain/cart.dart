import '../../../core/errors/domain_exception.dart';
import '../../catalog/domain/product.dart';

class CartLine {
  CartLine({
    required this.product,
    required this.quantity,
    this.variant,
    List<ProductVariant> complements = const [],
  }) : complements = List.unmodifiable(complements) {
    if (quantity < 1) {
      throw const DomainException('La cantidad debe ser al menos 1.');
    }
    if (product.variants.isEmpty && variant != null) {
      throw const DomainException('Este producto no tiene variantes.');
    }
    if (product.variants.isNotEmpty && variant == null) {
      throw const DomainException('Selecciona una variante del producto.');
    }
    if (variant != null && !product.variants.contains(variant)) {
      throw const DomainException('La variante no pertenece al producto.');
    }
    if (this.complements.length > product.complements.length ||
        this.complements.toSet().length != this.complements.length ||
        this.complements.any(
          (complement) => !product.complements.contains(complement),
        )) {
      throw const DomainException(
        'Los complementos seleccionados no son válidos.',
      );
    }
    if (this.complements.any((complement) => !complement.isAvailable)) {
      throw const DomainException('Un complemento seleccionado está agotado.');
    }
  }

  final Product product;
  final int quantity;
  final ProductVariant? variant;
  final List<ProductVariant> complements;

  int get unitPriceCents =>
      (variant?.priceCents ?? product.priceCents) +
      complements.fold(0, (total, item) => total + item.priceCents);

  int get totalCents => unitPriceCents * quantity;

  bool matches(
    String productId,
    String? variantLabel, [
    List<String> complementLabels = const [],
  ]) =>
      product.id == productId &&
      variant?.label == variantLabel &&
      _sameLabels(complements.map((item) => item.label), complementLabels);

  CartLine withQuantity(int quantity) {
    return CartLine(
      product: product,
      quantity: quantity,
      variant: variant,
      complements: complements,
    );
  }
}

bool _sameLabels(Iterable<String> left, Iterable<String> right) {
  final leftLabels = left.toList()..sort();
  final rightLabels = right.toList()..sort();
  if (leftLabels.length != rightLabels.length) return false;
  for (var index = 0; index < leftLabels.length; index++) {
    if (leftLabels[index] != rightLabels[index]) return false;
  }
  return true;
}

class Cart {
  Cart([List<CartLine> lines = const []]) : lines = List.unmodifiable(lines);

  final List<CartLine> lines;

  int get totalCents => lines.fold(0, (total, line) => total + line.totalCents);

  int get totalItems => lines.fold(0, (total, line) => total + line.quantity);

  bool get isEmpty => lines.isEmpty;
}
