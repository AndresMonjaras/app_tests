import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import 'admin_catalog_providers.dart';
import 'admin_roles_form_controller.dart';

class AdminRolesPanel extends ConsumerStatefulWidget {
  const AdminRolesPanel({super.key});
  @override
  ConsumerState<AdminRolesPanel> createState() => _AdminRolesPanelState();
}

class _AdminRolesPanelState extends ConsumerState<AdminRolesPanel> {
  final uid = TextEditingController();
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    uid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminRolesFormProvider);
    final controller = ref.read(adminRolesFormProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (ref.watch(adminAccessProvider).value == true)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Panel de administración'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRouter.adminPanel),
          ),
        Text(
          'Equipo y permisos',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Asigna o retira un permiso usando el UID de la cuenta. Personal atiende pedidos; administración gestiona productos y permisos.',
        ),
        const SizedBox(height: 20),
        Form(
          key: form,
          child: TextFormField(
            controller: uid,
            enabled: !state.busy,
            decoration: const InputDecoration(labelText: 'UID de la cuenta'),
            validator: (v) =>
                RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Escribe un UID válido.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<bool>(
          initialValue: state.admin,
          decoration: const InputDecoration(labelText: 'Permiso'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Personal')),
            DropdownMenuItem(value: true, child: Text('Administración')),
          ],
          onChanged: state.busy ? null : (v) => controller.setAdmin(v!),
        ),
        SwitchListTile(
          title: const Text('Conceder permiso'),
          subtitle: Text(
            state.enabled
                ? 'Se agregará este permiso.'
                : 'Se retirará este permiso.',
          ),
          value: state.enabled,
          onChanged: state.busy ? null : controller.setEnabled,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: state.busy ? null : () => _save(state),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: Text(state.busy ? 'Guardando…' : 'Aplicar permiso'),
        ),
        if (state.result != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(state.result!, semanticsLabel: state.result),
          ),
      ],
    );
  }

  Future<void> _save(AdminRolesFormState state) async {
    if (!form.currentState!.validate()) return;
    final target = uid.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio de permiso'),
        content: Text(
          '${state.enabled ? 'Conceder' : 'Retirar'} ${state.admin ? 'administración' : 'personal'} a la cuenta $target?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await ref.read(adminRolesFormProvider.notifier).applyChange(target);
  }
}
