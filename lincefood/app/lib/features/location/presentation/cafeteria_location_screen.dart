import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/cafeteria_map_place.dart';

const _mapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

// Evita que el mapa y la tarjeta se estiren en escritorio.
const _anchoMaximo = 720.0;

class CafeteriaLocationScreen extends StatefulWidget {
  const CafeteriaLocationScreen({super.key, this.mapsEnabled = _mapsEnabled});

  final bool mapsEnabled;

  @override
  State<CafeteriaLocationScreen> createState() =>
      _CafeteriaLocationScreenState();
}

class _CafeteriaLocationScreenState extends State<CafeteriaLocationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de cafetería')),
      body: _CafeteriaLocationsContent(
        mapsEnabled: widget.mapsEnabled,
        onMapCreated: _onMapCreated,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_centerCafeterias(controller));
    });
  }

  Future<void> _centerCafeterias(GoogleMapController controller) async {
    try {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(_cafeteriaBounds, 32),
      );
    } catch (_) {
      // El mapa conserva su posición inicial si el controlador aún no está listo.
    }
  }

  LatLngBounds get _cafeteriaBounds {
    final latitudes = cafeteriaMapPlaces.map((place) => place.latitude);
    final longitudes = cafeteriaMapPlaces.map((place) => place.longitude);
    final south = latitudes.reduce((a, b) => a < b ? a : b);
    final north = latitudes.reduce((a, b) => a > b ? a : b);
    final west = longitudes.reduce((a, b) => a < b ? a : b);
    final east = longitudes.reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }
}

class _CafeteriaLocationsContent extends StatelessWidget {
  const _CafeteriaLocationsContent({
    required this.mapsEnabled,
    required this.onMapCreated,
  });

  final bool mapsEnabled;
  final ValueChanged<GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _anchoMaximo,
              maxHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: mapsEnabled
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: const LatLng(20.5417, -100.8170),
                                zoom: 14,
                              ),
                              markers: {
                                for (final place in cafeteriaMapPlaces)
                                  Marker(
                                    markerId: MarkerId(place.id),
                                    position: LatLng(
                                      place.latitude,
                                      place.longitude,
                                    ),
                                    infoWindow: InfoWindow(
                                      title: place.name,
                                      snippet: place.details,
                                    ),
                                  ),
                              },
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              scrollGesturesEnabled: true,
                              onMapCreated: onMapCreated,
                            ),
                          )
                        : const _MapSetupCard(),
                  ),
                  const SizedBox(height: 8),
                  const _CafeteriaAvailabilityCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CafeteriaAvailabilityCard extends StatelessWidget {
  const _CafeteriaAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '¡Lincefood está disponible en las 3 cafeterías del ITC!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSetupCard extends StatelessWidget {
  const _MapSetupCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.map_outlined, size: 44),
            const SizedBox(height: 12),
            Text(
              'Mapa pendiente de configuración',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando se autorice la clave de Maps y se configure en este dispositivo, aquí aparecerá el mapa nativo.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
