import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_frequency_store.dart';
import 'package:lincefood_app/features/notifications/domain/local_advice_frequency.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('usa la frecuencia diaria y el primer consejo por defecto', () async {
    final store = SharedPreferencesLocalAdviceFrequencyStore();

    expect(await store.readFrequency(), LocalAdviceFrequency.daily);
    expect(await store.readNextTipIndex(), 0);
  });

  test('persiste la clave estable y el índice en el dispositivo', () async {
    final store = SharedPreferencesLocalAdviceFrequencyStore();
    await store.writeFrequency(LocalAdviceFrequency.hourly);
    await store.writeNextTipIndex(2);

    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    expect(preferences.getString('local_advice_frequency'), 'hourly');

    final nextStore = SharedPreferencesLocalAdviceFrequencyStore();
    expect(await nextStore.readFrequency(), LocalAdviceFrequency.hourly);
    expect(await nextStore.readNextTipIndex(), 2);

    await nextStore.writeFrequency(LocalAdviceFrequency.daily);
    await preferences.reload();
    expect(preferences.getString('local_advice_frequency'), 'daily');
  });

  test('restablece el valor diario ante una clave desconocida', () async {
    SharedPreferences.setMockInitialValues({
      'local_advice_frequency': 'weekly',
    });

    final store = SharedPreferencesLocalAdviceFrequencyStore();
    expect(await store.readFrequency(), LocalAdviceFrequency.daily);
  });
}
