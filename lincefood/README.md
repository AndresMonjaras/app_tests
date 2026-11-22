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
| Functions | `synchronizeAvatarEligibility` tiene 64 pruebas locales aprobadas; el despliegue está pendiente del owner por falta de `iam.serviceAccounts.ActAs`. |
| Semilla del menú | Datos ficticios, con variantes de prueba en `firebase/seeds/menu.seed.json`, sin importar |
| Semilla de notificaciones | Textos de ejemplo en español en `firebase/seeds/notificaciones.seed.json`, sin enviar |

## Único pendiente de A para el owner

Desplegar `synchronizeAvatarEligibility` y revisar/desplegar las reglas completas de
Storage desde la raíz del repositorio. El intento del alumno no desplegó la
función porque la cuenta no tiene `iam.serviceAccounts.ActAs` en
`lincefood-app@appspot.gserviceaccount.com`. Después, probar edición/eliminación
de avatar con una cuenta email verificada y confirmar que Google/GitHub no pueden
editarlo. El despliegue de Functions usa Cloud Build y Artifact Registry; el owner
debe vigilar el presupuesto del proyecto Blaze.

## Reglas de seguridad (resumen)

- Denegar por defecto en la raíz.
- Los clientes leen catálogo y solo escriben sus preferencias y perfil.
- Los pedidos no se escriben desde el cliente; el servidor los crea y cambia su estado.
- `payments`, `pickupTokens` y `staffQueue` nunca son legibles por el cliente.
- Roles de personal y administrador mediante custom claims (`staff`, `admin`), nunca por campos editables por el usuario.

## Validación local

- Los cuatro archivos JSON (`firebase.json` y los tres archivos de reglas y semillas) se validan con `node -e`.
- Firebase Emulator Suite está declarado en `firebase.json` y ya se pudo iniciar. No se completó la conexión desde el teléfono físico; esa validación local es opcional y no bloquea las pruebas del proyecto real.

La suite de emuladores ya está declarada y se ha podido iniciar. Para ejecutar
servicios locales (no despliega ni modifica Firebase remoto),
usa Node.js 22 (requerido por `functions/package.json`) e instala sus paquetes:

```bash
cd functions
npm ci
cd ..
firebase emulators:start --only auth,database,functions,storage --project lincefood-app
```

En otra terminal, desde `app/`, habilita el modo emulator para Android:

```bash
flutter run --dart-define=FIREBASE_EMULATORS=true
```

El host predeterminado `10.0.2.2` funciona desde el emulador Android de
Android Studio. En teléfono físico se necesita configurar `FIREBASE_EMULATOR_HOST`
con la dirección accesible de la computadora y permitir la conexión solo en la
red de prueba. El modo emulator no es para producción; Google/GitHub OAuth ni
FCM real se validan mediante este modo.

## Comandos

```bash
firebase use lincefood-app
firebase deploy --only database --project lincefood-app   # solo tras revisar las reglas
```

No desplegar reglas de RTDB ni importar semillas como parte de Plan A. El único
despliegue pendiente es la función de avatar y las reglas de Storage por parte
del owner.

## Instalación para colaboradores

Requisitos:

- Flutter estable (el proyecto usa Dart `^3.13.1`) con Android SDK.
- Node.js 22 (las funciones declaran `"node": "22"`).
- Firebase CLI (`npm install -g firebase-tools`), con sesión iniciada en la cuenta del equipo.

Pasos (sustituye `PROJECT_ID` por el ID del proyecto de desarrollo, nunca el de producción):

```bash
git clone <URL_DEL_REPOSITORIO>
cd lincefood

# 1. Configuración de Firebase local (no se versiona)
firebase use PROJECT_ID
# Genera app/lib/firebase_options.dart con FlutterFire CLI o copia el archivo
# de ejemplo app/lib/firebase_options.example.dart y completa sus valores.

# 2. Dependencias de la app
cd app
flutter pub get
flutter analyze
flutter test
cd ..

# 3. Dependencias y pruebas de las funciones
cd functions
npm ci
node --test
```

Archivos locales que no se incluyen en Git:

- `app/lib/firebase_options.dart` generado para tu proyecto de desarrollo.
- `app/android/app/google-services.json` descargado para el paquete Android; no se incluye en Git.
- `app/android/local.properties` con ruta del SDK Android y clave local de Maps.
- Archivos de servicio de Firebase Admin y cualquier `.env` con claves del servidor.
- Claves de Stripe: solo se usan claves de prueba (`pk_test_` en la app y `sk_test_` en
  el servidor), guardadas en el entorno seguro del servidor, nunca en el repositorio.

Para pruebas de integración en la app (sin servicios reales):

```bash
cd app
flutter test integration_test
```
