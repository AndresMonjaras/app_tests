# Lincefood · configuración Firebase

Proyecto Firebase: `lincefood-app` (plan Spark, sin facturación).

## Estado

| Componente | Estado |
|---|---|
| Proyecto Firebase | Creado |
| App Android `com.lincefood.app` | Registrada (`apps:create`) |
| Realtime Database | Pendiente: activar en la consola (la CLI pide el asistente la primera vez) |
| Auth: correo/contraseña y Google | Pendiente: activar en la consola |
| Storage | Fuera de alcance mientras no haya plan Blaze autorizado |
| Reglas RTDB | Borrador con validación de variantes en `firebase/database.rules.json`, sin desplegar |
| Semilla del menú | Datos ficticios, con variantes de prueba en `firebase/seeds/menu.seed.json`, sin importar |
| Semilla de notificaciones | Textos de ejemplo en español en `firebase/seeds/notificaciones.seed.json`, sin enviar |

## Pasos pendientes del responsable

1. En la consola de Firebase, abrir `lincefood-app` > Realtime Database > Crear base de datos (ubicación `us-central1`).
2. En Authentication > Métodos de acceso, habilitar Correo/contraseña y Google.
3. Revisar el borrador de reglas antes de desplegar.

## Reglas de seguridad (resumen)

- Denegar por defecto en la raíz.
- Los clientes leen catálogo y solo escriben sus preferencias y perfil.
- Los pedidos no se escriben desde el cliente; el servidor los crea y cambia su estado.
- `payments`, `pickupTokens` y `staffQueue` nunca son legibles por el cliente.
- Roles de personal y administrador mediante custom claims (`staff`, `admin`), nunca por campos editables por el usuario.

## Validación local

- Los cuatro archivos JSON (`firebase.json` y los tres archivos de reglas y semillas) se validan con `node -e`.
- Emulador Firebase: no configurado; la validación de las reglas en el emulador queda pendiente.

## Comandos

```bash
firebase use lincefood-app
firebase deploy --only database --project lincefood-app   # solo tras revisar las reglas
```

No desplegar las reglas ni importar las semillas como parte de esta tarea; siguen pendientes.

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
- Archivos de servicio de Firebase Admin y cualquier `.env` con claves del servidor.
- Claves de Stripe: solo se usan claves de prueba (`pk_test_` en la app y `sk_test_` en
  el servidor), guardadas en el entorno seguro del servidor, nunca en el repositorio.

Para pruebas de integración en la app (sin servicios reales):

```bash
cd app
flutter test integration_test
```

Las pruebas con Firebase real, OAuth, notificaciones push y Stripe Sandbox requieren
configuración del responsable del proyecto y no forman parte de esta guía.
