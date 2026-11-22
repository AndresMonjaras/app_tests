import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/data/firebase_auth_service.dart';

class _AuthConflict extends FirebaseAuthException {
  _AuthConflict({required String email, required AuthCredential credential})
    : super(
        code: 'account-exists-with-different-credential',
        email: email,
        credential: credential,
      );
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.signedInUser);

  final _FakeUser signedInUser;
  AuthCredential? conflictCredential;
  String? conflictEmail;
  int signOutCalls = 0;

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    throw _AuthConflict(email: conflictEmail!, credential: conflictCredential!);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _FakeUserCredential(signedInUser);

  @override
  Future<void> setLanguageCode(String? languageCode) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.email);

  @override
  final String email;
  final List<AuthCredential> linkedCredentials = [];
  FirebaseAuthException? linkError;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    final error = linkError;
    if (error != null) throw error;
    linkedCredentials.add(credential);
    return _FakeUserCredential(this);
  }
}

class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User user;
}

void main() {
  final oauthCredential = GoogleAuthProvider.credential(idToken: 'test-token');

  test('vincula GitHub después de acceder con la cuenta existente del mismo correo', () async {
    final user = _FakeUser(' Student@example.test ');
    final auth = _FakeAuth(user)
      ..conflictCredential = oauthCredential
      ..conflictEmail = 'student@example.test';
    final service = FirebaseAuthService(auth);

    await expectLater(
      service.signInWithGitHub(),
      throwsA(isA<_AuthConflict>()),
    );
    await service.signInWithEmail('student@example.test', 'password');

    expect(user.linkedCredentials, [same(oauthCredential)]);
  });

  test(
    'descarta la credencial si la cuenta autenticada tiene otro correo',
    () async {
      final user = _FakeUser('different@example.test');
      final auth = _FakeAuth(user)
        ..conflictCredential = oauthCredential
        ..conflictEmail = 'student@example.test';
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGitHub(),
        throwsA(isA<_AuthConflict>()),
      );
      await service.signInWithEmail('different@example.test', 'password');

      expect(user.linkedCredentials, isEmpty);
    },
  );

  test('permite reintentar el vínculo tras un error temporal de red', () async {
    final user = _FakeUser('student@example.test')
      ..linkError = FirebaseAuthException(code: 'network-request-failed');
    final auth = _FakeAuth(user)
      ..conflictCredential = oauthCredential
      ..conflictEmail = 'student@example.test';
    final service = FirebaseAuthService(auth);

    await expectLater(
      service.signInWithGitHub(),
      throwsA(isA<_AuthConflict>()),
    );
    await expectLater(
      service.signInWithEmail('student@example.test', 'password'),
      throwsA(isA<FirebaseAuthException>()),
    );
    user.linkError = null;
    await service.signInWithEmail('student@example.test', 'password');

    expect(user.linkedCredentials, [same(oauthCredential)]);
  });

  test('cerrar sesión limpia la credencial pendiente', () async {
    final user = _FakeUser('student@example.test');
    final auth = _FakeAuth(user)
      ..conflictCredential = oauthCredential
      ..conflictEmail = 'student@example.test';
    final service = FirebaseAuthService(auth);

    await expectLater(
      service.signInWithGitHub(),
      throwsA(isA<_AuthConflict>()),
    );
    await service.signOut();
    await service.signInWithEmail('student@example.test', 'password');

    expect(auth.signOutCalls, 1);
    expect(user.linkedCredentials, isEmpty);
  });
}
