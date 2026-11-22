import 'package:flutter/material.dart';

import '../domain/notification_inbox_item.dart';

class NotificationSection extends StatelessWidget {
  const NotificationSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class NotificationHistoryTile extends StatelessWidget {
  const NotificationHistoryTile({
    required this.item,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final NotificationInboxItem item;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fecha = DateTime.fromMillisecondsSinceEpoch(item.createdAt).toLocal();
    String dosDigitos(int valor) => valor.toString().padLeft(2, '0');
    final timestamp =
        '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year}  '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: colors.primary),
      title: Text(
        item.title,
        style: item.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.body),
          const SizedBox(height: 4),
          Text(
            timestamp,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: item.isRead
          ? null
          : Icon(Icons.circle, size: 10, color: colors.primary),
      onTap: onTap,
    );
  }
}
