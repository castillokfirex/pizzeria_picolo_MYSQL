-- =====================================================================
-- PROYECTO: Sistema de Gestión de Pedidos y Domicilios
-- EMPRESA : Pizzería Don Piccolo
-- ARCHIVO : vistas.sql
-- OBJETIVO: Vistas (CREATE VIEW) que simplifican los reportes más
--           consultados por el negocio, evitando repetir JOINs
--           complejos cada vez que se necesita esta información.
--
-- REQUISITO: ejecutar database.sql, funciones.sql y triggers.sql antes.
-- =====================================================================

USE pizzeria_don_piccolo;


-- =====================================================================
-- VISTA 1: vista_resumen_pedidos_cliente
-- ---------------------------------------------------------------------
-- Por cada cliente: cuántos pedidos ha hecho y cuánto ha gastado en
-- total. Útil para identificar clientes frecuentes / de alto valor.
-- Se usa LEFT JOIN para que aparezcan también los clientes que aún
-- no han hecho ningún pedido (con 0 pedidos y 0 gastado).
-- =====================================================================
CREATE VIEW vista_resumen_pedidos_cliente AS
SELECT
    c.id_cliente,
    c.nombre                           AS nombre_cliente,
    COUNT(p.id_pedido)                 AS cantidad_pedidos,
    COALESCE(SUM(p.total_pedido), 0)   AS total_gastado
FROM clientes c
LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre;


-- =====================================================================
-- VISTA 2: vista_desempeno_repartidores
-- ---------------------------------------------------------------------
-- Por cada repartidor: número de entregas completadas, tiempo promedio
-- de entrega (en minutos, desde hora_salida hasta hora_entrega) y su
-- zona asignada.
-- =====================================================================
CREATE VIEW vista_desempeno_repartidores AS
SELECT
    r.id_repartidor,
    r.nombre                                                     AS nombre_repartidor,
    r.zona_asignada,
    COUNT(d.id_domicilio)                                        AS numero_entregas,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, d.hora_salida, d.hora_entrega)), 2)
                                                                   AS tiempo_promedio_minutos
FROM repartidores r
LEFT JOIN domicilios d
       ON d.id_repartidor = r.id_repartidor
      AND d.hora_entrega IS NOT NULL   -- solo domicilios ya finalizados
GROUP BY r.id_repartidor, r.nombre, r.zona_asignada;


-- =====================================================================
-- VISTA 3: vista_stock_bajo_minimo
-- ---------------------------------------------------------------------
-- Lista los ingredientes cuyo stock actual está por debajo del stock
-- mínimo permitido, junto con la cantidad que falta para llegar al
-- mínimo. Útil para generar alertas de reabastecimiento.
-- =====================================================================
CREATE VIEW vista_stock_bajo_minimo AS
SELECT
    id_ingrediente,
    nombre,
    unidad_medida,
    stock_actual,
    stock_minimo,
    (stock_minimo - stock_actual) AS cantidad_faltante
FROM ingredientes
WHERE stock_actual < stock_minimo;


-- Ejemplos de uso:
-- SELECT * FROM vista_resumen_pedidos_cliente ORDER BY total_gastado DESC;
-- SELECT * FROM vista_desempeno_repartidores;
-- SELECT * FROM vista_stock_bajo_minimo;

-- Fin de vistas.sql
