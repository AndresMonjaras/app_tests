import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_panel_repository.dart';
import 'admin_panel_state.dart';
import 'admin_record_forms.dart';

typedef _RecordFilter = ({String search, bool? active});

class _RecordFilters extends Notifier<_RecordFilter> {
  @override
  _RecordFilter build() => (search: '', active: null);

  void search(String value) {
    state = (search: value.trim().toLowerCase(), active: state.active);
  }

  void active(bool? value) {
    state = (search: state.search, active: value);
  }
}

final _filters = NotifierProvider.autoDispose
    .family<_RecordFilters, _RecordFilter, AdminCollection>(
      (_) => _RecordFilters(),
    );

class AdminRecordsSection extends ConsumerWidget {
  const AdminRecordsSection({super.key, required this.collection});

  final AdminCollection collection;

  bool get _promotions => collection == AdminCollection.promotions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsProvider = adminRecordsProvider(collection);
    final records = ref.watch(recordsProvider);
    final filter = ref.watch(_filters(collection));
    final controller = ref.read(_filters(collection).notifier);
    final busy = ref.watch(adminMutationProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: controller.search,
                decoration: InputDecoration(
                  labelText: _promotions
                      ? 'Buscar promoción'
                      : 'Buscar por UID',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_promotions)
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<bool>(
                        isExpanded: true,
                        initialValue: filter.active,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(child: Text('Todas')),
                          DropdownMenuItem(value: true, child: Text('Activas')),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Inactivas'),
                          ),
                        ],
                        onChanged: controller.active,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => _edit(context),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _promotions ? 'Nueva promoción' : 'Asignar beca',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: AdminFeedState(
            value: records,
            onRetry: () => ref.invalidate(recordsProvider),
            content: (items) {
              final visible = items.where((item) {
                if (!_promotions) {
                  return item.id.toLowerCase().contains(filter.search);
                }
                return (filter.active == null ||
                        item.data['active'] == filter.active) &&
                    '${item.data['title']} ${item.data['description']}'
                        .toLowerCase()
                        .contains(filter.search);
              }).toList();
              return ListView(
                children: [
                  if (visible.isEmpty)
                    ListTile(
                      title: Text(
                        _promotions ? 'Sin promociones.' : 'Sin becas.',
                      ),
                    ),
                  for (final item in visible) _tile(context, ref, item, busy),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    AdminRecord item,
    bool busy,
  ) {
    final data = item.data;
    final active = data['active'] == true;
    final title = _promotions ? '${data['title']}' : item.id;
    final discount = data['discountPercent'] != null
        ? '${data['discountPercent']} %'
        : '${data['discountCents']} centavos';
    final disable = _promotions ? 'Desactivar promoción' : 'Revocar beca';
    return ListTile(
      title: Text(title),
      isThreeLine: _promotions,
      subtitle: Text(
        _promotions
            ? '${active ? 'Activa' : 'Inactiva'} · $discount\n'
                  '${adminDate(context, data['startsAt'])} a ${adminDate(context, data['endsAt'])}'
            : '${data['remainingUses']} usos de comida · ${adminDate(context, data['updatedAt'])}',
      ),
      trailing: PopupMenuButton<bool>(
        tooltip: 'Acciones de $title',
        enabled: !busy,
        itemBuilder: (_) => [
          const PopupMenuItem(value: true, child: Text('Editar')),
          if (!_promotions || active)
            PopupMenuItem(value: false, child: Text(disable)),
        ],
        onSelected: (editing) async {
          if (editing) {
            _edit(context, item);
            return;
          }
          final allowed = await confirmAdminChange(context, disable, title);
          if (!allowed || !context.mounted) return;
          await saveAdminChange(
            context,
            ref.read(adminMutationProvider.notifier),
            _promotions ? 'deactivatePromotion' : 'revokeScholarship',
            _promotions ? {'id': item.id} : {'uid': item.id},
          );
        },
      ),
    );
  }

  void _edit(BuildContext context, [AdminRecord? item]) {
    showDialog<void>(
      context: context,
      builder: (context) => _promotions
          ? PromotionAdminForm(item: item)
          : ScholarshipAdminForm(item: item),
    );
  }
}
