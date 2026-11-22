# Plan de trabajo del equipo · Lincefood

**Fecha de corte:** 22 de noviembre de 2026.
**Base de trabajo:** rama `main`, commit `003ff94`. Todo lo integrado de hoy ya está aquí.
**Responsable técnico:** Andrés (revisión, integración, despliegues y pruebas en el teléfono).

Este documento reemplaza al checklist anterior. Describe qué existe, qué falta y quién hace cada parte.

---

## 1. Cómo trabajar

1. Partir siempre de `main` actualizado: `git pull origin main`.
2. Crear una rama por tarea: `git checkout -b <nombre>-<tarea>`, por ejemplo `omar-carrito-pago`.
3. Hacer commits pequeños, con mensaje claro en español.
4. Antes de abrir PR, ejecutar:
   - `cd app && flutter analyze && flutter test`
   - `cd functions && npm test`
   - `cd storage-tests && npm test` (requiere emulador de Firebase)
5. Abrir PR hacia `main`. Andrés revisa e integra.
6. No tocar archivos de la parte de otro compañero sin avisar. Si hace falta, pedirlo en el PR.

### Archivos locales que NO van a Git

| Archivo | Para qué | Cómo obtenerlo |
|---|---|---|
| `app/dart_defines.local.json` | Claves de Firebase, Stripe y el ID de cliente web de Google | Copiar `app/config/firebase.example.json` y rellenar con los valores del proyecto. Pedir a Andrés los valores |
| `app/android/app/google-services.json` | Configuración Android de Firebase. Es opcional: sin él la app compila igual | Firebase Console → Configuración del proyecto → Tus apps → Android, o `firebase apps:sdkconfig ANDROID <APP_ID> --project lincefood-app --out app/android/app/google-services.json` |
| `app/android/local.properties` | Clave de Google Maps (`GOOGLE_MAPS_API_KEY`) | Ver `docs/mapa.md`. Pedir la clave a Andrés |

**Nunca** subir claves, tokens, contraseñas ni estos archivos al repositorio ni a un chat.

### SHA-1 de depuración

Google Sign-In solo funciona si el SHA-1 de tu máquina está registrado en Firebase:

```
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Envía ese SHA-1 a Andrés para registrarlo.

---

## 2. Asignaciones

| Persona | Área | Enfoque |
|---|---|---|
| **Omar** | **Cliente**: el estudiante | Menú, carrito, pago, seguimiento de pedidos, mapa, membresías, perfil y diseño |
| **Jesús** | **Trabajador**: quien toma los pedidos en la cafetería | Pedidos entrantes, estados, rechazo con nota, QR, biometría y gestión de productos |
| **Andrés** | Transversal | Autenticación con proveedores, Stripe, Firebase (reglas y funciones), integración, pruebas y rúbrica |

> La asignación es propuesta. Si Omar y Jesús prefieren intercambiar áreas, dígalo en el grupo y se actualiza este documento.

---

## 3. Parte de Omar: cliente

### Ya existe (revisar y probar en el teléfono)

| Función | Estado | Pendiente |
|---|---|---|
| Menú por categorías, búsqueda y detalle | Hecho | Probar búsqueda y detalle en el teléfono |
| Fotos del menú desde Storage | Hecho en código | Activar `MENU_IMAGES_ENABLED` y subir las fotos con licencia |
| Caché de imágenes sin conexión | Hecho con prueba | Verificar en modo avión con imágenes ya vistas |
| Variantes y complementos | Hecho | Probar con un producto real |
| Carrito y pago «Pagar $X MXN» (Stripe PaymentSheet) | Hecho | Probar pago con 4242 y rechazo con 4000 0000 0000 0002 |
| Mensajes de pago rechazado, abandonado y sin red | Hecho | Verificar que el mensaje sea claro |
| Seguimiento horizontal de pedidos | Hecho | Probar con un pedido real de cada estado |
| Deslizar para ocultar pedidos terminados, con deshacer | Hecho | Probar en el teléfono |
| Selector de avatar (neutro, lince masculino, lince femenino) | Hecho | Solo para cuentas con correo verificado |
| Mapa del Campus II con cobertura provisional | Hecho | Falta la clave de Google Maps |
| Botón «Cómo llegar» | Pendiente | Hoy solo copia la dirección. Falta añadir `url_launcher` (requiere autorizar la dependencia) |
| Planes semanal, mensual y de por vida | Hecho en código | Depende de que `stripeWebhook` esté desplegada (ya lo está) y de probar un cobro completo |
| Preferencias de notificaciones y consejos | Hecho | Probar frecuencia diaria y cada hora |

### Tareas nuevas para Omar

1. **Probar el flujo completo del cliente** con una cuenta de correo nueva: registro, verificación, menú, pedido, pago, seguimiento y recogida. Documentar cada paso con captura.
2. **Añadir «Cómo llegar»** con `url_launcher`. Pedir autorización antes de añadir la dependencia.
3. **Revisar accesibilidad y modo oscuro** en todas las pantallas del cliente (360, 768 y 1280 px).
4. **Mostrar el estado de la membresía** en Perfil: plan actual y fecha de vencimiento o «de por vida».
5. **Mensajes de error claros** en todo el flujo de pago y de pedidos.

---

## 4. Parte de Jesús: trabajador que toma pedidos

### Ya existe

| Función | Estado | Pendiente |
|---|---|---|
| Pantalla de personal con pedidos entrantes en vivo | Hecho | Probar con una cuenta de personal |
| Cambio de estado: confirmado, preparando, listo, entregado | Hecho | Probar el flujo completo |
| Rechazo con nota obligatoria (reembolso, aviso al estudiante, nota visible 10 minutos) | Hecho | Probar en el emulador con un pedido pagado |
| Cancelación de pedidos | Hecho | Probar el reembolso en Stripe Sandbox |
| QR de recogida de un solo uso y escaneo por el personal | Hecho | Probar que un segundo escaneo se rechace |
| Biometría antes de mostrar el QR | Hecho | Probar con huella real |
| Panel de superadmin: usuarios, roles, promociones, becas y auditoría | Hecho | Solo para administración. No se amplía en este plan |

### Tareas nuevas para Jesús: gestión de productos de la cafetería

Este es el trabajo principal de la parte del personal. Solo lo necesario para una cafetería real.

1. **Crear producto**
   - Nombre, descripción, categoría (desayunos, comidas, bebidas, snacks…).
   - Precio en MXN y porción o cantidad (gramos, mililitros o piezas).
   - Variantes y complementos sencillos, por ejemplo tamaño o extra de queso.
   - Disponible o agotado.
2. **Foto del producto**: tomarla con la cámara o elegirla de la galería, comprimirla y subirla a **Firebase Storage**. En la base de datos solo se guarda la ruta. Solo el personal puede escribir en Storage y todos los usuarios con sesión pueden leer.
3. **Editar producto**: precio, porción, foto, descripción y disponibilidad.
4. **Archivar producto** (borrado lógico): deja de aparecer en el menú, pero los pedidos antiguos siguen mostrándolo.
5. **Bitácora**: cada acción de personal guarda quién, qué, cuándo, valores antes y después, y motivo si aplica. El estudiante no puede leerla.
6. **Cancelación por el estudiante**: el personal la ve con la etiqueta «Cancelado por el estudiante», con la hora y el motivo si lo dio.

### Reglas que deben cumplirse

- Solo cuentas con claim de personal escriben productos y bitácora.
- Precios validados en el servidor: positivos y con campos obligatorios.
- Todo se guarda en Firebase, no solo en el teléfono.
- No se crea personal desde la app: el alta de nuevo personal lo hace el administrador.

---

## 5. Lo compartido y lo que lleva Andrés

| Tema | Responsable | Estado |
|---|---|---|
| Reglas de Realtime Database y Storage | Andrés | Publicadas hoy |
| Funciones de Firebase | Andrés | 20 desplegadas. 9 pendientes por cuota de CPU de la región |
| `stripeWebhook` | Andrés | Desplegada con membresías. Falta revisar endpoint y eventos en el Dashboard de Stripe |
| Google Sign-In | Andrés | Funciona con el ID de cliente web. Falta probarlo en el teléfono |
| GitHub Sign-In | Andrés o Jesús | Falta crear la OAuth App en GitHub y configurarla en Firebase Authentication |
| Clave de Google Maps | Andrés | Pendiente. Restringida a `com.lincefood.app` |
| Pagos inconsistentes de Sandbox | Andrés | `LF-YA18I63M` cobrado y pendiente; `LF-IEIED0RD` cancelado sin reembolso |
| Rúbrica del profesor | Todos | Ver sección 6 |
| Reporte técnico y problemática | Equipo | Ver `docs/reporte_tecnico.md` |

---

## 6. Rúbrica del profesor: qué le toca a quién

| Requisito | Quién |
|---|---|
| Firebase Realtime Database | Andrés |
| Autenticación con correo | Andrés |
| Dos proveedores sociales (Google y GitHub) | Andrés y Jesús |
| Notificaciones en segundo plano, primer plano y app cerrada | Andrés |
| Notificaciones por topics | Andrés |
| Storage multimedia (fotos del menú y del producto) | Omar (menú) y Jesús (productos) |
| Caché offline de imágenes | Omar |
| Biometría | Jesús |
| Pago completo con Stripe Sandbox | Omar (cliente) y Andrés (webhook) |
| Mapa nativo | Omar |
| Suscripción con 3 modalidades | Omar (pantalla) y Andrés (cobro y webhook) |
| Diseño responsivo, tema y tipografía | Omar |
| Widget avanzado | Hecho (Andrés) |
| Estabilidad (−20 % si falla) | Todos. Recorrido completo antes de presentar |
| Problemática fundamentada | Equipo: observación en fila y minutos de espera |
| Reporte técnico | Equipo |
| PR a `main` con commits de cada integrante | Todos |

---

## 7. Pruebas antes de cada PR

- [ ] `flutter analyze` sin incidencias.
- [ ] `flutter test` en verde.
- [ ] `npm test` en `functions` en verde.
- [ ] Pruebas de reglas en verde.
- [ ] Probado en el teléfono con la tarea descrita en su sección.
- [ ] Sin claves ni archivos locales en el commit.

## 8. Orden sugerido

1. **Primero:** configurar el entorno local (sección 1) y pedir los valores a Andrés.
2. **Omar:** probar el flujo completo del cliente y reportar lo que falle.
3. **Jesús:** probar el flujo de personal con el emulador y después crear la gestión de productos.
4. **Ambos:** PR pequeños, revisados por Andrés.
5. **Al final:** recorrido completo con dos cuentas y reporte para la rúbrica.
