import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_controller.dart';
import '../catalog/presentation/catalog_screen.dart';
import '../location/presentation/cafeteria_location_screen.dart';
import '../orders/presentation/orders_screen.dart';
import '../profile/presentation/profile_screen.dart';

enum AppSection { home, orders, map, profile }

class NavigationController extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.home;

  void select(AppSection section) => state = section;
}

final navigationControllerProvider =
    NotifierProvider<NavigationController, AppSection>(
      NavigationController.new,
    );

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({super.key});

  static const _sections = AppSection.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(navigationControllerProvider);
    final authUser = ref.watch(authUserProvider).asData?.value;
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 840;
    final screens = [
      CatalogScreen(userPhotoUrl: authUser?.photoURL),
      const OrdersScreen(),
      const CafeteriaLocationScreen(),
      const ProfileScreen(),
    ];
    final destinations = [
      const _NavigationDestination(
        label: 'Inicio',
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
      ),
      const _NavigationDestination(
        label: 'Pedidos',
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
      ),
      const _NavigationDestination(
        label: 'Mapa',
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
      ),
      _NavigationDestination(
        label: 'Perfil',
        icon: _ProfileNavigationAvatar(photoUrl: authUser?.photoURL),
        selectedIcon: _ProfileNavigationAvatar(photoUrl: authUser?.photoURL),
      ),
    ];

    final body = IndexedStack(index: selected.index, children: screens);
    return Scaffold(
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selected.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) => ref
                      .read(navigationControllerProvider.notifier)
                      .select(_sections[index]),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: selected.index,
              onDestinationSelected: (index) => ref
                  .read(navigationControllerProvider.notifier)
                  .select(_sections[index]),
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: item.label,
                  ),
              ],
            ),
      floatingActionButton: selected == AppSection.home
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed('/cart'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Carrito'),
            )
          : null,
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

class _ProfileNavigationAvatar extends StatelessWidget {
  const _ProfileNavigationAvatar({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return const Icon(Icons.person_outline);
    }
    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
      ),
    );
  }
}
