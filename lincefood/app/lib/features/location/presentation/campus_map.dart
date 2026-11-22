import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/delivery_location.dart';

const googleMapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

class CampusMap extends StatelessWidget {
  const CampusMap({
    required this.center,
    required this.markers,
    this.coverage,
    this.onTap,
    this.onMapCreated,
    super.key,
  });

  final LatLng center;
  final Set<Marker> markers;
  final DeliveryCoverage? coverage;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<GoogleMapController>? onMapCreated;

  @override
  Widget build(BuildContext context) {
    final area = coverage;
    final color = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 360,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 16),
          markers: markers,
          circles: {
            if (area != null)
              Circle(
                circleId: const CircleId('deliveryCoverage'),
                center: LatLng(area.centerLat, area.centerLng),
                radius: area.radiusMeters,
                strokeColor: color,
                strokeWidth: 2,
                fillColor: color.withValues(alpha: 0.14),
              ),
          },
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          onTap: onTap,
          onMapCreated: onMapCreated,
        ),
      ),
    );
  }
}

String coverageDescription(DeliveryCoverage coverage) {
  final status = coverage.approximate ? ' · Radio provisional' : '';
  return 'Cobertura Campus Pro: ${coverage.radiusMeters.toStringAsFixed(0)} m$status. ${coverage.note}';
}
