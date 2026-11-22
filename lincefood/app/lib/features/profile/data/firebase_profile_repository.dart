import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.length != 1 || !providers.contains('password')) return false;
    final result = await functions
        .httpsCallable('synchronizeAvatarEligibility')
        .call();
    await user.getIdToken(true);
    final data = result.data;
    return data is Map && data['avatarEditable'] == true;
  }

  Future<Uint8List?> loadAvatar(User user) async {
    if (auth.currentUser?.uid != user.uid) return null;
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.length != 1 || !providers.contains('password')) return null;
    final snapshot = await database
        .ref('profiles/${user.uid}/avatarPath')
        .get();
    final path = snapshot.value;
    final prefix = 'profiles/${user.uid}/avatar/';
    if (path is! String || !path.startsWith(prefix)) return null;
    return storage.ref(path).getData(2 * 1024 * 1024);
  }

  Future<Uint8List?> pickAndUploadAvatar(User user) async {
    if (auth.currentUser?.uid != user.uid || !user.emailVerified) {
      throw StateError('Inicia sesión con una cuenta verificada.');
    }
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.length != 1 || !providers.contains('password')) {
      throw StateError(
        'Solo las cuentas registradas con correo pueden cambiar su avatar.',
      );
    }
    final claims = await user.getIdTokenResult(true);
    if (claims.claims?['avatar_editable'] != true) {
      throw StateError(
        'El permiso seguro para cambiar el avatar todavía no está habilitado.',
      );
    }

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 82,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final contentType = _imageType(bytes);
    if (bytes.isEmpty ||
        bytes.length > 2 * 1024 * 1024 ||
        contentType == null) {
      throw StateError('Elige JPEG, PNG o WebP de hasta 2 MiB.');
    }
    if (auth.currentUser?.uid != user.uid) return null;

    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      _ => 'webp',
    };
    final path =
        'profiles/${user.uid}/avatar/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = storage.ref(path);
    var profileUpdated = false;
    try {
      await file.putData(bytes, SettableMetadata(contentType: contentType));
      if (auth.currentUser?.uid != user.uid) {
        await file.delete();
        return null;
      }
      await database.ref('profiles/${user.uid}').update({
        'avatarPath': path,
        'updatedAt': ServerValue.timestamp,
      });
      profileUpdated = true;
      return bytes;
    } catch (_) {
      if (!profileUpdated) {
        try {
          await file.delete();
        } catch (_) {
          // Limpieza best effort; el flujo principal conserva el error original.
        }
      }
      rethrow;
    }
  }

  String? _imageType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (bytes.length >= png.length &&
        List.generate(
          png.length,
          (index) => bytes[index] == png[index],
        ).every((value) => value)) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
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

final customerProfileProvider = StreamProvider.autoDispose<CustomerProfile?>((
  ref,
) {
  final user = ref.watch(authUserProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(firebaseProfileRepositoryProvider).watchProfile(user);
});

final profileAvatarProvider = FutureProvider.autoDispose<Uint8List?>((ref) {
  final user = ref.watch(authUserProvider).asData?.value;
  if (user == null) return null;
  return ref.watch(firebaseProfileRepositoryProvider).loadAvatar(user);
});

final avatarEligibilityProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authUserProvider).asData?.value;
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

final avatarUploadProvider =
    AsyncNotifierProvider<AvatarUploadController, Uint8List?>(
      AvatarUploadController.new,
    );

class AvatarUploadController extends AsyncNotifier<Uint8List?> {
  @override
  Future<Uint8List?> build() async {
    ref.watch(authUserProvider);
    return null;
  }

  Future<void> upload() async {
    final user = ref.read(firebaseAuthServiceProvider).currentUser;
    if (user == null) return;
    state = const AsyncLoading();
    try {
      final bytes = await ref
          .read(firebaseProfileRepositoryProvider)
          .pickAndUploadAvatar(user);
      state = AsyncData(bytes);
      ref.invalidate(profileAvatarProvider);
      ref.invalidate(customerProfileProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
