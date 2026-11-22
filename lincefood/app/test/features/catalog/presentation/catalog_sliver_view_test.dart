import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_sliver_view.dart';

const _categorias = <String>['Café', 'Postres'];

Widget _envoltura(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

CatalogSliverView _catalogo({
  List<Product> productos = const [],
  String categoriaSeleccionada = 'Café',
  ValueChanged<String>? onCategoriaSeleccionada,
  bool abierta = true,
}) {
  return CatalogSliverView(
    nombreCafeteria: 'Cafetería Central',
    abierta: abierta,
    categorias: _categorias,
    categoriaSeleccionada: categoriaSeleccionada,
    onCategoriaSeleccionada: onCategoriaSeleccionada ?? (_) {},
    productos: productos,
  );
}

void main() {
  testWidgets('muestra un producto y su precio en pesos', (tester) async {
    await tester.pumpWidget(
      _envoltura(
        _catalogo(
          productos: [Product(id: 'p1', name: 'Latte', priceCents: 4500)],
        ),
      ),
    );

    expect(find.text('Latte'), findsOneWidget);
    expect(find.text(r'$45.00 MXN'), findsOneWidget);
    expect(find.text('No hay productos disponibles por ahora.'), findsNothing);
  });

  testWidgets('muestra el estado vacío cuando no hay productos', (
    tester,
  ) async {
    await tester.pumpWidget(_envoltura(_catalogo()));

    expect(
      find.text('No hay productos disponibles por ahora.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra el estado de apertura y las categorías', (tester) async {
    await tester.pumpWidget(_envoltura(_catalogo(abierta: false)));

    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Café'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Postres'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SliverPersistentHeader && widget.pinned,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('notifica una categoría recién seleccionada', (tester) async {
    String? seleccionada;
    await tester.pumpWidget(
      _envoltura(
        _catalogo(
          onCategoriaSeleccionada: (categoria) => seleccionada = categoria,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Postres'));
    await tester.pump();

    expect(seleccionada, 'Postres');
  });

  testWidgets('ignora el intento de deseleccionar la categoría actual', (
    tester,
  ) async {
    String? seleccionada;
    await tester.pumpWidget(
      _envoltura(
        _catalogo(
          onCategoriaSeleccionada: (categoria) => seleccionada = categoria,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Café'));
    await tester.pump();

    expect(seleccionada, isNull);
  });
}
