import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_advice_frequency.dart';

abstract interface class LocalAdviceFrequencyStore {
  Future<LocalAdviceFrequency> readFrequency();
  Future<void> writeFrequency(LocalAdviceFrequency frequency);
  Future<int> readNextTipIndex();
  Future<void> writeNextTipIndex(int index);
}

final localAdviceFrequencyStoreProvider = Provider<LocalAdviceFrequencyStore>(
  (ref) => SharedPreferencesLocalAdviceFrequencyStore(),
);

class SharedPreferencesLocalAdviceFrequencyStore
    implements LocalAdviceFrequencyStore {
  static const _frequencyKey = 'local_advice_frequency';
  static const _nextTipIndexKey = 'local_advice_next_tip_index';

  @override
  Future<LocalAdviceFrequency> readFrequency() async {
    final preferences = await SharedPreferences.getInstance();
    final key = preferences.getString(_frequencyKey);
    return LocalAdviceFrequency.values.firstWhere(
      (frequency) => frequency.key == key,
      orElse: () => LocalAdviceFrequency.daily,
    );
  }

  @override
  Future<void> writeFrequency(LocalAdviceFrequency frequency) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_frequencyKey, frequency.key)) {
      throw StateError('No se pudo guardar la frecuencia del recordatorio.');
    }
  }

  @override
  Future<int> readNextTipIndex() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_nextTipIndexKey) ?? 0;
  }

  @override
  Future<void> writeNextTipIndex(int index) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setInt(_nextTipIndexKey, index)) {
      throw StateError('No se pudo guardar el siguiente consejo.');
    }
  }
}
