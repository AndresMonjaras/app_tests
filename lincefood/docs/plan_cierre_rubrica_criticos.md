# Plan de cierre de puntos críticos de la rúbrica

**Repositorio de trabajo:** `app_tests`
**Alcance:** resolver y verificar los puntos críticos de la rúbrica del proyecto.
**Control de versiones:** Codex revisa los cambios y es el único que realiza commits, push o merge.

Cada punto tiene una ruta recomendada única. El plan excluye superadmin. Las integraciones externas se probarán con la configuración autorizada del equipo, sin subir secretos al repositorio.

| Fase | Punto crítico | Decisión recomendada | Criterio para darlo por cerrado |
|---|---|---|---|
| **1. Preparar evidencia y entorno** | Firebase, credenciales y estado de despliegue | Usar el proyecto Firebase autorizado del equipo y verificar la configuración local sin subir secretos. Confirmar en consola qué reglas, funciones y Storage están desplegados. | App conectada al proyecto correcto; reglas y funciones activas identificadas; no se versionan claves. |
| **2. Notificaciones** | Recepción con app abierta, en segundo plano y cerrada; suscripción a topics | Mantener Firebase Cloud Messaging, sus listeners y topics existentes. Completar la configuración en consola y probar cada estado en el teléfono con una notificación controlada. | Evidencia de recepción en los tres estados y de suscripción a un topic. |
| **3. Firebase Storage** | Carga y visualización de imágenes | Usar Storage para las imágenes del menú, activar el flag de imágenes con la configuración existente y cargar imágenes de prueba autorizadas. | Imagen visible desde Storage en el catálogo; permisos y rutas comprobados sin exponer credenciales. |
| **4. Caché de imágenes** | Visualización de imágenes previamente cargadas sin conexión | Conservar `cached_network_image` y verificar en el dispositivo: cargar una imagen, desconectar la red y confirmar que permanece visible. | Captura o registro de la imagen visible sin conexión tras haberse almacenado en caché. |
| **5. Mapa nativo** | Mostrar el establecimiento en un mapa nativo | Usar `google_maps_flutter` con la clave autorizada y las coordenadas verificadas de la cafetería. Validar el mapa en el dispositivo. | Mapa nativo carga y muestra el establecimiento; no depende de WebView. |
| **6. Sensor** | Uso funcional de un sensor del dispositivo | Usar la biometría existente para proteger la revelación del QR de recogida. Probar con biometría configurada en el teléfono. | El QR se muestra tras autenticación biométrica y permanece protegido si la autenticación falla. |
| **7. Pago Sandbox** | Pago de producto, captura/validación segura y manejo de resultado | Mantener Stripe PaymentSheet en modo de prueba. Ejecutar un pago aprobado y uno rechazado; no capturar datos de tarjeta directamente en formularios propios. | Se demuestra el resultado aprobado, el rechazo y la actualización del pedido desde el servidor/webhook. |
| **8. Tres planes o modalidades** | Requisito de planes del profesor y discrepancia de precios | Presentar tres modalidades prepagadas dentro del flujo Sandbox actual, sin añadir Stripe Billing recurrente. Usar RTDB como única fuente de precios y alinear el helper con esos valores. | Las tres modalidades aparecen y el servidor cobra los precios de RTDB en Sandbox. |
| **9. Reporte técnico** | Evidencia académica incompleta | Completar el reporte con resultados observados: problemática, arquitectura, sensor, pruebas, capturas, conclusiones y contribuciones. Marcar como pendientes las pruebas aún no realizadas. | No quedan afirmaciones técnicas sin evidencia ni campos pendientes de información disponible. |
| **10. Estabilidad y cierre** | Riesgo de fallos durante evaluación | Ejecutar una ronda final secuencial: análisis y pruebas automatizadas, instalación en teléfono y recorrido de autenticación, catálogo, pago, notificación, mapa y QR. No correr builds simultáneas. | Resultados registrados y recorrido completo sin errores bloqueantes. |

## Secuencia de ejecución

1. **Confirmar configuración de Firebase y Stripe Sandbox.** Resolver primero accesos, flags, claves locales y estado de despliegue.
2. **Cerrar las verificaciones del teléfono:** FCM, Storage, caché, mapa y biometría.
3. **Alinear precios de las tres modalidades** entre RTDB y el helper de planes.
4. **Probar el flujo de compra Sandbox** con pago aprobado y rechazado.
5. **Completar el reporte** con evidencia real de las verificaciones.
6. **Realizar la ronda final de estabilidad** y registrar resultados antes de integrar cambios.

## Fuera de este plan

- No se implementará superadmin.
- No se incorporará reparto en Campus 2; no es necesario para cerrar los puntos críticos de esta rúbrica.
- Los accesos sociales Google/Facebook continúan con los compañeros responsables. Deberán quedar probados para la entrega, pero no forman parte de este bloque de trabajo.
