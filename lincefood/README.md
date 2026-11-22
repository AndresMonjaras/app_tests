# Lincefood · configuración Firebase

Proyecto Firebase: `lincefood-app` (plan Blaze, sujeto al control de costos del owner).

## Estado

| Componente | Estado |
|---|---|
| Proyecto Firebase | Creado |
| App Android `com.lincefood.app` | Registrada (`apps:create`) |
| Realtime Database | Activada; el alumno probó guardar preferencias de notificación. El catálogo pertenece al flujo B. |
| Auth: correo, Google y GitHub | Configurados y probados manualmente por el alumno en Android. Google y GitHub son los dos proveedores aprobados para la rúbrica. |
| Storage | El código de avatar y reglas están listos; el owner debe confirmar las reglas activas y desplegar las reglas locales para habilitar avatares propios. |
| Reglas RTDB | Versionadas en `firebase/database.rules.json`; no forman parte del despliegue de avatar pendiente. |
| Functions | `synchronizeAvatarEligibility` está implementada y cubierta por pruebas locales. Su despliegue está pendiente del owner por falta de `iam.serviceAccounts.ActAs`. |
| Semilla del menú | Datos ficticios, con variantes de prueba en `firebase/seeds/menu.seed.json`, sin importar |
| Semilla de notificaciones | Textos de ejemplo en español en `firebase/seeds/notificaciones.seed.json`, sin enviar |

## Pendiente del responsable del Plan A

Desplegar `synchronizeAvatarEligibility` y revisar/desplegar las reglas completas de
Storage desde la raíz del repositorio. El intento del alumno no desplegó la
función porque la cuenta no tiene `iam.serviceAccounts.ActAs` sobre la cuenta de servicio de ejecución. Después, probar edición/eliminación
de avatar con una cuenta email verificada y confirmar que las cuentas sociales muestran su foto y carecen de permisos
para editar el avatar. El despliegue de Functions usa Cloud Build y Artifact Registry; el owner
debe vigilar el presupuesto del proyecto Blaze.

## Reglas de seguridad (resumen)

- Denegar por defecto en la raíz.
- Cliente autenticado: lee cafetería, categorías, productos y planes; lee únicamente sus pedidos, su perfil, preferencias, registros de dispositivo e inbox. Solo escribe su perfil, preferencias, registro de dispositivo y la marca `isRead` de sus notificaciones.
- Personal (claim `staff`): lee la cola operativa y los perfiles según la regla; no cambia pedidos, estados ni importes desde el cliente.
- Administrador (claim `admin`): escribe catálogo (`products`, `categories`) y configuración de cafetería. Las reglas validan `available`, `priceCents`, `prepMinutes` y coordenadas.
- El servidor es el único escritor de pedidos, índices, pagos, tokens de recogida, entregas, membresías, cupos e historial de eventos. `payments`, `pickupTokens`, `staffQueue`, `pickupDeliveries`, `memberships` y `pickupSlots` no son legibles por clientes. `orderEvents` solo es legible por personal o administrador.
- Roles de personal y administrador mediante custom claims (`staff`, `admin`), nunca por campos editables por el usuario.

Las reglas de RTDB y las semillas quedan fuera del despliegue del Plan A.
Para publicar las reglas de RTDB en una entrega posterior, revísalas primero y
ejecuta `firebase deploy --only database --project lincefood-app` una vez autorizado.

## Validación local

- Valida `firebase.json`, las reglas RTDB y las semillas JSON con Node.js.
- Las pruebas de reglas en `storage-tests/database.rules.test.js` requieren
  Firebase Database Emulator en `127.0.0.1:9000`.

Para ejecutar el conjunto de emuladores, instala las dependencias de Functions
con Node.js 22 y ejecuta desde la raíz:

```bash
cd functions
npm ci
cd ..
firebase emulators:start --only auth,database,functions,storage --project lincefood-app
```

En otra terminal, desde `app/`, activa el modo de emuladores en Android:

```bash
flutter run --dart-define-from-file=dart_defines.local.json --dart-define=FIREBASE_EMULATORS=true
```

`10.0.2.2` es el host predeterminado desde el emulador de Android Studio. Para
usar un teléfono físico, configura `FIREBASE_EMULATOR_HOST` con la dirección de
la computadora en la red de pruebas. El alumno inició los emuladores, pero la
conexión desde el teléfono quedó pendiente. OAuth con Google o GitHub y las
notificaciones FCM reales se prueban con un proyecto de desarrollo.


## Instalación para colaboradores

Requisitos:

- Flutter estable (el proyecto usa Dart `^3.13.1`) con Android SDK.
- Node.js 22 (las funciones declaran `"node": "22"`).
- Firebase CLI (`npm install -g firebase-tools`), con sesión iniciada en la cuenta del equipo.

Pasos (sustituye `PROJECT_ID` por el ID del proyecto de desarrollo, nunca el de producción):

```bash
git clone <URL_DEL_REPOSITORIO>
cd <DIRECTORIO_DEL_REPOSITORIO>/lincefood

# 1. Configuración de Firebase local (no se versiona)
firebase use PROJECT_ID
cp app/config/firebase.example.json app/dart_defines.local.json
# Completa los valores del proyecto de desarrollo en dart_defines.local.json.
# GOOGLE_SERVER_CLIENT_ID es el ID de cliente web (tipo 3) del proyecto en
# Firebase; sin él Google Sign-In falla en Android. El SHA-1 de tu keystore de
# depuración debe estar registrado en la app Android de Firebase.

# 2. Dependencias de la app
cd app
flutter pub get
flutter analyze
flutter test
cd ..

# 3. Dependencias y pruebas de las funciones
cd functions
npm ci
npm test
```

Archivos locales que no se incluyen en Git:

- `app/dart_defines.local.json` se pasa con `--dart-define-from-file` para
  inicializar Firebase mediante `FirebaseOptions`.
- `app/android/app/google-services.json` es opcional. Gradle aplica el plugin
  de Google Services si el archivo existe.
- `app/android/local.properties` con ruta del SDK Android y clave local de Maps.
- Archivos de servicio de Firebase Admin y cualquier `.env` con claves del servidor.
- Claves de Stripe: solo se usan claves de prueba (`pk_test_` en la app y `sk_test_` en
  el servidor), guardadas en el entorno seguro del servidor, nunca en el repositorio.

Para pruebas de integración en la app (sin servicios reales):

```bash
cd app
flutter test integration_test
```
Las comprobaciones de OAuth, notificaciones push y Stripe Sandbox con servicios
reales requieren la configuración del responsable del proyecto.
