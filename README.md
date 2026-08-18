# E-commerce Cart Abandonment Analysis

> Por qué el 50,67% de los carritos de un e-commerce se abandonan — y por qué la respuesta no es el dispositivo, el canal ni el precio, sino el tiempo de sesión.

**Stack:** BigQuery · SQL · Python (Google Cloud BigQuery + gspread) · Google Sheets · Looker Studio

---

## 🎯 Problema
Un e-commerce con 15.000 carritos iniciados por 1.000 clientes no tenía forma de saber, con datos, en qué condiciones se concentraba el abandono de carrito (50,67% del total). Sin ese diagnóstico, cualquier esfuerzo de retención en el checkout era una apuesta a ciegas.

## 🔍 Enfoque
El dataset no incluía etapas de embudo (product view → checkout → pago), así que en vez de forzar un análisis de funnel inexistente, se descompuso la tasa de abandono contra 4 variables de contexto disponibles — duración de sesión, dispositivo, canal de adquisición y valor del carrito — para aislar cuál explica realmente el comportamiento.

**Pipeline:** BigQuery como warehouse → vistas modeladas en SQL → dashboard de 4 páginas en Looker Studio → script en Python que automatiza la carga de datos nuevos desde Google Sheets a BigQuery de forma idempotente.

## 📊 Hallazgos clave
- Tasa de abandono general: **50,67%** (7.600 de 15.000 carritos)
- La **duración de sesión** es, por lejos, el único factor que diferencia el abandono: las sesiones de más de 30 min concentran el **51,7%** de todo el abandono, contra apenas 6,7% en sesiones de menos de 5 min
- **Dispositivo, canal de adquisición y valor del carrito no explican el abandono** — diferencias menores a 2 puntos porcentuales entre segmentos
- **Mobile factura más que Desktop** ($2.330.713 vs $2.196.786) pese a una tasa de abandono levemente superior
- **Fashion** es la categoría que más factura ($1.652.365,87), seguida de Home ($1.477.818,37) y Electronics ($1.397.315,33)
- Facturación bruta total (compras concretadas): **$4.527.499,57**

## ✅ Recomendación
No segmentar los esfuerzos de retención por dispositivo o canal. Priorizar intervenciones de UX/soporte (chat proactivo, simplificación del checkout) dirigidas específicamente a sesiones que superan los 15-20 minutos, que es donde se concentra el riesgo real de abandono.

## 📂 Estructura del repo
```
├── data/
│   ├── cart_events.csv   # Eventos de carrito (15.000 filas)
│   ├── customers.csv     # Clientes (1.000 filas)
│   └── products.csv      # Catálogo de productos (400 filas)
├── sql/
│   └── views.sql       # Vistas SQL sobre BigQuery (KPIs, segmentaciones, rankings)
├── scripts/
│   └── ingest.py        # Carga idempotente Google Sheets → BigQuery
├── dashboard/
│   └── capturas/         # Capturas de las 4 páginas del dashboard
└── README.md
```

## 🛠️ Cómo reproducirlo
```bash
pip install -r requirements.txt
python scripts/ingest.py   # carga idempotente Google Sheets -> BigQuery (staging + MERGE)
```
Las vistas de `sql/views.sql` están escritas contra un dataset `Ecommerce_Cart` en BigQuery — para correrlas sobre otro proyecto, reemplazar el prefijo del dataset por el propio. `ingest.py` es una reconstrucción de referencia del pipeline original: ajustar credenciales, IDs y esquema de columnas antes de correrlo.

## 🔗 Dashboard en vivo
[Looker Studio – E-commerce Cart Abandonment](https://datastudio.google.com/s/uHUmk97qqkc)

---
**Autor:** Facundo Wattson Montero · [Portfolio](https://facuwattsonm.github.io/facundo-portfolio/)
