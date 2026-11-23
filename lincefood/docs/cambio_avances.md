# Cambio avances — revisión de app_tests

**Revisión:** 22-nov-2026.
**Base remota examinada:** `origin/main` → `08998312eec13796fd147db4b4cc3e1ffd24ced2`.
**Checkout local al revisar:** `main` → `0ef4e7e3d29688da30910d904d39027aee7e3c23`, seis commits detrás de `origin/main`.
**Alcance:** lectura estática de commits y archivos remotos; no se hizo checkout/merge, no se ejecutaron pruebas en esta revisión.

## 1. Cambios publicados encontrados

`origin/main` añade seis commits respecto de la copia local:

| Commit | Cambio principal |
|---|---|
| `5065828` | Configuración, reglas, hosting, semilla, roles y pruebas de reglas. |
| `04f8770` | Flujos de autenticación, verificación y recuperación de contraseña. |
| `d242d82` | Tema cálido, catálogo y carrito visuales, imágenes, administración de catálogo y roles. |
| `f2c98d0` | Pedidos/tickets, Stripe PaymentSheet, transiciones, QR/escáner staff y pantallas de planes. |
| `e236f1f` | Notificaciones, ubicación, biometría, perfil y almacenamiento de medios. |
| `0899831` | Pruebas de integración, reglas y funciones. |

Todos aparecen con autor Git `AndyMonjaras`. Git no permite concluir quién ejecutó el push. Esta observación queda para auditar el flujo de autoría contra la regla del equipo: Codex es el único encargado de commits, push y merge.

### Funcionalidad y UI añadida

- Catálogo con búsqueda, categorías, selección de variantes, detalle e imágenes opcionales; carrito con modalidad de recogida y barra fija de total.
- Tema claro/oscuro cálido, controles visuales compartidos, onboarding actualizado y vistas de autenticación/perfil ampliadas.
- Historial/ticket con folio, partidas, tiempo transcurrido y línea temporal; pantalla de pago con PaymentSheet; pantalla staff y escáner QR.
- Administración móvil de productos/precios/roles y una pantalla de planes.
- Funciones `createOrder`, `createPaymentIntent`, `stripeWebhook`, `updateOrderStatus`, `issuePickupToken`, `consumePickupToken`, catálogo, roles y notificaciones.
- Tokens de QR opacos con hash en base, reglas RTDB/Storage ampliadas, pruebas unitarias de app/servidor/reglas y una prueba de integración Flutter.

## 2. Discrepancias con `plan_omar_v1`

### Bloqueantes o de seguridad

1. **Etiqueta de estado:** `OrderStatus` y `OrderTimeline` usan “En cocina”; el acuerdo vigente es **“En preparación”**.
2. **Expiración y cancelación:** no se encontró `cancelOrder` ni expiración de pedidos `payment_pending` a los 30 minutos. El QR sí vence, pero es un TTL distinto.
3. **Duración del QR:** `pickup_handlers.mjs` configura ahora 20 minutos por decisión del usuario.
4. **Fallback biométrico:** QR requiere `biometricOnly`; si falla o no está disponible queda oculto, pero no implementa reautenticación Firebase acordada.
5. **Horario de pedidos:** la semilla tiene `acceptingOrders: false`, y la búsqueda en app/functions solo encuentra ese campo en la semilla. `createOrder` no valida el estado de apertura. El flujo necesita un estado visible en UI y enforcement en servidor.
6. **Verificación de correo en backend:** las funciones de creación de pedido y PaymentIntent exigen sesión, pero no verifican `email_verified`, aunque la app exige correo verificado.
7. **Estados mixtos:** Functions escribe `pendiente_pago`/`pagado`, mientras la app conserva códigos canónicos y alias de lectura. Conviene normalizar el almacenamiento a códigos canónicos.
8. **Confirmación de cocina:** la UI staff permite pasar de `paid` o `confirmed` directamente a `preparing`; el plan pide registrar `confirmed` y luego avanzar a `preparing`.
9. **Notificaciones duplicadas:** la implementación nueva registra `notificationTokens`, pero el servicio FCM anterior sigue escribiendo `deviceRegistrations`; las reglas contienen ambos. El plan designa `deviceRegistrations` como único esquema.
10. **App Check/emuladores:** el bootstrap remoto no activa App Check, `functions/index.mjs` no configura `enforceAppCheck` y `firebase.json` no define emuladores. El README dice que los servicios remotos y el emulador siguen pendientes.

### Desvíos de alcance y producto

11. **CRUD administrativo móvil:** se añadió junto con asignación de roles, aunque el plan aprobado para MVP era cargar semilla y administrar desde Firebase Console. Mantenerlo fuera del camino crítico hasta que el equipo cambie ese acuerdo.
12. **Planes/membresías:** hay pantalla y reglas de dominio, pero el cobro Stripe Billing no está implementado. La decisión vigente es posponerlo; no presentar los planes como suscripción disponible.
13. **Tokens/QR:** el servicio solo emite QR cuando el pedido está `ready`; esta es la regla de recogida acordada, aunque el documento de proceso también menciona `paid` como elegible. Mantener `ready` como decisión del plan vigente.
14. **Navegación adaptable:** el shell remoto muestra `NavigationBar`; no se observa `NavigationRail` para ventanas anchas como recomienda `DISENO_REFERENCIA.md`.
15. **Imágenes de menú:** las imágenes están detrás de `MENU_IMAGES_ENABLED` y desactivadas por defecto porque Storage no está habilitado; el catálogo usa iconos/fallback, no fotos reales.

### Observaciones de integración y evidencia

- PaymentSheet reporta éxito local al volver de la hoja; la autoridad del estado del pedido es el webhook. Verificar que el ticket espere el estado RTDB y muestre un estado de confirmación mientras llega el webhook.
- El reporte técnico indica que reglas/funciones no se desplegaron, RTDB/Auth están pendientes, no hubo prueba real de OAuth/FCM/Stripe ni biometría en dispositivo, y las capturas/evidencias siguen pendientes.
- `app/README.md` declara 142 pruebas Flutter y 40 Node aprobadas en una ejecución anterior. No se repitieron en esta revisión. El reporte técnico apunta a un reporte de `/tmp`, fuera del repositorio; conservar un resultado reproducible dentro del proyecto.
- La semilla sí incluye coordenadas `20.5409871, -100.8128506` y `locationConfigured: true`; el reporte técnico dice que las coordenadas están pendientes de confirmación. La presencia de coordenadas en la semilla no demuestra por sí sola que el campus las haya validado.

## 3. Lectura general del avance

Las pantallas de catálogo, carrito, pedido, pago y staff dejaron de ser placeholders y hay un backend local de Functions considerable. El avance cubre buena parte del flujo objetivo, pero **no equivale a despliegue ni a validación de extremo a extremo**. Para alinearlo con las decisiones vigentes, atender primero expiración/cancelación, validación del horario y correo en servidor, sincronización del pago con webhook, estado de cocina, TTL/fallback QR y esquema único de notificaciones.

## 4. Estado de esta documentación

Estos documentos se guardaron en `lincefood/docs/`. La rama local `main` no se actualizó a `origin/main`, no se hizo merge ni commit y no se modificó código. En este momento los documentos quedan como archivos locales sin commit en la rama local que está seis commits detrás; su contenido describe explícitamente la revisión del `origin/main` indicado arriba.
