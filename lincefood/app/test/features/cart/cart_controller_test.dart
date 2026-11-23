import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

void main() {
  late ProviderContainer container;
  late Product product;
  late ProductVariant small;
  late ProductVariant large;

  setUp(() {
    container = ProviderContainer();
    small = ProductVariant(label: 'Chica', priceCents: 1000);
    large = ProductVariant(label: 'Grande', priceCents: 1500);
    product = Product(
      id: 'p1',
      name: 'Pizza',
      priceCents: 0,
      variants: [small, large],
    );
  });

  tearDown(() => container.dispose());

  CartController controller() =>
      container.read(cartControllerProvider.notifier);
  Cart readCart() => container.read(cartControllerProvider);

  test('suma cantidades y calcula el total en centavos', () {
    controller().addProduct(product: product, variant: small, quantity: 2);
    controller().addProduct(product: product, variant: small, quantity: 1);

    expect(readCart().lines, hasLength(1));
    expect(readCart().lines.single.quantity, 3);
    expect(readCart().totalCents, 3000);
    expect(readCart().totalItems, 3);
  });

  test('mantiene variantes distintas en líneas separadas', () {
    controller().addProduct(product: product, variant: small);
    controller().addProduct(product: product, variant: large);

    expect(readCart().lines, hasLength(2));
    expect(readCart().totalCents, 2500);
  });

  test('guarda complementos, suma precio y separa selecciones distintas', () {
    final extraCheese = ProductVariant(label: 'Queso extra', priceCents: 300);
    final olive = ProductVariant(label: 'Aceituna', priceCents: 200);
    final pizza = Product(
      id: 'p2',
      name: 'Pizza especial',
      priceCents: 1000,
      complements: [extraCheese, olive],
    );

    controller().addProduct(product: pizza, complements: [extraCheese]);
    controller().addProduct(product: pizza, complements: [olive]);
    controller().addProduct(product: pizza, complements: [extraCheese]);

    expect(readCart().lines, hasLength(2));
    expect(readCart().lines.first.quantity, 2);
    expect(readCart().lines.first.unitPriceCents, 1300);
    expect(readCart().totalCents, 3800);
  });

  test('limita las cantidades entre uno y veinte', () {
    controller().addProduct(product: product, variant: small, quantity: 50);
    expect(readCart().lines.single.quantity, 20);

    controller().changeQuantity(
      productId: product.id,
      variantLabel: small.label,
      quantity: 0,
    );
    expect(readCart().lines.single.quantity, 1);
  });

  test('no modifica el carrito al cambiar una línea inexistente', () {
    controller().addProduct(product: product, variant: small);
    final before = readCart();

    controller().changeQuantity(
      productId: 'missing',
      variantLabel: null,
      quantity: 5,
    );

    expect(readCart(), same(before));
  });

  test('quita una sola variante y permite vaciar el carrito', () {
    controller().addProduct(product: product, variant: small);
    controller().addProduct(product: product, variant: large);

    controller().removeLine(productId: product.id, variantLabel: small.label);
    expect(readCart().lines, hasLength(1));
    expect(readCart().lines.single.variant, large);

    controller().clear();
    expect(readCart().isEmpty, isTrue);
    expect(readCart().totalCents, 0);
  });
}
