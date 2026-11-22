import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/media/domain/private_avatar_cache.dart';

class _FakePrivateAvatarCache implements PrivateAvatarCache {
  String? clearedUrl;
  final publicMenuFiles = {'menu/torta/v1.jpg'};

  @override
  Future<void> clear(String? imageUrl) async {
    clearedUrl = imageUrl;
  }
}

void main() {
  test(
    'al cerrar sesión limpia el avatar privado y conserva el caché público',
    () async {
      final privateCache = _FakePrivateAvatarCache();
      var signedOut = false;

      await signOutWithPrivateAvatarCleanup(
        avatarUrl: 'https://example.test/profiles/user/avatar',
        privateAvatarCache: privateCache,
        signOut: () async => signedOut = true,
      );

      expect(
        privateCache.clearedUrl,
        'https://example.test/profiles/user/avatar',
      );
      expect(signedOut, isTrue);
      expect(privateCache.publicMenuFiles, contains('menu/torta/v1.jpg'));
    },
  );

  test('cierra sesión aunque falle la limpieza privada', () async {
    final privateCache = _FailingPrivateAvatarCache();
    var signedOut = false;

    await expectLater(
      signOutWithPrivateAvatarCleanup(
        avatarUrl: 'https://example.test/avatar',
        privateAvatarCache: privateCache,
        signOut: () async => signedOut = true,
      ),
      throwsStateError,
    );
    expect(signedOut, isTrue);
  });
}

class _FailingPrivateAvatarCache implements PrivateAvatarCache {
  @override
  Future<void> clear(String? imageUrl) async => throw StateError('fallo');
}
