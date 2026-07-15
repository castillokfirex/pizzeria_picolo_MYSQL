-- =====================================================================
-- PROYECTO: Sistema de Gestión de Pedidos y Domicilios
-- EMPRESA : Pizzería Don Piccolo
-- ARCHIVO : triggers.sql
-- OBJETIVO: Automatizar reglas de negocio mediante triggers:
--             1) Validar y descontar stock de ingredientes al vender.
--             2) Auditar cambios de precio de las pizzas.
--             3) Liberar/ocupar repartidores automáticamente.
--
-- REQUISITO: ejecutar database.sql y funciones.sql antes de este archivo.
-- =====================================================================

USE pizzeria_don_piccolo;


-- =====================================================================
-- TRIGGER 1 (requerido): trg_actualizar_stock_ingredientes
-- ---------------------------------------------------------------------
-- Cuando se inserta una línea en detalle_pedido (se vende una pizza),
-- descuenta automáticamente el stock de cada ingrediente de la receta,
-- según la cantidad de pizzas vendidas.
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_actualizar_stock_ingredientes
AFTER INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE ingredientes i
    JOIN pizza_ingredientes pi ON pi.id_ingrediente = i.id_ingrediente
       SET i.stock_actual = i.stock_actual - (pi.cantidad_requerida * NEW.cantidad)
     WHERE pi.id_pizza = NEW.id_pizza;
END$$

DELIMITER ;


-- =====================================================================
-- TRIGGER 1B (complementario / buena práctica): trg_validar_stock_ingredientes
-- ---------------------------------------------------------------------
-- Se ejecuta ANTES de insertar el detalle del pedido y verifica que
-- haya suficiente stock de todos los ingredientes necesarios. Si no
-- hay stock suficiente, se cancela la operación con SIGNAL.
--
-- Esto evita que trg_actualizar_stock_ingredientes deje el stock en
-- números negativos.
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_validar_stock_ingredientes
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    DECLARE v_ingredientes_faltantes INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_ingredientes_faltantes
      FROM pizza_ingredientes pi
      JOIN ingredientes i ON i.id_ingrediente = pi.id_ingrediente
     WHERE pi.id_pizza = NEW.id_pizza
       AND i.stock_actual < (pi.cantidad_requerida * NEW.cantidad);

    IF v_ingredientes_faltantes > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock insuficiente de uno o más ingredientes para preparar esta pizza.';
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- TRIGGER 2 (requerido): trg_historial_precios
-- ---------------------------------------------------------------------
-- Auditoría de precios: cada vez que se modifica precio_base de una
-- pizza, se guarda el precio anterior y el nuevo en historial_precios.
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_historial_precios
BEFORE UPDATE ON pizzas
FOR EACH ROW
BEGIN
    IF OLD.precio_base <> NEW.precio_base THEN
        INSERT INTO historial_precios (id_pizza, precio_anterior, precio_nuevo, fecha_cambio)
        VALUES (OLD.id_pizza, OLD.precio_base, NEW.precio_base, NOW());
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- TRIGGER 3 (requerido): trg_repartidor_disponible
-- ---------------------------------------------------------------------
-- Cuando se registra la hora_entrega de un domicilio (antes era NULL,
-- ahora tiene un valor), el repartidor asignado vuelve a quedar
-- 'Disponible' automáticamente.
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_repartidor_disponible
AFTER UPDATE ON domicilios
FOR EACH ROW
BEGIN
    IF NEW.hora_entrega IS NOT NULL AND OLD.hora_entrega IS NULL THEN
        UPDATE repartidores
           SET estado = 'Disponible'
         WHERE id_repartidor = NEW.id_repartidor;
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- TRIGGER 3B (complementario / buena práctica): trg_repartidor_ocupado
-- ---------------------------------------------------------------------
-- Contraparte lógica del trigger anterior: cuando se asigna un
-- repartidor a un nuevo domicilio (INSERT en domicilios), su estado
-- pasa automáticamente a 'No disponible' mientras realiza la entrega.
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_repartidor_ocupado
AFTER INSERT ON domicilios
FOR EACH ROW
BEGIN
    UPDATE repartidores
       SET estado = 'No disponible'
     WHERE id_repartidor = NEW.id_repartidor;
END$$

DELIMITER ;

-- Fin de triggers.sql
