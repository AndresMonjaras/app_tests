import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/presentation/catalog_screen.dart';
import '../location/presentation/cafeteria_location_screen.dart';
import '../orders/presentation/orders_screen.dart';
import '../profile/data/firebase_profile_repository.dart';
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
  static const _railBreakpoint = 768.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(navigationControllerProvider);
    final photoUrl = ref.watch(profilePhotoUrlProvider);
    final screens = [
      CatalogScreen(userPhotoUrl: photoUrl),
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
        icon: _ProfileNavigationAvatar(photoUrl: photoUrl),
        selectedIcon: _ProfileNavigationAvatar(photoUrl: photoUrl),
      ),
    ];

    void onSelected(int index) => ref
        .read(navigationControllerProvider.notifier)
        .select(_sections[index]);

    final useRail = MediaQuery.sizeOf(context).width >= _railBreakpoint;
    final content = IndexedStack(index: selected.index, children: screens);

    return Scaffold(
      // Row con tres slots fijos: el contenido siempre queda en el índice 2,
      // así el IndexedStack no se desmonta al cruzar el breakpoint.
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: selected.index,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: Text(item.label),
                  ),
              ],
            )
          else
            const SizedBox.shrink(),
          if (useRail)
            const VerticalDivider(width: 1)
          else
            const SizedBox.shrink(),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: selected.index,
              onDestinationSelected: onSelected,
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
