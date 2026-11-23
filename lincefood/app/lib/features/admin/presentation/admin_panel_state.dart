import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_panel_repository.dart';

final adminRecordsProvider = StreamProvider.autoDispose
    .family<List<AdminRecord>, AdminCollection>(
      (ref, collection) =>
          ref.watch(adminPanelRepositoryProvider).watchRecords(collection),
    );

final adminUsersProvider = FutureProvider.autoDispose
    .family<AdminUserPage, AdminUserQuery>(
      (ref, query) => ref.watch(adminPanelRepositoryProvider).listUsers(query),
    );

class AdminMutation extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> run(String operation, Map<String, Object?> data) async {
    if (state) throw StateError('Hay un cambio en curso.');
    state = true;
    try {
      await ref.read(adminPanelRepositoryProvider).change(operation, data);
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final adminMutationProvider = NotifierProvider.autoDispose<AdminMutation, bool>(
  AdminMutation.new,
);

Future<bool> saveAdminChange(
  BuildContext context,
  AdminMutation mutation,
  String operation,
  Map<String, Object?> data,
) async {
  try {
    await mutation.run(operation, data);
    return true;
  } catch (error) {
    if (context.mounted) {
      final message = error is FirebaseFunctionsException
          ? error.message
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'No se pudo guardar el cambio.')),
      );
    }
    return false;
  }
}

Future<bool> confirmAdminChange(
  BuildContext context,
  String title,
  String body,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

String adminDate(BuildContext context, Object? value) {
  if (value is! int) return 'Sin fecha';
  final date = DateTime.fromMillisecondsSinceEpoch(value);
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatCompactDate(date)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class AdminFeedState<T> extends StatelessWidget {
  const AdminFeedState({
    super.key,
    required this.value,
    required this.onRetry,
    required this.content,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) content;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudieron cargar los datos.'),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
    data: content,
  );
}
