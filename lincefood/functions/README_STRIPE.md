# Configuración de pagos con Stripe

La clave secreta y el secreto de firma se guardan en Secret Manager de Firebase Functions. Cárgalos de forma interactiva en el proyecto correcto:

    firebase functions:secrets:set STRIPE_SECRET_KEY
    firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

La app recibe únicamente la clave publicable al compilarse o ejecutarse:

    flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=...

No guardes valores de claves en el repositorio, archivos de configuración, comandos compartidos, registros o reportes. El servidor lee STRIPE_SECRET_KEY y STRIPE_WEBHOOK_SECRET mediante defineSecret; la app lee STRIPE_PUBLISHABLE_KEY mediante String.fromEnvironment.

Las funciones usan la región us-central1, el proyecto lincefood-app y la instancia RTDB lincefood-app-default-rtdb. La cuenta debe tener el plan Blaze para desplegar Cloud Functions y habilitar Secret Manager. No se han cargado secretos ni se han desplegado funciones durante esta implementación.
