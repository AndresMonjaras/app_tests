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

  final period = MembershipPeriod.values.asNameMap()[raw['period']];
  final expiresAt = raw['expiresAt'];
  final legacyEnd = raw['currentPeriodEnd'];
  final end = expiresAt is int
      ? DateTime.fromMillisecondsSinceEpoch(expiresAt, isUtc: true)
      : legacyEnd is String
      ? DateTime.tryParse(legacyEnd)
      : null;
  final applied = raw['appliedPayments'];
  final intentId = raw['paymentIntentId'];
  return Membership(
    planId: planId,
    status: status,
    period: period,
    currentPeriodEnd: end,
    cancelAtPeriodEnd: raw['cancelAtPeriodEnd'] == true,
    appliedPayments: {
      if (applied is Map)
        for (final entry in applied.entries)
          if (entry.key is String && entry.value == true) entry.key as String,
      if (intentId is String) intentId,
    },
  );
}

Map<String, MembershipPrices> membershipPricesFromMap(Object? raw) {
  if (raw is! Map) return const {};
  final plans = <String, MembershipPrices>{};
  for (final plan in servicePlans.where((plan) => plan.isPaid)) {
    final config = raw[plan.id];
    if (config is! Map || config['prices'] is! Map) continue;
    final prices = config['prices'] as Map;
    final amounts = <MembershipPeriod, int>{};
    for (final period in MembershipPeriod.values) {
      final amount = prices[period.name];
      if (amount is int && amount > 0 && amount <= 99999999) {
        amounts[period] = amount;
      }
    }
    plans[plan.id] = MembershipPrices(
      amounts: amounts,
      demo: config['demo'] == true,
    );
  }
  return plans;
}
