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
          action: TextButton.icon(
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (mapsEnabled)
              CampusMap(
                key: ValueKey(position),
                center: position,
                markers: {
                  Marker(
                    markerId: const MarkerId('cafeteria'),
                    position: position,
                    infoWindow: InfoWindow(title: location.label),
                  ),
                },
                coverage: area,
              ),
            if (area != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(coverageDescription(area)),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (location.approximate)
                      const Text('Ubicación aproximada'),
                    if (location.address.isNotEmpty) Text(location.address),
                    if (location.hours.isNotEmpty) Text(location.hours),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => openMapDirections(context, location),
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Cómo llegar'),
                    ),
                  ],
                ),
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
