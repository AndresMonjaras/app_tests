import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdminRole {
  superadmin('superadmin', 'Superadministración'),
  cafeteria('cafeteria_staff', 'Personal de cafetería'),
  delivery('delivery_staff', 'Personal de reparto');

  const AdminRole(this.code, this.label);
  final String code;
  final String label;
}

enum AdminCollection {
  promotions('promotions'),
  scholarships('scholarships'),
  audit('adminAudit');

  const AdminCollection(this.path);
  final String path;
}

typedef AdminUserQuery = ({
  String search,
  AdminRole? role,
  bool? disabled,
  String? pageToken,
});

class AdminUser {
  const AdminUser({
    required this.uid,
    this.email,
    this.name,
    this.disabled = false,
    this.roles = const {},
  });

  final String uid;
  final String? email;
  final String? name;
  final bool disabled;
  final Set<AdminRole> roles;
}

typedef AdminUserPage = ({List<AdminUser> users, String? nextPageToken});
typedef AdminRecord = ({String id, Map<String, Object?> data});

abstract interface class AdminPanelRepository {
  Future<AdminUserPage> listUsers(AdminUserQuery query);
  Stream<List<AdminRecord>> watchRecords(
    AdminCollection collection, {
    int? limit,
  });
  Future<void> change(String operation, Map<String, Object?> data);
}

class FirebaseAdminPanelRepository implements AdminPanelRepository {
  FirebaseAdminPanelRepository(this.functions, this.database);

  final FirebaseFunctions functions;
  final FirebaseDatabase database;

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    final result = await functions
        .httpsCallable('listUsers')
        .call<Map<Object?, Object?>>({
          'search': query.search,
          if (query.role != null) 'role': query.role!.code,
          if (query.disabled != null) 'disabled': query.disabled,
          if (query.pageToken != null) 'pageToken': query.pageToken,
        });
    final users = (result.data['users'] as List).map((item) {
      final user = item as Map;
      final roles = user['roles'] as List;
      return AdminUser(
        uid: user['uid'] as String,
        email: user['email'] as String?,
        name: user['displayName'] as String?,
        disabled: user['disabled'] == true,
        roles: AdminRole.values
            .where((role) => roles.contains(role.code))
            .toSet(),
      );
    }).toList();
    return (
      users: users,
      nextPageToken: result.data['nextPageToken'] as String?,
    );
  }

  @override
  Stream<List<AdminRecord>> watchRecords(
    AdminCollection collection, {
    int? limit,
  }) {
    final ref = database.ref(collection.path);
    final query = limit == null ? ref : ref.orderByKey().limitToLast(limit);
    return query.onValue.map(
      (event) => event.snapshot.children
          .where((child) => child.key != null && child.value is Map)
          .map(
            (child) => (
              id: child.key!,
              data: Map<String, Object?>.from(child.value! as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> change(String operation, Map<String, Object?> data) async {
    await functions.httpsCallable(operation).call<Object?>(data);
  }
}

final adminPanelRepositoryProvider = Provider<AdminPanelRepository>(
  (ref) => FirebaseAdminPanelRepository(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseDatabase.instance,
  ),
);
