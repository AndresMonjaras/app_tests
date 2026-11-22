import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/customer_profile.dart';

class FirebaseProfileRepository {
  FirebaseProfileRepository({
    required this.database,
    required this.storage,
    required this.functions,
    required this.auth,
  });

  final FirebaseDatabase database;
  final FirebaseStorage storage;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  Stream<CustomerProfile?> watchProfile(User user) {
    return database.ref('profiles/${user.uid}').onValue.map((event) {
      final value = event.snapshot.value;
      final fields = value is Map
          ? value.map((key, item) => MapEntry('$key', item))
          : const <String, Object?>{};
      return CustomerProfile(
        id: user.uid,
        name: (fields['displayName'] as String?) ?? user.displayName ?? '',
        email: user.email ?? '',
        provider: user.providerData.map((info) => info.providerId).join(', '),
        providerPhotoUrl: _profilePhotoUrl(user),
        hasCustomPhoto:
            user.providerData.length == 1 &&
            user.providerData.single.providerId == 'password' &&
            user.photoURL != null,
      );
    });
  }

  Future<void> syncDisplayName(User user) async {
    if (auth.currentUser?.uid != user.uid || !user.emailVerified) return;
    final name = user.displayName?.trim();
    if (name == null || name.isEmpty) return;
    final reference = database.ref('profiles/${user.uid}');
    final current = await reference.child('displayName').get();
    if (current.value == name) return;
    await reference.update({
      'displayName': name,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<bool> synchronizeAvatarPermission(User user) async {
    if (!user.emailVerified || auth.currentUser?.uid != user.uid) return false;
    final result = await functions
        .httpsCallable('synchronizeAvatarEligibility')
        .call();
    await user.getIdToken(true);
    final data = result.data;
    return data is Map && data['avatarEditable'] == true;
  }
}

final firebaseProfileRepositoryProvider = Provider<FirebaseProfileRepository>(
  (ref) => FirebaseProfileRepository(
    auth: FirebaseAuth.instance,
    database: FirebaseDatabase.instance,
    storage: FirebaseStorage.instance,
    functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
  ),
);

final profilePhotoUrlProvider = Provider<String?>((ref) {
  final user = ref.watch(authUserProvider).asData?.value;
  return user == null ? null : _profilePhotoUrl(user);
});

String? _profilePhotoUrl(User user) {
  final providers = user.providerData;
  for (final provider in providers) {
    final photoUrl = provider.photoURL?.trim();
    if (provider.providerId != 'password' &&
        photoUrl != null &&
        photoUrl.isNotEmpty) {
      return photoUrl;
    }
  }
  // Al vincular una cuenta social, Firebase puede conservar el avatar de correo.
  if (providers.length > 1 &&
      providers.any((provider) => provider.providerId == 'password')) {
    return null;
  }
  final photoUrl = user.photoURL?.trim();
  return photoUrl == null || photoUrl.isEmpty ? null : photoUrl;
}

final customerProfileProvider = StreamProvider.autoDispose<CustomerProfile?>((
  ref,
) {
  final user = ref.watch(authUserProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(firebaseProfileRepositoryProvider).watchProfile(user);
});

final avatarEligibilityProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Actualizar el token no debe volver a invocar la función.
  final session = ref.watch(
    authUserProvider.select((auth) {
      final user = auth.asData?.value;
      return user == null
          ? null
          : (
              uid: user.uid,
              verified: user.emailVerified,
              providers: user.providerData
                  .map((info) => info.providerId)
                  .join(','),
            );
    }),
  );
  if (session == null || !session.verified) return false;
  final user = ref.read(authUserProvider).asData?.value;
  if (user == null) return false;
  try {
    return await ref
        .read(firebaseProfileRepositoryProvider)
        .synchronizeAvatarPermission(user);
  } catch (_) {
    return false;
  }
});

final profileSyncProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authUserProvider).asData?.value;
  if (user == null || !user.emailVerified) return false;
  try {
    await ref.read(firebaseProfileRepositoryProvider).syncDisplayName(user);
    return true;
  } catch (_) {
    return false;
  }
});
