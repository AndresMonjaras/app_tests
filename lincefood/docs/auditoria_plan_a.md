# Auditoría de avance del Plan A

Actualizado: 22 de noviembre de 2026. Esta auditoría separa lo integrado en el
código de lo que exige configuración, autorización o evidencia externa. No
equivale al reporte técnico final.

## Migración inspeccionada

- Proyecto fuente: `finanzas-familiares`, rama `feat/mapa`, commit base
  `ea0aafa1f5dabb25139805e97a905a9d9cb096ef`; su árbol estaba limpio durante la
  inspección.
- El Flutter package fuente está en `app/`; declara Dart `^3.13.0` y contiene
  Firebase Auth, Google/Facebook, FCM, Provider, Maps y otros módulos del dominio
  financiero. No se deben copiar modelos, datos, reglas ni credenciales de ese
  dominio.
- Lincefood ya tenía catálogo, carrito, pedidos, pagos/QR y Riverpod. Se mantuvo
  su arquitectura y esos módulos; la migración no reemplazó el `main.dart` ni
  arrastró el dominio de finanzas.
- La fuente permanece intacta. En la revisión del 22 de noviembre de 2026,
  `flutter analyze` pasó; `flutter test` encontró una falla preexistente en
  `cambio_sesion_navegacion_test.dart` (espera conservar una instancia de
  `ScaffoldMessengerState` que ya está desmontada). El resto de las pruebas que
  alcanzaron a ejecutarse pasó. No se modificó el repositorio fuente.

## Matriz de estado

| Área | Estado actual | Evidencia / pendiente |
|---|---|---|
| Arquitectura y estado | Integrado | Riverpod existente conservado; no se introdujo un segundo gestor. |
| Email/contraseña, verificación y recuperación | Probado manualmente por el alumno | Pruebas 1 y 2 comunicadas como superadas en Android. |
| Sesión, perfil y preferencias | Probado manualmente por el alumno | Prueba 3 comunicada como superada. |
| Google y GitHub | Cubierto y aprobado por el docente | El alumno probó ambos en Android; la rúbrica requiere dos proveedores. |
| Manejo de cuentas con proveedor distinto | Probado | El alumno confirma OAuth en Google y GitHub; tests locales cubren vinculación, correo distinto, error temporal y cierre de sesión. |
| Perfil y avatar | Código implementado | Muestra nombre/correo/proveedor; redes sociales conservan su foto. Email usa custom claim confiable, ruta versionada en Storage y `avatarPath` en RTDB. La callable y reglas locales requieren despliegue y prueba para activar edición segura en Firebase real. |
| Tema, onboarding y navegación adaptable | Código y pruebas de widget | Persistencia existente; navegación inferior a 360 px y `NavigationRail` a 1280 px. La navegación ancha pasa también con escalado 1.6; layouts del catálogo prueban móvil y escritorio. |
| Privacidad | Borrador académico listo | Datos institucionales confirmados por el alumno. El aviso incluye los plazos de referencia del prototipo (90/30 días), identificados como propuestas y no como política de producción. |
| FCM, topics y ciclo de vida | Fuera del cierre de A | El servicio global está integrado. B.6 es responsable de validar envío, topics y foreground/background/terminated. Los cambios locales de A no alteran ese flujo. |
| RTDB: catálogo | Fuera del cierre de A | Pertenece al catálogo/flujo B. Perfil y sincronización de nombre sí pertenecen a A.4. |
| Reglas y Emulator Suite | Configuración local añadida | Auth, RTDB, Functions y Storage Emulator declarados. Los emuladores arrancaron, pero la prueba móvil local falló por conexión HTTP/host; es opcional si se valida Firebase real. |
| Función de permiso de avatar | Código local integrado | `synchronizeAvatarEligibility` calcula `avatar_editable` consultando Admin Auth y conserva los demás claims. No desplegada ni invocada en Firebase real. |
| Despliegue de avatar | Pendiente del owner | El intento no desplegó nada porque falta `iam.serviceAccounts.ActAs` para la cuenta del alumno. El owner debe desplegar la callable y las reglas de Storage y vigilar los costos de Blaze. |
| Validación Lincefood | Pasó localmente | `flutter analyze`, 188 pruebas Flutter, build APK debug y 64 pruebas de Functions pasaron. No implica despliegue ni prueba de servicios remotos. |

## Cambios locales de esta ronda

- Unificada la edición de avatar en `ProfileAvatarRepository`; eliminada la
  segunda implementación antigua que subía a Storage sin actualizar `photoURL`.
- El avatar se guarda con nombre versionado para que `photoURL` cambie y se
  invalide la imagen anterior. La ruta se registra en `/profiles/{uid}`. Al
  reemplazar o borrar se limpia únicamente la versión conocida, sin listar el
  directorio privado de Storage.
- La UI solo muestra controles de edición cuando la cuenta es exclusivamente de
  correo, está verificada y recibió el custom claim del servidor. Las reglas de
  Storage vuelven a comprobar ese claim; ocultar botones no es la protección.
- Añadido `NavigationRail` para ventanas anchas y avatar en el destino de Perfil.
- El catálogo recibe la URL del avatar desde el shell; no crea una segunda
  suscripción Auth propia, por lo que las pantallas de catálogo aisladas siguen
  funcionando en pruebas.
- El conflicto entre proveedores OAuth conserva la credencial solo en memoria.
  Tras el acceso con la cuenta preexistente, enlaza únicamente si coincide el
  correo de esa cuenta. Se añadieron pruebas unitarias para coincidencia,
  descarte de correo distinto, reintento tras error de red y limpieza al salir.
- El aviso de privacidad de la app detalla cuenta, pedidos, pagos de prueba,
  notificaciones, ubicación y autenticación biométrica. El alumno confirma los
  datos institucionales y las propuestas de conservación/baja para el prototipo.
- Pruebas de shell confirman navegación inferior en 360 px y NavigationRail en
  1280 px con texto a escala 1.6; la pantalla de privacidad pasa con texto 1.5.
- En notificaciones se corrigió la ruta del asset local de consejos. Se retiró
  una implementación vieja de `core/notifications` que no tenía consumidores y
  duplicaba listeners/preferencias frente al servicio activo de
  `features/notifications`; permanece una sola implementación. No se cambió la
  lógica FCM de B ni se quitaron sus canales.
- Emulator Suite habilitable solo en builds locales. El archivo
  `google-services.json` local se añadió a `.gitignore`; conservarlo fuera del
  repositorio.

## Validación local de esta ronda

Ejecutado desde `app/`:

```text
Lincefood app/: flutter analyze               → No issues found
Lincefood app/: flutter test                  → 188 pruebas pasaron
Lincefood app/: flutter build apk --debug     → completado con aviso y pruebas
Lincefood functions/: npm test                → 64 pruebas pasaron, incluidas
  cuatro pruebas nuevas del permiso de avatar
Repo fuente app/: flutter analyze             → No issues found
Repo fuente app/: flutter test                → falla preexistente en
  test/cambio_sesion_navegacion_test.dart; 43 pruebas pasaron antes del fallo
```

Los emuladores Firebase arrancaron, pero no se completó una prueba móvil local
por configuración de host/conexión. No se requiere para usar el proyecto remoto.
Las pruebas manuales comunicadas por el alumno se registran como tales, no como
una repetición automatizada.

## Único pendiente para cerrar A

El owner debe desplegar `synchronizeAvatarEligibility` y revisar/desplegar las
reglas completas de Storage. El intento del alumno se detuvo por falta de
`iam.serviceAccounts.ActAs`, así que no cambió Firebase remoto. Después del
despliegue, probar edición/eliminación con una cuenta email y confirmar que
Google y GitHub no permiten editar la foto. Vigilar el presupuesto Blaze.

El alumno confirma que Google/GitHub y la vinculación OAuth ya están probados,
y que los datos institucionales y el borrador de privacidad están confirmados.
No hay otros pendientes del Plan A.

No forman parte del cierre de A: catálogo de RTDB, FCM/topics y ciclo de vida,
operación de pedidos, Stripe, QR, mapa ni pruebas T07–T23. Corresponden a B/C.
Google y GitHub cumplen los dos proveedores autorizados por el docente; Facebook
no queda como pendiente.

No se importaron semillas, no se cambiaron ajustes en Firebase Console y no se
ejecutaron comandos de Git.
