import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_roles_repository.dart';
import 'admin_catalog_providers.dart';

@immutable
class AdminRolesFormState {
  const AdminRolesFormState({
    this.admin = false,
    this.enabled = true,
    this.busy = false,
    this.result,
  });

  /// true para administración, false para personal.
  final bool admin;

  /// true concede el permiso; false lo retira.
  final bool enabled;
  final bool busy;
  final String? result;

  AdminRolesFormState copyWith({
    bool? admin,
    bool? enabled,
    bool? busy,
    String? result,
    bool clearResult = false,
  }) {
    return AdminRolesFormState(
      admin: admin ?? this.admin,
      enabled: enabled ?? this.enabled,
      busy: busy ?? this.busy,
      result: clearResult ? null : result ?? this.result,
    );
  }
}

class AdminRolesFormController extends Notifier<AdminRolesFormState> {
  @override
  AdminRolesFormState build() => const AdminRolesFormState();

  void setAdmin(bool value) {
    if (state.busy) return;
    state = state.copyWith(admin: value);
  }

  void setEnabled(bool value) {
    if (state.busy) return;
    state = state.copyWith(enabled: value);
  }

  /// Aplica el permiso elegido. La UI debe pedir confirmación antes.
  Future<void> applyChange(String uid) async {
    final admin = state.admin;
    final enabled = state.enabled;
    state = state.copyWith(busy: true, clearResult: true);
    try {
      await ref
          .read(adminRolesRepositoryProvider)
          .setRole(uid, admin: admin, enabled: enabled);
      if (!ref.mounted) return;
      state = state.copyWith(
        result: 'Permiso actualizado. La cuenta debe volver a iniciar sesión para actualizar su acceso.',
      );
      ref.invalidate(adminAccessProvider);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        result: 'No se pudo cambiar el permiso. Verifica la cuenta y tus permisos e inténtalo de nuevo.',
      );
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}

final adminRolesFormProvider =
    NotifierProvider.autoDispose<AdminRolesFormController, AdminRolesFormState>(
      AdminRolesFormController.new,
    );
