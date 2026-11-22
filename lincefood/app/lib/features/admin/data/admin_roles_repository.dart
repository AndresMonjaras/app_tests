import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AdminRolesRepository {
  Future<void> setRole(
    String uid, {
    required bool admin,
    required bool enabled,
  });
}

class CallableAdminRolesRepository implements AdminRolesRepository {
  CallableAdminRolesRepository(this.functions);
  final FirebaseFunctions functions;

  @override
  Future<void> setRole(
    String uid, {
    required bool admin,
    required bool enabled,
  }) async {
    await functions.httpsCallable('setUserRole').call<Object?>({
      'uid': uid,
      'role': admin ? 'superadmin' : 'cafeteria_staff',
      'enabled': enabled,
    });
  }
}

final adminRolesRepositoryProvider = Provider<AdminRolesRepository>(
  (ref) => CallableAdminRolesRepository(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  ),
);
