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
    this.height = 360,
    this.interactive = true,
    super.key,
  });

  final LatLng center;
  final Set<Marker> markers;
  final DeliveryCoverage? coverage;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final double height;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final area = coverage;
    final color = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
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
          zoomControlsEnabled: interactive,
          zoomGesturesEnabled: interactive,
          scrollGesturesEnabled: interactive,
          rotateGesturesEnabled: interactive,
          tiltGesturesEnabled: interactive,
          liteModeEnabled: !interactive,
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
