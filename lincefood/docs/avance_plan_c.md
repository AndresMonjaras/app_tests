# Avance del Plan C

## Implementado en esta etapa

### C.2 Biometría local

- Se agregó `local_auth` con autenticación exclusivamente biométrica (`biometricOnly`); cancelar o fallar no autoriza la acción.
- La preferencia de protección de QR se guarda localmente y el servicio `BiometricQrProtectionService` expone la verificación que el flujo de recogida deberá invocar antes de revelar el QR.
- Perfil muestra el ajuste y una acción de prueba cuando el sensor está disponible.
- Android usa `FlutterFragmentActivity`, permiso `USE_BIOMETRIC` y tema compatible.
- **Prueba básica ya realizada:** el usuario confirmó que el sensor funcionó durante la sesión de comprobación; se retiraron los controles temporales de preview.
- **Pendiente de B:** conectar el gate al QR real y definir el fallback de reautenticación para dispositivos sin biometría.
- **Pendiente de evidencia:** registrar rechazo/cancelación y dispositivo sin biometría; no se deben marcar aprobados por la prueba básica.

### C.3 Mapa y ubicación

- La pantalla consulta `/cafeteria/location` y valida límites de coordenadas; no contiene coordenadas predeterminadas.
- Si falta la ubicación, presenta el estado pendiente. Si hay etiqueta/dirección pero Maps no está configurado, las conserva como fallback.
- El mapa nativo y el botón opcional de ubicación del dispositivo solo se habilitan con `GOOGLE_MAPS_ENABLED=true`; el permiso se solicita al pulsar ese botón y no se almacena la ubicación del usuario.
- El usuario proporcionó el pin de Google Maps de **Cafetería 3 ITC**: `20.5409871, -100.8128506`; quedó registrado en la semilla local `firebase/seeds/menu.seed.json` con la dirección indicada por el enlace.
- El usuario configuró Maps en Google Cloud y agregó la propiedad de clave en `app/android/local.properties`.
- **Prueba básica ya realizada:** el usuario confirmó que el mapa cargó en el teléfono; se retiró la pantalla temporal que inyectaba el pin sin Firebase.
- **Pendiente:** confirmar el punto con el campus y probar ubicación denegada/sin conexión. No se importó la semilla a Firebase.

### C.4 Widget avanzado

- Se reemplazó la propuesta basada en Slivers por `OrderTimeline`, una línea de tiempo que dibuja su recorrido, nodos y marcas con `CustomPainter`; el avance del tramo activo se anima al cambiar el estado.
- Las etiquetas se mantienen como widgets semánticos independientes del canvas y anuncian si cada paso está pendiente, actual o completado.
- Se retiró `AdvancedCatalogView`: Slivers no se contarán como el widget avanzado solicitado.
- **Pendiente de B:** integrar `OrderTimeline` en el detalle real del pedido. También falta confirmar con el profesor que `CustomPainter` y la animación personalizada satisfacen el requisito de widget avanzado no visto en clase.

## Aún pendiente por dependencia

- **C.1 Planes/Stripe Billing:** depende del backend de pagos, catálogo de precios, webhooks y capacidad de recogida de B. No se creó una pantalla de precios sin flujo real.
- **C.2 QR:** sin flujo QR de B no se puede declarar completo el requisito de protección biométrica.
- **C.5–C.6:** pruebas integrales, capturas de evidencia y reporte final esperan la integración de A/B/C. Los tests locales de unidades/widgets cubren el código independiente descrito arriba.
- Las pruebas completas en dispositivo de biometría y mapas (cancelación/rechazo, permiso de ubicación denegado y pérdida de red) se posponen hasta tener integrados los flujos completos. Se retiraron los accesos temporales de preview.

## Verificación local actual

- `flutter analyze`: sin issues.
- `flutter test`: 46 pruebas pasan. Las pruebas de `OrderTimeline` cubren estados, semántica accesible, tema oscuro y avance animado; se retiraron los tests temporales de preview y del catálogo Sliver eliminado.
- `flutter build apk --debug` y `flutter build apk --release` compilan. El release actual usa firma debug según `android/app/build.gradle.kts`; requiere firma de entrega antes de distribución.
- La prueba básica de mapa y sensor en hardware fue confirmada por el usuario; falta registrar los casos negativos de la matriz.

## Configuración local de Maps 

Agrega una línea nueva al final de `app/android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=CLAVE
```

Ejecutar con la configuración Firebase local y `--dart-define=GOOGLE_MAPS_ENABLED=true`. La clave debe restringirse a `com.lincefood.app` y a la huella de firma correspondiente.
