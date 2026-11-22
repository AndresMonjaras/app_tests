import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/realtime_orders_repository.dart';
import '../domain/order_record.dart';
import '../domain/orders_repository.dart';
import '../domain/payment_gateway.dart';

final orderAuthUserProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) return Stream<User?>.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

final uidActivoProvider = Provider<String?>((ref) {
  return ref.watch(orderAuthUserProvider).value?.uid;
});

final staffPermissionProvider = _claimPermissionProvider('staff');

final adminPermissionProvider = _claimPermissionProvider('admin');

FutureProvider<bool> _claimPermissionProvider(String claim) {
  return FutureProvider<bool>((ref) async {
    final user = await ref.watch(orderAuthUserProvider.future);
    if (user == null) return false;

    try {
      final token = await user.getIdTokenResult();
      return token.claims?[claim] == true;
    } catch (_) {
      return false;
    }
  });
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  if (Firebase.apps.isEmpty) return RealtimeOrdersRepository();
  try {
    return RealtimeOrdersRepository(database: FirebaseDatabase.instance);
  } on FirebaseException {
    return RealtimeOrdersRepository();
  }
});

final ordersStreamProvider = StreamProvider<List<OrderRecord>>((ref) {
  final uid = ref.watch(uidActivoProvider);
  if (uid == null || uid.isEmpty) return Stream.value(const <OrderRecord>[]);

  return ref.watch(ordersRepositoryProvider).watchOrdersFor(uid);
});

final staffOrdersStreamProvider = StreamProvider<List<OrderRecord>>((ref) {
  final permission = ref.watch(staffPermissionProvider);
  if (!permission.hasValue) return Stream.value(const <OrderRecord>[]);
  if (permission.value != true) {
    return Stream.error(
      StateError('No tienes permiso para consultar los pedidos.'),
    );
  }

  return ref.watch(ordersRepositoryProvider).watchPaidOrdersForStaff();
});

final orderClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    controller.add(DateTime.now());
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  return const _BackendPaymentGatewayPending();
});

class _BackendPaymentGatewayPending implements PaymentGateway {
  const _BackendPaymentGatewayPending();

  @override
  Future<PaymentResult> pay(OrderRecord order) async {
    return const PaymentResult(
      approved: false,
      message: 'El pago estará disponible cuando se conecte el backend.',
    );
  }
}
