enum LocalAdviceFrequency {
  daily('daily', 'Una vez al día'),
  hourly('hourly', 'Cada hora');

  const LocalAdviceFrequency(this.key, this.label);

  final String key;
  final String label;
}
