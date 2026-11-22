import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indica si hay una operación de escritura del catálogo en curso.
class AdminCatalogBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Ejecuta la operación y devuelve true si terminó sin error.
  Future<bool> perform(Future<void> Function() operation) async {
    if (state) return false;
    state = true;
    try {
      await operation();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final adminCatalogBusyProvider =
    NotifierProvider.autoDispose<AdminCatalogBusyController, bool>(
      AdminCatalogBusyController.new,
    );
