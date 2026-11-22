import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/location/presentation/cafeteria_location_screen.dart';

enum AppSection { catalog, orders, location, profile }

class NavigationController extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.catalog;

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
    final selectedIndex = selected.index;
    final screens = [
      const CatalogScreen(),
      const OrdersScreen(),
      const CafeteriaLocationScreen(),
      const ProfileScreen(),
    ];
    final destinations = const [
      _NavigationDestination(
        label: 'Menú',
        icon: Icons.restaurant_menu_outlined,
        selectedIcon: Icons.restaurant_menu,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) => ref
                      .read(navigationControllerProvider.notifier)
                      .select(_sections[index]),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: selectedIndex, children: screens),
                ),
              ],
            ),
            floatingActionButton: _cartButton(context, selected),
          );
        }

        return Scaffold(
          body: IndexedStack(index: selectedIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
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
          floatingActionButton: _cartButton(context, selected),
        );
      },
    );
  }

  Widget? _cartButton(BuildContext context, AppSection selected) {
    if (selected != AppSection.catalog) return null;
    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).pushNamed('/cart'),
      icon: const Icon(Icons.shopping_bag_outlined),
      label: const Text('Carrito'),
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
