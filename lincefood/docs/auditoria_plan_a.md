# Integración del Plan A en Lincefood

## Decisión de migración

La app Flutter vive en `app/` y el repo ya contenía catálogo, carrito, pedidos,
modelo de dominio y pruebas de B/C. Se conservó esa estructura y Riverpod; no se
copió encima el `main.dart`, el shell ni el controlador Provider del repo
`app_cafeteria`. La fuente original permanece intacta como respaldo.

## Trabajo integrado localmente

| Área | Adaptación en Lincefood | Estado |
|---|---|---|
| Arquitectura/estado | Riverpod existente, providers por Auth, perfil, preferencias y FCM | Código integrado |
| Auth | Email/contraseña, registro, verificación, reenvío, recuperación, Google y Facebook | Falta configurar y probar proveedores remotos |
| Guard | Onboarding → sesión → email verificado → shell con módulos existentes | Implementado localmente |
| Perfil | Nombre/correo/proveedor, foto social, avatar privado por email con custom claim | Storage/Functions no desplegados |
| Preferencias | Onboarding y tema persistentes con Shared Preferences | Implementado localmente |
| UI | Tema claro/oscuro, fuente Plus Jakarta Sans con licencia OFL, menú adaptable y privacidad borrador | Identidad Lincefood preservada |
| FCM | Listener raíz, apertura de pedidos, topics públicos y asociación del token al UID | Falta validar en dispositivo y proyecto destino |
| Firebase | App Check, persistencia RTDB, emuladores, reglas y callable local | Falta config real y pruebas de emulador |

## Firebase y límites

La documentación existente identifica el proyecto `lincefood-app`, la app
Android `com.lincefood.app` y plan Spark. El código espera valores de Firebase
por `--dart-define-from-file`; los valores reales van en un archivo local
ignorado. No hay claves ni datos reales en el repo.

Las reglas de RTDB se ampliaron conservando catálogo, pedidos, pagos, planes y
roles. El permiso para avatar requiere custom claim `avatar_editable`, que solo
la callable de Functions asigna luego de consultar proveedores en Admin Auth.
La UI no es la barrera de seguridad. Storage requiere Blaze para habilitar
bucket; no se ha activado ni se ha desplegado nada.

## Pendientes para cerrar A

1. Verificación local ejecutada desde `app/`: las 39 pruebas de `flutter test`
   pasan, `flutter analyze` termina con **No issues found**, y
   `flutter build apk --debug` genera el APK. También se instaló y abrió en un
   Samsung SM M356B con Android 16; sin configuración de Firebase muestra la
   pantalla esperada de configuración pendiente.
2. Configurar el archivo local de Firebase para `lincefood-app`; habilitar RTDB
   y Auth (correo, Google, Facebook) con el responsable de la cuenta.
3. Confirmar autorización de Blaze antes de crear Storage o desplegar Functions.
4. Instalar dependencias de `functions/`, probar la callable y reglas en
   Emulator Suite.
5. Probar registro, verificación, OAuth, cierre de sesión, perfiles y FCM en
   Android. Configurar SHA y credenciales de Meta sin incluir App Secret.
6. Completar responsables, contacto y retención en el aviso institucional.

Las pruebas automatizadas anteriores no sustituyen la prueba autenticada en
Android. Esa prueba depende de recibir la configuración de desarrollo y de que
el responsable habilite los proveedores/servicios correspondientes en Firebase.

Para revisión visual local se añadió `--dart-define=LINFOOD_PREVIEW=true` en
builds no release. Abre onboarding y la UI de acceso con autenticación
deshabilitada. El flujo de preview se cubre con una prueba de widget; no simula
Firebase ni sustituye la prueba conectada.

No se desplegaron recursos, no se importaron semillas y no se ejecutaron
comandos de Git.
