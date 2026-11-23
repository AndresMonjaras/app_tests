# Plan de implementación — Bloque C

**Versión:** 1.0
**Fecha:** 22-nov-2026
**Repositorio activo:** `app_tests/lincefood/`
**Base contrastada:** `origin/main` en `08998312eec13796fd147db4b4cc3e1ffd24ced2`.
**Estado:** plan de trabajo; no implica cambios de código ni despliegue.
**Alcance:** sección 3 de la guía del profesor: arquitectura, UI/UX y manejo de estado. Se excluyen los bloques A y B.

## 1. Resultado del contraste

Los análisis de Claude, Antigravity y la revisión del código coinciden en que Riverpod y el tema claro/oscuro están presentes. Los siguientes elementos necesitan trabajo o una comprobación más fuerte:

| Requisito | Estado en `origin/main` | Evidencia / observación |
|---|---|---|
| Riverpod y ausencia de `setState` / `ValueNotifier` | Implementado en código | `flutter_riverpod` y controladores Riverpod; búsqueda estática sin usos de las primitivas prohibidas. |
| Tipografía personalizada | Pendiente | El TTF y la licencia existen, pero `pubspec.yaml` no registra la fuente y `AppTheme` no la aplica. |
| Tema claro/oscuro dinámico | Implementado en código | Hay temas claro y oscuro; la preferencia de usuario se conecta al `MaterialApp`. |
| Onboarding | Parcial | Tres temas introductorios aparecen como tarjetas en una sola vista; no es una secuencia guiada de pantallas/pasos. |
| Diseño móvil/escritorio | Parcial | El catálogo cambia columnas con el ancho y autenticación limita su ancho; el shell global solo tiene `NavigationBar`, sin navegación lateral. |
| Widget avanzado | Presente, aceptación pendiente | `OrderTimeline` usa `CustomPainter`, animación y semántica, y está conectado a pedidos. No se puede probar desde el repo que el docente no lo haya cubierto en clase. `CatalogSliverView` existe, pero no está conectado a la pantalla activa. |
| Caché de imágenes sin conexión | Parcial/no verificado | Existe `CachedNetworkImage`, pero el flag de imágenes está apagado por defecto y la URL se consulta a Storage antes de cargarla. No se comprobó la recuperación tras perder conexión o reiniciar. |

La revisión de Antigravity considera cumplidos onboarding y caché por la existencia de tres pasos y `CachedNetworkImage`. Para el criterio literal de la guía, este plan los trata como parciales: la pantalla actual no pagina el onboarding y la capacidad offline no está probada ni disponible con la configuración predeterminada.

## 2. Reglas de ejecución

- Trabajar primero en `app_tests`; `app_cafeteria` queda reservado para integración futura.
- Preservar el trabajo existente de Andy. Los cambios serán acotados a los requisitos pendientes; no se rehacen módulos completos ni se reescribe historial publicado.
- Codex es el único responsable de commits, push y merge. Los agentes pueden analizar, proponer y recibir tareas de código acotadas; Codex revisa e integra.
- Claude lidera los criterios visuales y revisa onboarding y layouts. Antigravity puede hacer una revisión independiente de los cambios solicitados. Ninguno realiza operaciones Git.
- Cada criterio se reporta como código implementado, validado localmente o validado en dispositivo; no se confunden esos niveles.
- No incluir cambios de Firebase Authentication, Storage como servicio, Database o Messaging que pertenezcan al bloque B; el uso de Storage aquí solo se considera como dependencia del requisito de caché de imágenes.

## 3. Secuencia de trabajo

### Fase 0 — Proteger la base de trabajo

1. Confirmar la rama y los cambios locales antes de actualizar el checkout. Al redactar este plan, `main` está seis commits detrás de `origin/main` y `plan_omar_v1.md` / `cambio_avances.md` son documentos locales sin seguimiento.
2. Preservar esos documentos y preparar una base de trabajo que contenga `origin/main` `0899831` sin sobrescribir cambios del compañero.
3. Registrar la lista exacta de archivos autorizados para el bloque C antes de editar.

**Cierre:** los cambios de documentación están preservados, el código base queda identificado y no se pierde ni altera trabajo publicado.

### Fase 1 — Activar la tipografía personalizada

1. Declarar la fuente existente `assets/fonts/PlusJakartaSans.ttf` en `lincefood/app/pubspec.yaml`, usando la familia `Jakarta` que estaba configurada en la base local previa.
2. Aplicar `fontFamily: 'Jakarta'` en el tema compartido para que afecte a ambas variantes claro/oscuro.
3. Revisar que no haya estilos globales que vuelvan a la fuente del sistema y que el texto ampliado siga siendo legible.

**Cierre:** la fuente está declarada, se aplica desde `AppTheme` en ambas apariencias y no se rompen layouts con escala de texto ampliada.

### Fase 2 — Convertir el onboarding en una introducción guiada

1. Mantener los tres contenidos actuales, pero presentarlos como pasos navegables con progreso visible, acciones anterior/siguiente y opción de saltar.
2. Conservar el guardián y la persistencia existentes: completar o saltar debe marcar onboarding como terminado y evitar repetirlo al abrir la app.
3. Mantener la lógica de estado en Riverpod; no introducir `setState` ni `ValueNotifier`.
4. Definir los estados inicial, intermedio, final y de regreso para que los controles tengan etiquetas y orden consistentes.

**Cierre:** el usuario recorre una secuencia real de introducción, puede avanzar, retroceder o saltar, y la finalización persiste.

### Fase 3 — Completar adaptación móvil y escritorio

1. Mantener `NavigationBar` en anchos móviles y mostrar `NavigationRail` en el shell a partir del breakpoint acordado (768 px).
2. Conservar el estado de las pestañas al cambiar entre secciones y asegurar que carrito/acciones principales sigan accesibles.
3. Revisar límites de ancho, columnas y scroll de catálogo, pedidos, perfil, ubicación y carrito; evitar que el contenido se extienda sin límite en pantallas anchas.
4. Mantener compatibilidad móvil y evitar que el trabajo requiera reconstruir pantallas que ya funcionan.

**Cierre:** navegación e interfaces principales funcionan en 360 px, tablet y 1280 px sin overflow ni navegación móvil estirada en escritorio.

### Fase 4 — Garantizar el uso de imágenes previamente descargadas sin conexión

1. Revisar el ciclo actual de `imagePath` → URL de Storage → `CachedNetworkImage`; determinar cómo se resuelve la URL cuando no hay red.
2. Persistir de forma segura la referencia/URL necesaria para volver a consultar la caché local sin depender de una solicitud de red en cada apertura, o implementar una estrategia equivalente con `CacheManager`.
3. Mantener el fallback visual cuando la imagen nunca se descargó, el producto no tiene imagen o Storage no está configurado.
4. Definir cómo se habilita la función en la compilación de evaluación; no dejarla inadvertidamente apagada por el valor predeterminado del flag cuando se espere mostrar imágenes.

**Cierre:** luego de descargar imágenes con conexión, el catálogo puede mostrarlas en modo avión y tras reiniciar la app. Una primera visita sin conexión usa el fallback y no produce errores.

### Fase 5 — Acreditar el widget avanzado

1. Preparar evidencia técnica breve de `OrderTimeline`: `CustomPainter`, dibujo vectorial, interpolación animada y semántica accesible; indicar que está integrado en la vista de pedidos.
2. Solicitar al docente confirmación de que cuenta como widget avanzado no cubierto en clase. Mantenerlo como candidato principal porque ya se muestra en una pantalla real.
3. Si el docente no lo acepta, integrar `CatalogSliverView` en el catálogo activo (o implementar un candidato alternativo aprobado), en vez de presentar como evidencia un widget sin uso.

**Cierre:** queda registrado el criterio aceptado por el docente y el componente que se demostrará durante la evaluación está activo en la aplicación.

### Fase 6 — Revisión visual, accesibilidad y validación

1. Claude revisa consistencia de tipografía, jerarquía, estados, navegación y adaptación en claro/oscuro; Codex contrasta las sugerencias con el alcance y el código actual.
2. Verificar tamaños 360/768/1280 px, escalado de texto, navegación por lector de pantalla y estados del onboarding.
3. Validar caché: descargar con conexión, habilitar modo avión, cerrar/abrir la aplicación y confirmar que se muestran las imágenes ya almacenadas.
4. Revisar estáticamente que no se incorporaron `setState` ni `ValueNotifier` en código nuevo.
5. Ejecutar los análisis y pruebas pertinentes del bloque C y registrar resultados, errores y entorno. La validación de caché sin conexión requiere dispositivo/emulador con almacenamiento persistente; una prueba de widget aislada no la sustituye.

**Cierre:** criterios del bloque C trazables a evidencia, pruebas reportadas y revisión visual completada. No se afirma validación en dispositivo si no se realizó.

## 4. Prioridad y dependencias

```text
Proteger base → fuente personalizada → onboarding → shell adaptable
                         └──────────────→ revisión visual
Estrategia de caché → validación offline en dispositivo
OrderTimeline → confirmación del profesor → alternativa si la rechaza
```

Orden recomendado: Fase 0 antes de cualquier edición; Fases 1–3 en secuencia para conservar consistencia del tema y navegación; la Fase 4 puede avanzar en paralelo tras acordar la estrategia de caché; la Fase 5 requiere respuesta docente; Fase 6 cierra el bloque.

## 5. Criterios finales del bloque C

- Riverpod sigue siendo el gestor de estado y no hay usos propios de `setState` ni `ValueNotifier`.
- Plus Jakarta Sans se encuentra cargada y aplicada en el tema global.
- Onboarding presenta una secuencia guiada con persistencia de finalización.
- Navegación y vistas principales se adaptan a teléfono, tablet y escritorio.
- Un widget avanzado activo cuenta con aceptación/evidencia respecto a la rúbrica.
- Imágenes descargadas previamente se muestran sin conexión; hay fallback claro para imágenes no almacenadas.
- Los resultados estáticos, automatizados y en dispositivo se reportan por separado.
