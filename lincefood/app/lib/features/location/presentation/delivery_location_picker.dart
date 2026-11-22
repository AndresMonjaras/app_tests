import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/delivery_location.dart';
import 'campus_map.dart';
import 'location_providers.dart';

class DeliveryLocationPicker extends ConsumerStatefulWidget {
  const DeliveryLocationPicker({
    required this.onConfirmed,
    this.mapsEnabled = googleMapsEnabled,
    super.key,
  });

  final ValueChanged<DeliveryLocation> onConfirmed;
  final bool mapsEnabled;

  @override
  ConsumerState<DeliveryLocationPicker> createState() =>
      _DeliveryLocationPickerState();
}

class _DeliveryLocationPickerState
    extends ConsumerState<DeliveryLocationPicker> {
  final _selectionProvider =
      NotifierProvider.autoDispose<
        _DeliverySelection,
        ({LatLng? pin, bool busy})
      >(_DeliverySelection.new);
  final _formKey = GlobalKey<FormState>();
  final _building = TextEditingController();
  final _room = TextEditingController();
  final _references = TextEditingController();
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _building.dispose();
    _room.dispose();
    _references.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mapsEnabled) {
      return const Text(
        'El mapa debe estar habilitado para seleccionar la entrega.',
      );
    }

    final selection = ref.watch(_selectionProvider);
    final area = ref.watch(deliveryCoverageProvider);
    return area.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(deliveryCoverageProvider),
        child: const Text('Reintentar cargar la cobertura de entrega'),
      ),
      data: (coverage) => coverage == null
          ? const Text('La cobertura de entrega aún no está configurada.')
          : _buildForm(coverage, selection),
    );
  }

  Widget _buildForm(
    DeliveryCoverage coverage,
    ({LatLng? pin, bool busy}) selection,
  ) {
    final controller = ref.read(_selectionProvider.notifier);
    final pin = selection.pin;
    final busy = selection.busy;
    final withinCoverage =
        pin != null && coverage.contains(pin.latitude, pin.longitude);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(coverageDescription(coverage)),
          const Text('Toca el mapa para marcar el punto de entrega.'),
          CampusMap(
            center: LatLng(coverage.centerLat, coverage.centerLng),
            coverage: coverage,
            markers: {
              if (pin != null)
                Marker(markerId: const MarkerId('delivery'), position: pin),
            },
            onTap: busy ? null : controller.select,
            onMapCreated: (map) => _mapController = map,
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _useMyLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación'),
          ),
          if (pin != null && !withinCoverage)
            Text(
              'El punto está fuera de la cobertura de entrega.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextFormField(
            controller: _building,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Edificio'),
            maxLength: 100,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Indica el edificio.' : null,
          ),
          TextFormField(
            controller: _room,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Salón'),
            maxLength: 100,
          ),
          TextFormField(
            controller: _references,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Referencias'),
            maxLength: 250,
          ),
          FilledButton(
            onPressed: !busy && withinCoverage ? () => _confirm(pin) : null,
            child: const Text('Confirmar ubicación'),
          ),
        ],
      ),
    );
  }

  Future<void> _useMyLocation() async {
    if (ref.read(_selectionProvider).busy) return;
    ref.read(_selectionProvider.notifier).setBusy(true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Activa la ubicación del dispositivo o marca el punto en el mapa.',
        );
        return;
      }
      if (!mounted) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && mounted) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _showMessage(
          'Sin permiso de ubicación, puedes marcar el punto en el mapa.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final pin = LatLng(position.latitude, position.longitude);
      ref.read(_selectionProvider.notifier).select(pin);
      await _mapController?.animateCamera(CameraUpdate.newLatLng(pin));
    } on TimeoutException {
      _showMessage('No se pudo obtener la ubicación a tiempo.');
    } catch (_) {
      _showMessage('No se pudo usar tu ubicación en este momento.');
    } finally {
      if (mounted) ref.read(_selectionProvider.notifier).setBusy(false);
    }
  }

  Future<void> _confirm(LatLng pin) async {
    if (ref.read(_selectionProvider).busy ||
        _formKey.currentState?.validate() != true) {
      return;
    }
    final location = DeliveryLocation(
      lat: pin.latitude,
      lng: pin.longitude,
      building: _building.text.trim(),
      room: _room.text.trim(),
      references: _references.text.trim(),
    );
    ref.read(_selectionProvider.notifier).setBusy(true);
    bool accepted;
    try {
      accepted = await ref.read(deliveryLocationValidatorProvider)(
        location.lat,
        location.lng,
      );
    } catch (_) {
      _showMessage('No se pudo validar la ubicación. Inténtalo de nuevo.');
      return;
    } finally {
      if (mounted) ref.read(_selectionProvider.notifier).setBusy(false);
    }
    if (!mounted) return;
    if (accepted) {
      widget.onConfirmed(location);
    } else {
      _showMessage('El punto está fuera de la cobertura de entrega vigente.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DeliverySelection extends Notifier<({LatLng? pin, bool busy})> {
  @override
  ({LatLng? pin, bool busy}) build() => (pin: null, busy: false);

  void select(LatLng pin) => state = (pin: pin, busy: state.busy);

  void setBusy(bool busy) => state = (pin: state.pin, busy: busy);
}
