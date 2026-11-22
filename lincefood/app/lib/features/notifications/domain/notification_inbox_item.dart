class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.orderId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final int createdAt;
  final bool isRead;
  final String? orderId;

  static NotificationInboxItem? fromMap(String id, Object? value) {
    if (value is! Map) return null;

    final type = value['type'];
    final title = value['title'];
    final body = value['body'];
    final createdAt = value['createdAt'];
    if (type is! String ||
        title is! String ||
        body is! String ||
        createdAt is! num) {
      return null;
    }

    return NotificationInboxItem(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt.toInt(),
      isRead: value['isRead'] == true,
      orderId: value['orderId'] is String ? value['orderId'] as String : null,
    );
  }
}
