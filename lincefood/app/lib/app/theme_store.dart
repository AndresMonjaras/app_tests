import 'theme_preference.dart';

abstract interface class ThemeStore {
  Future<ThemePreference> leer();

  Future<void> guardar(ThemePreference preferencia);
}

class ThemeStoreEnMemoria implements ThemeStore {
  ThemePreference _valor = ThemePreference.sistema;

  ThemePreference get valorActual => _valor;

  @override
  Future<ThemePreference> leer() async => _valor;

  @override
  Future<void> guardar(ThemePreference preferencia) async {
    _valor = preferencia;
  }
}
