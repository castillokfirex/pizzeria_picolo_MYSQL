-- examen
drop database if exists pizzeria_don_piccolo;

create database if not exists pizzeria_don_piccolo
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_spanish_ci;
USE pizzeria_don_piccolo;

-- tablas

-- clientes
CREATE TABLE clientes (
    id_cliente      INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    telefono        VARCHAR(20)  NOT NULL,
    direccion       VARCHAR(200) NOT NULL,
    email           VARCHAR(100) UNIQUE,
    fecha_registro  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- Pizzas
CREATE TABLE pizzas (
    id_pizza      INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    tamano        ENUM('Personal','Mediana','Grande','Familiar') NOT NULL,
    precio_base   DECIMAL(10,2) NOT NULL,
    tipo          ENUM('Clasica','Vegetariana','Especial') NOT NULL,
    disponible    TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=activa en el menú, 0=inactiva',
    CHECK (precio_base >= 0)
) ENGINE = InnoDB;

-- Pedidos
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

-- Detalle del pedido
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

-- inserción de datos
-- clientes 
INSERT INTO clientes (nombre, telefono, direccion, email, fecha_registro) VALUES
('Camila Restrepo',  '3001112233', 'Cra 45 #12-34, El Poblado',   'camila.restrepo@mail.com', '2026-06-01 10:00:00'),
('Juan Esteban Gómez','3002223344', 'Cll 33 #78-10, Laureles',     'juan.gomez@mail.com',      '2026-06-05 12:30:00'),
('Valentina Ríos',    '3003334455', 'Cra 70 #45-20, Belén',        'valentina.rios@mail.com',  '2026-06-10 19:00:00'),
('Andrés Zapata',     '3004445566', 'Cll 10 #40-15, Envigado',     'andres.zapata@mail.com',   '2026-06-12 20:15:00');

--pizzas
INSERT INTO pizzas (nombre, tamano, precio_base, tipo) VALUES
('Pizza Pepperoni Clásica',   'Grande',   35000, 'Clasica'),
('Pizza Vegetariana Jardín',  'Mediana',  30000, 'Vegetariana'),
('Pizza Especial Don Piccolo','Familiar', 48000, 'Especial');

-- pedidos
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


-- pasa el pedido de pediente a preparacion
update pedidos
 set estado_pedido = 'En preparacion'
 where id_pedido = 1;
select id_pedido, estado_pedido from pedidos where id_pedido = 1;

-- CONSULTAS DEl EXAMEN

-- 1 Pedidos pendientes, del más antiguo al ultimo
SELECT id_pedido, id_cliente, fecha_hora_pedido
FROM pedidos
WHERE estado_pedido = 'Pendiente'
ORDER BY fecha_hora_pedido ASC;

-- 2 Conteo de pedidos por estado 
SELECT estado_pedido, COUNT(*) AS cantidad
FROM pedidos
GROUP BY estado_pedido;

-- 3 Detalle del pedido completo
SELECT p.id_pedido, c.nombre AS cliente, pz.nombre AS pizza,
       dp.cantidad, dp.precio_unitario, dp.subtotal
FROM pedidos p
JOIN clientes c        ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
JOIN pizzas pz         ON pz.id_pizza = dp.id_pizza
WHERE p.id_pedido = 1;

-- 4 Pedidos realizados entre dos fechas
SELECT id_pedido, id_cliente, fecha_hora_pedido, estado_pedido
FROM pedidos
WHERE fecha_hora_pedido BETWEEN '2026-07-01 00:00:00' AND '2026-07-31 23:59:59';