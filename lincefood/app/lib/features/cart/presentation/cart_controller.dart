import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';
import '../domain/cart.dart';

int _boundedQuantity(int quantity) {
  if (quantity < 1) return 1;
  if (quantity > 20) return 20;
  return quantity;
}

class CartController extends Notifier<Cart> {
  @override
  Cart build() => Cart();

  void addProduct({
    required Product product,
    ProductVariant? variant,
    List<ProductVariant> complements = const [],
    int quantity = 1,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => line.matches(
        product.id,
        variant?.label,
        complements.map((item) => item.label).toList(),
      ),
    );

    if (index >= 0) {
      final current = lines[index];
      lines[index] = current.withQuantity(
        _boundedQuantity(current.quantity + quantity),
      );
    } else {
      lines.add(
        CartLine(
          product: product,
          variant: variant,
          complements: complements,
          quantity: _boundedQuantity(quantity),
        ),
      );
    }

    state = Cart(lines);
  }

  void changeQuantity({
    required String productId,
    String? variantLabel,
    List<String> complementLabels = const [],
    required int quantity,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => line.matches(productId, variantLabel, complementLabels),
    );
    if (index < 0) return;

    lines[index] = lines[index].withQuantity(_boundedQuantity(quantity));
    state = Cart(lines);
  }

  void removeLine({
    required String productId,
    String? variantLabel,
    List<String> complementLabels = const [],
  }) {
    final lines = state.lines
        .where(
          (line) => !line.matches(productId, variantLabel, complementLabels),
        )
        .toList();
    state = Cart(lines);
  }

  void clear() => state = Cart();
}

final cartControllerProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);
