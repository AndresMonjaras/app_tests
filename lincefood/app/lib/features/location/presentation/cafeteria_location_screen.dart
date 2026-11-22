import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/cafeteria_location.dart';
import 'location_providers.dart';

const _mapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

class CafeteriaLocationScreen extends ConsumerStatefulWidget {
  const CafeteriaLocationScreen({super.key, this.mapsEnabled = _mapsEnabled});

  final bool mapsEnabled;

  @override
  ConsumerState<CafeteriaLocationScreen> createState() =>
      _CafeteriaLocationScreenState();
}

class _CafeteriaLocationScreenState
    extends ConsumerState<CafeteriaLocationScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(cafeteriaLocationProvider);
    final findingMe = ref.watch(mapLocationSearchProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de cafetería')),
      body: location.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                message: 'La cafetería aún no ha publicado coordenadas verificadas por el campus.',
              )
            : _LocationContent(
                location: value,
                mapsEnabled: widget.mapsEnabled,
                findingMe: findingMe,
                onMapCreated: (controller) => _mapController = controller,
                onShowMyLocation: _showMyLocation,
              ),
      ),
    );
  }

  Future<void> _showMyLocation() async {
    if (ref.read(mapLocationSearchProvider)) return;
    ref.read(mapLocationSearchProvider.notifier).setSearching(true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Activa la ubicación del dispositivo para centrar el mapa.',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Sin permiso de ubicación, el mapa de la cafetería sigue disponible.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } on TimeoutException {
      _showMessage('No se pudo obtener la ubicación a tiempo.');
    } catch (_) {
      _showMessage('No se pudo usar tu ubicación en este momento.');
    } finally {
      if (mounted) {
        ref.read(mapLocationSearchProvider.notifier).setSearching(false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LocationContent extends StatelessWidget {
  const _LocationContent({
    required this.location,
    required this.mapsEnabled,
    required this.findingMe,
    required this.onMapCreated,
    required this.onShowMyLocation,
  });

  final CafeteriaLocation location;
  final bool mapsEnabled;
  final bool findingMe;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onShowMyLocation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mapsEnabled)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 360,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(location.latitude, location.longitude),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('cafeteria'),
                    position: LatLng(location.latitude, location.longitude),
                    infoWindow: InfoWindow(
                      title: location.label,
                      snippet: location.address.isEmpty
                          ? 'Punto de recogida'
                          : location.address,
                    ),
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                onMapCreated: onMapCreated,
              ),
            ),
          )
        else
          _MapSetupCard(),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(location.label),
            subtitle: Text(
              location.address.isEmpty
                  ? 'Punto de recogida de la cafetería universitaria.'
                  : location.address,
            ),
          ),
        ),
        if (mapsEnabled) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: findingMe ? null : onShowMyLocation,
            icon: findingMe
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: const Text('Centrar en mi ubicación'),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'El permiso de ubicación es opcional y solo se solicita al centrar el mapa.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text('Mapa: Google Maps', style: Theme.of(context).textTheme.bodySmall),
      ],
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
