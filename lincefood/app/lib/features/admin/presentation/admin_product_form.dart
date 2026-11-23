import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_image.dart';
import '../../media/presentation/media_storage_provider.dart';
import 'admin_catalog_providers.dart';
import 'admin_taxonomy_providers.dart';
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

class _UnitSelection extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? code) => state = code;
}

final _unitSelection = NotifierProvider.autoDispose
    .family<_UnitSelection, String?, String>((_) => _UnitSelection());

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
  bool isUploadingImage = false;
  String? imageError;

  @override
  void initState() {
    super.initState();
    imagePath = widget.product?.imagePath ?? '';
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
    final units =
        ref.watch(adminUnitsProvider).value ?? const <String, CatalogUnit>{};
    final preferred =
        ref.watch(_unitSelection(productId)) ?? widget.product?.portionUnit;
    final portionUnit = preferred == null
        ? (units.containsKey('pz') ? 'pz' : units.keys.firstOrNull)
        : units.containsKey(preferred)
        ? preferred
        : null;
    final archived = widget.product?.archived ?? false;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = widget.priceOnly
        ? 'Editar precio'
        : widget.product == null
        ? 'Agregar producto'
        : 'Editar producto';
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
        ),
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.priceOnly
                    ? Icons.sell_outlined
                    : widget.product == null
                    ? Icons.add_business_outlined
                    : Icons.edit_note_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.priceOnly) ...[
                    _productPhoto(context),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      context,
                      Icons.info_outline,
                      'Datos del producto',
                    ),
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
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
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
                    const SizedBox(height: 16),
                    _sectionHeader(
                      context,
                      Icons.scale_outlined,
                      'Porción y preparación',
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final amountField = TextFormField(
                          controller: portionAmount,
                          decoration: const InputDecoration(
                            labelText: 'Porción (opcional)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final amount = int.tryParse(value.trim());
                            return amount == null || amount <= 0
                                ? 'Usa una cantidad entera mayor a cero.'
                                : null;
                          },
                        );
                        final unitField = DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: portionUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                          ),
                          items: [
                            for (final entry in units.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value.label),
                              ),
                          ],
                          validator: (_) =>
                              portionAmount.text.trim().isNotEmpty &&
                                  portionUnit == null
                              ? 'Selecciona una unidad disponible.'
                              : null,
                          onChanged: ref
                              .read(_unitSelection(productId).notifier)
                              .select,
                        );
                        if (constraints.maxWidth < 360) {
                          return Column(
                            children: [
                              amountField,
                              const SizedBox(height: 12),
                              unitField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: amountField),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: unitField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      maxLength: 1000,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    Material(
                      color: colors.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        secondary: Icon(
                          available && !archived
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                        ),
                        title: Text(archived ? 'Archivado' : 'Disponible'),
                        subtitle: Text(
                          available && !archived
                              ? 'Los clientes pueden pedirlo.'
                              : 'No aparece para pedir.',
                        ),
                        value: available && !archived,
                        onChanged: archived
                            ? null
                            : ref.read(availability.notifier).update,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionHeader(context, Icons.payments_outlined, 'Precio'),
                  _priceField(price, 'Precio en MXN'),
                  const SizedBox(height: 16),
                  _sectionHeader(context, Icons.tune, 'Variantes'),
                  if (variants.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Las variantes tienen su propio precio de venta.',
                      ),
                    ),
                  _optionFields(variants, variantsController, 'variante'),
                  if (!widget.priceOnly) ...[
                    const SizedBox(height: 16),
                    _sectionHeader(
                      context,
                      Icons.add_circle_outline,
                      'Complementos',
                    ),
                  ],
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
        actionsOverflowButtonSpacing: 4,
        actions: [
          if (!widget.priceOnly && !archived && widget.onArchive != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
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
          FilledButton.icon(
            icon: const Icon(Icons.check),
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
                            : widget.priceOnly
                            ? widget.product?.portionUnit
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
            label: Text(widget.priceOnly ? 'Guardar precio' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  // Titulo de seccion con icono para ordenar el formulario.
  Widget _sectionHeader(BuildContext context, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: colors.primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: colors.outlineVariant)),
        ],
      ),
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
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () => _pickAndUploadImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Cámara'),
                      ),
                      OutlinedButton.icon(
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
      if (contentType == null) {
        throw const FormatException('Usa una imagen JPEG, PNG o WebP.');
      }
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                                    other.label.text.trim().toLowerCase() ==
                                    label,
                              )
                              .length >
                          1) {
                        return 'Usa un nombre diferente.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  _priceField(field.price, 'Precio de $name en MXN'),
                  if (!widget.priceOnly) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Disponible · $name'),
                      value: field.available,
                      onChanged: (value) =>
                          controller.setAvailability(field, value),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: () => controller.remove(field),
                      child: Text('Quitar $name'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      if (!widget.priceOnly && fields.length < 6)
        FilledButton.tonalIcon(
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
