String formatMoney(int cents) {
  final isNegative = cents < 0;
  final absoluteCents = cents.abs();
  final pesos = absoluteCents ~/ 100;
  final centavos = (absoluteCents % 100).toString().padLeft(2, '0');
  final sign = isNegative ? '-' : '';

  return '$sign\$$pesos.$centavos';
}
