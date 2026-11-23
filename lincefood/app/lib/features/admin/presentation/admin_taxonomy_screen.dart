import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';
import 'admin_catalog_providers.dart';
import 'admin_taxonomy_providers.dart';

class AdminTaxonomyScreen extends ConsumerWidget {
  const AdminTaxonomyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(catalogEditorAccessProvider).asData?.value != true) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Acceso restringido.')),
      );
    }
    final categories = ref
        .watch(adminCategoriesProvider)
        .whenData(
          (entries) => {
            for (final entry in entries.entries)
              entry.key: (label: entry.value, symbol: ''),
          },
        );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorías y unidades'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.category_outlined), text: 'Categorías'),
              Tab(icon: Icon(Icons.straighten), text: 'Unidades'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TaxonomyList(entries: categories, unit: false),
            _TaxonomyList(entries: ref.watch(adminUnitsProvider), unit: true),
          ],
        ),
      ),
    );
  }
}

class _TaxonomyList extends ConsumerWidget {
  const _TaxonomyList({required this.entries, required this.unit});
  final AsyncValue<Map<String, CatalogUnit>> entries;
  final bool unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('No se pudo cargar el catálogo.')),
      data: (items) {
        final colors = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(unit ? 'Agregar unidad' : 'Agregar categoría'),
                ),
                const SizedBox(height: 12),
                for (final entry in items.entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: unit
                            ? Text(
                                entry.value.symbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : const Icon(Icons.category_outlined),
                      ),
                      title: Text(
                        entry.value.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: unit
                          ? Text('${entry.key} · ${entry.value.symbol}')
                          : null,
                      onTap: () =>
                          _edit(context, ref, id: entry.key, item: entry.value),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.error),
                        tooltip: 'Eliminar',
                        onPressed: () =>
                            _delete(context, ref, entry.key, entry.value.label),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    String? id,
    CatalogUnit? item,
  }) async {
    final draft = (
      code: id ?? '',
      label: item?.label ?? '',
      symbol: item?.symbol ?? '',
    );
    final result = await showDialog<_Draft>(
      context: context,
      builder: (_) => _Editor(unit: unit, editing: id != null, initial: draft),
    );
    if (result == null || !context.mounted) return;
    await _write(context, ref, () async {
      final controller = ref.read(adminTaxonomyControllerProvider);
      if (unit) {
        await controller.saveUnit(result.code, result.label, result.symbol);
      } else {
        await controller.saveCategory(result.label, id: id);
      }
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar «$label»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _write(context, ref, () {
      final controller = ref.read(adminTaxonomyControllerProvider);
      return unit ? controller.removeUnit(id) : controller.removeCategory(id);
    });
  }

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    if (ref.read(catalogEditorAccessProvider).asData?.value != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error) {
      var message = 'No se pudo guardar el cambio. Intenta de nuevo.';
      if (error is FirebaseFunctionsException &&
          error.code == 'failed-precondition') {
        message = error.message ?? 'Un producto usa este elemento.';
      }
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}

typedef _Draft = ({String code, String label, String symbol});

class _DraftController extends Notifier<_Draft> {
  _DraftController(this.initial);
  final _Draft initial;
  @override
  _Draft build() => initial;
  void update({String? code, String? label, String? symbol}) => state = (
    code: code ?? state.code,
    label: label ?? state.label,
    symbol: symbol ?? state.symbol,
  );
}

final _draftProvider = NotifierProvider.autoDispose
    .family<_DraftController, _Draft, _Draft>(_DraftController.new);

class _Editor extends ConsumerWidget {
  const _Editor({
    required this.unit,
    required this.editing,
    required this.initial,
  });
  final bool unit;
  final bool editing;
  final _Draft initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _draftProvider(initial);
    final draft = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final valid =
        draft.label.trim().isNotEmpty &&
        (!unit ||
            (isValidUnitCode(draft.code) && draft.symbol.trim().isNotEmpty));
    return AlertDialog(
      title: Text(
        '${editing ? "Editar" : "Agregar"} ${unit ? "unidad" : "categoría"}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unit)
              TextFormField(
                initialValue: initial.code,
                readOnly: editing,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  helperText: '1 a 10 caracteres: a-z, 0-9 o _',
                ),
                onChanged: (value) => controller.update(code: value),
              ),
            TextFormField(
              initialValue: initial.label,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (value) => controller.update(label: value),
            ),
            if (unit)
              TextFormField(
                initialValue: initial.symbol,
                decoration: const InputDecoration(labelText: 'Símbolo'),
                onChanged: (value) => controller.update(symbol: value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, draft) : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
