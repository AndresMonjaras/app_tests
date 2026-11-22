import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_panel_repository.dart';
import 'admin_panel_state.dart';

class PromotionAdminForm extends ConsumerStatefulWidget {
  const PromotionAdminForm({super.key, this.item});

  final AdminRecord? item;

  @override
  ConsumerState<PromotionAdminForm> createState() => _PromotionAdminFormState();
}

class _PromotionAdminFormState extends ConsumerState<PromotionAdminForm> {
  final _form = GlobalKey<FormState>();

  String _dateInput(Object? value, DateTime fallback) {
    final date = value is int
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : fallback;
    return date.toIso8601String().replaceFirst('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final initial = item?.data ?? {};
    final values = <String, String>{};
    var active = item == null || initial['active'] == true;
    final now = DateTime.now();
    final busy = ref.watch(adminMutationProvider);

    Widget field(
      String key,
      String label,
      String value, {
      int? max,
      bool numeric = false,
    }) {
      return TextFormField(
        initialValue: value,
        enabled: !busy,
        maxLength: max,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onSaved: (text) => values[key] = text?.trim() ?? '',
        validator: (text) {
          final trimmed = text?.trim() ?? '';
          if (key == 'title' && trimmed.isEmpty) return 'Escribe un título.';
          if (key == 'startsAt' || key == 'endsAt') {
            if (DateTime.tryParse(trimmed) == null) {
              return 'Escribe una fecha y hora válidas.';
            }
          }
          if (numeric &&
              trimmed.isNotEmpty &&
              (int.tryParse(trimmed) ?? 0) < 1) {
            return 'Escribe un entero positivo.';
          }
          return null;
        },
      );
    }

    return _AdminFormDialog(
      title: item == null ? 'Nueva promoción' : 'Editar promoción',
      form: _form,
      busy: busy,
      fields: [
        field('title', 'Título', initial['title']?.toString() ?? '', max: 120),
        field(
          'description',
          'Descripción',
          initial['description']?.toString() ?? '',
          max: 1000,
        ),
        field(
          'discountPercent',
          'Descuento porcentual (1 a 90)',
          initial['discountPercent']?.toString() ?? '',
          numeric: true,
        ),
        field(
          'discountCents',
          'Descuento fijo en centavos',
          initial['discountCents']?.toString() ?? '',
          numeric: true,
        ),
        field(
          'startsAt',
          'Inicio (AAAA-MM-DD HH:mm)',
          _dateInput(initial['startsAt'], now),
        ),
        field(
          'endsAt',
          'Fin (AAAA-MM-DD HH:mm)',
          _dateInput(initial['endsAt'], now.add(const Duration(days: 7))),
        ),
        DropdownButtonFormField<bool>(
          isExpanded: true,
          initialValue: active,
          decoration: const InputDecoration(
            labelText: 'Estado de la promoción',
          ),
          items: const [
            DropdownMenuItem(value: true, child: Text('Activa')),
            DropdownMenuItem(value: false, child: Text('Inactiva')),
          ],
          onChanged: busy ? null : (_) {},
          onSaved: (value) => active = value == true,
        ),
      ],
      onSave: () async {
        final percent = int.tryParse(values['discountPercent']!);
        final cents = int.tryParse(values['discountCents']!);
        if ((percent == null) == (cents == null) ||
            (percent != null && percent > 90)) {
          _formError(context, 'Indica un solo descuento válido.');
          return;
        }
        final startsAt = DateTime.parse(values['startsAt']!)
            .millisecondsSinceEpoch;
        final endsAt = DateTime.parse(values['endsAt']!).millisecondsSinceEpoch;
        if (startsAt < 0 || endsAt <= startsAt) {
          _formError(context, 'El fin debe ser posterior al inicio.');
          return;
        }
        if (item?.data['active'] == true && !active) {
          final allowed = await confirmAdminChange(
            context,
            'Desactivar promoción',
            values['title']!,
          );
          if (!allowed || !context.mounted) return;
        }
        await _save(context, ref, 'upsertPromotion', {
          if (item != null) 'id': item.id,
          'title': values['title'],
          'description': values['description'],
          'discountPercent': ?percent,
          'discountCents': ?cents,
          'active': active,
          'startsAt': startsAt,
          'endsAt': endsAt,
        });
      },
    );
  }
}

class ScholarshipAdminForm extends ConsumerStatefulWidget {
  const ScholarshipAdminForm({super.key, this.item});

  final AdminRecord? item;

  @override
  ConsumerState<ScholarshipAdminForm> createState() =>
      _ScholarshipAdminFormState();
}

class _ScholarshipAdminFormState extends ConsumerState<ScholarshipAdminForm> {
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final busy = ref.watch(adminMutationProvider);
    var target = item?.id ?? '';
    var uses = 0;
    return _AdminFormDialog(
      title: item == null ? 'Asignar beca de comida' : 'Editar beca de comida',
      form: _form,
      busy: busy,
      fields: [
        TextFormField(
          initialValue: item?.id,
          enabled: !busy && item == null,
          decoration: const InputDecoration(labelText: 'UID o correo'),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Indica una cuenta.' : null,
          onSaved: (value) => target = value?.trim() ?? '',
        ),
        TextFormField(
          enabled: !busy,
          initialValue: item?.data['remainingUses']?.toString(),
          decoration: const InputDecoration(labelText: 'Usos restantes'),
          keyboardType: TextInputType.number,
          validator: (value) => (int.tryParse(value?.trim() ?? '') ?? -1) < 0
              ? 'Escribe un entero desde cero.'
              : null,
          onSaved: (value) => uses = int.parse(value!.trim()),
        ),
      ],
      onSave: () => _save(context, ref, 'upsertScholarship', {
        if (target.contains('@')) 'email': target else 'uid': target,
        'type': 'meal',
        'remainingUses': uses,
      }),
    );
  }
}

class _AdminFormDialog extends StatelessWidget {
  const _AdminFormDialog({
    required this.title,
    required this.form,
    required this.busy,
    required this.fields,
    required this.onSave,
  });

  final String title;
  final GlobalKey<FormState> form;
  final bool busy;
  final List<Widget> fields;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Form(
        key: form,
        child: SizedBox(
          width: 440,
          child: Column(
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: field,
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  form.currentState!.save();
                  await onSave();
                },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  String action,
  Map<String, Object?> data,
) async {
  final saved = await saveAdminChange(
    context,
    ref.read(adminMutationProvider.notifier),
    action,
    data,
  );
  if (saved && context.mounted) Navigator.of(context).pop();
}

void _formError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
