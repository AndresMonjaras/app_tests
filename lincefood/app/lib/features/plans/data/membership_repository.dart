import 'package:firebase_database/firebase_database.dart';

import '../domain/service_plan.dart';

abstract interface class MembershipRepository {
  /// Emite la membresía del usuario o null si no tiene plan registrado.
  Stream<Membership?> watchMembership(String uid);
}

class RealtimeDatabaseMembershipRepository implements MembershipRepository {
  const RealtimeDatabaseMembershipRepository(this._database);

  final FirebaseDatabase _database;

  @override
  Stream<Membership?> watchMembership(String uid) {
    return _database
        .ref('memberships/$uid')
        .onValue
        .map((event) => membershipFromMap(event.snapshot.value));
  }
}

/// Convierte el nodo de RTDB en una membresía. Devuelve null si el dato no es válido.
Membership? membershipFromMap(Object? raw) {
  if (raw is! Map) return null;
  final planId = raw['planId'];
  final status = raw['status'];
  if (planId is! String || status is! String) return null;

  final endRaw = raw['currentPeriodEnd'];
  final end = endRaw is String ? DateTime.tryParse(endRaw) : null;
  return Membership(
    planId: planId,
    status: status,
    currentPeriodEnd: end,
    cancelAtPeriodEnd: raw['cancelAtPeriodEnd'] == true,
  );
}
