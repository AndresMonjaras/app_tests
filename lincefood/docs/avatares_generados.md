# Avatares de perfil generados

Se añadieron tres presets ilustrados para el perfil de Lincefood. Las imágenes
se generaron con OpenAI ImageGen en el estilo animado de los avatares existentes,
se exportaron a WebP de 512 × 512 y se guardaron en `app/assets/avatars/`.

| Preset | Archivo |
| --- | --- |
| Mojarra | `mojarra.webp` |
| Rocky | `rocky.webp` |
| Buñuelos | `bunuelos.webp` |

Los tres presets aparecen en el selector de perfil y sus valores están permitidos
por la validación de `avatarPreset` en Realtime Database. Continúa aplicando la
regla existente: solo una cuenta de correo verificada puede elegir un preset.

También se cargaron copias compartidas en Firebase Storage bajo
`avatars/presets/{mojarra,rocky,bunuelos}.webp`. La regla que permite lectura
pública únicamente para WebP en esa ruta quedó en `firebase/storage.rules`, pero
su despliegue a Firebase sigue pendiente porque la cuenta no tiene
`serviceusage.services.use` (`roles/serviceusage.serviceUsageConsumer`). Las
copias empaquetadas en el APK siguen disponibles mientras se habilita ese permiso.
