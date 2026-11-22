import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_elapsed_time.dart';

void main() {
  test('calcula minutos transcurridos con la hora recibida', () {
    final createdAt = DateTime.utc(2026, 11, 22, 12);
    final now = DateTime.utc(2026, 11, 22, 12, 12, 59);

    expect(formatElapsedTime(createdAt, now: now), 'Hace 12 min');
  });

  test('no muestra tiempo negativo si el reloj está antes de la creación', () {
    final createdAt = DateTime.utc(2026, 11, 22, 12);
    final now = DateTime.utc(2026, 11, 22, 11, 59);

    expect(formatElapsedTime(createdAt, now: now), 'Hace 0 min');
  });
}
