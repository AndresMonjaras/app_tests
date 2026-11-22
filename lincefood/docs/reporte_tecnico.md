# Reporte técnico: Cafetería Universitaria (Lincefood)

> Estado del documento: borrador técnico. Las secciones describen lo que el repositorio
> demuestra a la fecha. Todo dato marcado como `PENDIENTE` requiere medición, captura,
> APK o evidencia que aún no existe. No se han inventado resultados.

## 1. Portada

- Universidad: `PENDIENTE`
- Asignatura: `PENDIENTE`
- Profesor: `PENDIENTE`
- Integrantes: `PENDIENTE` (no registrados en el repositorio)
- Fecha de entrega: `PENDIENTE` (dato no proporcionado)
- Proyecto: Campus Café / Lincefood, aplicación Flutter con Firebase y Stripe Sandbox.

## 2. Problema y objetivos

- Problema: filas en recesos y horarios de comida. Validación con observación en campo:
  `PENDIENTE` (no realizada en el repositorio).
- Objetivo general y específicos: definidos en el plan maestro de planeación.
- Mediciones de tiempos de fila, pago, preparación y recogida: `PENDIENTE`.

## 3. Alcance, actores y arquitectura

- Actores: estudiante, personal de cafetería y administrador (ver el plan maestro, sección 1.5).
- Arquitectura: `app/` (Flutter, Riverpod), `functions/` (Node, pruebas con `node --test`),
  `firebase/` (reglas y semillas de datos de prueba).
- Estructura de la app: `app/lib/features/<nombre>/{data,domain,presentation}`.
- Estado: Riverpod en toda la app. No se usan `setState` ni `ValueNotifier` en `app/lib`
  (verificado con `rg -n '\b(setState|ValueNotifier)\b' app/lib app/test`).
- Diagramas de estados del pedido: ver plan maestro, sección B.2.

## 4. Migración

- Módulos reutilizados de la base previa: `PENDIENTE` (el repositorio no conserva el
  historial de la migración en este worktree; ver nota de Git en el informe de implementación).
- Dependencias añadidas en esta fase: `cached_network_image` 3.4.1 (caché de imágenes de menú)
  e `integration_test` (SDK de Flutter, pruebas de integración).
- Trabajo propio identificado: pantallas de administración de roles y catálogo, planes de
  servicio, caché de imágenes, flujos de integración y reglas de planes en `functions/src/plans`.

## 5. Firebase

- Auth: correo/contraseña y Google/Facebook en la app. Verificación real con proveedores:
  `PENDIENTE` (requiere proyecto y OAuth configurados).
- Realtime Database: modelo y reglas en `firebase/database.rules.json` (borrador, sin desplegar).
- Storage: código de fotos de menú detrás de `MENU_IMAGES_ENABLED`, desactivado por defecto
  porque Cloud Storage requiere plan Blaze. Sin despliegue.
- FCM, topics y los tres estados de notificación: `PENDIENTE` (requiere dispositivo y consola).
- Automatización de push por cambio de estado: pendiente de decisión humana (plan B.6.4).

## 6. Diseño UI/UX

- Tema claro y oscuro, onboarding de tres pasos y selección de tema: implementados
  (`features/onboarding`, `core/preferences`).
- Responsividad: pruebas de integración en anchos de 360, 768 y 1280 px (`app/integration_test`).
  Capturas: `PENDIENTE`.
- Widget avanzado (`CustomScrollView` con categorías): implementado en el catálogo.
  Confirmación de novedad frente al curso: `PENDIENTE`.

## 7. Pedidos, tiempos y QR

- Transiciones de estado y regla de no cancelación: `app/lib/features/orders/domain` y
  `functions/src/orders`; pruebas en `app/test/domain_rules_test.dart`.
- Total del carrito en centavos enteros: `app/test/features/cart/cart_controller_test.dart`.
- Estimación de tiempo: `order_elapsed_time` y duración por producto.
- QR de un solo uso: `app/test/features/pickup_qr/pickup_qr_test.dart` (entrega una vez y
  rechaza lecturas simultáneas, con dobles).
- Tiempos reales de atención antes/después: `PENDIENTE`.

## 8. Stripe Sandbox

- Flujo de PaymentSheet y reintentos: `app/lib/features/payments` y pruebas con dobles.
- Lógica de transiciones de pago en servidor: `functions/src/payment_transitions.mjs`.
- Planes de servicio: reglas puras en `functions/src/plans/service_plans.mjs` (sin llamadas
  a Stripe Billing). El cobro real de suscripción queda `PENDIENTE` de configuración en
  Stripe Sandbox.
- Capturas del Dashboard de Stripe Sandbox: `PENDIENTE`.

## 9. Sensor biométrico, permisos y mapa

- Biometría con `local_auth` para proteger el QR: `app/lib/features/biometrics`, pruebas con
  dobles. Prueba en dispositivo con huella registrada: `PENDIENTE`.
- Mapa nativo con `google_maps_flutter`: código existente en `features/location`. Activación
  de facturación de Maps: no autorizada; las coordenadas reales de la cafetería son
  `PENDIENTE` de confirmación.

## 10. Resultados de pruebas

- `flutter analyze`, `flutter test` y `node --test`: resultados en el informe de implementación
  (`/tmp/claude-1000/-home-andresmonjaras-orca-workspaces-finanzas-familiares-claude-planb-lincefood/2b1aae03-024b-4568-9045-8246717e73ed/scratchpad/claude_implementacion_report.md`).
- Pruebas de integración en dispositivo Android: `PENDIENTE` de resultado final y fecha.
- Capturas, evidencias de cámara y biometría: `PENDIENTE`.
- Limitaciones de FCM: la entrega depende de conectividad, permisos y restricciones del
  sistema; no se promete entrega garantizada.

## 11. Conclusiones, pendientes y aportaciones

- Conclusiones: `PENDIENTE` de cierre tras las pruebas en dispositivo.
- Pendientes para producción: suscripciones con Stripe Billing, notificación automática por
  cambio de estado (requiere aprobación docente), coordenadas y horarios reales, despliegue
  de reglas, emulador de Firebase, APK de release.
- Referencias: plan maestro y documentación oficial de cada SDK.
- Aportaciones individuales: `PENDIENTE` (registrar contribución de cada integrante).
