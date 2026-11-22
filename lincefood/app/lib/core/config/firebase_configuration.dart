import 'package:firebase_core/firebase_core.dart';

class FirebaseConfiguration {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const useEmulators = bool.fromEnvironment('FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  static FirebaseOptions? get options {
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty ||
        databaseUrl.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      authDomain: authDomain.isEmpty ? null : authDomain,
    );
  }
}
