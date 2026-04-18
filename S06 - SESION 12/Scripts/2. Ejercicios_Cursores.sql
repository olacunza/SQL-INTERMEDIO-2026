/***************************************************************
 * SESIÓN 12: EJERCICIOS - CURSORES VS SET-BASED
 * SQL Server Intermedio - 2026
 * 
 * Instrucciones:
 *   - Completar cada ejercicio en el espacio indicado
 *   - Muchos ejercicios piden REFACTORIZAR de cursor a set-based
 *   - Usar BancoDB como base de datos
 *   - Las soluciones están al final del archivo
 * 
 * Temas evaluados:
 *   - Identificar cuándo NO usar cursores
 *   - Refactorizar cursores a operaciones set-based
 *   - Window functions como alternativa
 *   - Uso apropiado de cursores
 *   - CROSS APPLY y otras técnicas
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: Refactorizar UPDATE con Cursor
-- ============================================================
/*
   El siguiente código usa un cursor para actualizar el segmento
   de clientes basado en su saldo total. REFACTORÍZALO a set-based.
   
   Lógica:
   - Si saldo total > 100000 → 'VIP'
   - Si saldo total > 25000 → 'Premium'
   - Si saldo total > 5000 → 'Estándar'
   - Demás → 'Básico'
*/

-- CÓDIGO ORIGINAL CON CURSOR (No ejecutar, solo referencia):
/*
DECLARE @ClienteID INT, @SaldoTotal DECIMAL(18,2);
DECLARE cursor_segmento CURSOR FOR
    SELECT c.ClienteID, ISNULL(SUM(cu.Saldo), 0)
    FROM CLIENTES c
    LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    GROUP BY c.ClienteID;

OPEN cursor_segmento;
FETCH NEXT FROM cursor_segmento INTO @ClienteID, @SaldoTotal;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @SaldoTotal > 100000
        UPDATE CLIENTES SET Segmento = 'VIP' WHERE ClienteID = @ClienteID;
    ELSE IF @SaldoTotal > 25000
        UPDATE CLIENTES SET Segmento = 'Premium' WHERE ClienteID = @ClienteID;
    ELSE IF @SaldoTotal > 5000
        UPDATE CLIENTES SET Segmento = 'Estándar' WHERE ClienteID = @ClienteID;
    ELSE
        UPDATE CLIENTES SET Segmento = 'Básico' WHERE ClienteID = @ClienteID;
    
    FETCH NEXT FROM cursor_segmento INTO @ClienteID, @SaldoTotal;
END;

CLOSE cursor_segmento;
DEALLOCATE cursor_segmento;
*/

-- TU VERSIÓN SET-BASED AQUÍ:




-- ============================================================
-- EJERCICIO 2: Refactorizar Concatenación
-- ============================================================
/*
   El siguiente cursor concatena los nombres de todas las cuentas
   de cada cliente. Refactoriza usando STRING_AGG.
   
   Resultado esperado: ClienteID, NombreCliente, ListaCuentas
   Donde ListaCuentas es algo como: "Ahorro-001, Corriente-002, Inversión-003"
*/

-- CÓDIGO ORIGINAL (referencia):
/*
DECLARE @ClienteID INT, @Resultado VARCHAR(MAX);
DECLARE @NumeroCuenta VARCHAR(50), @TipoCuenta VARCHAR(50);

-- Para cada cliente...
DECLARE cursor_clientes CURSOR FOR SELECT DISTINCT ClienteID FROM CUENTAS;
OPEN cursor_clientes;
FETCH NEXT FROM cursor_clientes INTO @ClienteID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Resultado = '';
    
    DECLARE cursor_cuentas CURSOR FOR 
        SELECT TipoCuenta, NumeroCuenta FROM CUENTAS WHERE ClienteID = @ClienteID;
    OPEN cursor_cuentas;
    FETCH NEXT FROM cursor_cuentas INTO @TipoCuenta, @NumeroCuenta;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Resultado = @Resultado + @TipoCuenta + '-' + @NumeroCuenta + ', ';
        FETCH NEXT FROM cursor_cuentas INTO @TipoCuenta, @NumeroCuenta;
    END;
    
    CLOSE cursor_cuentas;
    DEALLOCATE cursor_cuentas;
    
    PRINT CAST(@ClienteID AS VARCHAR) + ': ' + @Resultado;
    FETCH NEXT FROM cursor_clientes INTO @ClienteID;
END;

CLOSE cursor_clientes;
DEALLOCATE cursor_clientes;
*/

-- TU VERSIÓN SET-BASED AQUÍ:




-- ============================================================
-- EJERCICIO 3: Refactorizar Running Total
-- ============================================================
/*
   El siguiente cursor calcula el saldo acumulado de transacciones.
   Refactoriza usando Window Functions.
   
   Resultado: TransaccionID, Fecha, Monto, SaldoAcumulado
*/

-- CÓDIGO ORIGINAL (referencia):
/*
DECLARE @TransID INT, @Fecha DATE, @Monto DECIMAL(18,2);
DECLARE @Acumulado DECIMAL(18,2) = 0;

CREATE TABLE #Resultado (TransID INT, Fecha DATE, Monto DECIMAL(18,2), Acumulado DECIMAL(18,2));

DECLARE cursor_trans CURSOR FOR
    SELECT TransaccionID, FechaTransaccion, 
           CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE -Monto END
    FROM TRANSACCIONES_BANCARIAS
    WHERE CuentaID = 1
    ORDER BY FechaTransaccion;

OPEN cursor_trans;
FETCH NEXT FROM cursor_trans INTO @TransID, @Fecha, @Monto;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Acumulado = @Acumulado + @Monto;
    INSERT INTO #Resultado VALUES (@TransID, @Fecha, @Monto, @Acumulado);
    FETCH NEXT FROM cursor_trans INTO @TransID, @Fecha, @Monto;
END;

CLOSE cursor_trans;
DEALLOCATE cursor_trans;
*/

-- TU VERSIÓN SET-BASED AQUÍ:




-- ============================================================
-- EJERCICIO 4: Refactorizar Numeración
-- ============================================================
/*
   El cursor asigna un número de orden a cada transacción por cuenta.
   Refactoriza usando ROW_NUMBER().
   
   Resultado: CuentaID, TransaccionID, NumeroOrden (1, 2, 3... por cuenta)
*/

-- TU VERSIÓN SET-BASED AQUÍ:




-- ============================================================
-- EJERCICIO 5: CROSS APPLY en lugar de Cursor
-- ============================================================
/*
   Crear una consulta que muestre para cada cliente sus 3 transacciones
   más recientes, SIN usar cursor.
   
   Resultado: ClienteID, NombreCliente, TransaccionID, Monto, Fecha
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 6: Cursor Apropiado
-- ============================================================
/*
   Este ES un caso donde un cursor puede ser apropiado:
   Crear un SP que ejecute DBCC CHECKDB para cada base de datos
   del servidor (excepto tempdb).
   
   Usar cursor LOCAL FAST_FORWARD.
   Solo mostrar los comandos que ejecutaría (PRINT), no ejecutar realmente.
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 7: WHILE Loop vs Cursor
-- ============================================================
/*
   Reescribir el siguiente cursor usando un WHILE loop con tabla
   temporal numerada.
   
   El cursor procesa clientes inactivos (sin transacciones en 90 días)
   y genera un mensaje para cada uno.
*/

-- CÓDIGO ORIGINAL (referencia):
/*
DECLARE @ClienteID INT, @Nombre VARCHAR(100);
DECLARE cursor_inactivos CURSOR FOR
    SELECT c.ClienteID, c.Nombre
    FROM CLIENTES c
    WHERE NOT EXISTS (
        SELECT 1 FROM CUENTAS cu
        JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
        WHERE cu.ClienteID = c.ClienteID
        AND t.FechaTransaccion >= DATEADD(DAY, -90, GETDATE())
    );

OPEN cursor_inactivos;
FETCH NEXT FROM cursor_inactivos INTO @ClienteID, @Nombre;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Cliente inactivo: ' + @Nombre + ' (ID: ' + CAST(@ClienteID AS VARCHAR) + ')';
    FETCH NEXT FROM cursor_inactivos INTO @ClienteID, @Nombre;
END;

CLOSE cursor_inactivos;
DEALLOCATE cursor_inactivos;
*/

-- TU VERSIÓN CON WHILE LOOP AQUÍ:




-- ============================================================
-- EJERCICIO 8: MERGE en lugar de Cursor
-- ============================================================
/*
   El cursor verifica si existe un cliente y lo actualiza o inserta.
   Refactoriza usando MERGE.
   
   Datos fuente: tabla temporal con ClienteID, NuevoEmail
*/

-- Crear datos de prueba
IF OBJECT_ID('tempdb..#ActualizacionesEmail') IS NOT NULL 
    DROP TABLE #ActualizacionesEmail;

CREATE TABLE #ActualizacionesEmail (
    ClienteID INT,
    NuevoEmail VARCHAR(100)
);

INSERT INTO #ActualizacionesEmail VALUES 
    (1, 'cliente1_nuevo@banco.com'),
    (2, 'cliente2_nuevo@banco.com'),
    (9999, 'cliente_nuevo@banco.com');  -- Este no existe

-- CÓDIGO ORIGINAL (referencia):
/*
DECLARE @ClienteID INT, @Email VARCHAR(100);
DECLARE cursor_emails CURSOR FOR SELECT ClienteID, NuevoEmail FROM #ActualizacionesEmail;

OPEN cursor_emails;
FETCH NEXT FROM cursor_emails INTO @ClienteID, @Email;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM CLIENTES WHERE ClienteID = @ClienteID)
        UPDATE CLIENTES SET Email = @Email WHERE ClienteID = @ClienteID;
    ELSE
        PRINT 'Cliente ' + CAST(@ClienteID AS VARCHAR) + ' no existe';
    
    FETCH NEXT FROM cursor_emails INTO @ClienteID, @Email;
END;

CLOSE cursor_emails;
DEALLOCATE cursor_emails;
*/

-- TU VERSIÓN CON MERGE AQUÍ:




-- ============================================================
-- EJERCICIO 9: Análisis de Performance
-- ============================================================
/*
   Crear una prueba que compare el tiempo de ejecución de:
   1. Un cursor que suma montos de transacciones
   2. Una agregación set-based (SUM con GROUP BY)
   
   Usar SET STATISTICS TIME ON y mostrar la diferencia.
   Documentar los resultados en comentarios.
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 10: SP con Cursor Justificado
-- ============================================================
/*
   Crear un SP sp_GenerarReportesPorCliente que:
   1. Use cursor para iterar sobre clientes VIP
   2. Para cada cliente, genere un "reporte" (puede ser simplemente
      un resultset o PRINT con su información)
   3. Incluya manejo de errores con TRY...CATCH
   4. Garantice CLOSE y DEALLOCATE incluso si hay error
   5. Retorne conteo de reportes generados vs errores
   
   Justificación: Un cursor aquí simula el caso donde necesitas
   llamar un SP externo o generar un archivo por cada cliente.
*/

-- TU CÓDIGO AQUÍ:










-- ============================================================
--                    SOLUCIONES
-- ============================================================
-- (No ver hasta intentar resolver los ejercicios)
-- ============================================================

/*
███████╗ ██████╗ ██╗     ██╗   ██╗ ██████╗██╗ ██████╗ ███╗   ██╗███████╗███████╗
██╔════╝██╔═══██╗██║     ██║   ██║██╔════╝██║██╔═══██╗████╗  ██║██╔════╝██╔════╝
███████╗██║   ██║██║     ██║   ██║██║     ██║██║   ██║██╔██╗ ██║█████╗  ███████╗
╚════██║██║   ██║██║     ██║   ██║██║     ██║██║   ██║██║╚██╗██║██╔══╝  ╚════██║
███████║╚██████╔╝███████╗╚██████╔╝╚██████╗██║╚██████╔╝██║ ╚████║███████╗███████║
╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚══════╝
*/

-- SOLUCIÓN EJERCICIO 1
-- ====================
;WITH SaldosPorCliente AS (
    SELECT 
        c.ClienteID,
        ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal
    FROM CLIENTES c
    LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    GROUP BY c.ClienteID
)
UPDATE c
SET c.Segmento = CASE 
    WHEN s.SaldoTotal > 100000 THEN 'VIP'
    WHEN s.SaldoTotal > 25000 THEN 'Premium'
    WHEN s.SaldoTotal > 5000 THEN 'Estándar'
    ELSE 'Básico'
END
FROM CLIENTES c
INNER JOIN SaldosPorCliente s ON c.ClienteID = s.ClienteID;

-- Verificar
SELECT Segmento, COUNT(*) AS Cantidad FROM CLIENTES GROUP BY Segmento;
GO


-- SOLUCIÓN EJERCICIO 2
-- ====================
SELECT 
    c.ClienteID,
    c.Nombre + ' ' + c.Apellido AS NombreCliente,
    STRING_AGG(cu.TipoCuenta + '-' + cu.NumeroCuenta, ', ') AS ListaCuentas
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
GROUP BY c.ClienteID, c.Nombre, c.Apellido
ORDER BY c.ClienteID;
GO


-- SOLUCIÓN EJERCICIO 3
-- ====================
SELECT 
    TransaccionID,
    FechaTransaccion AS Fecha,
    CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE -Monto END AS Monto,
    SUM(CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE -Monto END) 
        OVER (ORDER BY FechaTransaccion, TransaccionID 
              ROWS UNBOUNDED PRECEDING) AS SaldoAcumulado
FROM TRANSACCIONES_BANCARIAS
WHERE CuentaID = 1
ORDER BY FechaTransaccion, TransaccionID;
GO


-- SOLUCIÓN EJERCICIO 4
-- ====================
SELECT 
    CuentaID,
    TransaccionID,
    ROW_NUMBER() OVER (PARTITION BY CuentaID ORDER BY FechaTransaccion, TransaccionID) AS NumeroOrden
FROM TRANSACCIONES_BANCARIAS
ORDER BY CuentaID, NumeroOrden;
GO


-- SOLUCIÓN EJERCICIO 5
-- ====================
SELECT 
    c.ClienteID,
    c.Nombre + ' ' + c.Apellido AS NombreCliente,
    t.TransaccionID,
    t.Monto,
    t.FechaTransaccion
FROM CLIENTES c
CROSS APPLY (
    SELECT TOP 3 
        tb.TransaccionID,
        tb.Monto,
        tb.FechaTransaccion
    FROM CUENTAS cu
    INNER JOIN TRANSACCIONES_BANCARIAS tb ON cu.CuentaID = tb.CuentaID
    WHERE cu.ClienteID = c.ClienteID
    ORDER BY tb.FechaTransaccion DESC
) t
WHERE c.Estado = 'Activo'
ORDER BY c.ClienteID, t.FechaTransaccion DESC;
GO


-- SOLUCIÓN EJERCICIO 6
-- ====================
CREATE OR ALTER PROCEDURE dbo.sp_GenerarScriptCheckDB
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DBName NVARCHAR(256);
    DECLARE @SQL NVARCHAR(500);
    
    DECLARE cursor_dbs CURSOR LOCAL FAST_FORWARD FOR
        SELECT name 
        FROM sys.databases 
        WHERE name NOT IN ('tempdb')
          AND state = 0;  -- Solo online
    
    OPEN cursor_dbs;
    FETCH NEXT FROM cursor_dbs INTO @DBName;
    
    PRINT '-- Script de DBCC CHECKDB generado --';
    PRINT '';
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'DBCC CHECKDB (' + QUOTENAME(@DBName) + ') WITH NO_INFOMSGS;';
        PRINT @SQL;
        -- En producción se usaría: EXEC sp_executesql @SQL;
        
        FETCH NEXT FROM cursor_dbs INTO @DBName;
    END;
    
    CLOSE cursor_dbs;
    DEALLOCATE cursor_dbs;
    
    PRINT '';
    PRINT '-- Fin del script --';
END;
GO

EXEC dbo.sp_GenerarScriptCheckDB;
GO


-- SOLUCIÓN EJERCICIO 7
-- ====================
IF OBJECT_ID('tempdb..#ClientesInactivos') IS NOT NULL
    DROP TABLE #ClientesInactivos;

SELECT 
    ROW_NUMBER() OVER (ORDER BY c.ClienteID) AS RowNum,
    c.ClienteID,
    c.Nombre
INTO #ClientesInactivos
FROM CLIENTES c
WHERE NOT EXISTS (
    SELECT 1 FROM CUENTAS cu
    JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE cu.ClienteID = c.ClienteID
    AND t.FechaTransaccion >= DATEADD(DAY, -90, GETDATE())
);

DECLARE @TotalFilas INT = (SELECT COUNT(*) FROM #ClientesInactivos);
DECLARE @FilaActual INT = 1;
DECLARE @ClienteID INT, @Nombre VARCHAR(100);

WHILE @FilaActual <= @TotalFilas
BEGIN
    SELECT @ClienteID = ClienteID, @Nombre = Nombre
    FROM #ClientesInactivos
    WHERE RowNum = @FilaActual;
    
    PRINT 'Cliente inactivo: ' + @Nombre + ' (ID: ' + CAST(@ClienteID AS VARCHAR) + ')';
    
    SET @FilaActual = @FilaActual + 1;
END;
GO


-- SOLUCIÓN EJERCICIO 8
-- ====================
-- Nota: MERGE solo actualiza, no puede insertar clientes completos sin datos adicionales

-- Para los que existen: actualizar email
MERGE INTO CLIENTES AS target
USING #ActualizacionesEmail AS source
ON target.ClienteID = source.ClienteID
WHEN MATCHED THEN
    UPDATE SET Email = source.NuevoEmail
OUTPUT 
    $action AS Accion,
    COALESCE(inserted.ClienteID, deleted.ClienteID) AS ClienteID,
    COALESCE(inserted.Email, 'N/A') AS Email;

-- Identificar los que no existen
SELECT 
    ae.ClienteID,
    ae.NuevoEmail,
    'No existe en CLIENTES' AS Estado
FROM #ActualizacionesEmail ae
WHERE NOT EXISTS (SELECT 1 FROM CLIENTES c WHERE c.ClienteID = ae.ClienteID);
GO


-- SOLUCIÓN EJERCICIO 9
-- ====================
-- Crear tabla de prueba grande
IF OBJECT_ID('tempdb..#TransPrueba') IS NOT NULL DROP TABLE #TransPrueba;

SELECT TOP 50000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS TransaccionID,
    ABS(CHECKSUM(NEWID())) % 100 + 1 AS CuentaID,
    CAST(RAND(CHECKSUM(NEWID())) * 10000 AS DECIMAL(18,2)) AS Monto
INTO #TransPrueba
FROM sys.all_columns a CROSS JOIN sys.all_columns b;

CREATE INDEX IX_Cuenta ON #TransPrueba(CuentaID);

SET STATISTICS TIME ON;

-- MÉTODO 1: CURSOR
PRINT '=== CURSOR ===';
DECLARE @CuentaID INT, @Total DECIMAL(18,2);
IF OBJECT_ID('tempdb..#ResultadoCursor') IS NOT NULL DROP TABLE #ResultadoCursor;
CREATE TABLE #ResultadoCursor (CuentaID INT, Total DECIMAL(18,2));

DECLARE cursor_sum CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT CuentaID FROM #TransPrueba;

OPEN cursor_sum;
FETCH NEXT FROM cursor_sum INTO @CuentaID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Total = SUM(Monto) FROM #TransPrueba WHERE CuentaID = @CuentaID;
    INSERT INTO #ResultadoCursor VALUES (@CuentaID, @Total);
    FETCH NEXT FROM cursor_sum INTO @CuentaID;
END;

CLOSE cursor_sum;
DEALLOCATE cursor_sum;

SELECT COUNT(*) AS FilasCursor FROM #ResultadoCursor;

-- MÉTODO 2: SET-BASED
PRINT '=== SET-BASED ===';
SELECT 
    CuentaID,
    SUM(Monto) AS Total
INTO #ResultadoSetBased
FROM #TransPrueba
GROUP BY CuentaID;

SELECT COUNT(*) AS FilasSetBased FROM #ResultadoSetBased;

SET STATISTICS TIME OFF;

/*
RESULTADOS ESPERADOS:
- El cursor tardará varios segundos (100+ queries individuales)
- El set-based tardará milisegundos (1 sola query)
- Diferencia típica: 50x a 100x más rápido el set-based
*/
GO


-- SOLUCIÓN EJERCICIO 10
-- ====================
CREATE OR ALTER PROCEDURE dbo.sp_GenerarReportesPorCliente
    @ReportesGenerados INT OUTPUT,
    @Errores INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @ReportesGenerados = 0;
    SET @Errores = 0;
    
    DECLARE @ClienteID INT;
    DECLARE @Nombre VARCHAR(100);
    DECLARE @Email VARCHAR(100);
    DECLARE @SaldoTotal DECIMAL(18,2);
    
    DECLARE cursor_vip CURSOR LOCAL FAST_FORWARD FOR
        SELECT ClienteID, Nombre + ' ' + Apellido, Email
        FROM CLIENTES
        WHERE Segmento = 'VIP' AND Estado = 'Activo';
    
    BEGIN TRY
        OPEN cursor_vip;
        FETCH NEXT FROM cursor_vip INTO @ClienteID, @Nombre, @Email;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                -- Obtener saldo total del cliente
                SELECT @SaldoTotal = ISNULL(SUM(Saldo), 0)
                FROM CUENTAS WHERE ClienteID = @ClienteID;
                
                -- "Generar reporte" (simulado)
                PRINT '========================================';
                PRINT 'REPORTE VIP - ' + FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm');
                PRINT '----------------------------------------';
                PRINT 'Cliente: ' + @Nombre;
                PRINT 'ID: ' + CAST(@ClienteID AS VARCHAR);
                PRINT 'Email: ' + ISNULL(@Email, 'No registrado');
                PRINT 'Saldo Total: $' + FORMAT(@SaldoTotal, 'N2');
                PRINT '========================================';
                PRINT '';
                
                -- Aquí se llamaría: EXEC sp_EnviarReportePorEmail @ClienteID
                
                SET @ReportesGenerados = @ReportesGenerados + 1;
                
            END TRY
            BEGIN CATCH
                SET @Errores = @Errores + 1;
                PRINT 'ERROR procesando cliente ' + CAST(@ClienteID AS VARCHAR) + ': ' + ERROR_MESSAGE();
            END CATCH;
            
            FETCH NEXT FROM cursor_vip INTO @ClienteID, @Nombre, @Email;
        END;
        
    END TRY
    BEGIN CATCH
        -- Error general del cursor
        SET @Errores = @Errores + 1;
        PRINT 'ERROR GENERAL: ' + ERROR_MESSAGE();
    END CATCH;
    
    -- Limpieza garantizada
    IF CURSOR_STATUS('local', 'cursor_vip') >= 0
    BEGIN
        CLOSE cursor_vip;
    END;
    IF CURSOR_STATUS('local', 'cursor_vip') >= -1
    BEGIN
        DEALLOCATE cursor_vip;
    END;
    
    PRINT '';
    PRINT '=== RESUMEN ===';
    PRINT 'Reportes generados: ' + CAST(@ReportesGenerados AS VARCHAR);
    PRINT 'Errores: ' + CAST(@Errores AS VARCHAR);
    
END;
GO

-- Probar
DECLARE @Gen INT, @Err INT;
EXEC dbo.sp_GenerarReportesPorCliente @ReportesGenerados = @Gen OUTPUT, @Errores = @Err OUTPUT;
SELECT @Gen AS ReportesGenerados, @Err AS Errores;
GO


-- ============================================================
-- LIMPIEZA
-- ============================================================
DROP TABLE IF EXISTS #ClientesInactivos;
DROP TABLE IF EXISTS #ActualizacionesEmail;
DROP TABLE IF EXISTS #TransPrueba;
DROP TABLE IF EXISTS #ResultadoCursor;
DROP TABLE IF EXISTS #ResultadoSetBased;

PRINT '============================================================';
PRINT 'Ejercicios Sesión 12 completados';
PRINT '============================================================';
