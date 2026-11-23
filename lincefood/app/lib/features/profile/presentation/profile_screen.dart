import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
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
                  _ProfileHeader(
                    avatar: ProfileAvatar(
                      radius: 48,
                      photoUrl: photoUrl,
                      preset: selectedPreset,
                    ),
                    name: displayName,
                    email: user.email ?? '',
                    providerLabel: socialProviderLabel,
                    verified: user.emailVerified,
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Tu avatar',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
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
                                        : const Icon(
                                            Icons.add_a_photo_outlined,
                                          ),
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
                                                profileControllerProvider
                                                    .notifier,
                                              )
                                              .seleccionarPreset(
                                                user.uid,
                                                preset,
                                              ),
                                        );
                                      },
                              ),
                            if (presetState.hasError) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'No se pudo cargar el avatar guardado.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Mi cuenta',
                    children: [
                      if (ref.watch(catalogEditorAccessProvider).value == true)
                        _SettingsTile(
                          icon: Icons.admin_panel_settings_outlined,
                          title: ref.watch(adminAccessProvider).value == true
                              ? 'Administración'
                              : 'Productos de cafetería',
                          subtitle: ref.watch(adminAccessProvider).value == true
                              ? 'Productos, precios y permisos del equipo.'
                              : 'Administra el menú y su disponibilidad.',
                          onTap: () =>
                              Navigator.of(context).pushNamed(AppRouter.admin),
                        ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notificaciones',
                        subtitle: 'Configura los avisos de la cafetería.',
                        onTap: () =>
                            Navigator.of(context)
                                .pushNamed(AppRouter.notificationPreferences),
                      ),
                      _SettingsTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Planes de servicio',
                        subtitle: 'Compara reservas de recogida.',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRouter.plans),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Preferencias',
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        title: 'Apariencia',
                        trailing: Semantics(
                          label: 'Apariencia',
                          child: DropdownButton<ThemeMode>(
                            value: themeMode,
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(16),
                            menuMaxHeight: 320,
                            onChanged: preferences.isLoading
                                ? null
                                : (mode) {
                                    if (mode != null) {
                                      unawaited(
                                        _changeTheme(context, ref, mode),
                                      );
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
                      SwitchListTile(
                        secondary: const _IconBadge(icon: Icons.fingerprint),
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Información',
                    children: [
                      _SettingsTile(
                        icon: Icons.location_on_outlined,
                        title: 'Ubicación de la cafetería',
                        subtitle: 'Consulta el punto de recogida.',
                        onTap: () =>
                            Navigator.of(context)
                                .pushNamed(AppRouter.cafeteriaLocation),
                      ),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Aviso de privacidad',
                        subtitle: 'Qué datos usamos y para qué.',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRouter.privacy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_signOut(context, ref)),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                  const SizedBox(height: 8),
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

/// Cabecera con degradado cálido, avatar con aro y datos de la cuenta.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatar,
    required this.name,
    required this.email,
    required this.providerLabel,
    required this.verified,
  });

  final Widget avatar;
  final String name;
  final String email;
  final String providerLabel;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final success = AppTheme.successColor(Theme.of(context).brightness);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -4,
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/images/mojarra/mojarra_sola.png',
                  width: 96,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: avatar,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatusPill(
                        icon: Icons.login_rounded,
                        label: 'Acceso con $providerLabel',
                        color: colors.onPrimaryContainer,
                      ),
                      _StatusPill(
                        icon: verified
                            ? Icons.verified_rounded
                            : Icons.mark_email_unread_outlined,
                        label: verified
                            ? 'Correo verificado'
                            : 'Correo pendiente de verificación',
                        color: verified ? success : colors.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de ajustes: título pequeño y una tarjeta con filas separadas.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 68));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _IconBadge(icon: icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

/// Icono dentro de un cuadro redondeado con el color de la marca.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
    );
  }
}
