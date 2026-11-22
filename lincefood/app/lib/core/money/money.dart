// Formato de pesos mexicanos (MXN) a partir de centavos enteros.
String formatMoney(int cents) {
  final isNegative = cents < 0;
  final absoluteCents = cents.abs();
  final pesos = _groupThousands(absoluteCents ~/ 100);
  final centavos = (absoluteCents % 100).toString().padLeft(2, '0');
  final sign = isNegative ? '-' : '';

  return '$sign\$$pesos.$centavos MXN';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
