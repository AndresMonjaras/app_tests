# Cambios implementados: catálogo y pedidos de cafetería

**Rama de implementación:** `feat/cafeteria-operations-backend`

**Integración cliente:** `feature/cliente-pedidos`, basada en `main` e integrada
por fast-forward hasta `3b862f2` (incluye `5e2a4e9`, catálogo de demostración,
fotos y sincronización de roles).

**Repositorio:** `app_tests`
**Alcance:** operaciones de catálogo/pedidos de cafetería y flujo de cliente. No
se integró `superadmin`.

## Catálogo y operaciones de cafetería

- El personal puede crear y editar productos, disponibilidad, fotos, variantes,
  complementos definidos en el producto, ingredientes, porciones y tiempo de
  preparación. Las escrituras de productos pasan por Cloud Functions.
- Los productos se archivan y restauran sin borrar el historial. Los cambios se
  registran en `adminAudit`.
- El cliente escucha el catálogo en tiempo real; los productos archivados no se
  muestran y el carrito valida disponibilidad y precios antes del pago.
- La semilla local contiene 11 productos de demostración con descripciones e
  `imagePath`. Ya están las fotos locales del menú en `assets/images/menu/`; las
  tres últimas (`sandwich.jpg`, `torta.jpg` y `water.jpg`) son imágenes
  generadas con IA. Las fuentes y licencias están en
  `docs/imagenes_licencias.md`. La semilla local no se importó a RTDB; el equipo
  indica que el catálogo real ya está preparado.
- `functions/scripts/seed_menu.mjs` importa los productos y
  `functions/scripts/upload_menu_images.mjs` sube sus fotos una vez creados en
  RTDB. Ejecutarlos solo después de confirmar el proyecto de destino.

## Flujo de pedidos y cliente

- `createOrder` usa una clave idempotente, valida en servidor la disponibilidad
  y los precios vigentes, y devuelve el total y las líneas autoritativas. El
  cliente sigue el pedido y muestra sus cambios hasta la entrega.
- El pago se procesa mediante Stripe PaymentSheet y el webhook confirma el
  resultado. La cancelación del cliente solo se permite mientras el estado sea
  `payment_pending`.
- El personal avanza los pedidos por `confirmed`, `preparing` y `ready`; la
  entrega se confirma con el QR del estudiante.
- El cliente ve cambios del catálogo en tiempo real, puede reintentar la carga de
  pedidos/avisos y ve errores claros si no se puede generar o validar su QR.
- El estudiante puede seleccionar complementos opcionales desde el catálogo;
  sus selecciones se separan por línea, se muestran en carrito y ticket, y se
  incluyen en la clave idempotente. `createOrder` valida existencia,
  disponibilidad y precio desde RTDB, calcula el importe y guarda snapshots de
  complementos/precios en `orders` y `ordersByUser`.

## Roles en Firebase

El rol operativo se establece en `profiles/{uid}/role` con dos valores:

- `estudiante`: acceso de cliente.
- `personal`: acceso a operaciones de cafetería.

La función `synchronizeProfileRole` refleja `personal` como custom claim `staff`
para autorizar las reglas RTDB/Storage y las Cloud Functions. Las reglas impiden
que la persona usuaria cambie su propio rol; el cambio administrativo del perfil
es la fuente de verdad. El compañero indica que catálogo y roles ya están
preparados en Firebase. Sin embargo, la consulta remota no encontró desplegado
`synchronizeProfileRole`: si los claims `staff` se asignaron manualmente, el
personal puede acceder con un token actualizado; los cambios futuros en
`profiles/{uid}/role` no se sincronizarán automáticamente hasta desplegar esa
función. No se añadió `superadmin`.

## Estado remoto y pendientes de Firebase

Consulta de solo lectura al proyecto `lincefood-app`:

- La instancia `lincefood-app-default-rtdb` está activa en `us-central1`.
- Hay 30 Cloud Functions activas. Entre ellas están `createOrder`,
  `createPaymentIntent`, `stripeWebhook`, `updateOrderStatus`, `cancelOrder` y
  las dos funciones de QR. Por tanto, las funciones de pedidos/pago no están
  ausentes del proyecto.
- Las funciones de pago tienen referencias a secretos en Secret Manager:
  `createPaymentIntent` y `cancelOrder`/`rejectOrder` usan
  `STRIPE_SECRET_KEY`; `stripeWebhook` referencia `STRIPE_SECRET_KEY` y
  `STRIPE_WEBHOOK_SECRET`. La consulta no lee sus valores ni permite
  confirmar que sean claves de Stripe de prueba válidas. Tampoco confirma que
  el endpoint y eventos del webhook estén configurados en Stripe.
- `synchronizeProfileRole` no figura entre las funciones desplegadas.
- `firebase.json` apunta a `firebase/database.rules.json` y
  `firebase/storage.rules`, pero la CLI no ofrece una lectura de las reglas
  activas del proyecto. No se pudo confirmar si las reglas remotas coinciden con
  esos archivos; el owner debe revisarlas y desplegarlas si están desactualizadas.
- El código local de Functions incluye cambios de esta integración que aún no se
  han desplegado desde este workspace, incluido el precio y snapshot de
  complementos. Las funciones remotas existen, pero hay que publicar esta
  versión antes de probar el flujo actualizado.

Acciones para el owner antes de la prueba con dos teléfonos:

1. Revisar y desplegar la versión actual de Functions, que incluye
   `synchronizeProfileRole` y el pedido con complementos:

   ```bash
   firebase deploy --only functions --project lincefood-app
   ```

2. Revisar que las reglas activas coincidan con los archivos locales y, si no,
   desplegarlas:

   ```bash
   firebase deploy --only database,storage --project lincefood-app
   ```

3. Confirmar en Stripe que la clave asociada a `STRIPE_SECRET_KEY` sea de modo
   prueba, que `STRIPE_WEBHOOK_SECRET` corresponda al endpoint activo
   `stripeWebhook`, y que ese endpoint reciba los eventos de pago requeridos.
   No volver a cargar secretos si el owner ya verificó las versiones existentes.
4. Compilar ambos teléfonos con la clave publicable de prueba, sin guardarla en
   el repositorio:

   ```bash
   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

5. Confirmar que la cuenta de cafetería tiene `staff: true` y que renovó su
   sesión; comprobar desde estudiante la lectura del catálogo y su pedido.
6. Hacer la prueba Sandbox completa: crear pedido con complemento, pagar,
   avanzar estados, escanear QR y confirmar entrega. No usar tarjetas ni claves
   de producción.

No se hizo ningún despliegue ni cambio remoto en esta revisión. El catálogo y la
asignación actual de roles se consideran preparados según lo reportado por el
equipo; quedan pendientes la publicación/verificación de la versión actual, las
reglas activas y la comprobación de Stripe antes de la prueba real.

## Validación local de la integración cliente

- `flutter analyze`: sin incidencias.
- Suite Flutter completa: 295 pasaron, 0 fallos.
- Pruebas focalizadas de administración, claims de personal y handlers:
  52 pasaron, 0 fallos (10 Flutter y 42 Functions).
- `npm test` en `functions/`: 137 pasaron, 0 fallos; incluye pruebas de
  complementos, importes y validaciones.
- `flutter build apk --debug`: completado; APK en
  `app/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: sin errores.
- No se probaron operaciones de escritura remotas, pagos Stripe ni el flujo en
  dos dispositivos; se validarán después de las acciones del owner.

## Control de versiones

`feature/cliente-pedidos` avanzó por fast-forward hasta la punta actual
`3b862f2` de `feat/cafeteria-operations-backend`. El trabajo cliente continúa sin
commit; los stashes locales se conservan como respaldo.
