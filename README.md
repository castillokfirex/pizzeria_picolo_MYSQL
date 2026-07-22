# 🍕 Pizzería Don Piccolo — Sistema de Gestión de Pedidos y Domicilios

## hecho por

-nombre:Kevin Andrés Castillo Pabón
-skill: MySQL2 
-Grupo: Z1"

Proyecto de base de datos relacional en **MySQL** para gestionar el proceso completo
de venta de pizzas y domicilios de la Pizzería Don Piccolo: clientes, pizzas,
ingredientes, pedidos, repartidores, domicilios y pagos.

---

## 1. Descripción del proyecto

Actualmente Don Piccolo gestiona sus pedidos de forma manual, lo que genera
retrasos y errores en los registros. Este proyecto reemplaza ese proceso por
una base de datos relacional que permite:

- Registrar clientes y detectar automáticamente cuáles son **frecuentes**
  (más de 5 pedidos en un mes).
- Administrar el menú de pizzas y sus recetas (ingredientes y cantidades).
- Controlar el **stock de ingredientes**, descontándolo automáticamente
  cada vez que se vende una pizza, y alertando cuando el stock cae por
  debajo del mínimo permitido.
- Registrar pedidos completos: cliente, pizzas solicitadas, método de pago,
  estado y total (calculado automáticamente, incluyendo IVA y envío).
- Asignar repartidores a los domicilios y controlar su disponibilidad de
  forma automática (se marcan "No disponible" al salir y "Disponible" al
  entregar).
- Calcular la **ganancia neta diaria** del negocio (ventas − costo de
  ingredientes usados).
- Auditar los cambios de precio de las pizzas en una tabla de historial.
- Generar reportes mediante vistas: resumen de pedidos por cliente,
  desempeño de repartidores y stock bajo mínimo.

---

## 2. Estructura del proyecto

```
/pizzeria-don-piccolo/
 ├── database.sql     -- Creación de la BD, tablas, llaves y datos de prueba
 ├── funciones.sql     -- Funciones y procedimientos almacenados
 ├── triggers.sql      -- Triggers de negocio y auditoría
 ├── vistas.sql        -- Vistas de reportes
 ├── consultas.sql     -- Consultas SQL avanzadas de ejemplo
 └── README.md         -- Este archivo
```

---

## 3. Modelo de datos: tablas y relaciones

| Tabla                | Descripción                                                                 |
|-----------------------|------------------------------------------------------------------------------|
| `configuracion`        | Parámetros generales del negocio (ej. porcentaje de IVA).                    |
| `clientes`             | Nombre, teléfono, dirección, correo y fecha de registro.                    |
| `ingredientes`         | Stock actual/mínimo, unidad de medida y costo unitario de cada insumo.      |
| `pizzas`               | Catálogo de pizzas: nombre, tamaño, precio base y tipo.                     |
| `pizza_ingredientes`   | Relación **N:M** entre pizzas e ingredientes (la "receta" de cada pizza).   |
| `repartidores`         | Nombre, zona asignada y estado (Disponible / No disponible).                |
| `pedidos`              | Cabecera del pedido: cliente, fecha, método de pago, estado y total.        |
| `detalle_pedido`       | Líneas del pedido: qué pizzas y cuántas unidades de cada una.               |
| `domicilios`           | Entrega física de un pedido: repartidor, horarios, distancia y costo envío. |
| `pagos`                | Registro del pago asociado a cada pedido.                                   |
| `historial_precios`    | Auditoría automática de cada cambio de precio en `pizzas`.                  |

### Relaciones principales (llaves foráneas)

- `pedidos.id_cliente` → `clientes.id_cliente` *(ON DELETE RESTRICT)*
- `detalle_pedido.id_pedido` → `pedidos.id_pedido` *(ON DELETE CASCADE)*
- `detalle_pedido.id_pizza` → `pizzas.id_pizza` *(ON DELETE RESTRICT)*
- `pizza_ingredientes.id_pizza` → `pizzas.id_pizza` *(ON DELETE CASCADE)*
- `pizza_ingredientes.id_ingrediente` → `ingredientes.id_ingrediente` *(ON DELETE CASCADE)*
- `domicilios.id_pedido` → `pedidos.id_pedido` *(1 a 1, UNIQUE, ON DELETE CASCADE)*
- `domicilios.id_repartidor` → `repartidores.id_repartidor` *(ON DELETE RESTRICT)*
- `pagos.id_pedido` → `pedidos.id_pedido` *(1 a 1, UNIQUE, ON DELETE CASCADE)*
- `historial_precios.id_pizza` → `pizzas.id_pizza` *(ON DELETE CASCADE)*

**¿Por qué CASCADE en unos casos y RESTRICT en otros?**
Se usa `CASCADE` cuando el registro "hijo" no tiene sentido sin el "padre"
(por ejemplo, el detalle de un pedido no existe si el pedido se elimina).
Se usa `RESTRICT` cuando queremos **proteger el histórico** del negocio
(por ejemplo, no se debe poder borrar un cliente o una pizza si ya tienen
pedidos asociados).

---

## 4. Funciones y procedimientos (`funciones.sql`)

| Objeto                          | Tipo        | Descripción |
|----------------------------------|-------------|--------------|
| `fn_calcular_total_pedido`       | Función     | `(pizzas + envío) * (1 + IVA)`. Lee el IVA desde `configuracion`. |
| `fn_ganancia_neta_diaria`        | Función     | `ventas del día − costo de ingredientes usados`, solo pedidos "Entregado". |
| `sp_registrar_entrega`           | Procedimiento | Registra `hora_entrega` y cambia el pedido a `Entregado` automáticamente. |
| `sp_actualizar_total_pedido`     | Procedimiento | Recalcula y guarda `pedidos.total_pedido` usando `fn_calcular_total_pedido`. |

Ejemplo de uso:

```sql
-- Calcular (sin guardar) el total de un pedido
SELECT fn_calcular_total_pedido(1);

-- Calcular y GUARDAR el total en la tabla pedidos
CALL sp_actualizar_total_pedido(1);

-- Ganancia neta del 2 de julio de 2026
SELECT fn_ganancia_neta_diaria('2026-07-02');

-- Registrar la entrega del domicilio 1 a las 8:10 pm
CALL sp_registrar_entrega(1, '2026-07-02 20:10:00');
```

---

## 5. Triggers (`triggers.sql`)

| Trigger                                | Evento                     | Qué hace |
|------------------------------------------|----------------------------|-----------|
| `trg_validar_stock_ingredientes`         | `BEFORE INSERT` en `detalle_pedido` | Cancela la venta (con `SIGNAL`) si no hay stock suficiente. |
| `trg_actualizar_stock_ingredientes`      | `AFTER INSERT` en `detalle_pedido`  | Descuenta el stock de cada ingrediente según la receta y cantidad vendida. |
| `trg_historial_precios`                  | `BEFORE UPDATE` en `pizzas`          | Guarda el precio anterior y nuevo en `historial_precios` cuando cambia `precio_base`. |
| `trg_repartidor_ocupado`                 | `AFTER INSERT` en `domicilios`       | Marca al repartidor como `No disponible` al asignarle un domicilio. |
| `trg_repartidor_disponible`              | `AFTER UPDATE` en `domicilios`       | Marca al repartidor como `Disponible` cuando se registra `hora_entrega`. |

> Los dos primeros y el de historial de precios corresponden a los 3 triggers
> exigidos por el enunciado; los dos relacionados con el estado del
> repartidor se agregaron como complemento para que el ciclo de
> disponibilidad quede completamente automatizado.

---

## 6. Vistas (`vistas.sql`)

| Vista                          | Contenido |
|----------------------------------|------------|
| `vista_resumen_pedidos_cliente`   | Cliente, cantidad de pedidos y total gastado. |
| `vista_desempeno_repartidores`    | Repartidor, zona, número de entregas y tiempo promedio de entrega (min). |
| `vista_stock_bajo_minimo`         | Ingredientes cuyo stock actual está por debajo del mínimo permitido. |

```sql
SELECT * FROM vista_resumen_pedidos_cliente ORDER BY total_gastado DESC;
SELECT * FROM vista_desempeno_repartidores;
SELECT * FROM vista_stock_bajo_minimo;
```

---

## 7. Ejemplos de consultas (`consultas.sql`)

- **BETWEEN** — clientes con pedidos entre dos fechas.
- **GROUP BY + COUNT** — pizzas más vendidas.
- **JOIN** — domicilios atendidos por cada repartidor.
- **AVG + JOIN** — promedio de tiempo de entrega por zona.
- **HAVING** — clientes que han gastado más de $100.000 en total.
- **LIKE** — búsqueda de pizzas por coincidencia parcial del nombre.
- **Subconsulta** — clientes frecuentes (más de 5 pedidos en un mes).

Todas las consultas están comentadas explicando su propósito dentro del
archivo `consultas.sql`.

---

## 8. Instrucciones de ejecución

### Requisitos
- MySQL 8.0 o superior (usa `CHECK`, columnas `GENERATED` y funciones/triggers).
- Un cliente MySQL: consola `mysql`, MySQL Workbench, DBeaver, etc.

### Pasos

1. **Clona o descarga** la carpeta `pizzeria-don-piccolo/`.
2. Ejecuta los scripts **en este orden exacto** (cada uno depende del anterior):

```bash
mysql -u root -p < database.sql
mysql -u root -p < funciones.sql
mysql -u root -p < triggers.sql
mysql -u root -p < vistas.sql
mysql -u root -p < consultas.sql
```

   O si prefieres trabajar desde el cliente `mysql` interactivo:

```sql
SOURCE /ruta/database.sql;
SOURCE /ruta/funciones.sql;
SOURCE /ruta/triggers.sql;
SOURCE /ruta/vistas.sql;
SOURCE /ruta/consultas.sql;
```

3. El script `database.sql` ya incluye **datos de prueba** (clientes,
   ingredientes, pizzas, recetas, repartidores, pedidos y domicilios), por
   lo que las funciones, triggers, vistas y consultas pueden probarse de
   inmediato.

### Nota sobre funciones y `log_bin_trust_function_creators`

Si al ejecutar `funciones.sql` obtienes el error:

```
ERROR 1418: This function has none of DETERMINISTIC ...

Es porque el servidor tiene activado el *binary logging* y por seguridad
exige permisos especiales para crear funciones que leen datos. El script
ya incluye la línea:

```sql
SET GLOBAL log_bin_trust_function_creators = 1;
```

Si tu usuario no tiene privilegios para modificar variables globales,
pide a un administrador que ejecute esa línea antes, o crea las funciones
con un usuario con privilegios `SUPER`/`SYSTEM_VARIABLES_ADMIN`.

---

> **Nota importante sobre el orden de ejecución:** los pedidos, detalles y
> domicilios de prueba se insertan en `database.sql`, **antes** de que
> existan los triggers (que se crean en `triggers.sql`). Esto es
> intencional: es una carga inicial de datos históricos y no debe
> disparar automatizaciones. Por eso el stock de ingredientes de la
> sección 9 de `database.sql` aparece "completo" aunque ya haya pedidos
> registrados, y los repartidores figuran como `Disponible`. Los triggers
> sí actúan sobre **cualquier pedido o domicilio nuevo** que se inserte
> después de ejecutar `triggers.sql` (ver los ejemplos a continuación).

## 9. Ideas de prueba rápida (flujo completo)

```sql
-- 1. Ver el stock antes de vender
SELECT * FROM ingredientes WHERE nombre = 'Queso mozzarella';

-- 2. Registrar un nuevo pedido y su detalle
INSERT INTO pedidos (id_cliente, metodo_pago) VALUES (2, 'Efectivo');
INSERT INTO detalle_pedido (id_pedido, id_pizza, cantidad, precio_unitario)
VALUES (LAST_INSERT_ID(), 1, 1, 35000);
-- -> el trigger descuenta automáticamente el stock de masa, salsa, queso y pepperoni

-- 3. Actualizar el total del pedido con el envío incluido
CALL sp_actualizar_total_pedido(LAST_INSERT_ID());

-- 4. Cambiar el precio de una pizza y ver el historial
UPDATE pizzas SET precio_base = 37000 WHERE id_pizza = 1;
SELECT * FROM historial_precios;

-- 5. Registrar la entrega de un domicilio
CALL sp_registrar_entrega(1, NOW());
SELECT estado_pedido FROM pedidos WHERE id_pedido = 1;      -- 'Entregado'
SELECT estado FROM repartidores WHERE id_repartidor = 1;    -- 'Disponible'
```

---

## 10. Autoría

Proyecto académico desarrollado para la asignatura de bases de datos
(MySQL 2), con fines de aprendizaje sobre modelado relacional, funciones,
procedimientos, triggers, vistas y consultas SQL avanzadas.


# examen

## descripcion

la pizzeria don piccolo desea mejorar el control de sus pedidos para esto se modelo una mejor tabla de pedidos con relacion a los clientes y a las pizzas que permita obtener informacion mas util a la hora de consultar.

## pasos que hice

-copie y pegue las tablas clientes, pizzas, pedidos, detalle_pedido y los inserts, para asi tener un scripts unico del examen que sea funcional.
-luego agregue el update para la axtualizacion del estado del pedido.
-finalmente cree 4 consultas que considero necesarias para la pizzeria.

Consulta 1
"esta ordena los pedidos del mas viejo al mas nuevo para priorizar el hacer de las pizzas, bastante util en situaciones de presion"

Consulta 2 
"esta da un resume de cuántos pedidos tengo pendientes, cuántos en preparación, cuántos ya entregados."

Consulta 3 
"Del pedido número 1, quien lo pidio, qué pizza, cuántas de cada una, y cuánto vale con su factura."

Consulta 4
"muestra todos los pedidos echos en el mes."


