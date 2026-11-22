import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

void main() {
  group('Product.fromMap', () {
    test('lee los campos del catálogo y sus variantes', () {
      final product = Product.fromMap('sandwich', {
        'name': 'Sándwich',
        'categoryId': 'breakfast',
        'available': true,
        'prepMinutes': 5,
        'priceCents': 3000,
        'variants': [
          {'label': 'Chico', 'priceCents': 3000},
          {'label': 'Grande', 'priceCents': 4000},
        ],
      });

      expect(product.id, 'sandwich');
      expect(product.name, 'Sándwich');
      expect(product.categoryId, 'breakfast');
      expect(product.isAvailable, isTrue);
      expect(product.prepMinutes, 5);
      expect(product.priceCents, 3000);
      expect(product.variants, hasLength(2));
    });

    test('omite variantes con etiquetas o precios inválidos', () {
      final product = Product.fromMap('sandwich', {
        'name': 'Sándwich',
        'variants': [
          {'label': '  ', 'priceCents': 100},
          {'label': 'a' * 41, 'priceCents': 100},
          {'label': 'Negativa', 'priceCents': -1},
          {'label': 'Texto', 'priceCents': '100'},
          {'label': 'Válida', 'priceCents': 100},
        ],
      });

      expect(product.variants, hasLength(1));
      expect(product.variants.single.label, 'Válida');
    });

    test('limita las variantes válidas a seis', () {
      final product = Product.fromMap('sandwich', {
        'name': 'Sándwich',
        'variants': [
          for (var index = 0; index < 8; index++)
            {'label': 'Opción $index', 'priceCents': index * 100},
        ],
      });

      expect(product.variants, hasLength(6));
    });

    test('usa valores seguros si faltan campos o no son válidos', () {
      final product = Product.fromMap('sandwich', {
        'name': 'Sándwich',
        'available': 'true',
        'prepMinutes': 500,
        'priceCents': -100,
      });

      expect(product.isAvailable, isFalse);
      expect(product.prepMinutes, 0);
      expect(product.priceCents, 0);
    });
  });

  group('precio mostrado', () {
    test('usa el precio base cuando no hay variantes', () {
      final product = Product(
        id: 'water',
        name: 'Agua fresca',
        priceCents: 2000,
      );

      expect(product.displayPriceCents, 2000);
    });

    test('usa el precio de variante más bajo', () {
      final product = Product.fromMap('sandwich', {
        'name': 'Sándwich',
        'variants': [
          {'label': 'Grande', 'priceCents': 4000},
          {'label': 'Chico', 'priceCents': 3000},
        ],
      });

      expect(product.displayPriceCents, 3000);
    });
  });
}
