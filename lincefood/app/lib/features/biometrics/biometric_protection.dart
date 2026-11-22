import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/preferences/app_preferences_controller.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> get isBiometricAvailable;

  Future<bool> authenticateForPickupQr();
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator(this._authentication);

  final LocalAuthentication _authentication;

  @override
  Future<bool> get isBiometricAvailable async {
    try {
      if (!await _authentication.isDeviceSupported() ||
          !await _authentication.canCheckBiometrics) {
        return false;
      }
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticateForPickupQr() async {
    if (!await isBiometricAvailable) return false;
    try {
      return await _authentication.authenticate(
        localizedReason:
            'Confirma tu identidad para mostrar el QR de recogida.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

class BiometricQrProtectionService {
  const BiometricQrProtectionService(this.authenticator);

  final BiometricAuthenticator authenticator;

  Future<bool> authorizeQrReveal({required bool protectionEnabled}) async {
    if (!protectionEnabled) return true;
    return authenticator.authenticateForPickupQr();
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) {
  return LocalBiometricAuthenticator(LocalAuthentication());
});

final biometricAvailabilityProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricAuthenticatorProvider).isBiometricAvailable;
});

final biometricQrProtectionServiceProvider =
    Provider<BiometricQrProtectionService>((ref) {
      return BiometricQrProtectionService(
        ref.watch(biometricAuthenticatorProvider),
      );
    });

final protectPickupQrProvider = Provider<bool>((ref) {
  return ref
          .watch(appPreferencesProvider)
          .asData
          ?.value
          .protectPickupQrWithBiometrics ??
      false;
});
