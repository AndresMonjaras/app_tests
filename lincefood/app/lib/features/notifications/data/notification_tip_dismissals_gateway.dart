import 'package:firebase_database/firebase_database.dart';

/// Guarda por usuario los consejos que eliminó, en notificationTipDismissals/{uid}.
abstract interface class NotificationTipDismissalsGateway {
  Stream<Set<String>> watch(String uid);

  Future<void> dismiss(String uid, String tipId);
}

class FirebaseNotificationTipDismissalsGateway
    implements NotificationTipDismissalsGateway {
  FirebaseNotificationTipDismissalsGateway(this._database);

  final FirebaseDatabase _database;

  @override
  Stream<Set<String>> watch(String uid) {
    return _database.ref('notificationTipDismissals/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <String>{};
      return {
        for (final entry in value.entries)
          if (entry.key is String && entry.value == true) entry.key as String,
      };
    });
  }

  @override
  Future<void> dismiss(String uid, String tipId) =>
      _database.ref('notificationTipDismissals/$uid/$tipId').set(true);
}
