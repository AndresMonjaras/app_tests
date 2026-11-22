import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../navigation/auth_gate_screen.dart';
import '../../../core/notifications/firebase_notification_service.dart';
import '../../../core/notifications/notification_providers.dart';
import '../data/firebase_profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const AuthGateScreen(),
      data: (user) {
        if (user == null) return const AuthGateScreen();
        return _ProfileContent(user: user);
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider);
    final avatar = ref.watch(profileAvatarProvider);
    final eligibility = ref.watch(avatarEligibilityProvider);
    final upload = ref.watch(avatarUploadProvider);
    final preferences = ref.watch(appPreferencesProvider).asData?.value;
    final notifications = ref.watch(notificationPreferencesProvider);
    final providerIds = user.providerData
        .map((item) => item.providerId)
        .toSet();
    final providerLabel = providerIds.contains('google.com')
        ? 'Google'
        : providerIds.contains('facebook.com')
        ? 'Facebook'
        : 'Correo electrónico';
    final profileValue = profile.asData?.value;
    final displayName = profileValue?.name.trim().isNotEmpty == true
        ? profileValue!.name
        : user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : 'Estudiante';
    final themeMode = preferences?.themeMode ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _ProfileAvatar(
                      user: user,
                      storedBytes: avatar.asData?.value,
                      size: 104,
                    ),
                    eligibility.asData?.value == true
                        ? IconButton.filled(
                            tooltip: 'Cambiar foto de perfil',
                            onPressed: upload.isLoading
                                ? null
                                : () => ref
                                      .read(avatarUploadProvider.notifier)
                                      .upload(),
                            icon: upload.isLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.edit_outlined),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(user.email ?? ''),
                const SizedBox(height: 4),
                Text('Acceso con $providerLabel'),
                Text(
                  user.emailVerified
                      ? 'Correo verificado'
                      : 'Correo pendiente de verificación',
                ),
                if (avatar.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No se pudo cargar la foto guardada.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (upload.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      upload.error is StateError
                          ? (upload.error! as StateError).message
                          : 'No se pudo actualizar la foto. Revisa Firebase Storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (eligibility.hasError &&
                    providerLabel == 'Correo electrónico')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'La edición de foto requiere que el servicio seguro de Firebase esté configurado.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Apariencia'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setThemeMode(mode);
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
          Text(
            'Avisos generales',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Son canales públicos; no incluyen folios ni datos privados de pedidos.',
          ),
          notifications.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                const Text('No se pudieron cargar tus preferencias de avisos.'),
            data: (values) => Column(
              children: [
                for (final entry in FirebaseNotificationService.topics.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    value: values[entry.key] ?? false,
                    onChanged: (enabled) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .setPreference(entry.key, enabled),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(firebaseAuthServiceProvider).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.storedBytes,
    required this.size,
  });

  final User user;
  final Uint8List? storedBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? image = storedBytes != null
        ? MemoryImage(storedBytes!)
        : user.photoURL != null
        ? NetworkImage(user.photoURL!)
        : null;
    final initials =
        (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim().substring(0, 1)
                : user.email?.trim().isNotEmpty == true
                ? user.email!.trim().substring(0, 1)
                : 'L')
            .toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: image,
      child: image == null
          ? Text(initials, style: TextStyle(fontSize: size / 3))
          : null,
    );
  }
}
