import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/preferences/app_preferences_controller.dart';
import 'package:lincefood_app/features/biometrics/biometric_protection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  bool available = true;
  bool result = true;
  int promptCount = 0;

  @override
  Future<bool> get isBiometricAvailable async => available;

  @override
  Future<bool> authenticateForPickupQr() async {
    promptCount++;
    return available && result;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no pide biometría si la preferencia está desactivada', () async {
    final authenticator = _FakeBiometricAuthenticator();
    final service = BiometricQrProtectionService(authenticator);

    expect(await service.authorizeQrReveal(protectionEnabled: false), isTrue);
    expect(authenticator.promptCount, 0);
  });

  test('bloquea el QR cuando la biometría se cancela', () async {
    final authenticator = _FakeBiometricAuthenticator()..result = false;
    final service = BiometricQrProtectionService(authenticator);

    expect(await service.authorizeQrReveal(protectionEnabled: true), isFalse);
    expect(authenticator.promptCount, 1);
  });

  test('no autoriza el QR si el dispositivo no tiene biometría', () async {
    final authenticator = _FakeBiometricAuthenticator()..available = false;
    final service = BiometricQrProtectionService(authenticator);

    expect(
      await service.authorizeQrReveal(protectionEnabled: true),
      isFalse,
    );
    expect(authenticator.promptCount, 1);
  });

  test('persiste la preferencia local de proteger el QR', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appPreferencesProvider.future);

    await container
        .read(appPreferencesProvider.notifier)
        .setPickupQrBiometrics(true);

    expect(
      container
          .read(appPreferencesProvider)
          .requireValue
          .protectPickupQrWithBiometrics,
      isTrue,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'lincefood_protect_pickup_qr',
      ),
      isTrue,
    );
  });
}
