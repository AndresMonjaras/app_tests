import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Indica si hay una operación de escritura del catálogo en curso.
class AdminCatalogBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Ejecuta la operación y devuelve un mensaje solo si falló.
  Future<String?> perform(Future<void> Function() operation) async {
    if (state) return 'Ya hay un cambio del catálogo en curso.';
    state = true;
    try {
      await operation();
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'No se pudo guardar el cambio en el catálogo.';
    } catch (_) {
      return 'No se pudo guardar el cambio en el catálogo.';
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final adminCatalogBusyProvider =
    NotifierProvider.autoDispose<AdminCatalogBusyController, bool>(
      AdminCatalogBusyController.new,
    );
