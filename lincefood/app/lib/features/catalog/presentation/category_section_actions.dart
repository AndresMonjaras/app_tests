import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/presentation/admin_catalog_providers.dart';
import '../../admin/presentation/admin_taxonomy_providers.dart';

/// Crear, renombrar y eliminar secciones (categorias) desde Explora el menu.
class CategorySectionActions {
  const CategorySectionActions(this.ref);

  final WidgetRef ref;

  BuildContext get context => ref.context;

  Future<void> create() => _save(null, '');

  Future<void> rename(String id, String currentName) => _save(id, currentName);

  Future<void> _save(String? id, String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(initialName: currentName),
    );
    if (name == null || !context.mounted) return;
    await _run(
      () =>
          ref.read(adminTaxonomyControllerProvider).saveCategory(name, id: id),
      success: id == null ? 'Sección creada.' : 'Sección actualizada.',
    );
  }

  Future<void> delete(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text('¿Eliminar «$label»?'),
        content: const Text(
          'Solo se puede eliminar una sección que no tenga productos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
    await _run(
      () => ref.read(adminTaxonomyControllerProvider).removeCategory(id),
      success: 'Sección eliminada.',
    );
  }

  Future<void> _run(
    Future<Object?> Function() action, {
    required String success,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(catalogEditorAccessProvider).asData?.value != true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar secciones.'),
        ),
      );
      return;
    }
    var message = success;
    try {
      await action();
    } on FirebaseFunctionsException catch (error) {
      message = error.code == 'failed-precondition'
          ? (error.message ??
                'La sección tiene productos y no se puede eliminar.')
          : 'No se pudo guardar el cambio. Intenta de nuevo.';
    } catch (_) {
      message = 'No se pudo guardar el cambio. Intenta de nuevo.';
    }
    if (!messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

// Solo conserva el controlador del campo de texto.
class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _name.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialName.isNotEmpty;
    return AlertDialog(
      icon: Icon(
        editing ? Icons.edit_outlined : Icons.add_circle_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(editing ? 'Renombrar sección' : 'Nueva sección'),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nombre de la sección',
          hintText: 'Ej. Postres',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
