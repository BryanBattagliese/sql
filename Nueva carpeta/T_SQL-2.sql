use[GD2015C1]
go

/*

Implementar una regla de negocio para mantener siempre consistente (actualizada bajo cualquier circunstancia) INSERT UPDATE DELETE
una nueva tabla llamada PRODUCTOS_VENDIDOS. 

En esta tabla debe registrar el periodo (YYYYMM), el código de producto, el precio máximo de venta  y las unidades vendidas. 
  
Toda esta información debe estar por periodo (YYYYMM).

*/

create table productos_vendidos (
	periodo char(6),
	producto char(8),
	precio_max decimal(12,2),
	u_vendidas int
) go

create trigger vendidos on Item_Factura
after insert, update, delete
as
begin
set nocount on

	if exists (select 1 from inserted)
	begin
	begin tran

	-- UPDATE
	update v set
	v.precio_max = case when i.item_precio > v.precio_max then i.item_precio else v.precio_max end,
	v.u_vendidas = u_vendidas + i.item_cantidad
	from productos_vendidos v join inserted i on v.producto = i.item_producto join Factura f on i.item_numero =  f.fact_numero AND i.item_sucursal = f.fact_sucursal AND fact_tipo = i.item_tipo
	where v.periodo = concat(year(f.fact_fecha), month(f.fact_fecha))

	-- INSERT
	insert into productos_vendidos(periodo,producto,precio_max,u_vendidas)
	select
		concat(year(f.fact_fecha), month(f.fact_fecha)) as periodo,
		i.item_producto as producto,
		i.item_precio as precio_max,
		i.item_cantidad as u_vendidas
	from inserted i join Factura f on i.item_numero = f.fact_numero AND i.item_sucursal = f.fact_sucursal AND f.fact_tipo = i.item_tipo
	where not exists(select 1 from productos_vendidos v where v.periodo = concat(year(f.fact_fecha), month(f.fact_fecha))
		  and v.producto = i.item_producto)

	commit
	end

	-- DELETED
	if exists (select 1 from deleted)
	begin
	begin tran
	
	update v set
	v.u_vendidas = u_vendidas - d.item_cantidad,
	v.precio_max = case when v.precio_max = d.item_precio then 
	(	select max(i2.item_precio)
        from Item_Factura i2
        join Factura f2 on i2.item_tipo = f2.fact_tipo and i2.item_sucursal = f2.fact_sucursal and i2.item_numero = f2.fact_numero
        where i2.item_producto = d.item_producto and CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = v.periodo
	)
    else v.precio_max end
	from productos_vendidos v join deleted d on v.producto = d.item_producto join Factura f on d.item_numero =  f.fact_numero AND d.item_sucursal = f.fact_sucursal AND fact_tipo = d.item_tipo
	where v.periodo = concat(year(f.fact_fecha), month(f.fact_fecha))
	
	commit
	end

end
go