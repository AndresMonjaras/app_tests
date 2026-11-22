import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/config/firebase_bootstrap_provider.dart';
import 'package:lincefood_app/features/notifications/data/notification_service.dart';

void main() {
  test('no inicializa FCM cuando Firebase no está configurado', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWith(
          (ref) async => FirebaseBootstrapStatus.missing,
        ),
        notificationServiceProvider.overrideWith((ref) {
          throw StateError('El servicio FCM no debía inicializarse.');
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(notificationStartupProvider.future);
  });
}
