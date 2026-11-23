import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_image.dart';
import '../../media/presentation/media_storage_provider.dart';
import 'admin_product_variants_controller.dart';

class _AvailabilityController extends Notifier<bool> {
  _AvailabilityController(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void update(bool available) => state = available;
}

final _availabilityProvider = NotifierProvider.autoDispose
    .family<_AvailabilityController, bool, bool>(_AvailabilityController.new);

class _FormRefreshController extends Notifier<int> {
  _FormRefreshController(this.formId);

  final String formId;

  @override
  int build() => 0;

  void refresh() => state++;
}

final _formRefreshProvider = NotifierProvider.autoDispose
    .family<_FormRefreshController, int, String>(_FormRefreshController.new);

class AdminProductForm extends ConsumerStatefulWidget {
  const AdminProductForm({
    super.key,
    this.product,
    this.priceOnly = false,
    this.onArchive,
  });
  final Product? product;
  final bool priceOnly;
  final VoidCallback? onArchive;

  @override
  ConsumerState<AdminProductForm> createState() => _AdminProductFormState();
}

class _AdminProductFormState extends ConsumerState<AdminProductForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name);
  late final category = TextEditingController(text: widget.product?.categoryId);
  late final description = TextEditingController(
    text: widget.product?.description,
  );
  late final ingredients = TextEditingController(
    text: widget.product?.ingredients.join('\n'),
  );
  late final price = TextEditingController(
    text: adminCentsToText(widget.product?.priceCents ?? 0),
  );
  late final prep = TextEditingController(
    text: '${widget.product?.prepMinutes ?? 0}',
  );
  late final portionAmount = TextEditingController(
    text: widget.product?.portionAmount?.toString() ?? '',
  );
  late final String productId =
      widget.product?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
  String imagePath = '';
  String portionUnit = 'pz';
  bool isUploadingImage = false;
  String? imageError;

  @override
  void initState() {
    super.initState();
    imagePath = widget.product?.imagePath ?? '';
    portionUnit = widget.product?.portionUnit ?? 'pz';
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      category,
      price,
      prep,
      description,
      ingredients,
      portionAmount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_formRefreshProvider(productId));
    final initialVariants =
        widget.product?.variants ?? const <ProductVariant>[];
    final variants = ref.watch(adminVariantsProvider(initialVariants));
    final variantsController = ref.read(
      adminVariantsProvider(initialVariants).notifier,
    );
    final initialComplements =
        widget.product?.complements ?? const <ProductVariant>[];
    final complements = ref.watch(adminComplementsProvider(initialComplements));
    final complementsController = ref.read(
      adminComplementsProvider(initialComplements).notifier,
    );
    final availability = _availabilityProvider(
      widget.product?.isAvailable ?? true,
    );
    final available = ref.watch(availability);
    final categories =
        ref.watch(adminCategoriesProvider).value ?? const <String, String>{};
    final archived = widget.product?.archived ?? false;
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
                  _productPhoto(context),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    maxLength: 100,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe un nombre.'
                        : null,
                  ),
                  if (categories.isEmpty)
                    TextFormField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (ID)',
                      ),
                      maxLength: 100,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Escribe el identificador de categoría.'
                          : null,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: categories.containsKey(category.text)
                          ? category.text
                          : null,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        for (final entry in categories.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) => category.text = value ?? '',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Selecciona una categoría.'
                          : null,
                    ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: portionAmount,
                          decoration: const InputDecoration(
                            labelText: 'Porción (opcional)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return null;
                            final amount = int.tryParse(value.trim());
                            return amount == null || amount <= 0
                                ? 'Usa una cantidad entera mayor a cero.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: portionUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'g', child: Text('g')),
                            DropdownMenuItem(value: 'ml', child: Text('ml')),
                            DropdownMenuItem(value: 'pz', child: Text('pzas.')),
                          ],
                          onChanged: (value) {
                            portionUnit = value ?? 'pz';
                            ref
                                .read(_formRefreshProvider(productId).notifier)
                                .refresh();
                          },
                        ),
                      ),
                    ],
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
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLength: 1000,
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: ingredients,
                    decoration: const InputDecoration(
                      labelText: 'Ingredientes (uno por línea)',
                    ),
                    maxLines: 3,
                    validator: (_) =>
                        _ingredients.length > 30 ||
                            _ingredients.any((item) => item.length > 80)
                        ? 'Usa hasta 30 ingredientes de hasta 80 caracteres.'
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(archived ? 'Archivado' : 'Disponible'),
                    value: available && !archived,
                    onChanged: archived
                        ? null
                        : ref.read(availability.notifier).update,
                  ),
                  const SizedBox(height: 16),
                ],
                _priceField(price, 'Precio en MXN'),
                const SizedBox(height: 16),
                if (variants.isNotEmpty)
                  const Text('Las variantes tienen su propio precio de venta.'),
                _optionFields(variants, variantsController, 'variante'),
                if (!widget.priceOnly)
                  _optionFields(
                    complements,
                    complementsController,
                    'complemento',
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!widget.priceOnly && !archived && widget.onArchive != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onArchive!();
            },
            child: const Text('Archivar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isUploadingImage
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    Product(
                      id: productId,
                      name: name.text.trim(),
                      categoryId: category.text.trim(),
                      priceCents: parseAdminPrice(price.text)!,
                      prepMinutes: int.parse(prep.text),
                      isAvailable: available && !archived,
                      imagePath: imagePath,
                      portionAmount: int.tryParse(portionAmount.text.trim()),
                      portionUnit: portionAmount.text.trim().isEmpty
                          ? null
                          : portionUnit,
                      archived: archived,
                      description: description.text.trim(),
                      ingredients: _ingredients,
                      complements: widget.priceOnly
                          ? widget.product?.complements ?? const []
                          : _productOptions(complements),
                      variants: _productOptions(variants),
                    ),
                  );
                },
          child: Text(widget.priceOnly ? 'Guardar precio' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _productPhoto(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProductImage(
              imagePath: imagePath,
              productId: productId,
              fallbackIcon: imagePath.isEmpty
                  ? Icons.restaurant
                  : Icons.image_outlined,
              width: 72,
              height: 72,
              borderRadius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    imagePath.isEmpty
                        ? 'Sin foto de producto'
                        : 'Foto guardada',
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () => _pickAndUploadImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Cámara'),
                      ),
                      TextButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () => _pickAndUploadImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isUploadingImage) const LinearProgressIndicator(),
        if (imageError != null)
          Text(imageError!, style: TextStyle(color: colorScheme.error)),
      ],
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    isUploadingImage = true;
    imageError = null;
    ref.read(_formRefreshProvider(productId).notifier).refresh();
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (file == null) return;
      final extension = file.name.toLowerCase().split('.').last;
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null)
        throw const FormatException('Usa una imagen JPEG, PNG o WebP.');
      final Uint8List bytes = await file.readAsBytes();
      final path = await ref
          .read(mediaStorageProvider)
          .uploadProductImage(productId, bytes, contentType);
      if (mounted) {
        imagePath = path;
        ref.read(_formRefreshProvider(productId).notifier).refresh();
      }
    } catch (error) {
      if (mounted) {
        imageError = 'No se pudo subir la foto: $error';
        ref.read(_formRefreshProvider(productId).notifier).refresh();
      }
    } finally {
      if (mounted) {
        isUploadingImage = false;
        ref.read(_formRefreshProvider(productId).notifier).refresh();
      }
    }
  }

  List<String> get _ingredients => ingredients.text
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  List<ProductVariant> _productOptions(List<VariantFields> fields) => [
    for (final field in fields)
      ProductVariant(
        label: field.label.text,
        priceCents: parseAdminPrice(field.price.text)!,
        isAvailable: field.available,
      ),
  ];

  Widget _optionFields(
    List<VariantFields> fields,
    AdminVariantsController controller,
    String name,
  ) => Column(
    children: [
      for (final field in fields)
        Padding(
          key: ObjectKey(field),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              TextFormField(
                controller: field.label,
                readOnly: widget.priceOnly,
                decoration: InputDecoration(labelText: 'Nombre de $name'),
                maxLength: 40,
                validator: (value) {
                  final label = value?.trim().toLowerCase() ?? '';
                  if (label.isEmpty) return 'Escribe un nombre.';
                  if (fields
                          .where(
                            (other) =>
                                other.label.text.trim().toLowerCase() == label,
                          )
                          .length >
                      1) {
                    return 'Usa un nombre diferente.';
                  }
                  return null;
                },
              ),
              _priceField(field.price, 'Precio de $name en MXN'),
              if (!widget.priceOnly) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Disponible · $name'),
                  value: field.available,
                  onChanged: (value) =>
                      controller.setAvailability(field, value),
                ),
                TextButton(
                  onPressed: () => controller.remove(field),
                  child: Text('Quitar $name'),
                ),
              ],
            ],
          ),
        ),
      if (!widget.priceOnly && fields.length < 6)
        TextButton.icon(
          onPressed: controller.add,
          icon: const Icon(Icons.add),
          label: Text('Agregar $name'),
        ),
    ],
  );

  Widget _priceField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) => (parseAdminPrice(v ?? '') ?? 0) <= 0
            ? 'Usa un precio mayor a cero, con hasta 2 decimales.'
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
