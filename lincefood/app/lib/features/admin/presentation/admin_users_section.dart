import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../data/admin_panel_repository.dart';
import 'admin_panel_state.dart';

class _UsersQuery extends Notifier<AdminUserQuery> {
  @override
  AdminUserQuery build() =>
      (search: '', role: null, disabled: null, pageToken: null);

  void search(String value) {
    state = (
      search: value.trim(),
      role: state.role,
      disabled: state.disabled,
      pageToken: null,
    );
  }

  void filterRole(AdminRole? value) {
    state = (
      search: state.search,
      role: value,
      disabled: state.disabled,
      pageToken: null,
    );
  }

  void filterStatus(bool? value) {
    state = (
      search: state.search,
      role: state.role,
      disabled: value,
      pageToken: null,
    );
  }

  void page(String? token) {
    state = (
      search: state.search,
      role: state.role,
      disabled: state.disabled,
      pageToken: token,
    );
  }
}

final _usersQueryProvider =
    NotifierProvider.autoDispose<_UsersQuery, AdminUserQuery>(_UsersQuery.new);

class AdminUsersSection extends ConsumerStatefulWidget {
  const AdminUsersSection({super.key, this.currentUid});

  final String? currentUid;

  @override
  ConsumerState<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends ConsumerState<AdminUsersSection> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_usersQueryProvider);
    final controller = ref.read(_usersQueryProvider.notifier);
    final provider = adminUsersProvider(query);
    final users = ref.watch(provider);
    final busy = ref.watch(adminMutationProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextFormField(
                controller: _search,
                maxLength: 254,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: controller.search,
                decoration: InputDecoration(
                  labelText: 'Buscar por correo o nombre',
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: 'Buscar usuarios',
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      controller.search(_search.text);
                    },
                    icon: const Icon(Icons.search),
                  ),
                ),
                onChanged: (value) {
                  if (value.isEmpty) controller.search('');
                },
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 222,
                    child: DropdownButtonFormField<AdminRole>(
                      initialValue: query.role,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: [
                        const DropdownMenuItem(child: Text('Todos los roles')),
                        for (final role in AdminRole.values)
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                      ],
                      onChanged: controller.filterRole,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<bool>(
                      isExpanded: true,
                      initialValue: query.disabled,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(child: Text('Todos')),
                        DropdownMenuItem(value: false, child: Text('Activas')),
                        DropdownMenuItem(
                          value: true,
                          child: Text('Deshabilitadas'),
                        ),
                      ],
                      onChanged: controller.filterStatus,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: AdminFeedState(
            value: users,
            onRetry: () => ref.invalidate(provider),
            content: (page) => ListView(
              children: [
                if (page.users.isEmpty)
                  const ListTile(
                    title: Text('Sin coincidencias en esta página.'),
                  ),
                for (final user in page.users)
                  _userTile(context, ref, user, busy, provider),
                if (query.pageToken != null || page.nextPageToken != null)
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      if (query.pageToken != null)
                        OutlinedButton(
                          onPressed: busy ? null : () => controller.page(null),
                          child: const Text('Primera página'),
                        ),
                      if (page.nextPageToken != null)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => controller.page(page.nextPageToken),
                          child: const Text('Siguiente página'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _userTile(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
    bool busy,
    FutureProvider<AdminUserPage> provider,
  ) {
    final name = user.name ?? user.email ?? user.uid;
    final roles = user.roles.map((role) => role.label).join(', ');
    final subtitle = [
      if (user.email != null && user.email != name) user.email!,
      if (user.disabled) 'Cuenta deshabilitada',
      if (roles.isNotEmpty) roles,
    ].join('\n');
    final ownAccount = user.uid == widget.currentUid;

    return ListTile(
      title: Text(name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: PopupMenuButton<String>(
        popUpAnimationStyle: AppTheme.popupMenuAnimationStyle,
        tooltip: 'Acciones de $name',
        enabled: !busy,
        itemBuilder: (_) => [
          for (final role in AdminRole.values)
            PopupMenuItem(
              value: role.code,
              enabled:
                  !(role == AdminRole.superadmin &&
                      ownAccount &&
                      user.roles.contains(role)),
              child: Text(
                '${user.roles.contains(role) ? 'Retirar' : 'Conceder'} ${role.label}',
              ),
            ),
          PopupMenuItem(
            value: 'account',
            enabled: !ownAccount,
            child: Text(
              user.disabled ? 'Habilitar cuenta' : 'Deshabilitar cuenta',
            ),
          ),
        ],
        onSelected: (action) async {
          final mutation = ref.read(adminMutationProvider.notifier);
          final changed = await _changeUser(
            context,
            mutation,
            user,
            name,
            action,
          );
          if (changed && context.mounted) ref.invalidate(provider);
        },
      ),
    );
  }

  Future<bool> _changeUser(
    BuildContext context,
    AdminMutation mutation,
    AdminUser user,
    String name,
    String action,
  ) async {
    if (action == 'account') {
      final title = user.disabled ? 'Habilitar cuenta' : 'Deshabilitar cuenta';
      final allowed = await confirmAdminChange(context, title, name);
      if (!allowed || !context.mounted) return false;
      return saveAdminChange(context, mutation, 'setUserDisabled', {
        'uid': user.uid,
        'disabled': !user.disabled,
      });
    }
    final role = AdminRole.values.firstWhere((role) => role.code == action);
    final enabled = !user.roles.contains(role);
    final title = '${enabled ? 'Conceder' : 'Retirar'} ${role.label}';
    final allowed = await confirmAdminChange(context, title, name);
    if (!allowed || !context.mounted) return false;
    return saveAdminChange(context, mutation, 'setUserRole', {
      'uid': user.uid,
      'role': role.code,
      'enabled': enabled,
    });
  }
}
