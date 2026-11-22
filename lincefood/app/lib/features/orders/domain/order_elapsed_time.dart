String formatElapsedTime(DateTime createdAt, {required DateTime now}) {
  final elapsed = now.difference(createdAt);
  final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
  if (minutes < 60) return 'Hace $minutes min';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return 'Hace $hours h';
  return 'Hace $hours h $remainingMinutes min';
}
