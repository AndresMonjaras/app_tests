# Lincefood

Aplicación móvil Flutter para consultar el menú de una cafetería, crear pedidos y seguirlos hasta la recogida. El repositorio contiene la app Flutter, Firebase Realtime Database, Cloud Functions, reglas de seguridad, semillas de datos y configuración de emuladores.

## Estructura

```text
lincefood/
├── app/                 # Aplicación Flutter y pruebas
├── functions/            # Cloud Functions y pruebas Node.js
├── firebase/             # Reglas RTDB/Storage y datos semilla
├── hosting/              # Páginas informativas
├── storage-tests/        # Pruebas de reglas de Firebase
├── firebase.json         # Configuración de Firebase y emuladores
└── docs/                 # Documentación propia del proyecto
```

La app está organizada por funcionalidades en `app/lib/features/`; `app/lib/core/` contiene configuración, preferencias, errores y manejo monetario. Riverpod gestiona el estado. El identificador Android definido en el proyecto es `com.lincefood.app`.

## Requisitos de desarrollo

- Flutter estable compatible con Dart `^3.13.1` y Android SDK para ejecutar en Android.
- Node.js 22 y npm para las funciones.
- Firebase CLI para usar los emuladores.
- Una configuración Firebase de desarrollo creada por cada integrante. No se deben subir credenciales, claves de Stripe, archivos de servicio ni configuraciones locales.

## Preparar Flutter

Desde la raíz del repositorio:

```bash
cd lincefood/app
flutter pub get
flutter analyze
flutter test
```

Para ejecutar en un emulador o dispositivo, configura Firebase localmente y luego usa `flutter run`. Los valores locales se suministran mediante `--dart-define-from-file`; utiliza un archivo de ejemplo/versionado como guía y guarda el archivo completado fuera de Git.

## Preparar Cloud Functions

```bash
cd lincefood/functions
npm ci
npm test
```

Las funciones usan módulos ES y declaran Node.js 22. Stripe se configura mediante secretos del entorno seguro de Firebase; nunca escribas claves en el código o en archivos versionados.

## Emuladores Firebase

Instala Firebase CLI e inicia sesión con una cuenta autorizada. Desde `lincefood/`:

```bash
firebase emulators:start --only auth,database,functions,storage --project PROJECT_ID_DE_PRUEBA
```

Sustituye `PROJECT_ID_DE_PRUEBA` por el ID acordado para el entorno local y comprueba que Functions y la app apunten a los emuladores. No uses un ID de producción para pruebas. Para probar desde Android Emulator, el host del equipo suele ser `10.0.2.2`. En un dispositivo físico, configura la dirección LAN del equipo según el entorno de prueba.

No ejecutes comandos `firebase deploy` como parte de las pruebas locales o de una PR. Todo despliegue remoto requiere autorización explícita del responsable del proyecto.

## Firebase y seguridad

- Las reglas de Realtime Database están en `lincefood/firebase/database.rules.json`.
- Las reglas de Cloud Storage están en `lincefood/firebase/storage.rules`.
- Los datos iniciales de menú y notificaciones están en `lincefood/firebase/seeds/`.
- Las operaciones privilegiadas de pedidos, pagos y catálogo se realizan mediante Cloud Functions según las reglas vigentes.
- Roles y permisos deben verificarse en servidor; no confíes en un control de interfaz como barrera de seguridad.
- No subas `google-services.json`, `local.properties`, archivos `.env`, tokens, claves privadas ni archivos de configuración Firebase completados.

## Pruebas

Ejecuta las pruebas de la app y de Functions desde sus directorios. Los tests unitarios y de widgets no sustituyen la verificación con Firebase Emulator Suite, OAuth, Stripe Sandbox, notificaciones push ni pruebas en dispositivo. En la descripción de cada PR registra los comandos realmente ejecutados y sus resultados.

## Flujo de contribución

1. Actualiza la rama base y crea una rama acotada al cambio.
2. Revisa las instrucciones y el contrato de la funcionalidad antes de editar.
3. No copies secretos ni artefactos de herramientas al repositorio.
4. Ejecuta las validaciones afectadas y revisa el diff completo.
5. Publica una PR con alcance, rutas, pruebas, riesgos y dependencias reales.

Para detalles operativos de Firebase y configuración local, consulta [`lincefood/README.md`](lincefood/README.md). La documentación de implementación Flutter está en [`lincefood/app/README.md`](lincefood/app/README.md).
