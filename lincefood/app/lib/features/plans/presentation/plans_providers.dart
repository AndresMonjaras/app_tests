import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/membership_repository.dart';
import '../domain/service_plan.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return RealtimeDatabaseMembershipRepository(FirebaseDatabase.instance);
});

/// Membresía del usuario actual, en tiempo real desde RTDB.
final currentMembershipProvider = StreamProvider.autoDispose<Membership?>((
  ref,
) {
  final uid = ref.watch(authUserProvider).value?.uid;
  if (uid == null) return Stream<Membership?>.value(null);
  return ref.watch(membershipRepositoryProvider).watchMembership(uid);
});

final membershipPricesProvider =
    StreamProvider.autoDispose<Map<String, MembershipPrices>>((ref) {
      final uid = ref.watch(authUserProvider).value?.uid;
      if (uid == null) return Stream.value(const {});
      return FirebaseDatabase.instance
          .ref('membershipPlans')
          .onValue
          .map((event) => membershipPricesFromMap(event.snapshot.value));
    });
