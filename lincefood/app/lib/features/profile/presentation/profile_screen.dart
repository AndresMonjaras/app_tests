import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/preferences/app_preferences_controller.dart';
import '../../admin/presentation/admin_catalog_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../biometrics/biometric_protection.dart';
import '../../media/domain/private_avatar_cache.dart';
import '../data/firebase_profile_repository.dart';
import '../domain/avatar_rules.dart';
import '../domain/avatar_preset.dart';
import 'profile_controller.dart';

// Evita que las tarjetas de ajustes se estiren en escritorio.
const _anchoMaximo = 640.0;

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
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando perfil'),
        ),
      ),
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
        final photoUrl = ref.watch(profilePhotoUrlProvider);
        final isEmailAccount = puedeEditarAvatar(providerId);
        final avatarEligibility = ref.watch(avatarEligibilityProvider);
        final canEditAvatar =
            isEmailAccount &&
            user.emailVerified &&
            avatarEligibility.asData?.value == true;
        final presetState = ref.watch(avatarPresetProvider(user.uid));
        // Los avatares predefinidos son solo para cuentas con correo verificado.
        final canPickPreset = isEmailAccount && user.emailVerified;
        final selectedPreset = canPickPreset
            ? AvatarPreset.fromValue(presetState.asData?.value)
            : AvatarPreset.neutro;

        return Scaffold(
          appBar: AppBar(title: const Text('Mi perfil')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _anchoMaximo),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Column(
                      children: [
                        ProfileAvatar(
                          radius: 44,
                          photoUrl: photoUrl,
                          preset: selectedPreset,
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
                                onPressed: avatarState.isBusy
                                    ? null
                                    : () => unawaited(
                                        ref
                                            .read(
                                              profileControllerProvider
                                                  .notifier,
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
                                  photoUrl == null
                                      ? 'Añadir avatar'
                                      : 'Cambiar avatar',
                                ),
                              ),
                              if (photoUrl != null)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                    side: avatarState.isBusy
                                        ? null
                                        : BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                  ),
                                  onPressed: avatarState.isBusy
                                      ? null
                                      : () => unawaited(
                                          ref
                                              .read(
                                                profileControllerProvider
                                                    .notifier,
                                              )
                                              .eliminarAvatar(user.uid),
                                        ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Eliminar avatar'),
                                ),
                            ],
                          ),
                        ],
                        if (isEmailAccount && !user.emailVerified)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Verifica tu correo para cambiar el avatar.',
                            ),
                          ),
                        if (isEmailAccount &&
                            user.emailVerified &&
                            !canEditAvatar)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              avatarEligibility.isLoading
                                  ? 'Verificando permisos para el avatar…'
                                  : 'La edición segura del avatar aún no está habilitada en Firebase.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (!isEmailAccount)
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
                        const SizedBox(height: 12),
                        if (canPickPreset)
                          DropdownButtonFormField<AvatarPreset>(
                            key: ValueKey((
                              selectedPreset,
                              avatarState.errorMessage,
                            )),
                            initialValue: selectedPreset,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(16),
                            menuMaxHeight: 320,
                            decoration: const InputDecoration(
                              labelText: 'Avatar del perfil',
                            ),
                            items: [
                              for (final preset in AvatarPreset.values)
                                DropdownMenuItem(
                                  value: preset,
                                  enabled: preset.available,
                                  child: Text(
                                    preset.available
                                        ? preset.label
                                        : '${preset.label} · Próximamente',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: avatarState.isBusy
                                ? null
                                : (preset) {
                                    if (preset == null) return;
                                    unawaited(
                                      ref
                                          .read(
                                            profileControllerProvider.notifier,
                                          )
                                          .seleccionarPreset(user.uid, preset),
                                    );
                                  },
                          ),
                        if (presetState.hasError) ...[
                          const SizedBox(height: 8),
                          const Text('No se pudo cargar el avatar guardado.'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (ref.watch(catalogEditorAccessProvider).value == true)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        title: Text(
                          ref.watch(adminAccessProvider).value == true
                              ? 'Administración'
                              : 'Productos de cafetería',
                        ),
                        subtitle: Text(
                          ref.watch(adminAccessProvider).value == true
                              ? 'Productos, precios y permisos del equipo.'
                              : 'Administra el menú y su disponibilidad.',
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
                      subtitle: const Text(
                        'Configura los avisos de la cafetería.',
                      ),
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
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.plans),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Aviso de privacidad'),
                      subtitle: const Text('Qué datos usamos y para qué.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.privacy),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Apariencia'),
                      trailing: Semantics(
                        label: 'Apariencia',
                        child: DropdownButton<ThemeMode>(
                          value: themeMode,
                          borderRadius: BorderRadius.circular(16),
                          menuMaxHeight: 320,
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
                          preferences
                              .asData
                              ?.value
                              .protectPickupQrWithBiometrics ??
                          false,
                      onChanged:
                          preferences.isLoading ||
                              biometricAvailability.isLoading
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
            ),
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
      await signOutWithPrivateAvatarCleanup(
        avatarUrl: ref.read(authUserProvider).asData?.value?.photoURL,
        privateAvatarCache: ref.read(privateAvatarCacheProvider),
        signOut: () => ref.read(firebaseAuthServiceProvider).signOut(),
      );
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
