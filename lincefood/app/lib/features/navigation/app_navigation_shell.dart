import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final screens = [
      const CatalogScreen(),
      const OrdersScreen(),
      const CafeteriaLocationScreen(),
      const ProfileScreen(),
    ];
    const destinations = [
      _NavigationDestination(
        label: 'Inicio',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _NavigationDestination(
        label: 'Pedidos',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _NavigationDestination(
        label: 'Mapa',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
      ),
      _NavigationDestination(
        label: 'Perfil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: selected.index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (index) => ref
            .read(navigationControllerProvider.notifier)
            .select(_sections[index]),
        destinations: [
          for (final item in destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
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
  final IconData icon;
  final IconData selectedIcon;
}
