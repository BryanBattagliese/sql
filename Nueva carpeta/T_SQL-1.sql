use [gd2015c1]
go

/* 
 Se requiere mantener precalculada toda la informacion relacionada con las ventas, de modo que pueda
 consultarse de forma rapida y eficiente.
 La información debe incluir para cada combinación de mes, anio y producto:
 + Cantidad total vendida
 + Precio MAX venta
 + Precio MIN venta
 + Cliente que mas compro (cantidad)

 Garantizar que la info este disponible y actualizada, reflejando los datos de ventas.
 Permitir un acceso optimizado a las consultas filtradas por mes y año.
*/

-- Tabla donde se guardará esta información
CREATE TABLE Ventas_Realizadas (
    mes_anio CHAR(6),
    cod_prod CHAR(8),
    cant_total_vendida INT,
    precio_max DECIMAL(12,2),
    precio_min DECIMAL(12,2),
    mejor_cliente CHAR(8),
    cant_comprada_mejor_cliente INT
) GO

--Para estar siempre actualizada, al detectar una venta cargo la informacion en la nueva tabla
CREATE TRIGGER nueva_venta ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN 
  SET NOCOUNT ON

  -- CASO UPDATE Y CASO INSERT
  IF EXISTS (SELECT 1 FROM inserted)
  BEGIN
  BEGIN TRAN
    
  -- UPDATE: Realizo un update para los productos que tienen un registro para ese periodo
    UPDATE v SET 
    v.cant_total_vendida = cant_total_vendida + i.item_cantidad,
    v.precio_max = CASE WHEN i.item_precio > v.precio_max THEN i.item_precio ELSE v.precio_max END,
    v.precio_min = CASE WHEN i.item_precio < v.precio_min THEN i.item_precio ELSE v.precio_min END,
    v.mejor_cliente = CASE WHEN i.item_cantidad > v.cant_comprada_mejor_cliente THEN f.fact_cliente ELSE v.mejor_cliente END,
    v.cant_comprada_mejor_cliente = CASE WHEN i.item_cantidad > v.cant_comprada_mejor_cliente THEN i.item_cantidad ELSE v.cant_comprada_mejor_cliente END
  
    FROM Ventas_Realizadas v JOIN inserted i ON v.cod_prod = i.item_producto JOIN Factura f ON i.item_numero =  f.fact_numero AND i.item_sucursal = f.fact_sucursal AND f.fact_tipo = i.item_tipo
    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
 
    -- INSERT: Realizo un insert en donde no existe registro de ese producto para ese periodo
    INSERT INTO Ventas_Realizadas(mes_anio, cod_prod, cant_total_vendida, precio_max, precio_min, mejor_cliente, cant_comprada_mejor_cliente)
    SELECT
        CONCAT(MONTH(fact_fecha), YEAR(f.fact_fecha)) AS mes_anio,
        i.item_producto AS cod_prod,
        i.item_cantidad AS cant_total_vendida,
        i.item_precio AS precio_max,
        i.item_precio AS precio_min,
        f.fact_cliente AS mejor_cliente,
        i.item_cantidad AS cant_comprada_mejor_cliente
    FROM inserted i JOIN Factura f ON i.item_numero =  f.fact_numero AND i.item_sucursal = f.fact_sucursal AND f.fact_tipo = i.item_tipo
    WHERE NOT EXISTS (SELECT 1 FROM Ventas_Realizadas v WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
          AND 
          v.cod_prod = i.item_producto)
    COMMIT TRAN
    END 

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
    BEGIN TRAN
    UPDATE v SET 
    v.cant_total_vendida = cant_total_vendida - d.item_cantidad

    FROM Ventas_Realizadas v JOIN deleted d ON v.cod_prod = d.item_producto JOIN Factura f ON d.item_numero =  f.fact_numero AND d.item_sucursal = f.fact_sucursal AND f.fact_tipo = d.item_tipo
    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
    COMMIT TRAN
    END
END
GO

-- Para acceso 'optimizado', creo un indice por mes y año
CREATE CLUSTERED INDEX idx_mes_anio ON Ventas_Realizadas(mes_anio)
GO