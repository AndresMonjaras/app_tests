import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_audit_section.dart';
import 'admin_catalog_providers.dart';
import 'admin_content_layout.dart';
import 'admin_records_section.dart';
import 'admin_users_section.dart';
import '../data/admin_panel_repository.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminPanelAccessProvider);
    if (access.isLoading || access.value != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel de administración')),
        body: Center(
          child: access.isLoading
              ? const CircularProgressIndicator()
              : const Text('No tienes permiso para entrar al panel.'),
        ),
      );
    }

    final currentUid = ref.watch(adminAuthUserProvider).value?.uid;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de administración'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Usuarios y roles'),
              Tab(text: 'Promociones'),
              Tab(text: 'Becas'),
              Tab(text: 'Auditoría'),
            ],
          ),
        ),
        body: AdminContentLayout(
          child: TabBarView(
            children: [
              AdminUsersSection(currentUid: currentUid),
              const AdminRecordsSection(collection: AdminCollection.promotions),
              const AdminRecordsSection(
                collection: AdminCollection.scholarships,
              ),
              const AdminAuditSection(),
            ],
          ),
        ),
      ),
    );
  }
}
