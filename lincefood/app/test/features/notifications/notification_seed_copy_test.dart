import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la copia del seed en la app coincide con firebase/seeds', () {
    final appCopy = File('assets/notifications/notificaciones.seed.json')
        .readAsStringSync();
    final source = File('../firebase/seeds/notificaciones.seed.json')
        .readAsStringSync();

    expect(appCopy, source);
  });
}
