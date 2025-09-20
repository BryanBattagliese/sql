USE [GD2015C1]

-- EJERCICIO 11 --

--Realizar una consulta que retorne el  a, 
--la cantidad diferentes de productos vendidos y el monto de dichas 
--ventas sin impuestos. Los datos se deberán ordenar de mayor a menor,
--por la familia que más productos diferentes vendidos tenga, solo se 
--deberán mostrar las familias que tengan una venta superior a 20000 
--pesos para el año 2012. 

SELECT 
	f.fami_detalle, 
	COUNT(DISTINCT(p.prod_codigo)) AS cantidadProductos,
	SUM(i.item_precio * i.item_cantidad) AS monto, f.fami_id 
FROM 
	Familia f 
	JOIN producto p ON f.fami_id = p.prod_familia 
	JOIN Item_Factura i ON p.prod_codigo = i.item_producto 

GROUP BY 
	f.fami_id, 
	f.fami_detalle 

HAVING 
	(SELECT SUM(i2.item_cantidad * i2.item_precio) 
		FROM 
		producto p2 
			JOIN Item_Factura i2 ON p2.prod_codigo = i2.item_producto
			JOIN factura f2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal and f2.fact_numero = i2.item_numero 
		WHERE 
			p2.prod_familia = f.fami_id AND YEAR(f2.fact_fecha) = 2012 ) > 20000

ORDER BY 2

------------------------
-- EJERCICIO 12 --
-- Mostrar nombre de producto, cantidad de clientes distintos que lo compraron, importe prom pagado
-- cant de depositos en los q hay stock y stock actual del producto en todos los depositos
-- mostrar aquellos productos que hayan tenido operaciones en 2012. order by asc monto vendido x prod

SELECT
	p.prod_detalle,
	count(distinct f.fact_cliente) as clientes_q_compraron,
	SUM(i.item_cantidad * i.item_precio) / SUM (i.item_cantidad) as promedio,

	(SELECT COUNT (*) from stock s2
	where s2.stoc_producto = p.prod_codigo
	and s2.stoc_cantidad > 0) as cant_depositos,
	
	(SELECT ISNULL(SUM(s2.stoc_cantidad),0) from stock s2
	where s2.stoc_producto = p.prod_codigo) as stock_actual

FROM Producto p
	join Item_Factura i on p.prod_codigo = i.item_producto
	join Factura f on f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal and f.fact_numero = i.item_numero 

GROUP BY
	p.prod_codigo,
	p.prod_detalle

HAVING EXISTS 

	(SELECT 1 
		FROM Item_Factura i2 join Factura f2 on 
		f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal and f2.fact_numero = i2.item_numero 
		
		WHERE YEAR(f2.fact_fecha) = 2012 AND i2.item_producto = p.prod_codigo
		)

ORDER BY
	SUM(i.item_cantidad * i.item_precio) DESC

------------------------------------------------------------------------
-- EJERCICIO 18 -- :( :(

SELECT 
	r.rubr_id as ID_RUBRO,
	r.rubr_detalle as DETALLE_RUBRO,

	-- VENTAS TOTALES
	(SELECT ISNULL (SUM(i.item_cantidad * i.item_precio), 0)
		FROM Producto p1 join Item_Factura i 
			on i.item_producto = p1.prod_codigo
			WHERE 
				r.rubr_id = p1.prod_rubro) as VENTAS_RUBRO,

	-- PRODUCTO TOP 1
	ISNULL((SELECT TOP 1 p2.prod_codigo
		FROM Producto p2 join Item_Factura i2 on p2.prod_codigo = i2.item_producto
		WHERE r.rubr_id = p2.prod_rubro
		GROUP BY p2.prod_codigo, p2.prod_detalle
		ORDER BY ISNULL(SUM(i2.item_precio * i2.item_cantidad),0) DESC),0)
		AS PROD_TOP_1,

	-- PRODUCTO TOP 2
		ISNULL((
			SELECT TOP 1 p9.prod_codigo
			FROM Producto p9 
			JOIN Item_Factura i9 ON p9.prod_codigo = i9.item_producto
			WHERE r.rubr_id = p9.prod_rubro
			  AND p9.prod_codigo NOT IN (
					SELECT TOP 1 p1.prod_codigo
					FROM Producto p1 
					JOIN Item_Factura i1 ON p1.prod_codigo = i1.item_producto
					WHERE r.rubr_id = p1.prod_rubro
					GROUP BY p1.prod_codigo, p1.prod_detalle
					ORDER BY SUM(i1.item_precio * i1.item_cantidad) DESC
			  )
			GROUP BY p9.prod_codigo, p9.prod_detalle
			ORDER BY SUM(i9.item_precio * i9.item_cantidad) DESC
		), 0) AS PROD_TOP_2
,


	-- CLIENTE QUE MAS GASTO
		ISNULL ((SELECT TOP 1 f.fact_cliente
		FROM Producto p5 join Item_Factura i5 on p5.prod_codigo = i5.item_producto  join Factura f
			on f.fact_tipo = i5.item_tipo AND f.fact_sucursal = i5.item_sucursal AND f.fact_numero = i5.item_numero
		WHERE p5.prod_rubro = r.rubr_id --AND datediff(day, f.fact_fecha, GETDATE()) < 31 -- "ultimos 30 dias"
		GROUP BY f.fact_cliente 
		ORDER BY SUM(i5.item_cantidad * i5.item_precio)), 'SIN_CLIENTE')
		AS CLIE_MAS_COMPRO

FROM Rubro r join Producto p on p.prod_rubro = r.rubr_id
GROUP BY r.rubr_id, r.rubr_detalle
ORDER BY COUNT(DISTINCT p.prod_codigo)

------------------------------------------------------------------------
-- EJERCICIO 14 --
/*	1 Detale del cliente									-- listo
	2 Cantidad de veces que compro en 2012					-- listo
	3 Promedio por compra en 2012							-- listo
	4 Cantidad de productos distintos que compro en 2012	-- listo
	5 Monto de la mayor compra en 2012						-- listo
	retorno : todos los clientes
	order by: 2 
	sin nulos
*/

SELECT	f.fact_cliente as CLIENTE,
		COUNT(f.fact_cliente) as CANT_COMPRAS,
		AVG(f.fact_total) as PROM_COMPRA,
		
		(SELECT
			COUNT(DISTINCT i.item_producto)
		 FROM Item_Factura i join Factura f9 on f9.fact_tipo = i.item_tipo AND f9.fact_sucursal = i.item_sucursal and f9.fact_numero = i.item_numero 
		 WHERE f.fact_cliente = f9.fact_cliente and YEAR(f9.fact_fecha) = 2012
		) as CANT_PRODUCTOS,
		
		(SELECT TOP 1 f2.fact_total
		FROM Factura f2
		WHERE f2.fact_cliente = f.fact_cliente and YEAR(f2.fact_fecha) = 2012
		ORDER BY f2.fact_total DESC
		)as MAYOR_COMPRA

FROM Factura f

WHERE YEAR(f.fact_fecha) = 2012

GROUP BY f.fact_cliente

ORDER BY 2

------------------------------------------------------------------------
-- EJERCICIO 23 --
/*	-- 1 AÑO																
	2 PRODUCTO CON COMPOSICION MAS VENDIDO								
	3 CANTIDAD DE FACTURAS EN DONDE ESTA ESE PROD
	4 CODIGO DEL CLIENTE QUE MAS COMPRO ESE PROD
	5 PORCENTAJE QUE REPRESENTA LA VENTA DE ESE PROD RESPECTO AL TOTAL DE LA VENTA DEL AÑO
	retorno : todos los clientes
	order by: TOTAL VENDIDO POR AÑO DESC
*/

SELECT
	YEAR(f.fact_fecha)

FROM Factura f
GROUP BY YEAR(f.fact_fecha)

------------------------------------------------------------------------
-- EJERCICIO 24 --

/*	1. Detalle rubro
	2. Num de trimestre del año
	3. Cant de facturas emitidas ese trimestre con al menos 1 prod de ese rubro
	4. Cant de productos diferentes del rubro vendidos ese trimestre
	
	Order by detalle rubro asc
	No mostrar rubros ni trimestres con -100 facturas emitidas */

---

SELECT 
	DATEPART(QUARTER, f.fact_fecha) as TRIMESTRE,
	r.rubr_detalle as DETALLE_RUBRO,
	COUNT(DISTINCT CONCAT(f.fact_numero ,f.fact_sucursal, f.fact_tipo)) as CANT_FACTURAS_EMITIDAS,
	COUNT(DISTINCT p.prod_codigo) as CANT_PROD_DIFERENTES

FROM Factura f join Item_Factura i on f.fact_numero = i.item_numero
	and f.fact_sucursal = i.item_sucursal and f.fact_tipo = i.item_tipo
	join Producto p on p.prod_codigo = i.item_producto
	join Rubro r on p.prod_rubro = r.rubr_id

GROUP BY DATEPART(QUARTER, f.fact_fecha), r.rubr_id, r.rubr_detalle
ORDER BY 2, 3 DESC

--------

/* nota:7 sin comentarios del profesor.
1. Realizar una consulta SQL que muestre aquellos clientes que en 2
años consecutivos compraron.
De estos clientes mostrar
	El código de cliente.
	El nombre del cliente.
	El numero de rubros que compro el cliente.
	La cantidad de productos con composición que compro el cliente en el 2012.

El resultado deberá ser ordenado por cantidad de facturas del cliente en toda la historia, 
de manera ascendente.
*/

SELECT
	c.clie_codigo, 
	c.clie_razon_social,
	COUNT(DISTINCT r.rubr_detalle) AS RUBROS_COMPRADOS,

	(
	SELECT COUNT(DISTINCT c2.comp_producto) 
	FROM Composicion c2 join Item_Factura i2 on i2.item_producto = c2.comp_producto join Factura f2 on
	f2.fact_numero = i2.item_numero and f2.fact_sucursal = i2.item_sucursal and f2.fact_tipo = i2.item_tipo
	WHERE f2.fact_cliente = c.clie_codigo AND YEAR(f2.fact_fecha) = 2012
	) AS PROD_COMPUESTOS_COMPRADOS

FROM Cliente c join Factura f on f.fact_cliente = c.clie_codigo
join Item_Factura i on f.fact_numero = i.item_numero and f.fact_sucursal = i.item_sucursal and f.fact_tipo = i.item_tipo
join Producto p on p.prod_codigo = i.item_producto join Rubro r on p.prod_rubro = r.rubr_id

WHERE	0 < ( 
				SELECT 
					COUNT(DISTINCT I5.item_producto)
				FROM Item_Factura I5
				INNER JOIN Factura F5 ON F5.fact_numero = I5.item_numero AND F5.fact_sucursal = I5.item_sucursal AND F5.fact_tipo = I5.item_tipo
				WHERE YEAR(F5.fact_fecha) = YEAR(f.fact_fecha) AND F5.fact_cliente = C.clie_codigo
			 ) AND
		0 < (
				SELECT 
					COUNT(DISTINCT I6.item_producto)
				FROM Item_Factura I6
				INNER JOIN Factura F6 ON F6.fact_numero = I6.item_numero AND F6.fact_sucursal = I6.item_sucursal AND F6.fact_tipo = I6.item_tipo
				WHERE YEAR(F6.fact_fecha) = YEAR(f.fact_fecha) + 1 AND F6.fact_cliente = C.clie_codigo
			 )

GROUP BY
	c.clie_codigo, 
	c.clie_razon_social

ORDER BY COUNT(DISTINCT F.fact_tipo+F.fact_sucursal+F.fact_numero) ASC
----
/*
realiza una consulta SQL que devuelva todos los clientes que durante
2 años consecutivos compraron al menos 5 productos  distintos. 
De esos clientes mostrar.
• codigo cliente
• El monto total comprado en el 2012
• La cantidad de unidades de productos compradas  en el 2012

El resultado debe ser ordenado primero por aquellos clientes que compraron
solo productos compuestos en algún momento, luego el resto.
*/

SELECT
	c.clie_codigo as CLIENTES,
	SUM(CASE WHEN YEAR(f.fact_fecha) = 2012 then f.fact_total ELSE NULL END)as MONTO_TOTAL,
	COUNT(DISTINCT CASE WHEN YEAR(f.fact_fecha) = 2012 then i.item_producto ELSE NULL END) as CANT_PROD_COMPRADOS

FROM Cliente c join Factura f on c.clie_codigo = f.fact_cliente join Item_Factura i
	on i.item_numero = f.fact_numero and f.fact_sucursal = i.item_sucursal and i.item_tipo = f.fact_tipo

WHERE
	  (
		SELECT COUNT (DISTINCT i9.item_producto)
		FROM Cliente c9 join Factura f9 on c9.clie_codigo = f9.fact_cliente join Item_Factura i9
		on i9.item_numero = f9.fact_numero and f9.fact_sucursal = i9.item_sucursal and i9.item_tipo = f9.fact_tipo
		WHERE f9.fact_cliente = c.clie_codigo and YEAR(f9.fact_fecha) = YEAR(f.fact_fecha)
	  ) >= 5
	  and
	  (
		SELECT COUNT (DISTINCT i8.item_producto)
		FROM Cliente c8 join Factura f8 on c8.clie_codigo = f8.fact_cliente join Item_Factura i8
		on i8.item_numero = f8.fact_numero and f8.fact_sucursal = i8.item_sucursal and i8.item_tipo = f8.fact_tipo
		WHERE f8.fact_cliente = c8.clie_codigo and YEAR(f8.fact_fecha) = YEAR(f.fact_fecha) +1
	  ) >= 5

GROUP BY c.clie_codigo

