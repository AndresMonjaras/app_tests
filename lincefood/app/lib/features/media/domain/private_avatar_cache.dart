import 'package:flutter/painting.dart';

abstract interface class PrivateAvatarCache {
  Future<void> clear(String? imageUrl);
}

class FlutterPrivateAvatarCache implements PrivateAvatarCache {
  @override
  Future<void> clear(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    await NetworkImage(imageUrl).evict();
  }
}

/// Cierra la sesión aunque falle la limpieza del avatar privado.
Future<void> signOutWithPrivateAvatarCleanup({
  required String? avatarUrl,
  required PrivateAvatarCache privateAvatarCache,
  required Future<void> Function() signOut,
}) async {
  try {
    await privateAvatarCache.clear(avatarUrl);
  } finally {
    await signOut();
  }
}
