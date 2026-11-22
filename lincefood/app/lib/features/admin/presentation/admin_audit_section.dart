import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_panel_repository.dart';
import 'admin_panel_state.dart';

typedef _AuditFilter = ({String search, String? action, int limit});

class _AuditFilters extends Notifier<_AuditFilter> {
  @override
  _AuditFilter build() => (search: '', action: null, limit: 100);

  void search(String value) {
    state = (
      search: value.trim().toLowerCase(),
      action: state.action,
      limit: state.limit,
    );
  }

  void action(String? value) {
    state = (search: state.search, action: value, limit: state.limit);
  }

  void loadMore() {
    state = (
      search: state.search,
      action: state.action,
      limit: state.limit + 100,
    );
  }
}

final _filtersProvider =
    NotifierProvider.autoDispose<_AuditFilters, _AuditFilter>(
      _AuditFilters.new,
    );

final _eventsProvider = StreamProvider.autoDispose
    .family<List<AdminRecord>, int>(
      (ref, limit) => ref
          .watch(adminPanelRepositoryProvider)
          .watchRecords(AdminCollection.audit, limit: limit),
    );

const _actions = {
  'listUsers': 'Consultar usuarios',
  'setUserRole': 'Cambiar rol',
  'setUserDisabled': 'Cambiar estado de cuenta',
  'upsertPromotion': 'Guardar promoción',
  'deactivatePromotion': 'Desactivar promoción',
  'upsertScholarship': 'Guardar beca',
  'revokeScholarship': 'Revocar beca',
};

class AdminAuditSection extends ConsumerWidget {
  const AdminAuditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filtersProvider);
    final controller = ref.read(_filtersProvider.notifier);
    final provider = _eventsProvider(filter.limit);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: controller.search,
                decoration: const InputDecoration(
                  labelText: 'Buscar por actor u objetivo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: filter.action,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Acción'),
                items: [
                  const DropdownMenuItem(child: Text('Todas las acciones')),
                  for (final action in _actions.entries)
                    DropdownMenuItem(
                      value: action.key,
                      child: Text(action.value),
                    ),
                ],
                onChanged: controller.action,
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminFeedState(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            content: (events) {
              final visible = events.reversed.where((event) {
                final data = event.data;
                return (filter.action == null ||
                        data['action'] == filter.action) &&
                    '${data['actorUid']} ${data['target']}'
                        .toLowerCase()
                        .contains(filter.search);
              }).toList();
              return ListView(
                children: [
                  if (visible.isEmpty)
                    const ListTile(title: Text('Sin eventos de auditoría.')),
                  for (final event in visible) _AuditTile(event: event),
                  if (events.length >= filter.limit)
                    TextButton(
                      onPressed: controller.loadMore,
                      child: const Text('Ver eventos anteriores'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event});

  final AdminRecord event;

  @override
  Widget build(BuildContext context) {
    final data = event.data;
    const json = JsonEncoder.withIndent('  ');
    return ExpansionTile(
      key: ValueKey(event.id),
      title: Text(_actions[data['action']] ?? '${data['action']}'),
      subtitle: Text(adminDate(context, data['at'])),
      children: [
        ListTile(
          title: const Text('Actor'),
          subtitle: SelectableText('${data['actorUid']}'),
        ),
        ListTile(
          title: const Text('Objetivo'),
          subtitle: SelectableText('${data['target']}'),
        ),
        ListTile(
          title: const Text('Antes'),
          subtitle: SelectableText(json.convert(data['before'])),
        ),
        ListTile(
          title: const Text('Después'),
          subtitle: SelectableText(json.convert(data['after'])),
        ),
      ],
    );
  }
}
