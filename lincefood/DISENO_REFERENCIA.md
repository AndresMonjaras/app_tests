# Lincefood · referencias visuales y de flujo

**Fecha:** 22 de noviembre de 2026
**Uso:** referencia de diseño para el Plan A (tema, navegación) y el Plan B (pantallas de pedido). No se copian nombres, logotipos, fotos ni textos de los prototipos.

## 1. Prototipos recibidos

| Referencia | Qué aporta a Lincefood | Qué se descarta |
|---|---|---|
| **Buono** (recetas, naranja cálido) | Paleta cálida que encaja con el A.5 del plan; pestañas superiores; hoja inferior de filtros (ingredientes, dificultad, tiempo); tarjetas de categoría con foto | Red social («Tu red», seguidores, publicaciones): fuera del alcance del plan |
| **FrescoListo** (compra de comestibles) | Flujo completo: inicio, catálogo, detalle, carrito, pago, seguimiento del pedido y perfil. Barra inferior de cinco destinos. Pantalla de seguimiento con pasos (pagado, preparando, listo, entregado), que coincide con los estados del B.2 | Planificación de comidas, compras grupales y recetas: no son requisitos de la cafetería |
| **Borcelle** (menú de café) | Menú por categorías con precio y tamaños (CH / GDE); opciones de leche; precios en pesos. Es el modelo más cercano a los productos del B.4 | Logotipo, ilustraciones y precios reales: solo se usa la estructura |

## 2. Pantallas de Lincefood derivadas (requisito B.1)

| Pantalla de Lincefood | Referencia | Requisito |
|---|---|---|
| Inicio y menú por categorías, con estado de la cafetería | FrescoListo 1, Buono 2 | B.1, R20 |
| Detalle de producto con tamaño, opciones y cantidad | Borcelle, FrescoListo 3 | B.1 |
| Carrito con totales | FrescoListo 5 | B.1 |
| Confirmación previa al pago (aviso de pedido no editable) | FrescoListo 6 | B.1, R34 |
| Mis pedidos y seguimiento por pasos | FrescoListo 7 | B.1, B.2 |
| Recogida con QR cuando está listo | Propuesta propia | B.7 |
| Perfil con avatar y menú de cuenta | Buono 7, FrescoListo 8 | A.4 |
| Onboarding de tres pantallas | Propuesta propia | A.5 |

## 3. Decisiones de diseño

- **Paleta:** tonos naranja y crema, con variante oscura, para cumplir el A.5 («paleta cálida» con contraste accesible en claro y oscuro). Los colores exactos se definen en el tema, no se copian de Buono.
- **Navegación:** barra inferior en teléfono (`NavigationBar`) y riel lateral en ventanas anchas (`NavigationRail`), como pide el A.5.
- **Variantes de producto:** Borcelle muestra que un producto puede tener tamaños y precios distintos. El esquema del B.4 (`priceCents` único) no lo cubre. Propuesta: `variants` con `{ label, priceCents }` por producto, y el pedido guarda el precio de la variante elegida como snapshot.
- **Seguimiento del pedido:** la línea de tiempo de FrescoListo sirve de base para los estados `paid`, `confirmed`, `preparing`, `ready` y `delivered`. No debe mostrar botón de cancelar en ningún paso (regla B.2).
- **Widget avanzado (R21):** la línea de tiempo animada del seguimiento o un `SliverPersistentHeader` con categorías fijas en el menú. Se confirma con el docente antes de elegir.

## 4. Pendientes

- Confirmar con el responsable si las tres referencias son solo inspiración o si el diseño final debe ser propio. Por el plan, debe ser propio.
- Definir los colores exactos y la tipografía (Plus Jakarta Sans ya está en el proyecto anterior, con licencia OFL).
- Añadir `variants` al esquema de productos y a la semilla, solo después de aprobarlo.
