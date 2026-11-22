import 'dart:async';

class NotificationMessageListeners<T> {
  NotificationMessageListeners({
    required this.foregroundMessages,
    required this.openedMessages,
    required this.initialMessage,
    required this.onForeground,
    required this.onOpened,
  });

  final Stream<T> foregroundMessages;
  final Stream<T> openedMessages;
  final Future<T?> Function() initialMessage;
  final Future<void> Function(T message) onForeground;
  final Future<void> Function(T message) onOpened;

  StreamSubscription<T>? _foregroundSubscription;
  StreamSubscription<T>? _openedSubscription;
  Future<void>? _startFuture;

  Future<void> start() => _startFuture ??= _startOnce();

  Future<void> _startOnce() async {
    _foregroundSubscription = foregroundMessages.listen(onForeground);
    _openedSubscription = openedMessages.listen(onOpened);
    final message = await initialMessage();
    if (message != null) await onOpened(message);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
