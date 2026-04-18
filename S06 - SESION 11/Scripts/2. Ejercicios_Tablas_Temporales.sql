/***************************************************************
 * SESIÓN 11: EJERCICIOS - TABLAS TEMPORALES Y VARIABLES
 * SQL Server Intermedio - 2026
 * 
 * Instrucciones:
 *   - Completar cada ejercicio en el espacio indicado
 *   - Usar BancoDB como base de datos
 *   - Las soluciones están al final del archivo
 * 
 * Temas evaluados:
 *   - #temp vs @table vs ##temp
 *   - Scope y ciclo de vida
 *   - Índices en tablas temporales
 *   - Table-Valued Parameters
 *   - Performance y estadísticas
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: Tabla Temporal Básica
-- ============================================================
/*
   Crear una tabla temporal #ClientesSaldoAlto que contenga:
   - ClienteID
   - NombreCompleto (Nombre + Apellido)
   - TotalCuentas (número de cuentas)
   - SaldoTotal (suma de saldos de todas sus cuentas)
   
   Solo incluir clientes con SaldoTotal > 50000
   Crear un índice en SaldoTotal después de cargar los datos
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 2: Variable de Tabla con Índice
-- ============================================================
/*
   Declarar una variable de tabla @TransaccionesMes que contenga:
   - TransaccionID (PK)
   - CuentaID (con índice)
   - Monto
   - FechaTransaccion
   
   Cargar las transacciones del último mes
   Mostrar el total de monto por CuentaID
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 3: Comparar Scope
-- ============================================================
/*
   Crear un SP llamado sp_TestScopeTemp que:
   1. Reciba una #TablaExterna creada por el caller
   2. Agregue una fila a esa tabla
   3. Retorne el contenido de la tabla
   
   Luego crear la tabla #TablaExterna, insertar un dato,
   llamar al SP y verificar que tiene ambas filas.
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 4: Variable de Tabla y ROLLBACK
-- ============================================================
/*
   Demostrar que las variables de tabla NO se afectan por ROLLBACK:
   
   1. Declarar @LogAuditoria con columnas (ID INT IDENTITY, Mensaje VARCHAR(100))
   2. Insertar 'Inicio proceso'
   3. Iniciar transacción
   4. Insertar 'Dentro de transacción'
   5. Hacer ROLLBACK
   6. Insertar 'Después del rollback'
   7. Mostrar el contenido (deberían verse las 3 filas)
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 5: Tabla Temporal Global
-- ============================================================
/*
   Crear una tabla temporal global ##ConfiguracionETL con:
   - ParametroID INT IDENTITY PRIMARY KEY
   - Nombre VARCHAR(100)
   - Valor VARCHAR(500)
   - FechaModificacion DATETIME DEFAULT GETDATE()
   
   Insertar 3 parámetros de configuración
   Verificar que existe en tempdb
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 6: Type y Table-Valued Parameter
-- ============================================================
/*
   1. Crear un TYPE llamado TipoCuentasParametro con:
      - CuentaID INT PRIMARY KEY
   
   2. Crear un SP sp_DesactivarCuentas que:
      - Reciba el TVP como parámetro
      - Muestre las cuentas que SERÍAN desactivadas
        (no ejecutar UPDATE real, solo SELECT)
      - Retorne el count de cuentas afectadas
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 7: Proceso Multi-Paso con Tablas Temporales
-- ============================================================
/*
   Crear un SP sp_AnalisisTransaccionesMensual que:
   
   Paso 1: Crear #TransaccionesMes con todas las transacciones
           del mes actual
   
   Paso 2: Crear #ResumenPorTipo con suma y count por TipoTransaccion
   
   Paso 3: Crear #ResumenPorCuenta con suma de Depósitos y Retiros
           por cada CuentaID
   
   Paso 4: Retornar 3 resultsets:
           - Top 10 cuentas por volumen
           - Resumen por tipo de transacción
           - Total general del mes
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 8: Optimización con Índices
-- ============================================================
/*
   Comparar el rendimiento de una consulta con y sin índices
   en una tabla temporal:
   
   1. Crear #TransaccionesGrande con TODAS las transacciones
   2. Ejecutar una consulta que haga JOIN con CUENTAS y CLIENTES
      filtrando por un rango de fechas (sin índices)
   3. Crear índice en FechaTransaccion y CuentaID
   4. Ejecutar la misma consulta
   5. Usar SET STATISTICS IO ON para comparar
*/

-- TU CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 9: Cuándo Usar Cada Tipo
-- ============================================================
/*
   Para cada escenario, indica si usarías #temp, @variable, o ##temp
   y justifica por qué. Luego implementa UNO de los escenarios.
   
   Escenarios:
   A) Pasar 5 IDs de cliente a un SP para obtener info
   B) Almacenar 50,000 registros para procesar en lotes
   C) Compartir datos de configuración entre 3 ventanas SSMS
   D) Log de operaciones que debe sobrevivir a un ROLLBACK
   E) Resultado intermedio de un cálculo complejo con JOINs
*/

-- TUS RESPUESTAS Y CÓDIGO AQUÍ:




-- ============================================================
-- EJERCICIO 10: SP Completo de Reporte
-- ============================================================
/*
   Crear un SP sp_ReporteClientesInactivos que:
   
   1. Use tabla temporal para identificar clientes sin transacciones
      en los últimos 90 días
   
   2. Use variable de tabla para almacenar métricas de resumen
   
   3. Use TVP para recibir opcionalmente una lista de segmentos
      a filtrar (si está vacío, todos los segmentos)
   
   4. Retorne:
      - Lista de clientes inactivos con su última transacción
      - Resumen por segmento de inactividad
      - Total de saldo "dormido" (saldo de clientes inactivos)
   
   Bonus: Incluir manejo de errores con log en variable de tabla
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
DROP TABLE IF EXISTS #ClientesSaldoAlto;

SELECT 
    c.ClienteID,
    c.Nombre + ' ' + c.Apellido AS NombreCompleto,
    COUNT(cu.CuentaID) AS TotalCuentas,
    ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal
INTO #ClientesSaldoAlto
FROM CLIENTES c
LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
GROUP BY c.ClienteID, c.Nombre, c.Apellido
HAVING ISNULL(SUM(cu.Saldo), 0) > 50000;

-- Crear índice después de cargar
CREATE INDEX IX_SaldoTotal ON #ClientesSaldoAlto(SaldoTotal DESC);

-- Verificar
SELECT * FROM #ClientesSaldoAlto ORDER BY SaldoTotal DESC;
GO


-- SOLUCIÓN EJERCICIO 2
-- ====================
DECLARE @TransaccionesMes TABLE (
    TransaccionID INT PRIMARY KEY NONCLUSTERED,
    CuentaID INT NOT NULL,
    Monto DECIMAL(18,2),
    FechaTransaccion DATE,
    INDEX IX_Cuenta NONCLUSTERED (CuentaID)
);

INSERT INTO @TransaccionesMes
SELECT 
    TransaccionID,
    CuentaID,
    Monto,
    FechaTransaccion
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= DATEADD(MONTH, -1, GETDATE());

SELECT 
    CuentaID,
    COUNT(*) AS NumTransacciones,
    SUM(Monto) AS TotalMonto
FROM @TransaccionesMes
GROUP BY CuentaID
ORDER BY TotalMonto DESC;
GO


-- SOLUCIÓN EJERCICIO 3
-- ====================
CREATE OR ALTER PROCEDURE dbo.sp_TestScopeTemp
AS
BEGIN
    -- El SP puede acceder a #TablaExterna creada por el caller
    INSERT INTO #TablaExterna (ID, Valor)
    VALUES (2, 'Insertado desde SP');
    
    SELECT * FROM #TablaExterna;
END;
GO

-- Crear y probar
DROP TABLE IF EXISTS #TablaExterna;

CREATE TABLE #TablaExterna (
    ID INT,
    Valor VARCHAR(100)
);

INSERT INTO #TablaExterna (ID, Valor) VALUES (1, 'Insertado por caller');

-- Ejecutar SP
EXEC dbo.sp_TestScopeTemp;
-- Debe mostrar 2 filas
GO


-- SOLUCIÓN EJERCICIO 4
-- ====================
DECLARE @LogAuditoria TABLE (
    ID INT IDENTITY(1,1),
    Mensaje VARCHAR(100),
    Fecha DATETIME DEFAULT GETDATE()
);

-- Paso 1
INSERT INTO @LogAuditoria (Mensaje) VALUES ('Inicio proceso');

-- Paso 2: Iniciar transacción
BEGIN TRANSACTION;

-- Paso 3: Insertar dentro de transacción
INSERT INTO @LogAuditoria (Mensaje) VALUES ('Dentro de transacción');

-- Paso 4: Rollback
ROLLBACK;

-- Paso 5: Insertar después del rollback
INSERT INTO @LogAuditoria (Mensaje) VALUES ('Después del rollback');

-- Paso 6: Mostrar todo - las 3 filas están presentes
SELECT * FROM @LogAuditoria;
-- Esto demuestra que @variable NO se afecta por ROLLBACK
GO


-- SOLUCIÓN EJERCICIO 5
-- ====================
DROP TABLE IF EXISTS ##ConfiguracionETL;

CREATE TABLE ##ConfiguracionETL (
    ParametroID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Valor VARCHAR(500),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

INSERT INTO ##ConfiguracionETL (Nombre, Valor)
VALUES 
    ('BatchSize', '10000'),
    ('TimeoutMinutos', '30'),
    ('NotificarEmail', 'etl@banco.com');

-- Verificar existencia en tempdb
SELECT 
    name AS NombreTabla,
    create_date AS FechaCreacion,
    type_desc
FROM tempdb.sys.tables 
WHERE name LIKE '##ConfiguracionETL%';

SELECT * FROM ##ConfiguracionETL;
GO


-- SOLUCIÓN EJERCICIO 6
-- ====================
-- Limpiar si existe
IF TYPE_ID('dbo.TipoCuentasParametro') IS NOT NULL
BEGIN
    -- Primero eliminar SP que depende del type
    DROP PROCEDURE IF EXISTS dbo.sp_DesactivarCuentas;
    DROP TYPE dbo.TipoCuentasParametro;
END
GO

-- Crear el TYPE
CREATE TYPE dbo.TipoCuentasParametro AS TABLE (
    CuentaID INT PRIMARY KEY
);
GO

-- Crear el SP
CREATE OR ALTER PROCEDURE dbo.sp_DesactivarCuentas
    @CuentasADesactivar dbo.TipoCuentasParametro READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CuentasAfectadas INT;
    
    -- Mostrar cuentas que serían afectadas
    SELECT 
        c.CuentaID,
        c.NumeroCuenta,
        c.TipoCuenta,
        c.Saldo,
        c.Estado AS EstadoActual,
        'Inactiva' AS NuevoEstado,
        cl.Nombre + ' ' + cl.Apellido AS Titular
    FROM CUENTAS c
    INNER JOIN @CuentasADesactivar param ON c.CuentaID = param.CuentaID
    INNER JOIN CLIENTES cl ON c.ClienteID = cl.ClienteID;
    
    SET @CuentasAfectadas = @@ROWCOUNT;
    
    PRINT 'Cuentas que serían desactivadas: ' + CAST(@CuentasAfectadas AS VARCHAR(10));
    
    RETURN @CuentasAfectadas;
END;
GO

-- Probar
DECLARE @MisCuentas dbo.TipoCuentasParametro;
INSERT INTO @MisCuentas VALUES (1), (2), (3);
EXEC dbo.sp_DesactivarCuentas @CuentasADesactivar = @MisCuentas;
GO


-- SOLUCIÓN EJERCICIO 7
-- ====================
CREATE OR ALTER PROCEDURE dbo.sp_AnalisisTransaccionesMensual
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Paso 1: Transacciones del mes
    DROP TABLE IF EXISTS #TransaccionesMes;
    
    SELECT *
    INTO #TransaccionesMes
    FROM TRANSACCIONES_BANCARIAS
    WHERE MONTH(FechaTransaccion) = MONTH(GETDATE())
      AND YEAR(FechaTransaccion) = YEAR(GETDATE());
    
    -- Paso 2: Resumen por tipo
    DROP TABLE IF EXISTS #ResumenPorTipo;
    
    SELECT 
        TipoTransaccion,
        COUNT(*) AS Cantidad,
        SUM(Monto) AS MontoTotal,
        AVG(Monto) AS MontoPromedio
    INTO #ResumenPorTipo
    FROM #TransaccionesMes
    GROUP BY TipoTransaccion;
    
    -- Paso 3: Resumen por cuenta
    DROP TABLE IF EXISTS #ResumenPorCuenta;
    
    SELECT 
        CuentaID,
        SUM(CASE WHEN TipoTransaccion = 'Depósito' THEN Monto ELSE 0 END) AS TotalDepositos,
        SUM(CASE WHEN TipoTransaccion = 'Retiro' THEN Monto ELSE 0 END) AS TotalRetiros,
        COUNT(*) AS NumTransacciones
    INTO #ResumenPorCuenta
    FROM #TransaccionesMes
    GROUP BY CuentaID;
    
    CREATE INDEX IX_Volumen ON #ResumenPorCuenta(TotalDepositos DESC);
    
    -- Resultset 1: Top 10 cuentas
    SELECT TOP 10 
        rc.CuentaID,
        c.NumeroCuenta,
        cl.Nombre + ' ' + cl.Apellido AS Titular,
        rc.TotalDepositos,
        rc.TotalRetiros,
        rc.TotalDepositos + rc.TotalRetiros AS VolumenTotal
    FROM #ResumenPorCuenta rc
    JOIN CUENTAS c ON rc.CuentaID = c.CuentaID
    JOIN CLIENTES cl ON c.ClienteID = cl.ClienteID
    ORDER BY (rc.TotalDepositos + rc.TotalRetiros) DESC;
    
    -- Resultset 2: Por tipo de transacción
    SELECT * FROM #ResumenPorTipo ORDER BY MontoTotal DESC;
    
    -- Resultset 3: Total general
    SELECT 
        COUNT(*) AS TotalTransacciones,
        SUM(Monto) AS MontoTotal,
        COUNT(DISTINCT CuentaID) AS CuentasActivas
    FROM #TransaccionesMes;
    
END;
GO

EXEC dbo.sp_AnalisisTransaccionesMensual;
GO


-- SOLUCIÓN EJERCICIO 8
-- ====================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Crear tabla sin índices
DROP TABLE IF EXISTS #TransaccionesGrande;

SELECT *
INTO #TransaccionesGrande
FROM TRANSACCIONES_BANCARIAS;

PRINT '--- CONSULTA SIN ÍNDICES ---';
SELECT 
    c.Nombre,
    t.TipoTransaccion,
    SUM(t.Monto) AS TotalMonto
FROM #TransaccionesGrande t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2024-01-01'
GROUP BY c.Nombre, t.TipoTransaccion;

-- Crear índices
CREATE INDEX IX_Fecha ON #TransaccionesGrande(FechaTransaccion);
CREATE INDEX IX_Cuenta ON #TransaccionesGrande(CuentaID);

PRINT '--- CONSULTA CON ÍNDICES ---';
SELECT 
    c.Nombre,
    t.TipoTransaccion,
    SUM(t.Monto) AS TotalMonto
FROM #TransaccionesGrande t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2024-01-01'
GROUP BY c.Nombre, t.TipoTransaccion;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


-- SOLUCIÓN EJERCICIO 9
-- ====================
/*
   Respuestas conceptuales:
   
   A) 5 IDs -> @variable (conjunto pequeño, scope limitado)
   B) 50,000 registros -> #temp (estadísticas, índices)
   C) Compartir entre ventanas -> ##temp (global)
   D) Log que sobreviva rollback -> @variable (no afectado por rollback)
   E) Cálculo complejo -> #temp (estadísticas para optimizador)
*/

-- Implementación escenario D: Log que sobrevive rollback
CREATE OR ALTER PROCEDURE dbo.sp_ProcesoConLogPersistente
AS
BEGIN
    DECLARE @Log TABLE (
        Paso INT IDENTITY,
        Accion VARCHAR(100),
        Resultado VARCHAR(50),
        Fecha DATETIME DEFAULT GETDATE()
    );
    
    INSERT INTO @Log (Accion, Resultado) VALUES ('Inicio', 'OK');
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO @Log (Accion, Resultado) VALUES ('Validación', 'OK');
        INSERT INTO @Log (Accion, Resultado) VALUES ('Proceso principal', 'En progreso');
        
        -- Simular error
        RAISERROR('Error simulado para demostración', 16, 1);
        
        COMMIT;
        INSERT INTO @Log (Accion, Resultado) VALUES ('Commit', 'OK');
    END TRY
    BEGIN CATCH
        ROLLBACK;
        INSERT INTO @Log (Accion, Resultado) 
        VALUES ('Error capturado', ERROR_MESSAGE());
    END CATCH;
    
    -- El log está completo a pesar del rollback
    SELECT * FROM @Log ORDER BY Paso;
END;
GO

EXEC dbo.sp_ProcesoConLogPersistente;
GO


-- SOLUCIÓN EJERCICIO 10
-- ====================
-- Crear TYPE para el filtro de segmentos
IF TYPE_ID('dbo.TipoSegmentos') IS NOT NULL
BEGIN
    DROP PROCEDURE IF EXISTS dbo.sp_ReporteClientesInactivos;
    DROP TYPE dbo.TipoSegmentos;
END
GO

CREATE TYPE dbo.TipoSegmentos AS TABLE (
    Segmento VARCHAR(50) PRIMARY KEY
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_ReporteClientesInactivos
    @SegmentosFiltro dbo.TipoSegmentos READONLY,
    @DiasInactividad INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variable para log (sobrevive errores)
    DECLARE @Log TABLE (
        Paso INT IDENTITY,
        Mensaje VARCHAR(200),
        Fecha DATETIME DEFAULT GETDATE()
    );
    
    INSERT INTO @Log (Mensaje) VALUES ('Inicio del reporte de inactividad');
    
    BEGIN TRY
        -- Determinar si hay filtro de segmentos
        DECLARE @TieneFiltroBit BIT = 0;
        IF EXISTS (SELECT 1 FROM @SegmentosFiltro)
            SET @TieneFiltroBit = 1;
        
        INSERT INTO @Log (Mensaje) 
        VALUES ('Filtro de segmentos: ' + CASE WHEN @TieneFiltroBit = 1 THEN 'Sí' ELSE 'No (todos)' END);
        
        -- Tabla temporal: Última transacción por cliente
        DROP TABLE IF EXISTS #UltimaActividad;
        
        SELECT 
            c.ClienteID,
            c.Nombre + ' ' + c.Apellido AS NombreCompleto,
            c.Segmento,
            c.Email,
            MAX(t.FechaTransaccion) AS UltimaTransaccion,
            DATEDIFF(DAY, MAX(t.FechaTransaccion), GETDATE()) AS DiasInactivo
        INTO #UltimaActividad
        FROM CLIENTES c
        LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
        LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
        WHERE c.Estado = 'Activo'
        GROUP BY c.ClienteID, c.Nombre, c.Apellido, c.Segmento, c.Email;
        
        CREATE INDEX IX_DiasInactivo ON #UltimaActividad(DiasInactivo);
        CREATE INDEX IX_Segmento ON #UltimaActividad(Segmento);
        
        INSERT INTO @Log (Mensaje) 
        VALUES ('Clientes analizados: ' + CAST(@@ROWCOUNT AS VARCHAR(10)));
        
        -- Tabla temporal: Clientes inactivos
        DROP TABLE IF EXISTS #ClientesInactivos;
        
        SELECT ua.*
        INTO #ClientesInactivos
        FROM #UltimaActividad ua
        WHERE (ua.DiasInactivo >= @DiasInactividad OR ua.UltimaTransaccion IS NULL)
          AND (@TieneFiltroBit = 0 OR ua.Segmento IN (SELECT Segmento FROM @SegmentosFiltro));
        
        INSERT INTO @Log (Mensaje) 
        VALUES ('Clientes inactivos encontrados: ' + CAST(@@ROWCOUNT AS VARCHAR(10)));
        
        -- Variable de tabla: Métricas de resumen
        DECLARE @ResumenSegmento TABLE (
            Segmento VARCHAR(50),
            ClientesInactivos INT,
            SaldoDormido DECIMAL(18,2)
        );
        
        INSERT INTO @ResumenSegmento
        SELECT 
            ci.Segmento,
            COUNT(DISTINCT ci.ClienteID) AS ClientesInactivos,
            ISNULL(SUM(cu.Saldo), 0) AS SaldoDormido
        FROM #ClientesInactivos ci
        LEFT JOIN CUENTAS cu ON ci.ClienteID = cu.ClienteID
        GROUP BY ci.Segmento;
        
        -- RESULTSET 1: Lista de clientes inactivos
        SELECT 
            ci.ClienteID,
            ci.NombreCompleto,
            ci.Segmento,
            ci.Email,
            ci.UltimaTransaccion,
            ci.DiasInactivo,
            ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal
        FROM #ClientesInactivos ci
        LEFT JOIN CUENTAS cu ON ci.ClienteID = cu.ClienteID
        GROUP BY ci.ClienteID, ci.NombreCompleto, ci.Segmento, 
                 ci.Email, ci.UltimaTransaccion, ci.DiasInactivo
        ORDER BY ci.DiasInactivo DESC;
        
        -- RESULTSET 2: Resumen por segmento
        SELECT * FROM @ResumenSegmento ORDER BY SaldoDormido DESC;
        
        -- RESULTSET 3: Total de saldo dormido
        SELECT 
            COUNT(DISTINCT ci.ClienteID) AS TotalClientesInactivos,
            SUM(DISTINCT ISNULL(
                (SELECT SUM(Saldo) FROM CUENTAS WHERE ClienteID = ci.ClienteID), 0
            )) AS TotalSaldoDormido
        FROM #ClientesInactivos ci;
        
        INSERT INTO @Log (Mensaje) VALUES ('Reporte generado exitosamente');
        
    END TRY
    BEGIN CATCH
        INSERT INTO @Log (Mensaje) 
        VALUES ('ERROR: ' + ERROR_MESSAGE());
    END CATCH;
    
    -- RESULTSET 4: Log del proceso
    SELECT * FROM @Log ORDER BY Paso;
    
END;
GO

-- Probar sin filtro
EXEC dbo.sp_ReporteClientesInactivos @DiasInactividad = 30;

-- Probar con filtro de segmentos
DECLARE @MisSegmentos dbo.TipoSegmentos;
INSERT INTO @MisSegmentos VALUES ('VIP'), ('Premium');
EXEC dbo.sp_ReporteClientesInactivos 
    @SegmentosFiltro = @MisSegmentos,
    @DiasInactividad = 30;
GO


-- ============================================================
-- LIMPIEZA
-- ============================================================
DROP TABLE IF EXISTS #ClientesSaldoAlto;
DROP TABLE IF EXISTS #TransaccionesGrande;
DROP TABLE IF EXISTS #TransaccionesMes;
DROP TABLE IF EXISTS #ResumenPorTipo;
DROP TABLE IF EXISTS #ResumenPorCuenta;
DROP TABLE IF EXISTS #UltimaActividad;
DROP TABLE IF EXISTS #ClientesInactivos;
DROP TABLE IF EXISTS #TablaExterna;
DROP TABLE IF EXISTS ##ConfiguracionETL;

PRINT '============================================================';
PRINT 'Ejercicios Sesión 11 completados';
PRINT '============================================================';
