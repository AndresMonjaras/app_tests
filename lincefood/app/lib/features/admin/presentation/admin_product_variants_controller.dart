import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';

/// Campos de texto de una variante en el formulario de producto.
class VariantFields {
  VariantFields(String name, int cents, this.available)
    : label = TextEditingController(text: name),
      price = TextEditingController(text: adminCentsToText(cents));

  final TextEditingController label;
  final TextEditingController price;
  bool available;

  void dispose() {
    label.dispose();
    price.dispose();
  }
}

/// Lista editable de variantes. Se crea una instancia por cada lista inicial.
class AdminVariantsController extends Notifier<List<VariantFields>> {
  AdminVariantsController(this._initial);

  final List<ProductVariant> _initial;
  // Se conservan todos los campos creados para liberarlos al cerrar el formulario.
  final _created = <VariantFields>[];

  @override
  List<VariantFields> build() {
    ref.onDispose(() {
      for (final fields in _created) {
        fields.dispose();
      }
    });
    return [
      for (final v in _initial) _create(v.label, v.priceCents, v.isAvailable),
    ];
  }

  void add() {
    if (state.length < 6) state = [...state, _create('', 0, true)];
  }

  void setAvailability(VariantFields fields, bool available) {
    fields.available = available;
    state = [...state];
  }

  void remove(VariantFields fields) {
    state = [
      for (final current in state)
        if (current != fields) current,
    ];
  }

  VariantFields _create(String label, int cents, bool available) {
    final fields = VariantFields(label, cents, available);
    _created.add(fields);
    return fields;
  }
}

final adminVariantsProvider = NotifierProvider.autoDispose
    .family<AdminVariantsController, List<VariantFields>, List<ProductVariant>>(
      AdminVariantsController.new,
    );

final adminComplementsProvider = NotifierProvider.autoDispose
    .family<AdminVariantsController, List<VariantFields>, List<ProductVariant>>(
      AdminVariantsController.new,
    );

String adminCentsToText(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
