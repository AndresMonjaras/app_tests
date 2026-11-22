import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/profile/data/firebase_profile_repository.dart';

void main() {
  test('la foto compartida sigue los cambios de los proveedores', () async {
    const customPhoto = 'https://example.test/avatar-propio.jpg';
    const googlePhoto = 'https://example.test/avatar-google.jpg';
    const githubPhoto = 'https://example.test/avatar-github.jpg';
    const facebookPhoto = 'https://example.test/avatar-facebook.jpg';
    final users = StreamController<User?>();
    addTearDown(users.close);
    var canEditAvatar = false;
    final container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith((ref) => users.stream),
        avatarEligibilityProvider.overrideWith((ref) async => canEditAvatar),
      ],
    );
    addTearDown(container.dispose);
    final photo = container.listen(profilePhotoUrlProvider, (_, _) {});
    addTearDown(photo.close);

    users.add(const _User(customPhoto, [_Provider('password')]));
    await container.pump();
    await container.read(avatarEligibilityProvider.future);
    expect(photo.read(), isNull);

    canEditAvatar = true;
    container.invalidate(avatarEligibilityProvider);
    await container.read(avatarEligibilityProvider.future);
    expect(photo.read(), customPhoto);

    users.add(
      const _User(customPhoto, [
        _Provider('password'),
        _Provider('google.com', googlePhoto),
      ]),
    );
    await container.pump();
    expect(photo.read(), googlePhoto);

    users.add(
      const _User(customPhoto, [
        _Provider('facebook.com', facebookPhoto),
        _Provider('github.com', githubPhoto),
      ]),
    );
    await container.pump();
    expect(photo.read(), githubPhoto);

    users.add(const _User(null, [_Provider('facebook.com', facebookPhoto)]));
    await container.pump();
    expect(photo.read(), facebookPhoto);

    users.add(null);
    await container.pump();
    expect(photo.read(), isNull);
  });
}

class _User implements User {
  const _User(this.photoURL, this.providerData);

  @override
  String get uid => 'perfil-de-prueba';

  @override
  bool get emailVerified => true;

  @override
  final String? photoURL;

  @override
  final List<UserInfo> providerData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Provider implements UserInfo {
  const _Provider(this.providerId, [this.photoURL]);

  @override
  final String providerId;

  @override
  final String? photoURL;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
