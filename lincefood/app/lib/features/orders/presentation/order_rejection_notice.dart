import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_record.dart';
import 'orders_providers.dart';

typedef RejectionNotice = ({String reason, int expiresAt});

final rejectionNoticeProvider = FutureProvider.autoDispose
    .family<RejectionNotice?, String>((ref, orderId) async {
      final uid = ref.watch(uidActivoProvider);
      if (uid == null || uid.isEmpty || Firebase.apps.isEmpty) return null;
      final snapshot = await FirebaseDatabase.instance
          .ref('rejectionNotices/$uid/$orderId')
          .get();
      final data = snapshot.value;
      if (data case {'rejectionReason': String reason, 'expiresAt': int end}) {
        return (reason: reason, expiresAt: end);
      }
      return null;
    }, retry: (_, _) => null);

final _visibleReasonProvider = StreamProvider.autoDispose
    .family<String?, OrderRecord>((ref, order) {
      final uid = ref.watch(uidActivoProvider);
      if (uid == null || uid.isEmpty || order.ownerUid != uid) {
        return Stream.value(null);
      }
      final rejectedAt = order.rejectedAt;
      if (rejectedAt == null) return Stream.value(null);
      final deadline = rejectedAt.add(const Duration(minutes: 10));
      if (!deadline.isAfter(DateTime.now())) return Stream.value(null);

      final result = ref.watch(rejectionNoticeProvider(order.id));
      if (result.isLoading) return Stream.value(null);
      final notice = result.asData?.value;
      final reason = notice?.reason ?? order.rejectionReason;
      if (reason == null || reason.trim().isEmpty) return Stream.value(null);
      var end = deadline.millisecondsSinceEpoch;
      if (notice != null && notice.expiresAt < end) end = notice.expiresAt;

      return Stream.multi((events) {
        final remaining = end - DateTime.now().millisecondsSinceEpoch;
        if (remaining <= 0) {
          events.add(null);
          events.close();
          return;
        }
        events.add(reason);
        // Retira la nota a su hora aun si el ticket sigue abierto.
        final timer = Timer(Duration(milliseconds: remaining), () {
          events.add(null);
          events.close();
        });
        events.onCancel = timer.cancel;
      });
    });

class OrderRejectionNotice extends ConsumerWidget {
  const OrderRejectionNotice({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(_visibleReasonProvider(order)).value;
    if (reason == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        reason,
        semanticsLabel: 'Motivo del rechazo: $reason',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
