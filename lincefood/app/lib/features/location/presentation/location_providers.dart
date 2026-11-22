import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cafeteria_location_repository.dart';
import '../data/delivery_location_repository.dart';
import '../domain/cafeteria_location.dart';
import '../domain/delivery_location.dart';

final cafeteriaLocationRepositoryProvider =
    Provider<CafeteriaLocationRepository>((ref) {
      return FirebaseCafeteriaLocationRepository(FirebaseDatabase.instance);
    });

final cafeteriaLocationProvider = StreamProvider<CafeteriaLocation?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return ref.watch(cafeteriaLocationRepositoryProvider).watchLocation();
});

final deliveryCoverageProvider = StreamProvider<DeliveryCoverage?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return watchDeliveryCoverage(FirebaseDatabase.instance);
});

final deliveryLocationValidatorProvider =
    Provider<Future<bool> Function(double, double)>((ref) {
      return validateDeliveryLocation;
    });
