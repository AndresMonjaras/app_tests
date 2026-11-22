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
    int quantity = 1,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => line.matches(product.id, variant?.label),
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
          quantity: _boundedQuantity(quantity),
        ),
      );
    }

    state = Cart(lines);
  }

  void changeQuantity({
    required String productId,
    String? variantLabel,
    required int quantity,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => line.matches(productId, variantLabel),
    );
    if (index < 0) return;

    lines[index] = lines[index].withQuantity(_boundedQuantity(quantity));
    state = Cart(lines);
  }

  void removeLine({required String productId, String? variantLabel}) {
    final lines = state.lines
        .where((line) => !line.matches(productId, variantLabel))
        .toList();
    state = Cart(lines);
  }

  void clear() => state = Cart();
}

final cartControllerProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);
