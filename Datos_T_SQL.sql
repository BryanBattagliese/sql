use[GD2015C1]
go

---------------------
-- Consideraciones --

-- Count         : cuenta la "cantidad de filas".
-- Count (*)     : todas las filas de esa tabla.
-- Count columna : todas las filas donde esa columna no es nula.

-- SUM           : suma el valor numérico de esa columna. Ignora los valores NULL.

-- ¿Cuando uso COUNT?   - Cuando no me importa el valor de esos datos.  (para validar existencia... ej: "existe al menos uno ")
-- ¿Cuando uso SUM?     - Cuando necesito el valor total de una columna.(para validar límites... ej: "el total es +100")

-- Alter: cambia o agrega columnas
-- Update: para actualizar datos/campos
---------------------------------------------------------------------------------------------------------------------------

-- (en base al siguiente ejercicio de parcial) 
/* Se agregó recientemente un campo CUIT a la tabla de clientes. 
Debido a un error, se generaron múltiples registros de clientes con el mismo CUIT.
Se deberá desarrollar un algoritmo de depuración de datos que identifique y corrija
estos duplicados, manteniendo un único registro por CUIT. Será necesario definir un
criterio de selección para determinar qué registro conservar y cuáles eliminar.
Adicionalmente, se deberá implementar una restricción que impida la creación futura
de registros con CUIT duplicado. 
*/

-- Modificar una tabla existente: 
-- Crear un nuevo campo/columna
alter table cliente add clie_cuit char(13)

-- Crear tabla aux para guardar algunos datos (en este ejemplo, busco los CUITs unicos... y los inserto)
create table cliente_aux(cod char(6), cuit char(13))
insert into cliente_aux
select min(clie_codigo), clie_cuit
from Cliente
group by clie_cuit

-- Elmino los datos de esa columna de la tabla original
update cliente set clie_cuit = null

-- Inserto los nuevos datos que tenia en la tabla auxiliar
update cliente set clie_cuit = (select cuit from cliente_aux where cod = clie_codigo)

-- Seteo que un campo de la tabla sea "unico" (para ahorrarme el trigger a la hora de insertar)
alter table cliente add constraint unica unique (clie_cuit)
go

------------------------------
/* Otra forma de resolverlo */
------------------------------
ALTER TABLE Cliente ADD clie_cuit char(10)
GO

CREATE PROCEDURE depurar_duplicados
AS
BEGIN
     DELETE FROM Cliente WHERE clie_codigo NOT IN ( --me quedo con el minimo y borro lo demas 
     SELECT MIN(clie_codigo)
     FROM Cliente
     GROUP BY clie_cuit)
END
GO

CREATE TRIGGER detectar_duplicados ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
     IF EXISTS (SELECT 1 FROM inserted GROUP BY clie_cuit HAVING COUNT(1) > 1) --si hay uno multiplicado por cuit
     BEGIN ROLLBACK TRANSACTION --deshago la operacion
     RAISERROR('ERROR: Se esta cargando mas de una vez un mismo CUIT'),
     END
END
GO

/* TRIGGER + FUNCIóN RECURSIVA  
Ejercicio 12: Cree el/los objetos de base de datos necesarios para que nunca un producto pueda ser compuesto por sí mismo. 
Se sabe que en la actualidad dicha regla se cumple y que la base de datos es accedida por n aplicaciones de diferentes 
tipos y tecnologías. No se conoce la cantidad de  niveles de composición existentes.
--
Es un trigger que se ejecuta "AFTER INSERT" un registro. En caso de que cumpla con la condición, se rollbackea.
La condicion, la evaluamos de forma RECURSIVA en una funcion. 

*/
CREATE FUNCTION ejE12 (@componente char(8), @producto char(8))
RETURNS INT
AS
BEGIN
     DECLARE @retorno int, @comp char(8)

	   IF @producto = @componente
	     SET @retorno = 1
	   
	   ELSE 
	     BEGIN
	      DECLARE cur CURSOR FOR SELECT comp_componente FROM Composicion WHERE comp_producto = @producto
          OPEN cur
	      FETCH NEXT FROM cur INTO @comp
	      WHILE @@FETCH_STATUS = 0 AND @retorno = 0
	       BEGIN
		        SELECT @retorno = dbo.ejE12(@producto, @comp)
		        FETCH NEXT FROM cur INTO @comp
	       END
		 CLOSE cur 
		 DEALLOCATE cur
		END

	RETURN @retorno
END
GO

CREATE TRIGGER ejercicio12 ON Composicion AFTER INSERT 
AS BEGIN 
   IF (SELECT COUNT(*) FROM inserted i  WHERE dbo.ejE12(i.comp_componente,i.comp_producto) = 1) > 0
   BEGIN ROLLBACK TRANSACTION
   END
END
GO 

/* TRIGGER + FUNCIóN RECURSIVA  
Ejercicio 13: Cree el/los objetos de base de datos necesarios para implantar la siguiente regla “Ningún jefe puede tener 
un salario mayor al 20% de las suma de los salarios de sus empleados totales (directos + indirectos)”. Se sabe que en la 
actualidad dicha regla se cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos y tecnologías
--
Es un trigger que se ejecuta AFTER UPDATE - DELETE, debido a que al eliminar o cambiar el sueldo de un empleado, podría afectar
a este calculo del 20% mientras que con un INSERT, este calculo siempre hace cumplir la regla.
La condición la evaluamos en una función, en la que dentro del RETURN aplicamos la recursividad ("indirectos")
*/
CREATE FUNCTION ej13 (@codigo numeric(6))
RETURNS INT
AS
BEGIN
    RETURN (SELECT SUM(empl_salario + dbo.ej13(empl_codigo)) FROM Empleado WHERE empl_jefe = @codigo)

END
GO

CREATE TRIGGER ejercicio13 ON Empleado AFTER UPDATE, DELETE
AS
BEGIN 
     IF(SELECT COUNT(*) FROM inserted i WHERE (SELECT empl_salario FROM Empleado WHERE empl_codigo = i.empl_jefe) 
	  < dbo.ej13(i.empl_jefe) * 0.2) < 0 -- cuento los jefes para los que los salarios de sus empleados son menores a 
      BEGIN ROLLBACK TRANSACTION
	  PRINT 'El salario del jefe no puede ser mayor al 20% de la suma de los de sus empleados'
      END

	  BEGIN
	  IF(SELECT COUNT(*) FROM deleted d WHERE (SELECT empl_salario FROM Empleado WHERE empl_codigo = d.empl_jefe) 
	  < dbo.ej13(d.empl_jefe) * 0.2) < 0 -- cuento los jefes para los que los salarios de sus empleados son menores a 
      ROLLBACK TRANSACTION
	  PRINT 'El salario del jefe no puede ser mayor al 20% de la suma de los de sus empleados'
      END
END
GO

/* FUNCIóN RECURSIVA 
Ejercicio 15: Cree el/los objetos de base de datos necesarios para que el objeto principal reciba un producto como parametro y retorne 
el precio del mismo. Se debe prever que el precio de los productos compuestos sera la sumatoria de los componentes del mismo multiplicado
por sus respectivas cantidades.  No se conocen los nivles de anidamiento posibles de los productos. Se asegura que nunca un producto esta 
compuesto por si mismo a ningun nivel. El objeto principal debe poder ser utilizado como filtro en el where de una sentencia select.
*/
CREATE FUNCTION ejercicio15 (@prodCod char(8))
RETURNS decimal(12,2)
AS
BEGIN
    DECLARE @precioTotal decimal(12,2)

    -- Verifica si el producto es COMPUESTO
    IF EXISTS (SELECT 1 FROM Composicion WHERE comp_producto = @prodCod)
    BEGIN
        -- SÍ ES COMPUESTO (Caso Recursivo)
        -- Calcula el precio sumando el precio de CADA componente
        -- (llamando a esta misma función) multiplicado por su cantidad.
        SELECT @precioTotal = SUM(dbo.ejercicio15(c.comp_componente) * c.comp_cantidad)
        FROM Composicion c
        WHERE c.comp_producto = @prodCod
    END
    ELSE
    BEGIN
        -- NO ES COMPUESTO (Caso Base)
        -- Simplemente obtiene el precio de la tabla Producto.
        SELECT @precioTotal = prod_precio
        FROM Producto
        WHERE prod_codigo = @prodCod
    END

    -- Devuelve el precio (el simple o el calculado)
    -- Se usa ISNULL por si un producto simple no tiene precio y devuelve NULL.
    RETURN ISNULL(@precioTotal, 0)
END
GO

----------------------------------------------------------------------------------------------------------------------
-- Ejercicio de parcial: (Trabajo con PK, FK y drop)

/* Por un error de programación la tabla item factura le ejecutaron DROP a la primary key y a sus foreign key.
Este evento permitió la inserción de filas duplicadas (exactas e iguales) y también inconsistencias debido a la falta de FK.
Realizar un algoritmo que resuelva este inconveniente depurando los datos de manera coherente y lógica y que deje la estructura de la tabla item 
factura de manera correcta. */

CREATE TABLE Item_Factura_Nueva (
    item_tipo char(1),
    item_sucursal char(4),
    item_numero char(8),
    item_producto char(8),
    item_cantidad decimal(12,2),
	item_precio decimal(12,2)
)

INSERT INTO Item_Factura_Nueva (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
SELECT DISTINCT item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio
FROM Item_Factura
-- Where prod and fact is not null ...

TRUNCATE TABLE Item_Factura

INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
SELECT item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio
FROM Item_Factura_Nueva

ALTER TABLE Item_Factura
ADD FOREIGN KEY (item_tipo, item_sucursal, item_numero) REFERENCES Factura (fact_tipo, fact_sucursal, fact_numero);

ALTER TABLE Item_Factura
ADD FOREIGN KEY (item_producto) REFERENCES Producto (prod_codigo)

DROP TABLE Item_Factura_Nueva
go

-----
-- Ejercicio de parcial (trigger) 
/* Implementar una regla de negocio en línea donde nunca una factura
nueva tenga un precio de producto distinto al que figura en la tabla
PRODUCTO. Registrar en una estructura adicional todos los casos
donde se intenta guardar un precio distinto. 
*/

-- Creo la tabla "erronea" para guardar los datos

create table factura_erronea(
		tipo char(1), 
		sucursal char(4), 
		numero char(8), 
		fecha smalldatetime, 
		vendedor numeric(6,0), 
		totalErroneo decimal(12,2),
		totalErroneoImp decimal(12,2), 
		cliente char(6)
) go

create trigger ejercicioParcialN on Item_factura instead of insert
as
begin

	-- Si existe algun insertado con precio DISTINTO ...
	if exists (
	select *
	from Producto p join inserted i on i.item_producto=p.prod_codigo
	where p.prod_precio <> i.item_precio
	)
	
	begin
	-- Registro en tabla alternativa los datos "incorrectos"
	insert into factura_erronea(tipo,sucursal,numero,fecha,vendedor,totalErroneo,totalErroneoImp,cliente)
	select 
		i.item_tipo,
		i.item_sucursal,
		i.item_numero,
		f.fact_fecha,
		f.fact_vendedor,
		f.fact_total,
		f.fact_total_impuestos,
		f.fact_cliente

	from inserted i join Factura f on f.fact_sucursal = i.item_sucursal and
									  i.item_tipo = f.fact_tipo and
									  i.item_numero = f.fact_numero
	print('El precio de algun producto no coincide con el "item" de la factura')
	end

	else
		insert into Item_Factura(item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
		select i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto, i.item_cantidad, i.item_precio
		from inserted i
		join Producto p on i.item_producto = p.prod_codigo
		where p.prod_precio = i.item_precio
end
go

-----
-- Ejercicio de parcial (trigger)
/* Implementar una regla de negocio de validación en línea que permita
implementar una lógica de control de precios en las ventas. 
Se deberá poder seleccionar una lista de rubros y aquellos productos de los rubros
que sean los seleccionados no podrán aumentar por mes más de un 2%. 
En caso que no se tenga referencia del mes anterior no validar dicha regla. */

CREATE TABLE rubros_seleccionados (cod_rubro char(8))
GO

create trigger ejParcialn2 on Producto after update 
as
begin

	if exists(
		select 1
		from inserted p join rubros_seleccionados r on r.cod_rubro = p.prod_rubro
		join Item_Factura it on p.prod_codigo = it.item_producto join Factura fac on 
									  fac.fact_sucursal = it.item_sucursal and
									  it.item_tipo = fac.fact_tipo and
									  it.item_numero = fac.fact_numero

		where p.prod_precio > 1.02 * 
		(
			select i.item_precio,0
			from Item_Factura i join Factura f 
			on f.fact_sucursal = i.item_sucursal
			and i.item_tipo = f.fact_tipo 
			and i.item_numero = f.fact_numero
			
			where (month(f.fact_fecha) = month((fac.fact_fecha)-1)) and i.item_producto = p.prod_codigo
			
		)
	)

	begin rollback transaction
	end
end
go

