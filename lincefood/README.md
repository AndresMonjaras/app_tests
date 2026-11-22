# Lincefood

Proyecto Flutter para pedidos anticipados y recogida en cafetería universitaria.
El cliente Android está en `app/`; Firebase Functions, reglas, semillas y
Hosting se administran desde esta raíz.

## Firebase de desarrollo

La configuración documentada usa el proyecto Firebase `lincefood-app` y el
identificador Android `com.lincefood.app`. `.firebaserc` selecciona ese ID por
defecto para Firebase CLI. No se han desplegado reglas, funciones ni semillas.

| Servicio | Estado local | Pendiente remoto |
|---|---|---|
| Authentication | Flujos email, Google y Facebook implementados | Activar/verificar proveedores y OAuth |
| Realtime Database | Reglas y semilla presentes | Crear instancia y probar reglas |
| Storage | Reglas privadas de avatar | Requiere habilitar Storage y plan Blaze |
| Cloud Functions | Callable de elegibilidad de avatar | Instalar, probar y desplegar con autorización |
| FCM | Listener y preferencias de temas implementados | Configurar y probar en Android real |
| Hosting | Privacidad y eliminación de datos | Despliegue pendiente |

Cloud Storage para Firebase requiere Blaze desde el 3 de febrero de 2026. No
actives facturación sin autorización del responsable del proyecto. No copies
secretos ni configuraciones del repo `finanzas-familiares`.

## Probar servicios locales

Desde la raíz del repo, con Firebase CLI y Java instalados, instala primero las
dependencias de Functions:

```bash
npm install --prefix functions
firebase emulators:start --project demo-lincefood --only auth,database,storage,functions
```

En otra terminal, desde `app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/firebase.emulator.json --dart-define=FIREBASE_EMULATORS=true
```

Para Android Emulator se usa `10.0.2.2` como host del emulador. En teléfono
físico define `FIREBASE_EMULATOR_HOST` con la IP LAN del equipo. OAuth y FCM
no se cubren con estos emuladores.

## Estructura

- `app/`: aplicación Flutter con Riverpod.
- `firebase/`: reglas RTDB/Storage y datos seed.
- `functions/`: callable de servidor para proteger cambios de avatar.
- `hosting/`: privacidad y solicitud de eliminación de datos.
- `docs/auditoria_plan_a.md`: integración, decisiones y trabajo remoto pendiente.
