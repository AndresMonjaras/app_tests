import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_media_storage.dart';
import '../domain/media_storage.dart';

final mediaStorageProvider = Provider<MediaStorage>((ref) {
  return FirebaseMediaStorage();
});
