use[GD2015C1]
go

-- NO PUEDO USAR SUM EN EL WHERE !!!

/* EJERCICIOS DE PARCIAL */

/* Realizar una consulta SQL que permita saber los clientes que
compraron por encima del promedio de compras (fact_total) de todos
los clientes del 2012.

De estos clientes mostrar para el 2012:
1. El código del cliente
2. La razón social del cliente
3. Código de producto que en cantidades más compro.
4. El nombre del producto del punto 3.
5. Cantidad de productos distintos comprados por el cliente,
6. Cantidad de productos con composición comprados por el cliente,

El resultado deberá ser ordenado poniendo primero aquellos clientes
que compraron más de entre 5 y 10 productos distintos en el 2012 */

select
	c.clie_codigo as codigo,
	c.clie_razon_social as razon_social,
	
	(select top 1 i.item_producto
	from Item_Factura i join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012'
	group by i.item_producto
	order by sum(i.item_cantidad) desc) as cod_mas_comprado,
	
	(select top 1 p.prod_detalle
	from Item_Factura i join Producto p on p.prod_codigo = i.item_producto join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012'
	group by i.item_producto
	order by sum(i.item_cantidad) desc) as prod_mas_comprado,

	(select count (distinct i.item_producto)
	from Item_Factura i join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012') as productos_comprados,
	
	(select count (distinct i.item_producto)
	from Item_Factura i join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	join Composicion co on co.comp_producto = i.item_producto
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012') as comp_comprado

from Cliente c

where 
(select sum (f.fact_total) from Factura f 
where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012') 
>
(select avg(f.fact_total) from Factura f 
where year(f.fact_fecha) = '2012')

/* La idea es crear dos grupos:
- Uno con los clientes que hayan comprado entre 5 y 10 prod
- Otro con el resto
*/
order by -- aqui no se puede usar un where
    case
		-- Condicion para detectar entre 5 y 10 productos...
        when (select count(distinct i.item_producto)
              from Item_Factura i
              join Factura f on f.fact_tipo = i.item_tipo 
                              and f.fact_sucursal = i.item_sucursal 
                              and f.fact_numero = i.item_numero
              where f.fact_cliente = c.clie_codigo
                and YEAR(f.fact_fecha) = 2012
             ) BETWEEN 5 AND 10
        
		-- When = true => Grupo 1
		then 1
		-- When = false => Grupo 2
        else 2
	-- Primero el 1 despues el 2
    end asc
go

/* Realizar una consulta SQL que retorne para los 10 clientes que más
compraron en el 2012 y que fueron atendldos por más de 3 vendedores
distintos:

• Apellido y Nombro del Cliente.
• Cantidad de Productos distmtos comprados en el 2012,
• Cantidad de unidades compradas dentro del primer semestre del 2012.
• El resultado deberá mostrar ordenado la cantidad de ventas descendente
  del 2012 de cada cliente, en caso de igualdad de ventas ordenar porcódigo de cliente. */

select top 10
	c.clie_razon_social as cliente, 
	
	(select count (distinct i.item_producto)
	from Item_Factura i join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012') as productos_comprados,

	(select sum(i.item_cantidad)
	from Item_Factura i join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012' 
	and month(f.fact_fecha) <= 6) as unidades_primer_semestre

from Cliente c
where(select count (distinct f2.fact_vendedor) from Factura f2 
	  where YEAR(f2.fact_fecha) = 2012 and f2.fact_cliente = c.clie_codigo) > 3

order by(

	select sum(f.fact_total)
	from Factura f 
	where f.fact_cliente = c.clie_codigo and year(f.fact_fecha) = '2012'
) desc, c.clie_codigo
go


/* Crear una consulta SQL que identifique los 10 primeros productos que, 
Los datos a mostrar por cada producto que cumpla con la consigna son:
(1.) Nombre del producto
(2.) Fecha de última compra del producto
(3.) Cantidad de clientes que lo compraron en el 2025.

durante tres años consecutivos, hayan registrado en cada año un incremento mínimo del
20 % en sus cantidades vendidas respecto al año anterior.

De los productos seleccionados, mostrar únicamente aquellos que actualmente
dispongan de stock en al menos el 75 % de los depósitos. */

select
	top 10 p.prod_detalle as producto,
	
	(
		select top 1 f2.fact_fecha
		from Item_Factura i2 join Factura f2
		on f2.fact_numero+f2.fact_sucursal+f2.fact_tipo=i2.item_numero+i2.item_sucursal+i2.item_tipo
		where i2.item_producto = p.prod_codigo
		order by f2.fact_fecha desc

	) as ult_vez_comprado,
	
	(
		select count (distinct f3.fact_cliente)
		from Item_Factura i3 join Factura f3
		on f3.fact_numero+f3.fact_sucursal+f3.fact_tipo=i3.item_numero+i3.item_sucursal+i3.item_tipo
		where i3.item_producto = p.prod_codigo and year(f3.fact_fecha) = '2012'
		
	) as clientes_compradores

from Producto p

group by p.prod_detalle, p.prod_codigo

having(
	
	select count (distinct s.stoc_producto)
	from Stock s
	where p.prod_codigo = s.stoc_producto

) > (select count (*) * 0.75 from DEPOSITO)

/*
Se solicita estadística por Año y familia, para ello se deberá mostrar:

+ Año, 
+ Código de familia, 
+ Detalle de familia,
+ cantidad de facturas, 
+ cantidad de productos con Composición vendidos, 
+ monto total vendido.

Solo se deberán considerar las familias que tengan al menos un producto con
composición y que se hayan vendido conjuntamente (en la misma factura)
con otra familia distinta.
*/

select 
	year(f.fact_fecha) as año,
	fa.fami_id as cod_flia,
	fa.fami_detalle as detalle_flia,
	sum(i.item_cantidad*i.item_precio) as total_vendido,
	
	count (distinct f.fact_numero+f.fact_sucursal+f.fact_tipo) as cant_facturas,
	
	(select sum(i2.item_cantidad)
	from Composicion c join Item_Factura i2 
	on i2.item_producto=c.comp_producto
	join Factura f2 on f2.fact_numero+f2.fact_sucursal+f2.fact_tipo=i2.item_numero+i2.item_sucursal+i2.item_tipo
	join Producto p2 on p2.prod_codigo = i2.item_producto
	where year(f2.fact_fecha) = year(f.fact_fecha) and
	fa.fami_id = p2.prod_familia) as prod_compuestos

from Item_Factura i join Factura f 
on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo
join Producto p on p.prod_codigo = i.item_producto join Familia fa on fa.fami_id = p.prod_familia

where 

-- Que la familia tenga al menos un producto compuesto
fa.fami_id in (
	select fa1.fami_id from Composicion c1
	join Producto p1 on p1.prod_codigo = c1.comp_producto
	join Familia fa1 on fa1.fami_id = p1.prod_familia
	join Item_Factura i1 on i1.item_producto=p1.prod_codigo
	join Factura f1 on f1.fact_numero+f1.fact_sucursal+f1.fact_tipo=i1.item_numero+i1.item_sucursal+i1.item_tipo
	group by fa1.fami_id)

-- Que la familia se haya vendido en una misma factura con prod de otre familia
and fa.fami_id in  (
	select p1.prod_familia from Producto p1 
	join Item_Factura i1 on i1.item_producto = p1.prod_codigo
	join Item_Factura i2 on i1.item_numero+i1.item_sucursal+i1.item_tipo = i2.item_numero+i2.item_sucursal+i2.item_tipo
	join Producto p2 on p2.prod_codigo = i2.item_producto
	where p2.prod_familia <> p1.prod_familia
	group by p1.prod_familia)

group by year(f.fact_fecha),fa.fami_id,fa.fami_detalle
order by 6 desc

---
