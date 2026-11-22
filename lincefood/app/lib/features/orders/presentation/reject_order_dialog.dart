import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_record.dart';
import 'order_actions_controller.dart';

class _RejectionNote extends Notifier<String> {
  @override
  String build() => '';

  void update(String note) => state = note;
}

final _rejectionNoteProvider =
    NotifierProvider.autoDispose<_RejectionNote, String>(_RejectionNote.new);

class RejectOrderDialog extends ConsumerWidget {
  const RejectOrderDialog({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(_rejectionNoteProvider);
    final actions = ref.watch(orderActionsProvider);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !actions.isWorking,
      child: AlertDialog(
        title: const Text('Rechazar pedido'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              autofocus: true,
              enabled: !actions.isWorking,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              onChanged: ref.read(_rejectionNoteProvider.notifier).update,
              decoration: const InputDecoration(
                labelText: 'Nota para el estudiante',
                helperText: 'Explica el motivo en al menos 5 caracteres.',
                helperMaxLines: 2,
              ),
            ),
            if (actions.errorMessage != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  actions.errorMessage!,
                  style: TextStyle(color: colors.error),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: actions.isWorking ? null : () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: !actions.isWorking && isValidRejectionReason(note)
                ? () async {
                    if (ref.read(orderActionsProvider).isWorking) return;
                    await ref
                        .read(orderActionsProvider.notifier)
                        .rejectOrder(orderId: orderId, reason: note.trim());
                    if (context.mounted &&
                        ref.read(orderActionsProvider).errorMessage == null) {
                      Navigator.pop(context);
                    }
                  }
                : null,
            child: Text(actions.isWorking ? 'Rechazando…' : 'Rechazar'),
          ),
        ],
      ),
    );
  }
}
