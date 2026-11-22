const int resendCooldownSeconds = 60;

bool canResendVerification(DateTime? lastSentAt, DateTime now) {
  if (lastSentAt == null) return true;
  return now.difference(lastSentAt).inSeconds >= resendCooldownSeconds;
}

int remainingCooldownSeconds(DateTime? lastSentAt, DateTime now) {
  if (lastSentAt == null) return 0;
  final remaining = resendCooldownSeconds - now.difference(lastSentAt).inSeconds;
  return remaining.clamp(0, resendCooldownSeconds).toInt();
}
