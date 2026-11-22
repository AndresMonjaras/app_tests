abstract interface class AuthGateway {
  String? get currentEmail;

  Future<void> sendVerificationEmail();

  Future<bool> reloadUser();

  Future<void> signOut();
}
