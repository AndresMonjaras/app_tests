# Lincefood App

Base Flutter para la aplicación de cafetería. La interfaz usa Riverpod y separa
las reglas del dominio de las pantallas. El catálogo incluye repositorios de
memoria y una interfaz para Realtime Database.

## Configuración local

Firebase no incluye claves en este repositorio. La plantilla
`lib/firebase_options.example.dart` contiene marcadores `TODO_FILL`; la app
muestra un mensaje en español mientras Firebase no tenga configuración local.
El archivo `lib/firebase_options.dart` está excluido por `.gitignore`.

## Integraciones pendientes

- Completar Firebase Authentication y Realtime Database con la configuración
  del proyecto.
- Implementar lectura real del catálogo desde Realtime Database.
- Integrar Stripe, FCM, Maps, sensores, almacenamiento y cámara después de
  definir sus servicios y configuración.
- Completar la lógica de las pantallas placeholder de autenticación, catálogo,
  carrito, pedidos y perfil.

Las pruebas unitarias cubren reglas de carrito, variantes y estados de pedido;
la prueba de widget verifica los títulos del onboarding.
