abstract interface class AuthGateway {
  String? get currentEmail;

  Future<void> sendVerificationEmail();

  Future<void> sendPasswordResetEmail(String email);

  Future<bool> reloadUser();

  Future<void> signOut();
}
