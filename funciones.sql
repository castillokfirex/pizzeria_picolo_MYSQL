-- =====================================================================
-- PROYECTO: Sistema de Gestión de Pedidos y Domicilios
-- EMPRESA : Pizzería Don Piccolo
-- ARCHIVO : funciones.sql
-- OBJETIVO: Funciones y procedimientos almacenados que encapsulan la
--           lógica de negocio: cálculo de totales, ganancia neta diaria
--           y registro de entregas.
--
-- REQUISITO: ejecutar database.sql antes de este archivo.
-- =====================================================================

USE pizzeria_don_piccolo;

-- Necesario en algunos servidores MySQL para poder crear funciones que
-- leen/escriben datos, cuando el binary logging está activado.
SET GLOBAL log_bin_trust_function_creators = 1;


-- =====================================================================
-- FUNCIÓN 1: fn_calcular_total_pedido
-- ---------------------------------------------------------------------
-- Calcula el total de un pedido = (suma de subtotales de pizzas +
-- costo de envío) * (1 + IVA). El IVA se lee de la tabla configuracion,
-- para no dejarlo "quemado" dentro del código.
--
-- Esta función es de solo LECTURA (no modifica datos); si se quiere
-- persistir el resultado en pedidos.total_pedido, usar el procedimiento
-- sp_actualizar_total_pedido definido más abajo.
-- =====================================================================
DELIMITER $$

CREATE FUNCTION fn_calcular_total_pedido(p_id_pedido INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_subtotal_pizzas DECIMAL(10,2) DEFAULT 0;
    DECLARE v_costo_envio     DECIMAL(10,2) DEFAULT 0;
    DECLARE v_iva             DECIMAL(10,4) DEFAULT 0;
    DECLARE v_total           DECIMAL(10,2) DEFAULT 0;

    -- 1) Sumar el valor de todas las pizzas pedidas (cantidad * precio_unitario)
    SELECT COALESCE(SUM(subtotal), 0)
      INTO v_subtotal_pizzas
      FROM detalle_pedido
     WHERE id_pedido = p_id_pedido;

    -- 2) Obtener el costo de envío, si el pedido tiene domicilio asociado
    SELECT COALESCE(costo_envio, 0)
      INTO v_costo_envio
      FROM domicilios
     WHERE id_pedido = p_id_pedido
     LIMIT 1;

    -- 3) Obtener el porcentaje de IVA vigente desde configuracion
    SELECT valor
      INTO v_iva
      FROM configuracion
     WHERE parametro = 'IVA'
     LIMIT 1;

    -- 4) Calcular el total final
    SET v_total = (v_subtotal_pizzas + v_costo_envio) * (1 + v_iva);

    RETURN v_total;
END$$

DELIMITER ;


-- =====================================================================
-- FUNCIÓN 2: fn_ganancia_neta_diaria
-- ---------------------------------------------------------------------
-- Calcula la ganancia neta de un día específico:
--     ganancia = ventas del día (pedidos ENTREGADOS)
--              - costo de los ingredientes usados en esas ventas
-- =====================================================================
DELIMITER $$

CREATE FUNCTION fn_ganancia_neta_diaria(p_fecha DATE)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_ventas    DECIMAL(12,2) DEFAULT 0;
    DECLARE v_costos    DECIMAL(12,2) DEFAULT 0;
    DECLARE v_ganancia  DECIMAL(12,2) DEFAULT 0;

    -- 1) Ventas: suma del total_pedido de los pedidos entregados ese día
    SELECT COALESCE(SUM(p.total_pedido), 0)
      INTO v_ventas
      FROM pedidos p
     WHERE DATE(p.fecha_hora_pedido) = p_fecha
       AND p.estado_pedido = 'Entregado';

    -- 2) Costos: costo de ingredientes de cada pizza vendida ese día.
    --    Subconsulta "costo_pizza" calcula el costo de la receta de
    --    cada pizza (suma de cantidad_requerida * costo_unitario).
    SELECT COALESCE(SUM(dp.cantidad * costo_pizza.costo_ingredientes), 0)
      INTO v_costos
      FROM detalle_pedido dp
      JOIN pedidos p ON p.id_pedido = dp.id_pedido
      JOIN (
            SELECT pi.id_pizza,
                   SUM(pi.cantidad_requerida * i.costo_unitario) AS costo_ingredientes
              FROM pizza_ingredientes pi
              JOIN ingredientes i ON i.id_ingrediente = pi.id_ingrediente
             GROUP BY pi.id_pizza
           ) AS costo_pizza ON costo_pizza.id_pizza = dp.id_pizza
     WHERE DATE(p.fecha_hora_pedido) = p_fecha
       AND p.estado_pedido = 'Entregado';

    -- 3) Ganancia neta
    SET v_ganancia = v_ventas - v_costos;

    RETURN v_ganancia;
END$$

DELIMITER ;


-- =====================================================================
-- PROCEDIMIENTO 1: sp_registrar_entrega
-- ---------------------------------------------------------------------
-- Registra la hora de entrega de un domicilio y, automáticamente,
-- cambia el estado del pedido asociado a 'Entregado'.
--
-- Nota: al actualizar domicilios.hora_entrega, el trigger
-- trg_repartidor_disponible (ver triggers.sql) libera al repartidor
-- automáticamente, por lo que aquí no es necesario hacerlo manualmente.
-- =====================================================================
DELIMITER $$

CREATE PROCEDURE sp_registrar_entrega(
    IN p_id_domicilio INT,
    IN p_hora_entrega  DATETIME
)
BEGIN
    DECLARE v_id_pedido INT;

    -- 1) Registrar la hora real de entrega
    UPDATE domicilios
       SET hora_entrega = p_hora_entrega
     WHERE id_domicilio = p_id_domicilio;

    -- 2) Obtener el pedido asociado a este domicilio
    SELECT id_pedido
      INTO v_id_pedido
      FROM domicilios
     WHERE id_domicilio = p_id_domicilio;

    -- 3) Cambiar automáticamente el estado del pedido a 'Entregado'
    UPDATE pedidos
       SET estado_pedido = 'Entregado'
     WHERE id_pedido = v_id_pedido;
END$$

DELIMITER ;


-- =====================================================================
-- PROCEDIMIENTO 2 (complementario): sp_actualizar_total_pedido
-- ---------------------------------------------------------------------
-- Utiliza fn_calcular_total_pedido() para recalcular y GUARDAR el total
-- de un pedido en la tabla pedidos. Se recomienda llamarlo después de
-- insertar el detalle del pedido y/o el domicilio asociado.
-- =====================================================================
DELIMITER $$

CREATE PROCEDURE sp_actualizar_total_pedido(
    IN p_id_pedido INT
)
BEGIN
    UPDATE pedidos
       SET total_pedido = fn_calcular_total_pedido(p_id_pedido)
     WHERE id_pedido = p_id_pedido;
END$$

DELIMITER ;


-- =====================================================================
-- APLICAR EL CÁLCULO A LOS PEDIDOS DE PRUEBA
-- ---------------------------------------------------------------------
-- Recalcula el total de los pedidos de ejemplo insertados en
-- database.sql, para dejar la tabla pedidos con datos consistentes
-- antes de probar las vistas y consultas.
-- =====================================================================
CALL sp_actualizar_total_pedido(1);
CALL sp_actualizar_total_pedido(2);
CALL sp_actualizar_total_pedido(3);
CALL sp_actualizar_total_pedido(4);

-- Ejemplo de uso de las funciones:
-- SELECT fn_calcular_total_pedido(1);
-- SELECT fn_ganancia_neta_diaria('2026-07-02');

-- Fin de funciones.sql
