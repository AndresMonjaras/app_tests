import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';
import 'admin_product_variants_controller.dart';

class AdminProductForm extends ConsumerStatefulWidget {
  const AdminProductForm({super.key, this.product, this.priceOnly = false});
  final Product? product;
  final bool priceOnly;

  @override
  ConsumerState<AdminProductForm> createState() => _AdminProductFormState();
}

class _AdminProductFormState extends ConsumerState<AdminProductForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name);
  late final category = TextEditingController(text: widget.product?.categoryId);
  late final price = TextEditingController(
    text: adminCentsToText(widget.product?.priceCents ?? 0),
  );
  late final prep = TextEditingController(
    text: '${widget.product?.prepMinutes ?? 0}',
  );

  @override
  void dispose() {
    for (final controller in [name, category, price, prep]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialVariants =
        widget.product?.variants ?? const <ProductVariant>[];
    final variants = ref.watch(adminVariantsProvider(initialVariants));
    final variantsController = ref.read(
      adminVariantsProvider(initialVariants).notifier,
    );
    return AlertDialog(
      title: Text(
        widget.priceOnly
            ? 'Editar precio'
            : widget.product == null
            ? 'Agregar producto'
            : 'Editar producto',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.priceOnly) ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    maxLength: 100,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe un nombre.'
                        : null,
                  ),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    maxLength: 100,
                  ),
                  TextFormField(
                    controller: prep,
                    decoration: const InputDecoration(
                      labelText: 'Preparación en minutos',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 240
                          ? 'Usa de 0 a 240 minutos.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _priceField(price, 'Precio en MXN'),
                const SizedBox(height: 16),
                if (variants.isNotEmpty)
                  const Text('Las variantes tienen su propio precio de venta.'),
                for (final variant in variants)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: variant.label,
                          readOnly: widget.priceOnly,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de variante',
                          ),
                          maxLength: 40,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Escribe el nombre de la variante.'
                              : null,
                        ),
                        _priceField(variant.price, 'Precio de variante en MXN'),
                        if (!widget.priceOnly)
                          TextButton(
                            onPressed: () => variantsController.remove(variant),
                            child: const Text('Quitar variante'),
                          ),
                      ],
                    ),
                  ),
                if (!widget.priceOnly && variants.length < 6)
                  TextButton.icon(
                    onPressed: variantsController.add,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar variante'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              context,
              Product(
                id:
                    widget.product?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                categoryId: category.text.trim(),
                priceCents: parseAdminPrice(price.text)!,
                prepMinutes: int.parse(prep.text),
                isAvailable: widget.product?.isAvailable ?? true,
                variants: [
                  for (final v in variants)
                    ProductVariant(
                      label: v.label.text,
                      priceCents: parseAdminPrice(v.price.text)!,
                    ),
                ],
              ),
            );
          },
          child: Text(widget.priceOnly ? 'Guardar precio' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _priceField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) => parseAdminPrice(v ?? '') == null
            ? 'Usa un precio positivo o cero, con hasta 2 decimales.'
            : null,
      );
}

int? parseAdminPrice(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final digits =
      '${parts.first}${parts.length == 1 ? '00' : parts.last.padRight(2, '0')}';
  final amount = BigInt.tryParse(digits);
  if (amount == null || amount > BigInt.from(9007199254740991)) return null;
  return amount.toInt();
}
