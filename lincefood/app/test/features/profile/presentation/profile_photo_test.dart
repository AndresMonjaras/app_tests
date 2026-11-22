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
    const facebookPhoto = 'https://example.test/avatar-facebook.jpg';
    final users = StreamController<User?>();
    addTearDown(users.close);
    final container = ProviderContainer(
      overrides: [authUserProvider.overrideWith((ref) => users.stream)],
    );
    addTearDown(container.dispose);
    final urls = StreamController<String?>();
    addTearDown(urls.close);
    final expected = expectLater(
      urls.stream,
      emitsInOrder([customPhoto, googlePhoto, facebookPhoto, null]),
    );
    final subscription = container.listen(
      profilePhotoUrlProvider,
      (_, photoUrl) => urls.add(photoUrl),
    );
    addTearDown(subscription.close);

    users.add(const _User(customPhoto, [_Provider('password')]));
    await container.pump();
    users.add(
      const _User(customPhoto, [
        _Provider('password'),
        _Provider('google.com', googlePhoto),
      ]),
    );
    await container.pump();
    users.add(const _User(null, [_Provider('facebook.com', facebookPhoto)]));
    await container.pump();
    users.add(null);

    await expected;
  });
}

class _User implements User {
  const _User(this.photoURL, this.providerData);

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
