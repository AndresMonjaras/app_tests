import 'package:firebase_database/firebase_database.dart';

import '../domain/cafeteria_location.dart';

abstract interface class CafeteriaLocationRepository {
  Stream<CafeteriaLocation?> watchLocation();
}

class FirebaseCafeteriaLocationRepository
    implements CafeteriaLocationRepository {
  const FirebaseCafeteriaLocationRepository(this.database);

  final FirebaseDatabase database;

  @override
  Stream<CafeteriaLocation?> watchLocation() {
    return database
        .ref('cafeteria/location')
        .onValue
        .map((event) => CafeteriaLocation.tryFrom(event.snapshot.value));
  }
}
