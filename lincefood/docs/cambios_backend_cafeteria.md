# Cambios implementados: operaciones de cafetería y pedidos

**Rama:** `feat/cafeteria-operations-backend`

**Commit:** `5e2a4e9` — `feat: habilita operaciones de cafeteria y flujo de pedidos`

**Repositorio:** `app_tests`

**Alcance:** administración del catálogo por personal autorizado y ciclo de pedido existente. No se integró `superadmin`.

## Catálogo y operaciones de personal

- Se habilitó el claim Firebase `staff: true` para que el personal acceda a la gestión del catálogo y a las operaciones de pedidos; administración conserva sus permisos.
- El formulario de productos permite crear y editar nombre, categoría, precio, disponibilidad, descripción, ingredientes, variantes, complementos definidos en el producto, porción, tiempo de preparación y fotografía desde cámara o galería.
- La foto se carga a Firebase Storage bajo `menu/{productId}/...`. Las reglas permiten administrar estas imágenes a `staff` y `admin`; las escrituras de productos siguen pasando por Cloud Functions.
- El backend valida campos, precios en centavos, categorías, variantes, complementos, porciones y rutas de imagen. Para productos antiguos admite conservar su ruta de imagen ya registrada.
- El personal puede cambiar disponibilidad, archivar productos sin borrar registros históricos y restaurar productos archivados.
- Las operaciones del catálogo generan registros en `adminAudit` con actor, acción, producto y valores antes/después.
- La interfaz presenta los errores devueltos por Cloud Functions, en vez de ocultarlos tras un mensaje genérico.
- El catálogo del estudiante escucha cambios en tiempo real y excluye productos archivados.
- La semilla contiene 11 productos de demostración con descripciones en español e `imagePath` para `menu/{productId}.jpg`. Se añadieron fotos locales para torta de milanesa y torta de pierna; las demás fotos ya estaban en el repositorio. Las dos nuevas imágenes se optimizaron a 512 × 512 y pesan cerca de 50 KB cada una.
- La app usa las fotos locales como fallback y muestra la descripción en las tarjetas del catálogo. La subida de las fotos a Cloud Storage se realiza con `functions/scripts/upload_menu_images.mjs` después de que existan los productos en RTDB.

## Flujo de pedidos y atención en cocina

- La creación del pedido usa una clave idempotente persistida en el backend. Repetir la misma solicitud devuelve el mismo pedido y evita duplicados.
- El precio y la disponibilidad se validan en servidor; los productos archivados o agotados no se aceptan en un pedido.
- La cola de personal se ordena primero por antigüedad (FIFO) y sus tarjetas muestran folio, estado, total, modalidad, tiempo transcurrido y productos con cantidades/variantes.
- Se mantiene el avance de estado del personal hacia `confirmed`, `preparing` y `ready`; la entrega se confirma mediante el escaneo del QR de recogida.
- Cuando el pedido está listo, la pantalla de cocina indica al personal que escanee el QR del estudiante.
- El flujo de webhook de Stripe incorpora registro de eventos para evitar procesar dos veces un evento ya completado.
- La cancelación del estudiante se limita a pedidos cuyo pago todavía está pendiente, según la regla acordada. Flutter interpreta el estado `cancelled` del backend.

## Roles en Firebase

El rol operativo se establece en `profiles/{uid}/role` con dos valores:

- **`estudiante`:** acceso de cliente.
- **`personal`:** acceso a operaciones de cafetería.

La rama añade una función que refleja `personal` como custom claim `staff` para que las reglas de Storage y RTDB puedan autorizar con seguridad. Las reglas impiden que cada usuario cambie su propio rol. El cambio del perfil en Firebase Console es la fuente administrativa; el claim se sincroniza cuando la función está desplegada. No se añadió un rol `superadmin`.

## Pendientes y límites de este cambio

- Los complementos pueden administrarse en el producto y se muestran en su ficha, pero el flujo actual no permite seleccionarlos para una línea del carrito ni los incluye como selecciones del pedido.
- Las categorías existentes se pueden seleccionar; la creación de categorías continúa reservada a administración.
- No se importó `menu.seed.json` ni se subieron las imágenes a Firebase Storage. Las fotos y los datos están preparados localmente para ese paso.
- No se desplegaron Cloud Functions ni reglas a Firebase. Por eso, la sincronización automática del perfil al claim aún no está activa en el proyecto remoto.
- No se ejecutaron suites de pruebas, `flutter analyze`, builds ni pruebas en dispositivo. Se comprobó formato de Dart, sintaxis de los archivos Node.js modificados y `git diff --check`.

## Control de versiones

Los cambios de código se publicaron en `feat/cafeteria-operations-backend` en el commit indicado. No se hizo merge. Los cambios locales preexistentes de `lincefood/app/android/gradle.properties` y los documentos locales no formaron parte de ese commit.
