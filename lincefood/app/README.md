# Lincefood App

Aplicación Flutter de cafetería con Riverpod y Firebase. No confundir este
subproyecto con la aplicación del directorio padre.

## Administración y acceso

- Sin sesión, el acceso muestra primero el login. Una sesión sin correo verificado
  continúa a verificación; después se muestra la bienvenida pendiente.
- Login, registro y recuperación comparten el formulario existente. La recuperación
  no revela si un correo existe. Los errores de conexión, límites y conflictos de
  proveedores tienen mensajes en español; se bloquean envíos duplicados.
- Google y Facebook siempre aparecen. Los flags `GOOGLE_SIGN_IN_ENABLED` y
  `FACEBOOK_SIGN_IN_ENABLED` habilitan los botones, pero no configuran los servicios:
  también hacen falta los ajustes de Firebase y de cada proveedor.
- Perfil muestra Administración únicamente con el claim `admin`. La pantalla
  también comprueba acceso; las funciones del servidor exigen el claim.
- Administración permite crear y editar nombre, categoría, preparación, precio,
  hasta seis variantes, disponibilidad y eliminación confirmada. Los precios se
  validan como centavos enteros seguros, aceptando punto o coma decimal.
- Roles permite conceder o retirar `staff`/`admin` mediante UID y confirmación.
  El servidor conserva los demás claims y rechaza retirar el propio claim admin.
  La cuenta afectada debe volver a iniciar sesión para refrescar sus permisos.
- El catálogo combina categorías en cuadrícula, acentos amarillo/rosa, tarjetas
  claras redondeadas y naranja. Incluye búsqueda, detalle y selección de variantes.
  Usa iconos mientras las fotos de menú estén desactivadas. Con
  `--dart-define=MENU_IMAGES_ENABLED=true` muestra la foto de `imagePath` mediante
  `cached_network_image`; requiere Cloud Storage, por lo que queda desactivado por defecto.

## Validación local del 22 de noviembre de 2026

Comandos ejecutados desde `app/`:

```bash
flutter analyze
flutter test --reporter expanded
```

Desde `functions/`: `node --test`.

El análisis no encontró incidencias. La suite Flutter pasa 142 pruebas y la suite
Node pasa 40. Se cubren precios límite, conservación de variantes, errores de
formularios, confirmación de permisos, doble envío, login antes de bienvenida,
verificación, sesión vigente, recuperación, errores de acceso y pantalla pequeña
con teclado y texto ampliado. Se inspeccionaron capturas móviles de login y
catálogo generadas con widgets y datos de prueba.

Codex comparó los cambios con copias previas y revisó independientemente los
contratos y las pruebas. DeepSeek propuso un conversor completo de precios usando
BigInt; se conservó una implementación más breve con la misma protección y pruebas.
Agy no entregó una revisión: el modelo predeterminado no estaba disponible y el
modelo compatible devolvió RESOURCE_EXHAUSTED (429).

## Límites y puesta en servicio pendiente

- No se desplegaron funciones/reglas, no hubo commits ni cambios de credenciales.
  No se verificaron OAuth, correo, custom claims o RTDB contra servicios reales.
  Las pruebas del servidor usan dobles; no sustituyen una prueba de integración
  con el emulador. No se generó un APK nuevo en esta tarea.
- Firebase debe estar configurado localmente. La app mantiene la pantalla de
  configuración cuando no puede inicializar Firebase.
- Los cambios concurrentes de roles sobre un mismo UID todavía pueden sobrescribirse:
  Firebase Auth utiliza lectura y reemplazo de custom claims, sin transacción.
  Evitar administrar simultáneamente la misma cuenta desde distintas sesiones.
  El bloqueo del formulario evita doble envío local, no concurrencia distribuida.
- El bloqueo de autorretiro no garantiza conservar un último administrador frente
  a revocaciones simultáneas entre distintas cuentas o tokens aún vigentes.
- Las transacciones de precio/disponibilidad validan el estado del servidor incluso
  con caché inicial vacía y devuelven not-found cuando el producto no existe.
  La edición completa de un producto conserva la política existente de último guardado.

## Archivos de esta implementación

Rutas relativas a `lincefood/`:

- `app/lib/app/app_router.dart`
- `app/lib/app/app_theme.dart`
- `app/lib/features/admin/data/admin_roles_repository.dart`
- `app/lib/features/admin/presentation/admin_catalog_screen.dart`
- `app/lib/features/admin/presentation/admin_product_form.dart`
- `app/lib/features/admin/presentation/admin_roles_panel.dart`
- `app/lib/features/auth/presentation/auth_controller.dart`
- `app/lib/features/auth/presentation/auth_screen.dart`
- `app/lib/features/catalog/presentation/catalog_screen.dart`
- `app/lib/features/navigation/auth_gate_screen.dart`
- `app/lib/features/profile/presentation/profile_screen.dart`
- `app/test/features/admin/admin_management_test.dart`
- `app/test/features/admin/admin_roles_panel_test.dart`
- `app/test/features/auth/presentation/auth_flow_test.dart`
- `app/test/features/auth/presentation/auth_provider_visibility_test.dart`
- `functions/src/catalog/catalog_handlers.mjs`
- `functions/src/roles/role_handlers.mjs`
- `functions/test/catalog.test.mjs`
- `functions/test/roles.test.mjs`
- `app/README.md`

## Planes de servicio

- Básico, Campus Plus y Campus Pro se comparan en Perfil > Planes de servicio.
- El estado de la suscripción se lee de `memberships/{uid}` y lo escribe solo el servidor.
- El cobro de suscripción en Stripe Billing no está implementado: los botones de pago
  aparecen deshabilitados hasta configurar Stripe Sandbox.
