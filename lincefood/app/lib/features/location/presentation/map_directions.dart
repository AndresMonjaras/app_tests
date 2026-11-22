import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/cafeteria_location.dart';

Future<void> openMapDirections(
  BuildContext context,
  CafeteriaLocation location,
) async {
  final destination = location.address.isEmpty
      ? '${location.latitude},${location.longitude}'
      : location.address;
  await Clipboard.setData(ClipboardData(text: destination));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Dirección copiada al portapapeles.')),
  );
}
