import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../domain/delivery_location.dart';

Stream<DeliveryCoverage?> watchDeliveryCoverage(FirebaseDatabase database) {
  return database
      .ref('deliveryCoverage')
      .onValue
      .map((event) => DeliveryCoverage.tryFrom(event.snapshot.value));
}

Future<bool> validateDeliveryLocation(double lat, double lng) async {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final result = await functions
      .httpsCallable('validateDeliveryLocation')
      .call<Map<String, dynamic>>({'lat': lat, 'lng': lng});
  return result.data['withinCoverage'] == true;
}
