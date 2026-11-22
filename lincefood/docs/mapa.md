# Mapa de Cafetería · Campus II

1. En Google Cloud, usa un proyecto con facturación activa y habilita **Maps SDK for Android**.
2. En **APIs y servicios → Credenciales**, crea una clave de API. En **Restricciones de aplicaciones**, elige **Aplicaciones Android**. Agrega el paquete `com.lincefood.app` y el SHA-1 del certificado que firma la app que se instalará. Si usas otra firma para desarrollo o Google Play, usa el SHA-1 correspondiente.
3. En **Restricciones de API**, selecciona únicamente **Maps SDK for Android** y guarda. [Guía oficial de configuración](https://developers.google.com/maps/documentation/android-sdk/get-api-key).
4. En `app/android/local.properties`, agrega `GOOGLE_MAPS_API_KEY=<clave restringida>`. Gradle ya pasa el valor al manifiesto. Mantén ese archivo fuera de Git.
5. Activa el mapa con `--dart-define=GOOGLE_MAPS_ENABLED=true`. La bandera es de compilación y viene desactivada. La tarjeta mantiene la dirección y el horario sin la bandera.

La semilla `firebase/seeds/menu.seed.json` incluye la cafetería y la cobertura Campus Pro. Valida en campo el punto de la cafetería y el radio provisional de 350 m. Si ya hay datos, la callable `setCafeteriaLocation` permite actualizar `location`, `deliveryCoverage` o ambos con un usuario que tenga el claim `admin`. Al guardar `location`, también se guarda `cafeteria/locationConfigured: true`.

`DeliveryLocationPicker` devuelve la ubicación y los datos del edificio mediante `onConfirmed` después de validar las coordenadas con `validateDeliveryLocation`. Se puede insertar en un contenedor desplazable. Solo envía al servidor las coordenadas para obtener el resultado de cobertura y todavía no se usa en el carrito.
