abstract interface class AuthGateway {
  String? get currentEmail;

  String? get currentUid;

  Future<void> sendVerificationEmail();

  Future<bool> reloadUser();

  Future<void> signOut();
}
