-- Proyecto: E-commerce Shopping Cart Abandonment
-- Dataset: Ecommerce_Cart (BigQuery)
-- Reemplazar el prefijo del dataset por el propio antes de correr.

-- 1. Tasa de abandono de carritos (KPI principal)
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_tasa_abandono` AS
SELECT
    COUNT(*) AS total_carritos,
    SUM(abandoned) AS carritos_abandonados,
    ROUND(100.0 * SUM(abandoned) / COUNT(*), 2) AS tasa_abandono_pct
FROM `Ecommerce_Cart.Cart_Events`;

-- 2. Abandono segmentado por duración de sesión
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_abandono_por_duracion_sesion` AS
SELECT
    instancia_sesion,
    carritos_abandonados,
    ROUND(100.0 * carritos_abandonados / SUM(carritos_abandonados) OVER (), 2) AS pct_del_total_abandonado
FROM (
    SELECT
        CASE
            WHEN session_minutes < 5 THEN '01 - Menos de 5 min'
            WHEN session_minutes < 15 THEN '02 - 5 a 15 min'
            WHEN session_minutes < 30 THEN '03 - 15 a 30 min'
            ELSE '04 - Más de 30 min'
        END AS instancia_sesion,
        COUNT(*) AS carritos_abandonados
    FROM `Ecommerce_Cart.Cart_Events`
    WHERE abandoned = 1
    GROUP BY instancia_sesion
)
ORDER BY instancia_sesion;

-- 2b. Abandono segmentado por device
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_abandono_por_device` AS
SELECT
    device,
    total_carritos,
    carritos_abandonados,
    tasa_abandono_pct,
    ROUND(100.0 * carritos_abandonados / SUM(carritos_abandonados) OVER (), 2) AS pct_del_total_abandonado
FROM (
    SELECT
        cu.device,
        COUNT(*) AS total_carritos,
        SUM(c.abandoned) AS carritos_abandonados,
        ROUND(100.0 * SUM(c.abandoned) / COUNT(*), 2) AS tasa_abandono_pct
    FROM `Ecommerce_Cart.Cart_Events` c
    JOIN `Ecommerce_Cart.Customers` cu ON cu.customer_id = c.customer_id
    GROUP BY cu.device
)
ORDER BY tasa_abandono_pct DESC;

-- 2c. Facturación bruta total (solo compras concretadas)
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_facturacion_bruta_total` AS
SELECT ROUND(SUM(cart_value), 2) AS facturacion_bruta_total
FROM `Ecommerce_Cart.Cart_Events`
WHERE abandoned = 0;

-- 2d. Abandono por rango de valor del carrito
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_abandono_por_valor_carrito` AS
SELECT
    rango_valor_carrito,
    total_carritos,
    carritos_abandonados,
    tasa_abandono_pct,
    ROUND(100.0 * carritos_abandonados / SUM(carritos_abandonados) OVER (), 2) AS pct_del_total_abandonado
FROM (
    SELECT
        CASE
            WHEN cart_value < 300 THEN '01 - Menos de $300'
            WHEN cart_value < 600 THEN '02 - $300 a $600'
            WHEN cart_value < 900 THEN '03 - $600 a $900'
            ELSE '04 - Más de $900'
        END AS rango_valor_carrito,
        COUNT(*) AS total_carritos,
        SUM(abandoned) AS carritos_abandonados,
        ROUND(100.0 * SUM(abandoned) / COUNT(*), 2) AS tasa_abandono_pct
    FROM `Ecommerce_Cart.Cart_Events`
    GROUP BY rango_valor_carrito
)
ORDER BY rango_valor_carrito;

-- 2e. Abandono por traffic source
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_abandono_por_traffic_source` AS
SELECT
    traffic_source,
    total_carritos,
    carritos_abandonados,
    tasa_abandono_pct,
    ROUND(100.0 * carritos_abandonados / SUM(carritos_abandonados) OVER (), 2) AS pct_del_total_abandonado
FROM (
    SELECT
        traffic_source,
        COUNT(*) AS total_carritos,
        SUM(abandoned) AS carritos_abandonados,
        ROUND(100.0 * SUM(abandoned) / COUNT(*), 2) AS tasa_abandono_pct
    FROM `Ecommerce_Cart.Cart_Events`
    GROUP BY traffic_source
)
ORDER BY tasa_abandono_pct DESC;

-- 2f. Clientes por género y dispositivo
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_clientes_por_genero_device` AS
SELECT
    device,
    gender,
    COUNT(*) AS cantidad_clientes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY device), 2) AS pct_dentro_device
FROM `Ecommerce_Cart.Customers`
GROUP BY device, gender
ORDER BY device, gender;

-- 3. Facturación bruta por categoría (solo compras concretadas)
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_facturacion_por_categoria` AS
SELECT
    p.category,
    ROUND(SUM(c.cart_value), 2) AS facturacion_total
FROM `Ecommerce_Cart.Cart_Events` c
JOIN `Ecommerce_Cart.Products` p ON p.product_id = c.product_id
WHERE c.abandoned = 0
GROUP BY p.category
ORDER BY facturacion_total DESC;

-- 4. Top 3 productos por facturación, dentro de cada categoría
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_top3_facturacion_por_categoria` AS
SELECT category, product_id, product_name, facturacion, rn
FROM (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        ROUND(SUM(c.cart_value), 2) AS facturacion,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(c.cart_value) DESC) AS rn
    FROM `Ecommerce_Cart.Cart_Events` c
    JOIN `Ecommerce_Cart.Products` p ON p.product_id = c.product_id
    WHERE c.abandoned = 0
    GROUP BY p.category, p.product_id, p.product_name
)
WHERE rn <= 3
ORDER BY category, rn;

-- 5. Top 3 productos por unidades vendidas, dentro de cada categoría
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_top3_unidades_por_categoria` AS
SELECT category, product_id, product_name, unidades_vendidas, rn
FROM (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(c.items_in_cart) AS unidades_vendidas,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(c.items_in_cart) DESC) AS rn
    FROM `Ecommerce_Cart.Cart_Events` c
    JOIN `Ecommerce_Cart.Products` p ON p.product_id = c.product_id
    WHERE c.abandoned = 0
    GROUP BY p.category, p.product_id, p.product_name
)
WHERE rn <= 3
ORDER BY category, rn;

-- 6. Precio promedio del carrito (todos los carritos)
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_precio_promedio_carrito` AS
SELECT ROUND(AVG(cart_value), 2) AS precio_promedio_carrito
FROM `Ecommerce_Cart.Cart_Events`;

-- 7. Minutos promedio por sesión
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_minutos_promedio_sesion` AS
SELECT ROUND(AVG(session_minutes), 2) AS minutos_promedio_sesion
FROM `Ecommerce_Cart.Cart_Events`;

-- 7b. Items promedio por carrito
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_items_promedio_carrito` AS
SELECT ROUND(AVG(items_in_cart), 2) AS items_promedio_carrito
FROM `Ecommerce_Cart.Cart_Events`;

-- 8. Ciudades por facturación y cantidad de clientes
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_ciudades` AS
SELECT
    cu.city,
    COUNT(DISTINCT cu.customer_id) AS cantidad_clientes,
    ROUND(SUM(CASE WHEN c.abandoned = 0 THEN c.cart_value ELSE 0 END), 2) AS facturacion_total,
    ROUND(SUM(CASE WHEN c.abandoned = 0 THEN c.cart_value ELSE 0 END) / COUNT(DISTINCT cu.customer_id), 2) AS ticket_promedio_cliente
FROM `Ecommerce_Cart.Customers` cu
LEFT JOIN `Ecommerce_Cart.Cart_Events` c ON c.customer_id = cu.customer_id
GROUP BY cu.city
ORDER BY facturacion_total DESC;

-- 9. Facturación por device
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_facturacion_por_device` AS
SELECT
    cu.device,
    ROUND(SUM(c.cart_value), 2) AS facturacion_total
FROM `Ecommerce_Cart.Cart_Events` c
JOIN `Ecommerce_Cart.Customers` cu ON cu.customer_id = c.customer_id
WHERE c.abandoned = 0
GROUP BY cu.device
ORDER BY facturacion_total DESC;

-- 10. Facturación bruta por mes
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_facturacion_por_mes` AS
SELECT
    FORMAT_DATE('%Y-%m', DATE(cart_date)) AS mes,
    ROUND(SUM(cart_value), 2) AS facturacion_total
FROM `Ecommerce_Cart.Cart_Events`
WHERE abandoned = 0
GROUP BY mes
ORDER BY mes;

-- 11. Clientes y facturación por traffic_source
CREATE OR REPLACE VIEW `Ecommerce_Cart.kpi_traffic_source` AS
SELECT
    traffic_source,
    COUNT(DISTINCT customer_id) AS clientes,
    ROUND(SUM(CASE WHEN abandoned = 0 THEN cart_value ELSE 0 END), 2) AS facturacion_total
FROM `Ecommerce_Cart.Cart_Events`
GROUP BY traffic_source
ORDER BY facturacion_total DESC;
