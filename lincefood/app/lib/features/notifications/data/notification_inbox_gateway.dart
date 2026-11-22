import 'package:firebase_database/firebase_database.dart';

import '../domain/notification_inbox_item.dart';

abstract interface class NotificationInboxGateway {
  Stream<List<NotificationInboxItem>> watch(String uid);

  Future<void> markAsRead(String uid, String notificationId);
}

class FirebaseNotificationInboxGateway implements NotificationInboxGateway {
  FirebaseNotificationInboxGateway(this._database);

  final FirebaseDatabase _database;

  @override
  Stream<List<NotificationInboxItem>> watch(String uid) {
    final query = _database
        .ref('notificationInbox/$uid')
        .orderByChild('createdAt')
        .limitToLast(100);
    return query.onValue.map((event) {
      final items = event.snapshot.children
          .map((child) {
            final id = child.key;
            if (id == null) return null;
            return NotificationInboxItem.fromMap(id, child.value);
          })
          .whereType<NotificationInboxItem>()
          .toList();
      items.sort(
        (first, second) => second.createdAt.compareTo(first.createdAt),
      );
      return items;
    });
  }

  @override
  Future<void> markAsRead(String uid, String notificationId) =>
      _database.ref('notificationInbox/$uid/$notificationId/isRead').set(true);
}
