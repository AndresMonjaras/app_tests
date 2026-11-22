import '../../../core/errors/domain_exception.dart';
import '../../catalog/domain/product.dart';

class CartLine {
  CartLine({required this.product, required this.quantity, this.variant}) {
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
  }

  final Product product;
  final int quantity;
  final ProductVariant? variant;

  int get unitPriceCents => variant?.priceCents ?? product.priceCents;

  int get totalCents => unitPriceCents * quantity;

  bool matches(String productId, String? variantLabel) =>
      product.id == productId && variant?.label == variantLabel;

  CartLine withQuantity(int quantity) {
    return CartLine(product: product, quantity: quantity, variant: variant);
  }
}

class Cart {
  Cart([List<CartLine> lines = const []]) : lines = List.unmodifiable(lines);

  final List<CartLine> lines;

  int get totalCents => lines.fold(0, (total, line) => total + line.totalCents);

  int get totalItems => lines.fold(0, (total, line) => total + line.quantity);

  bool get isEmpty => lines.isEmpty;
}
