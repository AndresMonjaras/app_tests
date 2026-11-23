import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/cafeteria_map_place.dart';

const _mapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

/// Cafeteria seleccionada en el carrusel y en el mapa (indice en la lista).
class SelectedCafeteriaNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedCafeteriaProvider =
    NotifierProvider.autoDispose<SelectedCafeteriaNotifier, int>(
      SelectedCafeteriaNotifier.new,
    );

// Evita que el mapa y las tarjetas se estiren en escritorio.
const _anchoMaximo = 720.0;

class CafeteriaLocationScreen extends ConsumerStatefulWidget {
  const CafeteriaLocationScreen({super.key, this.mapsEnabled = _mapsEnabled});

  final bool mapsEnabled;

  @override
  ConsumerState<CafeteriaLocationScreen> createState() =>
      _CafeteriaLocationScreenState();
}

class _CafeteriaLocationScreenState
    extends ConsumerState<CafeteriaLocationScreen> {
  final _pages = PageController(viewportFraction: 0.88);
  GoogleMapController? _map;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de cafetería')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoMaximo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _AvailabilityBanner(),
              ),
              Expanded(
                child: widget.mapsEnabled ? _mapWithCarousel() : _setupList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Con Maps activo: mapa a todo lo ancho y tarjetas flotando abajo.
  Widget _mapWithCarousel() {
    final colors = Theme.of(context).colorScheme;
    final selected = ref.watch(selectedCafeteriaProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(20.5417, -100.8170),
                  zoom: 14,
                ),
                markers: {
                  for (var i = 0; i < cafeteriaMapPlaces.length; i++)
                    Marker(
                      markerId: MarkerId(cafeteriaMapPlaces[i].id),
                      position: LatLng(
                        cafeteriaMapPlaces[i].latitude,
                        cafeteriaMapPlaces[i].longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        i == selected
                            ? BitmapDescriptor.hueOrange
                            : BitmapDescriptor.hueRose,
                      ),
                      infoWindow: InfoWindow(title: cafeteriaMapPlaces[i].name),
                      onTap: () => _select(i, moveCards: true),
                    ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) {
                  _map = controller;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_showAll());
                  });
                },
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.surface.withValues(alpha: 0.92),
                  foregroundColor: colors.onSurface,
                ),
                onPressed: () => unawaited(_showAll()),
                icon: const Icon(Icons.zoom_out_map, size: 18),
                label: const Text('Ver todas'),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              height: 190,
              child: PageView.builder(
                controller: _pages,
                itemCount: cafeteriaMapPlaces.length,
                onPageChanged: (index) => _select(index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _CafeteriaCard(
                    place: cafeteriaMapPlaces[index],
                    number: index + 1,
                    selected: index == selected,
                    onShowOnMap: () => _select(index, moveCards: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sin Maps: explicacion amable y la lista de cafeterías para consultar.
  Widget _setupList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        const _MapSetupCard(),
        const SizedBox(height: 12),
        for (var i = 0; i < cafeteriaMapPlaces.length; i++) ...[
          _CafeteriaCard(
            place: cafeteriaMapPlaces[i],
            number: i + 1,
            selected: false,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _select(int index, {bool moveCards = false}) {
    if (!mounted) return;
    ref.read(selectedCafeteriaProvider.notifier).select(index);
    final place = cafeteriaMapPlaces[index];
    unawaited(_moveCamera(place));
    if (moveCards && _pages.hasClients) {
      unawaited(
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _moveCamera(CafeteriaMapPlace place) async {
    try {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16),
      );
    } catch (_) {
      // Si el mapa aún no está listo, la cámara conserva su posición.
    }
  }

  Future<void> _showAll() async {
    try {
      await _map?.animateCamera(
        CameraUpdate.newLatLngBounds(_cafeteriaBounds, 48),
      );
    } catch (_) {
      // El mapa conserva su posición inicial si el controlador no está listo.
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

/// Banner cálido con el aviso de disponibilidad y el cardumen de mojarras.
class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [colors.secondaryContainer, colors.tertiaryContainer],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Lincefood está disponible en las 3 cafeterías del ITC!',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/mojarra/mojarras_cardumen.png',
              width: 84,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CafeteriaCard extends StatelessWidget {
  const _CafeteriaCard({
    required this.place,
    required this.number,
    required this.selected,
    this.onShowOnMap,
  });

  final CafeteriaMapPlace place;
  final int number;
  final bool selected;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final chips = place.details.split(' · ').where((part) => part.isNotEmpty);
    final infoChips = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final part in chips) _InfoChip(text: part)],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected
                    ? colors.primary
                    : colors.primaryContainer,
                child: Text(
                  '$number',
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? colors.onPrimary : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  place.name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // En el carrusel la altura es fija; en la lista se ajusta al contenido.
          if (onShowOnMap != null)
            Expanded(child: SingleChildScrollView(child: infoChips))
          else
            infoChips,
          const SizedBox(height: 8),
          Row(
            children: [
              if (onShowOnMap != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShowOnMap,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Ver en el mapa'),
                  ),
                ),
              if (onShowOnMap != null) const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Copiar coordenadas',
                onPressed: () => _copyCoordinates(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyCoordinates(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: '${place.latitude}, ${place.longitude}'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Coordenadas de ${place.name} copiadas.')),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  IconData get _icon {
    final lower = text.toLowerCase();
    if (lower.contains('abre')) return Icons.schedule;
    if (lower.contains('reseñas') || RegExp(r'^\d\.\d \(').hasMatch(text)) {
      return Icons.star_rounded;
    }
    if (text.contains(r'$')) return Icons.payments_outlined;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _MapSetupCard extends StatelessWidget {
  const _MapSetupCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Image.asset(
                'assets/images/mojarra/mojarra_sola.png',
                height: 72,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.map_outlined, size: 44),
              ),
            ),
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
