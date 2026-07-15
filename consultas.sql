-- =====================================================================
-- PROYECTO: Sistema de Gestión de Pedidos y Domicilios
-- EMPRESA : Pizzería Don Piccolo
-- ARCHIVO : consultas.sql
-- OBJETIVO: Consultas SQL avanzadas requeridas por el negocio (JOIN,
--           GROUP BY, HAVING, subconsultas, BETWEEN, LIKE, etc.).
--
-- REQUISITO: ejecutar database.sql, funciones.sql, triggers.sql y
--            vistas.sql antes de este archivo.
-- =====================================================================

USE pizzeria_don_piccolo;


-- =====================================================================
-- CONSULTA 1: Clientes con pedidos entre dos fechas (BETWEEN)
-- ---------------------------------------------------------------------
-- Lista los clientes que realizaron pedidos durante julio de 2026.
-- =====================================================================
SELECT DISTINCT
    c.id_cliente,
    c.nombre,
    p.fecha_hora_pedido
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.fecha_hora_pedido BETWEEN '2026-07-01 00:00:00' AND '2026-07-31 23:59:59'
ORDER BY p.fecha_hora_pedido;


-- =====================================================================
-- CONSULTA 2: Pizzas más vendidas (GROUP BY + COUNT)
-- ---------------------------------------------------------------------
-- Ranking de pizzas según unidades vendidas (número de pedidos),
-- de mayor a menor.
-- =====================================================================
SELECT
    pz.id_pizza,
    pz.nombre,
    SUM(dp.cantidad) AS unidades_vendidas,
    COUNT(dp.id_detalle) AS veces_pedida
FROM detalle_pedido dp
JOIN pizzas pz ON pz.id_pizza = dp.id_pizza
GROUP BY pz.id_pizza, pz.nombre
ORDER BY unidades_vendidas DESC;


-- =====================================================================
-- CONSULTA 3: Pedidos (domicilios) atendidos por cada repartidor (JOIN)
-- ---------------------------------------------------------------------
-- Cuenta cuántos domicilios ha atendido cada repartidor.
-- =====================================================================
SELECT
    r.id_repartidor,
    r.nombre        AS repartidor,
    r.zona_asignada,
    COUNT(d.id_domicilio) AS total_domicilios_atendidos
FROM repartidores r
JOIN domicilios d ON d.id_repartidor = r.id_repartidor
GROUP BY r.id_repartidor, r.nombre, r.zona_asignada
ORDER BY total_domicilios_atendidos DESC;


-- =====================================================================
-- CONSULTA 4: Promedio de tiempo de entrega por zona (AVG + JOIN)
-- ---------------------------------------------------------------------
-- Calcula, para cada zona, el promedio de minutos transcurridos entre
-- la salida del repartidor y la entrega efectiva al cliente.
-- =====================================================================
SELECT
    d.zona,
    COUNT(d.id_domicilio) AS total_domicilios,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, d.hora_salida, d.hora_entrega)), 2) AS promedio_minutos_entrega
FROM domicilios d
WHERE d.hora_entrega IS NOT NULL
GROUP BY d.zona
ORDER BY promedio_minutos_entrega;


-- =====================================================================
-- CONSULTA 5: Clientes que han gastado más de un monto (HAVING)
-- ---------------------------------------------------------------------
-- Filtra, después de agrupar, a los clientes cuyo total acumulado en
-- pedidos supera $100.000 COP. HAVING se usa porque el filtro aplica
-- sobre el resultado de una función de agregación (SUM).
-- =====================================================================
SELECT
    c.id_cliente,
    c.nombre,
    SUM(p.total_pedido) AS total_gastado
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre
HAVING SUM(p.total_pedido) > 100000
ORDER BY total_gastado DESC;


-- =====================================================================
-- CONSULTA 6: Búsqueda por coincidencia parcial de nombre de pizza (LIKE)
-- ---------------------------------------------------------------------
-- Ejemplo: buscar todas las pizzas que contengan la palabra "vegetariana"
-- o cualquier fragmento de su nombre.
-- =====================================================================
SELECT
    id_pizza,
    nombre,
    tamano,
    precio_base,
    tipo
FROM pizzas
WHERE nombre LIKE '%vegetariana%';

-- Otro ejemplo de búsqueda parcial (case-insensitive por defecto en MySQL):
-- SELECT * FROM pizzas WHERE nombre LIKE '%especial%';


-- =====================================================================
-- CONSULTA 7: Subconsulta para obtener clientes frecuentes
-- ---------------------------------------------------------------------
-- Un cliente "frecuente" es aquel con más de 5 pedidos dentro de un
-- mismo mes. La subconsulta agrupa pedidos por cliente durante julio
-- de 2026 y filtra con HAVING; la consulta externa trae los datos
-- completos del cliente.
-- =====================================================================
SELECT
    id_cliente,
    nombre,
    telefono,
    email
FROM clientes
WHERE id_cliente IN (
    SELECT id_cliente
      FROM pedidos
     WHERE fecha_hora_pedido >= '2026-07-01'
       AND fecha_hora_pedido <  '2026-08-01'
     GROUP BY id_cliente
    HAVING COUNT(id_pedido) > 5
);

-- Fin de consultas.sql
