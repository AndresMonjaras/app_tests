# Lincefood App

Aplicación Flutter para pedidos y recogida en cafetería universitaria. Esta
carpeta contiene el proyecto Android/Flutter; Firebase, Functions, reglas y
Hosting se configuran desde la raíz del repositorio.

## Desarrollo local

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/firebase.dev.json
```

Para configurar el mapa en Android, agrega la clave restringida por paquete y
SHA-1/SHA-256 a `android/local.properties` (Flutter ya crea ese archivo). Usa
[`android/local.properties.example`](android/local.properties.example) como
referencia; añade la línea sin reemplazar las rutas locales del SDK:

```properties
GOOGLE_MAPS_API_KEY=TU_CLAVE_RESTRINGIDA
```

Con Firebase configurado, activa el mapa con
`--dart-define=GOOGLE_MAPS_ENABLED=true`. Sin coordenadas verificadas o sin esa
autorización, se muestra un estado pendiente y la etiqueta/dirección disponible.

La app conserva Riverpod como gestor de estado. No copies un `pubspec.lock` de
otro proyecto; resuelve las dependencias desde esta carpeta.

## Firebase

1. El proyecto de desarrollo documentado es `lincefood-app` y la app Android
   usa `com.lincefood.app`.
2. Copia `config/firebase.example.json` a `config/firebase.dev.json` y completa
   los valores del proyecto autorizado. El archivo local está ignorado.
3. En Firebase Authentication habilita email/contraseña, Google y Facebook;
   para Google registra las huellas SHA correspondientes y para Facebook
   configura App ID y Client Token en Android. Nunca incluyas App Secret.
4. Realtime Database, Storage, FCM y Cloud Functions necesitan configuración
   en la consola. Storage y Functions no están desplegados desde este repo.

Para el emulador Android usa el ejemplo local:

```bash
firebase emulators:start --project demo-lincefood --only auth,database,storage,functions
flutter run --dart-define-from-file=config/firebase.emulator.json --dart-define=FIREBASE_EMULATORS=true
```

El ejemplo de emulador es ficticio y no sirve para acceder a producción. FCM y
los proveedores OAuth se deben validar con un proyecto y dispositivo reales.

## Alcance integrado desde el Plan A

- Gate de onboarding, sesión y verificación de correo.
- Registro, inicio y recuperación por correo; Google y Facebook con Firebase.
- Tema persistente, onboarding interactivo, idioma español y navegación
  adaptable que conserva las pantallas existentes de catálogo, carrito y
  pedidos.
- Perfil RTDB, foto del proveedor social y avatar privado para cuenta de correo
  cuando Storage y la callable segura estén configurados.
- Listener global FCM y preferencias de canales públicos.

Consulta [la auditoría del Plan A](../docs/auditoria_plan_a.md) para límites,
decisiones de migración y verificaciones todavía pendientes.
