import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/cafeteria_location.dart';
import '../domain/delivery_location.dart';
import 'campus_map.dart';
import 'location_providers.dart';
import 'map_directions.dart';

class CafeteriaLocationScreen extends ConsumerWidget {
  const CafeteriaLocationScreen({
    super.key,
    this.mapsEnabled = googleMapsEnabled,
  });

  final bool mapsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(cafeteriaLocationProvider);
    final coverage = mapsEnabled
        ? ref.watch(deliveryCoverageProvider).value
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: location.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Cargando ubicación',
          ),
        ),
        error: (_, _) => _LocationMessage(
          icon: Icons.location_off_outlined,
          title: 'No se pudo cargar la ubicación',
          message: 'Comprueba tu conexión e inténtalo de nuevo.',
          action: OutlinedButton.icon(
            onPressed: () => ref.invalidate(cafeteriaLocationProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
        data: (value) => value == null
            ? const _LocationMessage(
                icon: Icons.location_searching,
                title: 'Ubicación pendiente de confirmar',
                message: 'La cafetería aún no ha publicado su ubicación.',
              )
            : _LocationContent(
                location: value,
                coverage: coverage,
                mapsEnabled: mapsEnabled,
              ),
      ),
    );
  }
}

class _LocationContent extends StatelessWidget {
  const _LocationContent({
    required this.location,
    required this.coverage,
    required this.mapsEnabled,
  });

  final CafeteriaLocation location;
  final DeliveryCoverage? coverage;
  final bool mapsEnabled;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(location.latitude, location.longitude);
    final area = coverage;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [
      if (location.address.isNotEmpty) (Icons.place_outlined, location.address),
      if (location.hours.isNotEmpty) (Icons.schedule_outlined, location.hours),
      if (area != null)
        (
          Icons.delivery_dining_outlined,
          'Entrega hasta ${area.radiusMeters.toStringAsFixed(0)} m'
              '${area.approximate ? ' (provisional)' : ''}',
        ),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: mapsEnabled
                        ? CampusMap(
                            key: ValueKey(position),
                            center: position,
                            height: 150,
                            interactive: false,
                            markers: {
                              Marker(
                                markerId: const MarkerId('cafeteria'),
                                position: position,
                              ),
                            },
                            coverage: area,
                          )
                        : Container(
                            height: 110,
                            color: scheme.primaryContainer,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 44,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location.label, style: theme.textTheme.titleLarge),
                        if (location.approximate)
                          Text(
                            'Ubicación aproximada',
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 8),
                        for (final (icon, text) in details)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 20, color: scheme.primary),
                                const SizedBox(width: 10),
                                Expanded(child: Text(text)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                openMapDirections(context, location),
                            icon: const Icon(Icons.directions_outlined),
                            label: const Text('Cómo llegar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}
