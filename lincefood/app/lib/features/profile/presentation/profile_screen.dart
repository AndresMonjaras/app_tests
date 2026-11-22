import 'dart:async';

import '../../admin/presentation/admin_catalog_providers.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/preferences/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../biometrics/biometric_protection.dart';
import '../data/firebase_profile_repository.dart';
import '../domain/avatar_rules.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final biometricAvailability = ref.watch(biometricAvailabilityProvider);
    final avatarState = ref.watch(profileControllerProvider);
    ref.watch(profileSyncProvider);

    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No pudimos cargar tu perfil.')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('No hay una sesión activa.')),
          );
        }

        final themeMode =
            preferences.asData?.value.themeMode ?? ThemeMode.system;
        final profile = ref.watch(customerProfileProvider).asData?.value;
        final syncedName = profile?.name.trim();
        final displayName = syncedName?.isNotEmpty == true
            ? syncedName!
            : user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Estudiante';
        final providerId = user.providerData.length == 1
            ? user.providerData.single.providerId
            : '';
        final socialProviderLabel = _providerLabel(user.providerData);
        final avatarEligibility = ref.watch(avatarEligibilityProvider);
        final canEditAvatar =
            puedeEditarAvatar(providerId) &&
            user.emailVerified &&
            avatarEligibility.asData?.value == true;

        return Scaffold(
          appBar: AppBar(title: const Text('Mi perfil')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: user.photoURL == null
                          ? null
                          : NetworkImage(user.photoURL!),
                      child: user.photoURL == null
                          ? const Icon(Icons.person_outline, size: 44)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(user.email ?? ''),
                    const SizedBox(height: 4),
                    Text('Acceso con $socialProviderLabel'),
                    const SizedBox(height: 4),
                    Text(
                      user.emailVerified
                          ? 'Correo verificado'
                          : 'Correo pendiente de verificación',
                    ),
                    if (canEditAvatar) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: avatarState.isBusy || !user.emailVerified
                                ? null
                                : () => unawaited(
                                    ref
                                        .read(
                                          profileControllerProvider.notifier,
                                        )
                                        .seleccionarAvatar(user.uid),
                                  ),
                            icon: avatarState.isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_a_photo_outlined),
                            label: Text(
                              user.photoURL == null
                                  ? 'Añadir avatar'
                                  : 'Cambiar avatar',
                            ),
                          ),
                          if (user.photoURL != null)
                            OutlinedButton.icon(
                              onPressed:
                                  avatarState.isBusy || !user.emailVerified
                                  ? null
                                  : () => unawaited(
                                      ref
                                          .read(
                                            profileControllerProvider.notifier,
                                          )
                                          .eliminarAvatar(user.uid),
                                    ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar avatar'),
                            ),
                        ],
                      ),
                    ],
                    if (puedeEditarAvatar(providerId) && !user.emailVerified)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Verifica tu correo para cambiar el avatar.',
                        ),
                      ),
                    if (puedeEditarAvatar(providerId) &&
                        user.emailVerified &&
                        avatarEligibility.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Verificando permisos para el avatar…'),
                      ),
                    if (puedeEditarAvatar(providerId) &&
                        user.emailVerified &&
                        avatarEligibility.asData?.value != true)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'La edición segura del avatar aún no está habilitada en Firebase.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!puedeEditarAvatar(providerId))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'La foto se administra desde $socialProviderLabel.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (avatarState.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        avatarState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (ref.watch(adminAccessProvider).value == true)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Administración'),
                    subtitle: const Text(
                      'Productos, precios y permisos del equipo.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRouter.admin),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Configura los avisos de la cafetería.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRouter.notificationPreferences),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Planes de servicio'),
                  subtitle: const Text('Compara reservas de recogida.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(AppRouter.plans),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Apariencia'),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    onChanged: preferences.isLoading
                        ? null
                        : (mode) {
                            if (mode != null) {
                              unawaited(_changeTheme(context, ref, mode));
                            }
                          },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Sistema'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Claro'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Oscuro'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Proteger QR con biometría'),
                  subtitle: const Text(
                    'Solicita huella o rostro antes de mostrar el código de recogida.',
                  ),
                  value:
                      preferences.asData?.value.protectPickupQrWithBiometrics ??
                      false,
                  onChanged:
                      preferences.isLoading || biometricAvailability.isLoading
                      ? null
                      : (enabled) => unawaited(
                          _setPickupQrProtection(context, ref, enabled),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Ubicación de la cafetería'),
                  subtitle: const Text('Consulta el punto de recogida.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRouter.cafeteriaLocation),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => unawaited(_signOut(context, ref)),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    try {
      await ref.read(appPreferencesProvider.notifier).setThemeMode(mode);
    } catch (_) {
      if (context.mounted) _showError(context, 'No se pudo guardar el tema.');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(firebaseAuthServiceProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'No se pudo cerrar la sesión. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> _setPickupQrProtection(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled &&
        ref.read(biometricAvailabilityProvider).asData?.value != true) {
      _showError(
        context,
        'Configura una huella o rostro en el dispositivo para activar esta protección.',
      );
      return;
    }
    try {
      await ref
          .read(appPreferencesProvider.notifier)
          .setPickupQrBiometrics(enabled);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'No se pudo guardar la protección biométrica.');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _providerLabel(List<UserInfo> providers) {
  if (providers.isEmpty) return 'tu cuenta';
  final labels = providers.map((provider) {
    return switch (provider.providerId) {
      'password' => 'correo y contraseña',
      'google.com' => 'Google',
      'github.com' => 'GitHub',
      'facebook.com' => 'Facebook',
      _ => 'otro proveedor',
    };
  }).toSet();
  return labels.join(' y ');
}
