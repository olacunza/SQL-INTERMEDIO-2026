/***************************************************************
 * SESIÓN 12: CURSORES VS OPERACIONES SET-BASED
 * SQL Server Intermedio - 2026
 * 
 * Contenido:
 *   1. Introducción: Procesamiento fila por fila vs conjunto
 *   2. Anatomía de un cursor
 *   3. Tipos de cursores
 *   4. WHILE loops como alternativa
 *   5. Casos legítimos para cursores
 *   6. Refactorización a set-based
 *   7. Performance comparativo
 *   8. Patrones anti-cursor
 *   9. Mejores prácticas
 *   10. Casos prácticos con BancoDB
 * 
 * Base de datos: BancoDB
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- PARTE 1: INTRODUCCIÓN - FILA POR FILA VS CONJUNTO
-- ============================================================
/*
   SQL Server está optimizado para operaciones SET-BASED
   (procesamiento de conjuntos de datos).
   
   ┌──────────────────────┬─────────────────────────────────────┐
   │ SET-BASED            │ Proceso TODO el conjunto de una vez │
   │                      │ - Un solo plan de ejecución         │
   │                      │ - Optimizador puede paralelizar     │
   │                      │ - Usa índices eficientemente        │
   ├──────────────────────┼─────────────────────────────────────┤
   │ ROW-BY-ROW (Cursor)  │ Procesa UNA fila a la vez           │
   │                      │ - Un plan por cada operación        │
   │                      │ - Sin paralelismo                   │
   │                      │ - Overhead de fetch continuo        │
   └──────────────────────┴─────────────────────────────────────┘
   
   Regla general: Si puedes hacerlo sin cursor, hazlo sin cursor.
*/

-- Ejemplo simple: Actualizar todos los clientes VIP
-- -------------------------------------------------

-- MAL: Con cursor (fila por fila)
DECLARE @ClienteID INT;
DECLARE @NuevoSegmento VARCHAR(50) = 'VIP Plus';

DECLARE cursor_clientes CURSOR FOR
    SELECT ClienteID FROM CLIENTES WHERE Segmento = 'VIP';

OPEN cursor_clientes;
FETCH NEXT FROM cursor_clientes INTO @ClienteID;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Una operación por cada cliente
    UPDATE CLIENTES SET Segmento = @NuevoSegmento WHERE ClienteID = @ClienteID;
    FETCH NEXT FROM cursor_clientes INTO @ClienteID;
END;

CLOSE cursor_clientes;
DEALLOCATE cursor_clientes;

-- BIEN: Set-based (todo de una vez)
UPDATE CLIENTES 
SET Segmento = 'VIP Plus' 
WHERE Segmento = 'VIP';
-- Una sola operación para TODOS los registros


-- ============================================================
-- PARTE 2: ANATOMÍA DE UN CURSOR
-- ============================================================
/*
   Estructura completa de un cursor:
   
   1. DECLARE - Definir el cursor y su query
   2. OPEN    - Ejecutar el query y preparar el conjunto
   3. FETCH   - Obtener filas una por una
   4. CLOSE   - Liberar el conjunto actual
   5. DEALLOCATE - Liberar el cursor completamente
*/

-- Anatomía detallada
DECLARE 
    @CuentaID INT,
    @NumeroCuenta VARCHAR(20),
    @Saldo DECIMAL(18,2),
    @TipoCuenta VARCHAR(50);

-- 1. DECLARE: Definir cursor con opciones
DECLARE cursor_cuentas CURSOR 
    LOCAL           -- Solo visible en este batch/SP
    FAST_FORWARD    -- Solo hacia adelante, solo lectura (más eficiente)
FOR
    SELECT CuentaID, NumeroCuenta, Saldo, TipoCuenta
    FROM CUENTAS
    WHERE Estado = 'Activa'
    ORDER BY Saldo DESC;

-- 2. OPEN: Ejecuta el SELECT y prepara el result set
OPEN cursor_cuentas;

-- 3. FETCH: Obtener primera fila
FETCH NEXT FROM cursor_cuentas 
INTO @CuentaID, @NumeroCuenta, @Saldo, @TipoCuenta;

-- Procesar mientras haya filas
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Aquí va la lógica de procesamiento
    PRINT 'Cuenta: ' + @NumeroCuenta + ' - Saldo: $' + CAST(@Saldo AS VARCHAR(20));
    
    -- FETCH siguiente fila
    FETCH NEXT FROM cursor_cuentas 
    INTO @CuentaID, @NumeroCuenta, @Saldo, @TipoCuenta;
END;

-- 4. CLOSE: Libera el result set actual
CLOSE cursor_cuentas;

-- 5. DEALLOCATE: Libera la definición del cursor
DEALLOCATE cursor_cuentas;


-- @@FETCH_STATUS valores:
-- 0  = Fetch exitoso
-- -1 = Fetch falló (fin del cursor o error)
-- -2 = Fila no encontrada (en cursores KEYSET/DYNAMIC)


-- ============================================================
-- PARTE 3: TIPOS DE CURSORES
-- ============================================================
/*
   Tipos de cursor (de más a menos eficiente):
   
   ┌─────────────────┬──────────────────────────────────────────┐
   │ FAST_FORWARD    │ Solo lectura, solo adelante. MÁS RÁPIDO │
   │ STATIC          │ Copia datos a tempdb. No ve cambios     │
   │ KEYSET          │ Keys en tempdb. Ve cambios de valores   │
   │ DYNAMIC         │ Ve todos los cambios. MÁS LENTO         │
   └─────────────────┴──────────────────────────────────────────┘
*/

-- FAST_FORWARD: El más eficiente (recomendado si solo lees)
DECLARE cursor_ff CURSOR LOCAL FAST_FORWARD
FOR SELECT ClienteID, Nombre FROM CLIENTES WHERE Estado = 'Activo';

-- STATIC: Copia los datos, no ve cambios posteriores
DECLARE cursor_static CURSOR LOCAL STATIC
FOR SELECT ClienteID, Nombre FROM CLIENTES WHERE Estado = 'Activo';

-- KEYSET: Solo las keys, datos actualizados en cada fetch
DECLARE cursor_keyset CURSOR LOCAL KEYSET
FOR SELECT ClienteID, Nombre FROM CLIENTES WHERE Estado = 'Activo';

-- DYNAMIC: El más flexible pero más lento
DECLARE cursor_dynamic CURSOR LOCAL DYNAMIC
FOR SELECT ClienteID, Nombre FROM CLIENTES WHERE Estado = 'Activo';


-- Demostración: Diferencia entre STATIC y DYNAMIC
-- ------------------------------------------------
-- Crear tabla de prueba
IF OBJECT_ID('tempdb..#TestCursor') IS NOT NULL DROP TABLE #TestCursor;
CREATE TABLE #TestCursor (ID INT, Valor VARCHAR(50));
INSERT INTO #TestCursor VALUES (1, 'Original'), (2, 'Original'), (3, 'Original');

-- STATIC no ve cambios
DECLARE @ID INT, @Valor VARCHAR(50);
DECLARE cursor_test CURSOR LOCAL STATIC FOR
    SELECT ID, Valor FROM #TestCursor;

OPEN cursor_test;
FETCH NEXT FROM cursor_test INTO @ID, @Valor;

-- Modificar datos MIENTRAS el cursor está abierto
UPDATE #TestCursor SET Valor = 'Modificado' WHERE ID = 2;
INSERT INTO #TestCursor VALUES (4, 'Nuevo');

PRINT '--- Cursor STATIC (no ve cambios) ---';
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'ID: ' + CAST(@ID AS VARCHAR) + ' - Valor: ' + @Valor;
    FETCH NEXT FROM cursor_test INTO @ID, @Valor;
END;

CLOSE cursor_test;
DEALLOCATE cursor_test;

-- Verificar que los datos sí cambiaron
PRINT '--- Datos reales en la tabla ---';
SELECT * FROM #TestCursor;


-- ============================================================
-- PARTE 4: WHILE LOOPS COMO ALTERNATIVA
-- ============================================================
/*
   Los WHILE loops pueden reemplazar cursores en muchos casos,
   pero siguen siendo fila-por-fila.
   
   Ventajas sobre cursores:
   - Sintaxis más simple
   - Menos overhead de apertura/cierre
   - Más familiar para programadores
   
   Desventajas:
   - Sigue siendo procesamiento secuencial
   - No es set-based
*/

-- Patrón WHILE con tabla temporal numerada
-- ----------------------------------------
IF OBJECT_ID('tempdb..#ClientesProcesar') IS NOT NULL 
    DROP TABLE #ClientesProcesar;

-- Crear lista numerada para procesar
SELECT 
    ROW_NUMBER() OVER (ORDER BY ClienteID) AS RowNum,
    ClienteID,
    Nombre,
    Email
INTO #ClientesProcesar
FROM CLIENTES
WHERE Segmento = 'Premium';

DECLARE @TotalFilas INT = (SELECT COUNT(*) FROM #ClientesProcesar);
DECLARE @FilaActual INT = 1;
DECLARE @ClienteID_W INT, @Nombre VARCHAR(100), @Email VARCHAR(100);

WHILE @FilaActual <= @TotalFilas
BEGIN
    -- Obtener fila actual
    SELECT @ClienteID_W = ClienteID, @Nombre = Nombre, @Email = Email
    FROM #ClientesProcesar
    WHERE RowNum = @FilaActual;
    
    -- Procesar
    PRINT 'Procesando: ' + @Nombre;
    
    -- Siguiente
    SET @FilaActual = @FilaActual + 1;
END;


-- Patrón WHILE con DELETE (procesa y elimina)
-- -------------------------------------------
IF OBJECT_ID('tempdb..#Cola') IS NOT NULL DROP TABLE #Cola;

SELECT ClienteID, Nombre
INTO #Cola
FROM CLIENTES
WHERE Estado = 'Activo';

WHILE EXISTS (SELECT 1 FROM #Cola)
BEGIN
    -- Tomar el primero
    SELECT TOP 1 @ClienteID_W = ClienteID, @Nombre = Nombre
    FROM #Cola;
    
    -- Procesar
    PRINT 'Procesando cliente: ' + @Nombre;
    
    -- Eliminar de la cola
    DELETE FROM #Cola WHERE ClienteID = @ClienteID_W;
END;


-- ============================================================
-- PARTE 5: CASOS LEGÍTIMOS PARA CURSORES
-- ============================================================
/*
   A pesar de las desventajas, hay casos donde un cursor es apropiado:
   
   1. Llamar un SP una vez por cada fila
   2. Operaciones que dependen del resultado de la fila anterior
   3. Mantenimiento de base de datos (recorrer tablas/bases)
   4. Generación de código dinámico complejo
   5. Procesamiento con lógica condicional muy compleja
   6. Cuando el conjunto es PEQUEÑO y la claridad importa más
*/

-- CASO LEGÍTIMO 1: Ejecutar SP por cada registro
-- -----------------------------------------------
-- Supongamos que tenemos un SP que envía email
CREATE OR ALTER PROCEDURE dbo.sp_EnviarAlertaCuenta
    @CuentaID INT,
    @TipoAlerta VARCHAR(50)
AS
BEGIN
    -- Simulación de envío de alerta
    DECLARE @NumeroCuenta VARCHAR(20);
    SELECT @NumeroCuenta = NumeroCuenta FROM CUENTAS WHERE CuentaID = @CuentaID;
    
    PRINT 'Enviando alerta "' + @TipoAlerta + '" para cuenta: ' + ISNULL(@NumeroCuenta, 'N/A');
    -- Aquí iría la lógica real de envío
END;
GO

-- Usar cursor para llamar SP por cada cuenta con saldo bajo
DECLARE @CuentaID INT;
DECLARE cursor_alertas CURSOR LOCAL FAST_FORWARD FOR
    SELECT CuentaID FROM CUENTAS WHERE Saldo < 1000 AND Estado = 'Activa';

OPEN cursor_alertas;
FETCH NEXT FROM cursor_alertas INTO @CuentaID;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.sp_EnviarAlertaCuenta @CuentaID, 'Saldo Bajo';
    FETCH NEXT FROM cursor_alertas INTO @CuentaID;
END;

CLOSE cursor_alertas;
DEALLOCATE cursor_alertas;
GO


-- CASO LEGÍTIMO 2: Operaciones de mantenimiento DBA
-- -------------------------------------------------
-- Recorrer todas las tablas para verificar tamaño
DECLARE @TableName NVARCHAR(256);
DECLARE @SchemaName NVARCHAR(256);
DECLARE @SQL NVARCHAR(MAX);

DECLARE cursor_tablas CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name, t.name
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.type = 'U';

OPEN cursor_tablas;
FETCH NEXT FROM cursor_tablas INTO @SchemaName, @TableName;

PRINT '=== Conteo de filas por tabla ===';
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'SELECT ''' + @SchemaName + '.' + @TableName + ''' AS Tabla, COUNT(*) AS Filas FROM ' 
               + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
    EXEC sp_executesql @SQL;
    
    FETCH NEXT FROM cursor_tablas INTO @SchemaName, @TableName;
END;

CLOSE cursor_tablas;
DEALLOCATE cursor_tablas;


-- CASO LEGÍTIMO 3: Proceso que depende de la fila anterior
-- --------------------------------------------------------
-- Calcular saldo acumulado con lógica especial
IF OBJECT_ID('tempdb..#SaldoAcumulado') IS NOT NULL DROP TABLE #SaldoAcumulado;

CREATE TABLE #SaldoAcumulado (
    Fecha DATE,
    Monto DECIMAL(18,2),
    SaldoAcumulado DECIMAL(18,2)
);

DECLARE @Fecha DATE, @Monto DECIMAL(18,2);
DECLARE @SaldoAnterior DECIMAL(18,2) = 0;
DECLARE @NuevoSaldo DECIMAL(18,2);

DECLARE cursor_movimientos CURSOR LOCAL FAST_FORWARD FOR
    SELECT CAST(FechaTransaccion AS DATE), 
           SUM(CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE -Monto END)
    FROM TRANSACCIONES_BANCARIAS
    WHERE CuentaID = 1
    GROUP BY CAST(FechaTransaccion AS DATE)
    ORDER BY CAST(FechaTransaccion AS DATE);

OPEN cursor_movimientos;
FETCH NEXT FROM cursor_movimientos INTO @Fecha, @Monto;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @NuevoSaldo = @SaldoAnterior + @Monto;
    
    INSERT INTO #SaldoAcumulado (Fecha, Monto, SaldoAcumulado)
    VALUES (@Fecha, @Monto, @NuevoSaldo);
    
    SET @SaldoAnterior = @NuevoSaldo;
    
    FETCH NEXT FROM cursor_movimientos INTO @Fecha, @Monto;
END;

CLOSE cursor_movimientos;
DEALLOCATE cursor_movimientos;

SELECT * FROM #SaldoAcumulado ORDER BY Fecha;


-- ============================================================
-- PARTE 6: REFACTORIZACIÓN A SET-BASED
-- ============================================================

-- EJEMPLO 1: Actualización condicional
-- ------------------------------------

-- ANTES: Cursor que actualiza según condiciones
/*
DECLARE cursor_update CURSOR FOR SELECT CuentaID, Saldo FROM CUENTAS;
OPEN cursor_update;
FETCH NEXT...
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @Saldo > 100000
        UPDATE CUENTAS SET TipoCuenta = 'Premium' WHERE CuentaID = @CuentaID;
    ELSE IF @Saldo > 10000
        UPDATE CUENTAS SET TipoCuenta = 'Estándar' WHERE CuentaID = @CuentaID;
    ELSE
        UPDATE CUENTAS SET TipoCuenta = 'Básica' WHERE CuentaID = @CuentaID;
    FETCH NEXT...
END;
*/

-- DESPUÉS: Set-based con CASE
UPDATE CUENTAS
SET TipoCuenta = CASE 
    WHEN Saldo > 100000 THEN 'Premium'
    WHEN Saldo > 10000 THEN 'Estándar'
    ELSE 'Básica'
END;


-- EJEMPLO 2: Inserción de datos calculados
-- ----------------------------------------

-- ANTES: Cursor que inserta en tabla de log
/*
DECLARE cursor_log CURSOR FOR SELECT TransaccionID, Monto, CuentaID FROM TRANSACCIONES_BANCARIAS;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO LogTransacciones (TransaccionID, Monto, FechaLog)
    VALUES (@TransID, @Monto, GETDATE());
    FETCH NEXT...
END;
*/

-- DESPUÉS: INSERT...SELECT
INSERT INTO LogTransacciones (TransaccionID, Monto, FechaLog)
SELECT TransaccionID, Monto, GETDATE()
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= DATEADD(DAY, -1, GETDATE());


-- EJEMPLO 3: Concatenar valores (STRING_AGG vs cursor)
-- ----------------------------------------------------

-- ANTES: Cursor para concatenar nombres de clientes por segmento
/*
DECLARE @Resultado VARCHAR(MAX) = '';
DECLARE cursor_concat CURSOR FOR 
    SELECT Nombre FROM CLIENTES WHERE Segmento = 'VIP' ORDER BY Nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Resultado = @Resultado + @Nombre + ', ';
    FETCH NEXT...
END;
*/

-- DESPUÉS: STRING_AGG (SQL Server 2017+)
SELECT 
    Segmento,
    STRING_AGG(Nombre + ' ' + Apellido, ', ') AS Clientes
FROM CLIENTES
WHERE Estado = 'Activo'
GROUP BY Segmento;


-- EJEMPLO 4: Numeración y ranking
-- -------------------------------

-- ANTES: Cursor para asignar números secuenciales
/*
DECLARE @Numero INT = 1;
DECLARE cursor_num CURSOR FOR SELECT ClienteID FROM CLIENTES ORDER BY FechaRegistro;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE CLIENTES SET NumeroCliente = @Numero WHERE ClienteID = @ClienteID;
    SET @Numero = @Numero + 1;
    FETCH NEXT...
END;
*/

-- DESPUÉS: ROW_NUMBER()
;WITH ClientesNumerados AS (
    SELECT 
        ClienteID,
        ROW_NUMBER() OVER (ORDER BY FechaRegistro) AS NumeroNuevo
    FROM CLIENTES
)
UPDATE c
SET c.NumeroCliente = cn.NumeroNuevo
FROM CLIENTES c
INNER JOIN ClientesNumerados cn ON c.ClienteID = cn.ClienteID;


-- EJEMPLO 5: Running total (saldo acumulado)
-- ------------------------------------------

-- ANTES: Cursor para calcular acumulados (visto arriba)

-- DESPUÉS: Window function
SELECT 
    FechaTransaccion,
    TipoTransaccion,
    Monto,
    SUM(CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE -Monto END) 
        OVER (ORDER BY FechaTransaccion ROWS UNBOUNDED PRECEDING) AS SaldoAcumulado
FROM TRANSACCIONES_BANCARIAS
WHERE CuentaID = 1
ORDER BY FechaTransaccion;


-- ============================================================
-- PARTE 7: PERFORMANCE COMPARATIVO
-- ============================================================

-- Comparación: Cursor vs Set-Based
-- --------------------------------
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Crear tabla de prueba con muchos datos
IF OBJECT_ID('tempdb..#PruebaPerf') IS NOT NULL DROP TABLE #PruebaPerf;

SELECT TOP 10000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ID,
    CAST(RAND(CHECKSUM(NEWID())) * 100000 AS DECIMAL(18,2)) AS Valor,
    'Original' AS Estado
INTO #PruebaPerf
FROM sys.all_columns a
CROSS JOIN sys.all_columns b;

CREATE INDEX IX_Valor ON #PruebaPerf(Valor);

-- Tarea: Marcar como 'Alto' si Valor > 50000

-- MÉTODO 1: Cursor
PRINT '=== CURSOR ===';
DECLARE @ID INT, @Valor DECIMAL(18,2);
DECLARE cursor_perf CURSOR LOCAL FAST_FORWARD FOR
    SELECT ID, Valor FROM #PruebaPerf WHERE Valor > 50000;

OPEN cursor_perf;
FETCH NEXT FROM cursor_perf INTO @ID, @Valor;

WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE #PruebaPerf SET Estado = 'Alto' WHERE ID = @ID;
    FETCH NEXT FROM cursor_perf INTO @ID, @Valor;
END;

CLOSE cursor_perf;
DEALLOCATE cursor_perf;

-- Reset para segunda prueba
UPDATE #PruebaPerf SET Estado = 'Original';

-- MÉTODO 2: Set-Based
PRINT '=== SET-BASED ===';
UPDATE #PruebaPerf 
SET Estado = 'Alto' 
WHERE Valor > 50000;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- El set-based será SIGNIFICATIVAMENTE más rápido


-- ============================================================
-- PARTE 8: PATRONES ANTI-CURSOR
-- ============================================================
/*
   Técnicas para evitar cursores:
*/

-- 1. MERGE en lugar de cursor INSERT/UPDATE/DELETE
-- ------------------------------------------------
-- En lugar de cursor que verifica existencia y actualiza o inserta:

MERGE INTO CUENTAS AS target
USING (SELECT 1 AS CuentaID, 50000 AS NuevoSaldo) AS source
ON target.CuentaID = source.CuentaID
WHEN MATCHED THEN
    UPDATE SET Saldo = source.NuevoSaldo
WHEN NOT MATCHED THEN
    INSERT (NumeroCuenta, Saldo, TipoCuenta, Estado, ClienteID, FechaApertura)
    VALUES ('NUEVA001', source.NuevoSaldo, 'Ahorro', 'Activa', 1, GETDATE());


-- 2. APPLY para ejecutar función por cada fila
-- --------------------------------------------
-- En lugar de cursor que llama función por cada cliente:

-- Crear función que retorna tabla
CREATE OR ALTER FUNCTION dbo.fn_UltimasTransacciones(@ClienteID INT)
RETURNS TABLE
AS
RETURN (
    SELECT TOP 3 t.*
    FROM TRANSACCIONES_BANCARIAS t
    INNER JOIN CUENTAS c ON t.CuentaID = c.CuentaID
    WHERE c.ClienteID = @ClienteID
    ORDER BY t.FechaTransaccion DESC
);
GO

-- Usar CROSS APPLY en lugar de cursor
SELECT 
    c.ClienteID,
    c.Nombre,
    ut.*
FROM CLIENTES c
CROSS APPLY dbo.fn_UltimasTransacciones(c.ClienteID) ut
WHERE c.Segmento = 'VIP';


-- 3. Recursive CTE para jerarquías
-- --------------------------------
-- En lugar de cursor que navega árbol:
/*
;WITH Jerarquia AS (
    SELECT ID, ParentID, Nombre, 0 AS Nivel
    FROM Empleados WHERE ParentID IS NULL
    
    UNION ALL
    
    SELECT e.ID, e.ParentID, e.Nombre, j.Nivel + 1
    FROM Empleados e
    INNER JOIN Jerarquia j ON e.ParentID = j.ID
)
SELECT * FROM Jerarquia;
*/


-- 4. UNPIVOT/PIVOT en lugar de cursor para transformar
-- ----------------------------------------------------
-- En lugar de cursor que lee columnas dinámicamente:
/*
SELECT ClienteID, Atributo, Valor
FROM (
    SELECT ClienteID, Nombre, Email, Telefono
    FROM CLIENTES
) AS SourceTable
UNPIVOT (
    Valor FOR Atributo IN (Nombre, Email, Telefono)
) AS UnpivotTable;
*/


-- ============================================================
-- PARTE 9: MEJORES PRÁCTICAS
-- ============================================================

/*
   Si DEBES usar un cursor:
*/

-- 1. SIEMPRE usar LOCAL FAST_FORWARD si solo lees
DECLARE cursor_bueno CURSOR LOCAL FAST_FORWARD
FOR SELECT columnas FROM tabla;

-- 2. NO olvides CLOSE y DEALLOCATE
-- Usar TRY...CATCH para garantizar limpieza
BEGIN TRY
    DECLARE cursor_seguro CURSOR LOCAL FAST_FORWARD FOR
        SELECT ClienteID FROM CLIENTES;
    
    OPEN cursor_seguro;
    -- ... procesamiento ...
    
    CLOSE cursor_seguro;
    DEALLOCATE cursor_seguro;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'cursor_seguro') >= 0
    BEGIN
        CLOSE cursor_seguro;
        DEALLOCATE cursor_seguro;
    END;
    THROW;
END CATCH;


-- 3. Verificar estado del cursor antes de operaciones
IF CURSOR_STATUS('local', 'mi_cursor') = 1  -- Abierto
    CLOSE mi_cursor;
IF CURSOR_STATUS('local', 'mi_cursor') >= -1  -- Existe
    DEALLOCATE mi_cursor;


-- 4. Limitar el conjunto de datos del cursor
-- Usar WHERE restrictivo y TOP si es posible
DECLARE cursor_limitado CURSOR LOCAL FAST_FORWARD FOR
    SELECT TOP 100 ClienteID FROM CLIENTES WHERE Estado = 'Activo';


-- 5. Considerar variables de tabla como alternativa más limpia
DECLARE @FilasAProcesar TABLE (
    RowNum INT IDENTITY,
    ClienteID INT
);

INSERT INTO @FilasAProcesar (ClienteID)
SELECT ClienteID FROM CLIENTES WHERE Estado = 'Activo';

-- Procesar con WHILE en lugar de cursor


-- ============================================================
-- PARTE 10: CASOS PRÁCTICOS CON BancoDB
-- ============================================================

-- CASO 1: Reporte de clientes - Refactorizado
-- -------------------------------------------
-- ANTES: Cursor que genera reporte línea por línea

-- DESPUÉS: Set-based completo
CREATE OR ALTER PROCEDURE dbo.sp_ReporteClientesCompleto
    @Segmento VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Todo en una sola consulta set-based
    SELECT 
        c.ClienteID,
        c.Nombre + ' ' + c.Apellido AS NombreCompleto,
        c.Segmento,
        c.Email,
        COUNT(DISTINCT cu.CuentaID) AS TotalCuentas,
        ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal,
        ISNULL(COUNT(t.TransaccionID), 0) AS TotalTransacciones,
        MAX(t.FechaTransaccion) AS UltimaTransaccion,
        DATEDIFF(DAY, MAX(t.FechaTransaccion), GETDATE()) AS DiasInactivo,
        CASE 
            WHEN MAX(t.FechaTransaccion) >= DATEADD(MONTH, -1, GETDATE()) THEN 'Activo'
            WHEN MAX(t.FechaTransaccion) >= DATEADD(MONTH, -3, GETDATE()) THEN 'Moderado'
            ELSE 'Inactivo'
        END AS NivelActividad
    FROM CLIENTES c
    LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.Estado = 'Activo'
      AND (@Segmento IS NULL OR c.Segmento = @Segmento)
    GROUP BY c.ClienteID, c.Nombre, c.Apellido, c.Segmento, c.Email
    ORDER BY SaldoTotal DESC;
END;
GO

EXEC dbo.sp_ReporteClientesCompleto @Segmento = 'VIP';


-- CASO 2: Cursor necesario - Ejecutar SP por cuenta
-- -------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ProcesarInteresMensual
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CuentaID INT;
    DECLARE @Saldo DECIMAL(18,2);
    DECLARE @TipoCuenta VARCHAR(50);
    DECLARE @TasaInteres DECIMAL(5,4);
    DECLARE @InteresCalculado DECIMAL(18,2);
    DECLARE @ErrorCount INT = 0;
    DECLARE @SuccessCount INT = 0;
    
    -- Cursor para procesar intereses (necesario porque cada cuenta
    -- puede tener lógica diferente o llamar SP externo)
    DECLARE cursor_interes CURSOR LOCAL FAST_FORWARD FOR
        SELECT CuentaID, Saldo, TipoCuenta
        FROM CUENTAS
        WHERE Estado = 'Activa' AND Saldo > 0;
    
    OPEN cursor_interes;
    FETCH NEXT FROM cursor_interes INTO @CuentaID, @Saldo, @TipoCuenta;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Calcular tasa según tipo (lógica que podría estar en SP externo)
            SET @TasaInteres = CASE @TipoCuenta
                WHEN 'Ahorro' THEN 0.0025
                WHEN 'Corriente' THEN 0.0010
                WHEN 'Inversión' THEN 0.0050
                ELSE 0.0015
            END;
            
            SET @InteresCalculado = @Saldo * @TasaInteres;
            
            -- Aquí se podría llamar: EXEC sp_AplicarInteres @CuentaID, @InteresCalculado
            PRINT 'Cuenta ' + CAST(@CuentaID AS VARCHAR) + ': Interés $' + CAST(@InteresCalculado AS VARCHAR(20));
            
            SET @SuccessCount = @SuccessCount + 1;
        END TRY
        BEGIN CATCH
            SET @ErrorCount = @ErrorCount + 1;
            PRINT 'Error en cuenta ' + CAST(@CuentaID AS VARCHAR) + ': ' + ERROR_MESSAGE();
        END CATCH;
        
        FETCH NEXT FROM cursor_interes INTO @CuentaID, @Saldo, @TipoCuenta;
    END;
    
    CLOSE cursor_interes;
    DEALLOCATE cursor_interes;
    
    PRINT '=== Resumen ===';
    PRINT 'Procesadas: ' + CAST(@SuccessCount AS VARCHAR(10));
    PRINT 'Errores: ' + CAST(@ErrorCount AS VARCHAR(10));
END;
GO

EXEC dbo.sp_ProcesarInteresMensual;


-- CASO 3: Alternativa con tally/números
-- -------------------------------------
-- Procesar sin cursor usando tabla de números

-- Crear tabla de números (útil en general)
IF OBJECT_ID('dbo.Numeros') IS NULL
BEGIN
    CREATE TABLE dbo.Numeros (N INT PRIMARY KEY);
    
    WITH E1 AS (SELECT 1 AS N UNION ALL SELECT 1),
         E2 AS (SELECT 1 AS N FROM E1 a CROSS JOIN E1 b),
         E4 AS (SELECT 1 AS N FROM E2 a CROSS JOIN E2 b),
         E8 AS (SELECT 1 AS N FROM E4 a CROSS JOIN E4 b),
         Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N FROM E8)
    INSERT INTO dbo.Numeros
    SELECT N FROM Nums WHERE N <= 10000;
END;

-- Usar para generar datos sin cursor
-- Ejemplo: Crear registro por cada día del mes
SELECT 
    DATEADD(DAY, N - 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) AS Fecha
FROM dbo.Numeros
WHERE N <= DAY(EOMONTH(GETDATE()));


-- ============================================================
-- RESUMEN: ÁRBOL DE DECISIÓN
-- ============================================================
/*
   ¿Necesitas procesar filas individualmente?
   │
   ├─ NO ──► Usa SET-BASED (UPDATE, INSERT...SELECT, MERGE)
   │
   └─ SÍ
      │
      ├─ ¿Puedes usar window functions? ──► SUM() OVER, ROW_NUMBER()
      │
      ├─ ¿Puedes usar CROSS/OUTER APPLY? ──► Función que retorna tabla
      │
      ├─ ¿Puedes usar CTE recursivo? ──► Para jerarquías
      │
      ├─ ¿Puedes usar STRING_AGG? ──► Para concatenaciones
      │
      └─ NO hay alternativa set-based
         │
         ├─ ¿Solo lees datos? ──► CURSOR LOCAL FAST_FORWARD
         │
         └─ ¿Necesitas modificar? ──► CURSOR LOCAL STATIC o KEYSET
            │
            └─ Siempre: TRY...CATCH + CLOSE + DEALLOCATE
*/

-- Limpieza
DROP TABLE IF EXISTS #TestCursor;
DROP TABLE IF EXISTS #ClientesProcesar;
DROP TABLE IF EXISTS #Cola;
DROP TABLE IF EXISTS #SaldoAcumulado;
DROP TABLE IF EXISTS #PruebaPerf;

PRINT '============================================================';
PRINT 'Sesión 12 completada: Cursores vs Operaciones Set-Based';
PRINT '============================================================';
