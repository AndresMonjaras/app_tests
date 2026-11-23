import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/product_image.dart';
import 'package:lincefood_app/features/media/data/in_memory_media_storage.dart';
import 'package:lincefood_app/features/media/presentation/media_storage_provider.dart';
import 'package:lincefood_app/features/media/presentation/menu_image_providers.dart';

class _FailingMediaStorage extends InMemoryMediaStorage {
  @override
  Future<String> productImageUrl(String path) async =>
      throw StateError('sin red');
}

Widget _app({
  required bool imagesEnabled,
  required InMemoryMediaStorage storage,
  String imagePath = 'menu/torta/v1.jpg',
}) {
  return ProviderScope(
    overrides: [
      menuImagesEnabledProvider.overrideWithValue(imagesEnabled),
      mediaStorageProvider.overrideWithValue(storage),
      // Evita tocar disco/sqflite: resuelve el archivo según el storage de prueba.
      menuImageFileProvider.overrideWith((ref, path) async {
        if (path.isEmpty || !imagesEnabled) return null;
        await ref.watch(mediaStorageProvider).productImageUrl(path);
        return File('/tmp/menu_image_test.png');
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: ProductImage(
            imagePath: imagePath,
            fallbackIcon: Icons.restaurant_outlined,
            width: 56,
            height: 56,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('Product solo acepta rutas de imagen bajo menu/', () {
    final valid = Product.fromMap('torta', {
      'name': 'Torta',
      'imagePath': 'menu/torta/v1.jpg',
    });
    final traversal = Product.fromMap('x', {
      'name': 'X',
      'imagePath': 'menu/../profiles/uid/avatar/avatar',
    });
    final foreign = Product.fromMap('y', {
      'name': 'Y',
      'imagePath': 'profiles/uid/avatar/avatar',
    });

    expect(valid.imagePath, 'menu/torta/v1.jpg');
    expect(traversal.imagePath, isEmpty);
    expect(foreign.imagePath, isEmpty);
  });

  testWidgets('sin flag activo muestra el icono y no descarga nada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(imagesEnabled: false, storage: InMemoryMediaStorage()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('sin ruta de imagen muestra el icono', (tester) async {
    await tester.pumpWidget(
      _app(imagesEnabled: true, storage: InMemoryMediaStorage(), imagePath: ''),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con flag activo muestra la imagen desde archivo local', (
    tester,
  ) async {
    final storage = InMemoryMediaStorage();
    final path = await storage.uploadProductImage(
      'torta',
      Uint8List.fromList([1, 2, 3]),
      'image/png',
    );
    await tester.pumpWidget(
      _app(imagesEnabled: true, storage: storage, imagePath: path),
    );
    // Espera a que el provider resuelva la URL antes de buscar la imagen.
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('si falla la URL muestra el icono sin romper la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(imagesEnabled: true, storage: _FailingMediaStorage()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
