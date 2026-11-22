import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cafeteria_location_repository.dart';
import '../domain/cafeteria_location.dart';

final cafeteriaLocationRepositoryProvider =
    Provider<CafeteriaLocationRepository>((ref) {
      return FirebaseCafeteriaLocationRepository(FirebaseDatabase.instance);
    });

final cafeteriaLocationProvider = StreamProvider<CafeteriaLocation?>((ref) {
  return ref.watch(cafeteriaLocationRepositoryProvider).watchLocation();
});

class MapLocationSearchController extends Notifier<bool> {
  @override
  bool build() => false;

  void setSearching(bool searching) => state = searching;
}

final mapLocationSearchProvider =
    NotifierProvider<MapLocationSearchController, bool>(
      MapLocationSearchController.new,
    );
