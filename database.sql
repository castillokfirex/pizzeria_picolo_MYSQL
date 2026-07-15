-- =====================================================================
-- PROYECTO: Sistema de Gestión de Pedidos y Domicilios
-- EMPRESA : Pizzería Don Piccolo
-- ARCHIVO : database.sql
-- OBJETIVO: Creación de la base de datos y de todas las tablas del
--           modelo relacional, con sus llaves primarias, llaves
--           foráneas, restricciones (CHECK, UNIQUE, DEFAULT) e índices.
--
-- ORDEN DE EJECUCIÓN DEL PROYECTO:
--   1. database.sql   (este archivo)
--   2. funciones.sql
--   3. triggers.sql
--   4. vistas.sql
--   5. consultas.sql  (consultas de prueba / reportes)
-- =====================================================================

-- Se elimina la base de datos si existe, para poder ejecutar el script
-- las veces que sea necesario durante el desarrollo/pruebas.
DROP DATABASE IF EXISTS pizzeria_don_piccolo;

CREATE DATABASE pizzeria_don_piccolo
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_spanish_ci;

USE pizzeria_don_piccolo;

-- =====================================================================
-- SECCIÓN 1: TABLA DE CONFIGURACIÓN GENERAL
-- ---------------------------------------------------------------------
-- Guarda parámetros configurables del negocio (ej: IVA), en lugar de
-- "quemar" el valor dentro de las funciones. Buena práctica para que
-- el negocio pueda cambiar el IVA sin modificar código SQL.
-- =====================================================================
CREATE TABLE configuracion (
    id_config     INT AUTO_INCREMENT PRIMARY KEY,
    parametro     VARCHAR(50)  NOT NULL UNIQUE,
    valor         DECIMAL(10,4) NOT NULL,
    descripcion   VARCHAR(200)
) ENGINE = InnoDB;

INSERT INTO configuracion (parametro, valor, descripcion) VALUES
    ('IVA', 0.19, 'Porcentaje de IVA aplicado sobre pizzas + envío (19%)');


-- =====================================================================
-- SECCIÓN 2: CLIENTES
-- ---------------------------------------------------------------------
-- Almacena la información básica de cada cliente. El correo es único
-- porque se usará como dato de contacto/identificación adicional.
-- =====================================================================
CREATE TABLE clientes (
    id_cliente      INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    telefono        VARCHAR(20)  NOT NULL,
    direccion       VARCHAR(200) NOT NULL,
    email           VARCHAR(100) UNIQUE,
    fecha_registro  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- Índice para acelerar búsquedas de clientes por nombre (LIKE '%...%')
CREATE INDEX idx_clientes_nombre ON clientes(nombre);


-- =====================================================================
-- SECCIÓN 3: INGREDIENTES
-- ---------------------------------------------------------------------
-- Controla el stock disponible de cada ingrediente y su costo, lo cual
-- se usa luego para calcular la ganancia neta diaria y para validar/
-- descontar stock automáticamente mediante triggers.
-- =====================================================================
CREATE TABLE ingredientes (
    id_ingrediente  INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL UNIQUE,
    unidad_medida   VARCHAR(20) NOT NULL COMMENT 'gramos, mililitros, unidades, etc.',
    stock_actual    DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_minimo    DECIMAL(10,2) NOT NULL DEFAULT 0,
    costo_unitario  DECIMAL(10,2) NOT NULL DEFAULT 0,
    CHECK (stock_actual >= 0),
    CHECK (stock_minimo >= 0)
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 4: PIZZAS
-- ---------------------------------------------------------------------
-- Catálogo de pizzas del menú, con su tamaño, precio base y tipo.
-- =====================================================================
CREATE TABLE pizzas (
    id_pizza      INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    tamano        ENUM('Personal','Mediana','Grande','Familiar') NOT NULL,
    precio_base   DECIMAL(10,2) NOT NULL,
    tipo          ENUM('Clasica','Vegetariana','Especial') NOT NULL,
    disponible    TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=activa en el menú, 0=inactiva',
    CHECK (precio_base >= 0)
) ENGINE = InnoDB;

CREATE INDEX idx_pizzas_nombre ON pizzas(nombre);


-- =====================================================================
-- SECCIÓN 5: PIZZA_INGREDIENTES (relación N:M)
-- ---------------------------------------------------------------------
-- Receta de cada pizza: qué ingredientes lleva y en qué cantidad
-- (por cada unidad de pizza vendida). Es la tabla que permite:
--   - Controlar disponibilidad de ingredientes.
--   - Descontar stock automáticamente al vender una pizza.
--   - Calcular el costo de producción de cada pizza.
-- =====================================================================
CREATE TABLE pizza_ingredientes (
    id_pizza            INT NOT NULL,
    id_ingrediente      INT NOT NULL,
    cantidad_requerida  DECIMAL(10,2) NOT NULL COMMENT 'Cantidad del ingrediente por cada pizza',
    PRIMARY KEY (id_pizza, id_ingrediente),
    CONSTRAINT fk_pi_pizza
        FOREIGN KEY (id_pizza) REFERENCES pizzas(id_pizza)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pi_ingrediente
        FOREIGN KEY (id_ingrediente) REFERENCES ingredientes(id_ingrediente)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (cantidad_requerida > 0)
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 6: REPARTIDORES
-- ---------------------------------------------------------------------
-- Personal encargado de realizar los domicilios.
-- =====================================================================
CREATE TABLE repartidores (
    id_repartidor   INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    telefono        VARCHAR(20),
    zona_asignada   VARCHAR(50) NOT NULL,
    estado          ENUM('Disponible','No disponible') NOT NULL DEFAULT 'Disponible'
) ENGINE = InnoDB;

CREATE INDEX idx_repartidores_zona ON repartidores(zona_asignada);


-- =====================================================================
-- SECCIÓN 7: PEDIDOS
-- ---------------------------------------------------------------------
-- Cabecera del pedido: quién lo hizo, cuándo, cómo se paga y en qué
-- estado se encuentra. El total_pedido se calcula con la función
-- fn_calcular_total_pedido() (ver funciones.sql) y se guarda aquí
-- como valor "congelado" para reportes rápidos.
-- =====================================================================
CREATE TABLE pedidos (
    id_pedido           INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente          INT NOT NULL,
    fecha_hora_pedido   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago         ENUM('Efectivo','Tarjeta','App') NOT NULL,
    estado_pedido       ENUM('Pendiente','En preparacion','Entregado','Cancelado')
                         NOT NULL DEFAULT 'Pendiente',
    total_pedido        DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Índice para acelerar consultas por rango de fechas (BETWEEN)
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_hora_pedido);
CREATE INDEX idx_pedidos_estado ON pedidos(estado_pedido);


-- =====================================================================
-- SECCIÓN 8: DETALLE_PEDIDO
-- ---------------------------------------------------------------------
-- Líneas del pedido: qué pizzas y cuántas unidades de cada una.
-- El campo subtotal es una columna calculada (GENERATED), evitando que
-- quede desincronizada respecto a cantidad * precio_unitario.
-- =====================================================================
CREATE TABLE detalle_pedido (
    id_detalle       INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido        INT NOT NULL,
    id_pizza         INT NOT NULL,
    cantidad         INT NOT NULL DEFAULT 1,
    precio_unitario  DECIMAL(10,2) NOT NULL COMMENT 'Precio de la pizza al momento de la venta',
    subtotal         DECIMAL(10,2) AS (cantidad * precio_unitario) STORED,
    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_pizza
        FOREIGN KEY (id_pizza) REFERENCES pizzas(id_pizza)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (cantidad > 0)
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 9: DOMICILIOS
-- ---------------------------------------------------------------------
-- Información de la entrega física de un pedido: repartidor asignado,
-- horarios, distancia y costo de envío. Un pedido tiene, como máximo,
-- un domicilio asociado (por eso id_pedido es UNIQUE).
-- =====================================================================
CREATE TABLE domicilios (
    id_domicilio    INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido       INT NOT NULL UNIQUE,
    id_repartidor   INT NOT NULL,
    zona            VARCHAR(50) NOT NULL,
    hora_salida     DATETIME NULL,
    hora_entrega    DATETIME NULL,
    distancia_km    DECIMAL(5,2) NOT NULL,
    costo_envio     DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_domicilio_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_domicilio_repartidor
        FOREIGN KEY (id_repartidor) REFERENCES repartidores(id_repartidor)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (distancia_km >= 0),
    CHECK (costo_envio >= 0)
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 10: PAGOS
-- ---------------------------------------------------------------------
-- Registro formal del pago del pedido (puede diferir en el tiempo del
-- momento en que se creó el pedido, por ejemplo en pagos contra entrega).
-- =====================================================================
CREATE TABLE pagos (
    id_pago       INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido     INT NOT NULL UNIQUE,
    monto         DECIMAL(10,2) NOT NULL,
    metodo_pago   ENUM('Efectivo','Tarjeta','App') NOT NULL,
    estado_pago   ENUM('Pendiente','Pagado','Rechazado') NOT NULL DEFAULT 'Pendiente',
    fecha_pago    DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pago_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 11: HISTORIAL_PRECIOS (tabla de auditoría)
-- ---------------------------------------------------------------------
-- Registra cada cambio de precio_base de una pizza. Se llena de forma
-- automática mediante el trigger trg_historial_precios (ver triggers.sql).
-- =====================================================================
CREATE TABLE historial_precios (
    id_historial      INT AUTO_INCREMENT PRIMARY KEY,
    id_pizza          INT NOT NULL,
    precio_anterior   DECIMAL(10,2) NOT NULL,
    precio_nuevo      DECIMAL(10,2) NOT NULL,
    fecha_cambio      DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historial_pizza
        FOREIGN KEY (id_pizza) REFERENCES pizzas(id_pizza)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;


-- =====================================================================
-- SECCIÓN 12: DATOS DE PRUEBA
-- ---------------------------------------------------------------------
-- Datos de ejemplo para poder probar funciones, triggers, vistas y
-- consultas inmediatamente después de crear el modelo.
-- =====================================================================

-- --- Clientes ---------------------------------------------------------
INSERT INTO clientes (nombre, telefono, direccion, email, fecha_registro) VALUES
('Camila Restrepo',  '3001112233', 'Cra 45 #12-34, El Poblado',   'camila.restrepo@mail.com', '2026-06-01 10:00:00'),
('Juan Esteban Gómez','3002223344', 'Cll 33 #78-10, Laureles',     'juan.gomez@mail.com',      '2026-06-05 12:30:00'),
('Valentina Ríos',    '3003334455', 'Cra 70 #45-20, Belén',        'valentina.rios@mail.com',  '2026-06-10 19:00:00'),
('Andrés Zapata',     '3004445566', 'Cll 10 #40-15, Envigado',     'andres.zapata@mail.com',   '2026-06-12 20:15:00');

-- --- Ingredientes -------------------------------------------------------
INSERT INTO ingredientes (nombre, unidad_medida, stock_actual, stock_minimo, costo_unitario) VALUES
('Masa de pizza',        'unidades', 100, 20, 2500),
('Salsa de tomate',      'gramos',   5000, 1000, 10),
('Queso mozzarella',     'gramos',   8000, 1500, 25),
('Pepperoni',            'gramos',   3000, 800, 35),
('Champiñones',          'gramos',   2000, 500, 15),
('Pimentón',             'gramos',   1500, 400, 12),
('Cebolla',              'gramos',   1500, 400, 8),
('Aceitunas negras',     'gramos',   1000, 300, 20);

-- --- Pizzas ---------------------------------------------------------
INSERT INTO pizzas (nombre, tamano, precio_base, tipo) VALUES
('Pizza Pepperoni Clásica',   'Grande',   35000, 'Clasica'),
('Pizza Vegetariana Jardín',  'Mediana',  30000, 'Vegetariana'),
('Pizza Especial Don Piccolo','Familiar', 48000, 'Especial');

-- --- Receta de cada pizza (pizza_ingredientes) ------------------------
-- Pizza Pepperoni Clásica (id_pizza = 1)
INSERT INTO pizza_ingredientes (id_pizza, id_ingrediente, cantidad_requerida) VALUES
(1, 1, 1),     -- 1 masa
(1, 2, 150),   -- 150 g salsa
(1, 3, 250),   -- 250 g queso
(1, 4, 120);   -- 120 g pepperoni

-- Pizza Vegetariana Jardín (id_pizza = 2)
INSERT INTO pizza_ingredientes (id_pizza, id_ingrediente, cantidad_requerida) VALUES
(2, 1, 1),
(2, 2, 130),
(2, 3, 200),
(2, 5, 100),   -- champiñones
(2, 6, 80),    -- pimentón
(2, 7, 60);    -- cebolla

-- Pizza Especial Don Piccolo (id_pizza = 3)
INSERT INTO pizza_ingredientes (id_pizza, id_ingrediente, cantidad_requerida) VALUES
(3, 1, 1),
(3, 2, 180),
(3, 3, 300),
(3, 4, 100),
(3, 5, 100),
(3, 8, 60);    -- aceitunas

-- --- Repartidores -------------------------------------------------------
INSERT INTO repartidores (nombre, telefono, zona_asignada, estado) VALUES
('Carlos Mesa',    '3101112233', 'El Poblado', 'Disponible'),
('Luisa Fernanda',  '3102223344', 'Laureles',   'Disponible'),
('Pedro Ortiz',     '3103334455', 'Belén',      'Disponible');

-- --- Pedidos y su detalle ------------------------------------------
-- (El total_pedido se actualizará usando la función/procedimiento
--  fn_calcular_total_pedido / sp_actualizar_total_pedido en funciones.sql)
INSERT INTO pedidos (id_cliente, fecha_hora_pedido, metodo_pago, estado_pedido) VALUES
(1, '2026-07-02 19:30:00', 'Tarjeta',  'Pendiente'),
(2, '2026-07-05 20:10:00', 'Efectivo', 'Pendiente'),
(1, '2026-07-08 13:00:00', 'App',      'Pendiente'),
(3, '2026-07-10 21:00:00', 'Efectivo', 'Pendiente');

INSERT INTO detalle_pedido (id_pedido, id_pizza, cantidad, precio_unitario) VALUES
(1, 1, 2, 35000),   -- pedido 1: 2 pizzas pepperoni
(1, 2, 1, 30000),   -- pedido 1: 1 pizza vegetariana
(2, 3, 1, 48000),   -- pedido 2: 1 pizza especial
(3, 2, 2, 30000),   -- pedido 3: 2 pizzas vegetarianas
(4, 1, 1, 35000);   -- pedido 4: 1 pizza pepperoni

-- --- Domicilios -------------------------------------------------------
INSERT INTO domicilios (id_pedido, id_repartidor, zona, hora_salida, distancia_km, costo_envio) VALUES
(1, 1, 'El Poblado', '2026-07-02 19:45:00', 3.2, 5000),
(2, 2, 'Laureles',   '2026-07-05 20:25:00', 4.0, 6000),
(3, 1, 'El Poblado', '2026-07-08 13:15:00', 2.5, 4500),
(4, 3, 'Belén',      '2026-07-10 21:15:00', 5.1, 7000);

-- Fin de database.sql
