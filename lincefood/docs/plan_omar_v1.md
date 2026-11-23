# Plan Omar v1 — Lincefood

**Estado:** decisiones de producto aprobadas; plan de ejecución.
**Repositorio de trabajo:** `app_tests`, dentro de `lincefood/`.
**Base de revisión de avances:** `origin/main` en `08998312eec13796fd147db4b4cc3e1ffd24ced2` (22-nov-2026).
**Alcance:** completar y corregir el flujo de pedidos y la experiencia de la app; `app_cafeteria` se conserva para una integración posterior.

## 1. Acuerdos establecidos

- Stripe se probará en **modo sandbox** con la cuenta de prueba del responsable.
- Claude lidera el diseño UI/UX y el análisis visual; propone el sistema visual y las vistas para revisión del equipo.
- Los textos de estado serán en español de México. `preparing` se muestra como **En preparación**.
- Los importes se muestran en **pesos mexicanos (MXN)**, con separador de miles y dos decimales.
- Un pedido sin pago vence a los **30 minutos**. El servidor gestiona su expiración y el PaymentIntent asociado, contemplando la carrera entre expiración y confirmación de Stripe.
- Pago cancelado o fallido conserva el pedido en `payment_pending`. Se permite reintentar el mismo pedido; la cancelación requiere una operación de servidor y solo procede antes del pago.
- Si está activa la protección del QR, se exige biometría. Si no está disponible o falla, se solicita reautenticación segura con la cuenta Firebase. Si no se completa, no se revela el QR; la asistencia del personal no debe omitir la validación.
- El QR de recogida dura **5 minutos**, contiene un token opaco de un solo uso y se emite cuando el pedido está listo.
- El personal usa la misma app mediante el claim `staff`. Las operaciones sensibles se autorizan en servidor.
- Para el MVP, el catálogo se carga desde la semilla y se administra en Firebase Console; no se construirá un CRUD móvil administrativo.
- Para notificaciones se conserva `deviceRegistrations` como el esquema único de dispositivos. Se notifican pago confirmado, pedido en preparación y pedido listo con textos versionados en la semilla, sin datos privados en el payload.
- `campusHint`/proximidad del alumno queda fuera del MVP. El mapa de la cafetería existente se conserva.
- Stripe Billing y membresías se posponen hasta cerrar el flujo de compra única.
- Una persona responsable administra Firebase, Stripe sandbox, App Check y la firma del APK. Sus secretos permanecen fuera de Git. No se entiende autorizado ningún despliegue por este plan.
- Codex es el único agente que crea commits, hace push o merge; primero en `app_tests`.

## 2. Plan de ejecución

### Fase A — Alinear contratos y entorno de desarrollo

1. Usar el código real como fuente de verdad y mantener documentadas las diferencias con especificaciones antiguas.
2. Consolidar el contrato del pedido: propietario, folio, líneas con snapshot, precios en centavos, modalidad, estados canónicos, timestamps, errores de pago y relaciones `ordersByUser`/`staffQueue`.
3. Normalizar los estados almacenados a códigos canónicos (`payment_pending`, `paid`, `confirmed`, `preparing`, `ready`, `delivered`, `incident`); traducirlos a español solo en UI.
4. Definir emuladores y datos semilla para poder probar sin despliegue. Resolver App Check para pruebas en APK sideloaded y verificar los requisitos de facturación antes de cualquier servicio remoto.
5. Preparar el trabajo visual con Claude: mapa de pantallas, jerarquía visual, tokens, estados vacíos/carga/error, modo claro/oscuro, accesibilidad y navegación adaptable.

**Cierre:** contrato y decisiones visuales revisados; entorno local reproducible; ninguna clave versionada.

### Fase B — Menú, producto y carrito

1. Construir el catálogo con categorías, búsqueda, estado real de la cafetería, disponibilidad, imágenes con fallback y variantes.
2. Construir el detalle de producto y el carrito con cantidades y totales MXN.
3. Cargar menú de prueba desde RTDB/emulador; el servidor también debe respetar `acceptingOrders`, no solo la UI.
4. Diseñar la confirmación R34: mostrar el resumen y advertir que no se modifica después de pagarse.

**Cierre:** navegación de menú a carrito funcional, con variantes, estados de disponibilidad y totales correctos.

### Fase C — Crear pedido de forma segura

1. Implementar `createOrder` como callable: validar sesión y correo verificado, cafetería abierta, productos disponibles, variantes y cantidades; recalcular precios exclusivamente en servidor.
2. Guardar snapshot del pedido y actualizar de forma coherente `orders`, `ordersByUser` y `staffQueue`.
3. Mantener reglas que deniegan escrituras directas del cliente.
4. Implementar expiración a los 30 minutos y cancelación solo desde `payment_pending`; cancelar o reconciliar el PaymentIntent sin permitir que un pago confirmado quede descartado.

**Cierre:** pruebas de servidor y reglas prueban pedidos válidos, rechazos, cancelación y expiración, incluida la carrera con el webhook.

### Fase D — Pago sandbox y ticket del alumno

1. Crear PaymentIntent en servidor con clave de idempotencia estable por pedido.
2. Integrar PaymentSheet con claves test y secretos en configuración segura; manejar cancelar, fallar, reintentar y regresar a ticket.
3. Confirmar el pago solo por webhook firmado e idempotente; la UI espera el estado autoritativo del pedido.
4. Implementar historial/ticket en tiempo real con folio, partidas, total MXN, tiempo transcurrido y `OrderTimeline`.

**Cierre:** recorrido de carrito a pago y ticket funciona con eventos de webhook duplicados, tardíos y fallidos.

### Fase E — Cocina, QR y entrega

1. Integrar cola de personal en la misma app; comprobar roles en UI y servidor.
2. Aplicar transiciones de manera secuencial y autorizada: `paid` → `confirmed` → `preparing` → `ready` → `delivered`; registrar `incident` cuando proceda.
3. Emitir QR de cinco minutos solo para pedidos `ready`, con token aleatorio guardando solo el hash.
4. Conectar QR con biometría y reautenticación Firebase; agregar cámara/escáner staff y consumo atómico de un solo uso.

**Cierre:** pedido pagado, preparado, listo, escaneado y entregado; intentos sin rol, vencidos, reemplazados o duplicados son rechazados.

### Fase F — Notificaciones y pulido UI/UX

1. Usar una sola ruta de tokens (`deviceRegistrations`) y retirar duplicación con `notificationTokens`.
2. Completar textos de la semilla para `paid`, `preparing` y `ready`; probar apertura en estados activo, background y cerrado.
3. Revisar contraste, texto ampliado, lector de pantalla, orientación/tamaños y navegación adaptativa; validar visualmente en Android real.

**Cierre:** eventos correctos sin datos privados y pantallas coherentes en móvil y anchos mayores.

### Fase G — Entrega y alcance pospuesto

- Documentar instalación, configuración local, decisiones de seguridad y evidencias reales.
- Ejecutar y reportar Flutter analyze/tests, pruebas Node, reglas/emuladores y build APK; en dispositivo, validar Stripe sandbox, cámara, QR, biometría, FCM y permisos.
- Dejar fuera del flujo MVP el CRUD administrativo móvil, `campusHint` y Stripe Billing. Reconsiderarlos como fases independientes si el equipo lo solicita.
- Desplegar recursos solo tras autorización expresa del responsable.

**Cierre:** cada bloque es funcional y verificable antes de integrarlo; Codex revisa y realiza cualquier commit/push/merge dentro de `app_tests`.

## 3. Dependencias principales

```text
Contrato + entorno → menú/carrito → createOrder → pago/webhook → ticket
                                               └→ roles/staff → estados → QR → entrega
Semillas + notificaciones ────────────────────────────────┘
```

El diseño visual puede avanzar en paralelo una vez acordado el contrato de pantallas y estados. La integración conectada depende de que el responsable habilite y configure Firebase/Stripe; el desarrollo y las pruebas con dobles/emuladores no autorizan despliegues.
