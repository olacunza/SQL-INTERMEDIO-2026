/*
=====================================================================
  SESIÓN 08: EXECUTION PLANS II - QUERY HINTS Y OPTIMIZACIÓN AVANZADA
  SQL Server Intermedio 2026
  
  Temas:
    1. ¿Qué son los Query Hints?
    2. Join Hints: LOOP, HASH, MERGE
    3. Table Hints: NOLOCK, READPAST, etc.
    4. OPTION Clause: RECOMPILE, OPTIMIZE FOR
    5. Parameter Sniffing: Problema y Soluciones
    6. Plan Guides
    7. Query Store: Monitoreo y Plan Forcing
    8. Plan Freezing para consultas críticas
    9. FORCESEEK y FORCESCAN
   10. Hints de paralelismo: MAXDOP
   11. Caso práctico: Estabilizando el Core Bancario
   
  Base de datos: BancoDB
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- PARTE 1: ¿QUÉ SON LOS QUERY HINTS?
-- =====================================================================
/*
   Los Query Hints son INSTRUCCIONES al Query Optimizer para:
   - Forzar un tipo específico de JOIN
   - Controlar el acceso a tablas
   - Modificar el comportamiento de compilación
   - Controlar el paralelismo
   
   ⚠️ ADVERTENCIA:
   Los hints ANULAN la inteligencia del optimizer.
   Usar solo cuando:
   1. Has probado que el optimizer elige mal
   2. Tienes evidencia con STATISTICS IO/TIME
   3. El hint es la mejor solución a largo plazo
   
   TIPOS DE HINTS:
   - JOIN Hints: Fuerzan tipo de join (LOOP, HASH, MERGE)
   - TABLE Hints: Controlan acceso a tablas (NOLOCK, INDEX, etc.)
   - QUERY Hints: Afectan toda la consulta (OPTION clause)
*/

-- =====================================================================
-- PARTE 2: JOIN HINTS - LOOP, HASH, MERGE
-- =====================================================================

/*
   TIPOS DE JOIN FÍSICOS:
   
   ┌─────────────────┬────────────────────────────────────────────────┐
   │ TIPO            │ MEJOR USADO CUANDO                             │
   ├─────────────────┼────────────────────────────────────────────────┤
   │ NESTED LOOPS    │ Outer pequeño + índice en inner table          │
   │ HASH JOIN       │ Sin índices útiles, tablas grandes             │
   │ MERGE JOIN      │ Ambas tablas ordenadas por columna de JOIN     │
   └─────────────────┴────────────────────────────────────────────────┘
*/

-- 2.1 Sin hint - el optimizer decide
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.ClienteID BETWEEN 1 AND 100;

-- 2.2 Forzar LOOP JOIN
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER LOOP JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.ClienteID BETWEEN 1 AND 100;

-- 2.3 Forzar HASH JOIN
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER HASH JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.ClienteID BETWEEN 1 AND 100;

-- 2.4 Forzar MERGE JOIN
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER MERGE JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.ClienteID BETWEEN 1 AND 100;

-- Comparar planes y STATISTICS IO para ver diferencias
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Ejecutar las 4 versiones y comparar logical reads

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- =====================================================================
-- PARTE 3: TABLE HINTS
-- =====================================================================

/*
   TABLE HINTS se aplican a tablas individuales:
   
   ┌────────────────────┬────────────────────────────────────────────┐
   │ HINT               │ EFECTO                                     │
   ├────────────────────┼────────────────────────────────────────────┤
   │ NOLOCK             │ Lee sin tomar locks (dirty reads)          │
   │ READUNCOMMITTED    │ Igual que NOLOCK                           │
   │ READPAST           │ Salta filas bloqueadas                     │
   │ UPDLOCK            │ Toma lock de actualización al leer         │
   │ HOLDLOCK           │ Mantiene lock hasta fin de transacción     │
   │ TABLOCK            │ Lock a nivel de tabla                      │
   │ INDEX(nombre)      │ Fuerza uso de índice específico            │
   │ FORCESEEK          │ Fuerza Index Seek (no Scan)                │
   │ FORCESCAN          │ Fuerza Index Scan (no Seek)                │
   └────────────────────┴────────────────────────────────────────────┘
*/

-- 3.1 NOLOCK - Lecturas sucias (usar con precaución)
-- ⚠️ Puede leer datos no committed, datos parciales, o duplicados
SELECT c.Nombre, c.Email
FROM CLIENTES c WITH (NOLOCK)
WHERE c.FechaRegistro >= '2024-01-01';

-- 3.2 READPAST - Salta filas bloqueadas (útil en procesamiento por lotes)
-- Ideal para colas o procesamiento paralelo
SELECT TOP 100 TransaccionID, Monto
FROM TRANSACCIONES_BANCARIAS WITH (READPAST, UPDLOCK)
WHERE Estado = 'Pendiente'
ORDER BY FechaTransaccion;

-- 3.3 INDEX hint - Forzar uso de índice específico
-- Crear índice para demo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_Monto_Demo')
    CREATE NONCLUSTERED INDEX IX_TX_Monto_Demo 
    ON TRANSACCIONES_BANCARIAS(Monto);

-- Forzar uso del índice
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS WITH (INDEX(IX_TX_Monto_Demo))
WHERE Monto > 5000;

-- Sin el hint, el optimizer podría elegir otro plan
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS
WHERE Monto > 5000;

-- =====================================================================
-- PARTE 4: OPTION CLAUSE - HINTS A NIVEL DE CONSULTA
-- =====================================================================

/*
   OPTION se coloca al FINAL de la consulta:
   
   SELECT ... FROM ... WHERE ...
   OPTION (hint1, hint2, ...)
   
   HINTS COMUNES:
   - RECOMPILE: Genera nuevo plan cada ejecución
   - OPTIMIZE FOR: Optimiza para valor específico
   - OPTIMIZE FOR UNKNOWN: Ignora valor real del parámetro
   - MAXDOP n: Limita grado de paralelismo
   - FORCE ORDER: Mantiene orden de tablas en FROM
   - USE PLAN: Usa plan XML específico
*/

-- 4.1 OPTION (RECOMPILE)
-- Genera nuevo plan en cada ejecución
-- Útil cuando el parámetro varía drásticamente
DECLARE @TipoTX VARCHAR(20) = 'Transferencia';

SELECT TransaccionID, Monto, FechaTransaccion
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = @TipoTX
OPTION (RECOMPILE);  -- Nuevo plan cada vez

-- 4.2 OPTION (OPTIMIZE FOR)
-- Optimiza el plan para un valor específico
DECLARE @MontoMinimo DECIMAL(18,2) = 10000;

SELECT TransaccionID, Monto, TipoTransaccion
FROM TRANSACCIONES_BANCARIAS
WHERE Monto >= @MontoMinimo
OPTION (OPTIMIZE FOR (@MontoMinimo = 50000));  -- Optimiza como si fuera 50000

-- 4.3 OPTION (OPTIMIZE FOR UNKNOWN)
-- Usa distribución promedio, ignora el valor real
DECLARE @ClienteID INT = 1;

SELECT c.Nombre, cu.NumeroCuenta, t.Monto
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE c.ClienteID = @ClienteID
OPTION (OPTIMIZE FOR UNKNOWN);

-- 4.4 OPTION (MAXDOP n)
-- Limita el paralelismo
SELECT 
    TipoTransaccion,
    COUNT(*) AS Total,
    SUM(Monto) AS MontoTotal
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= '2024-01-01'
GROUP BY TipoTransaccion
OPTION (MAXDOP 1);  -- Sin paralelismo

-- 4.5 OPTION (FORCE ORDER)
-- Mantiene el orden de JOINs como está escrito
SELECT c.Nombre, cu.NumeroCuenta, t.Monto
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE t.Monto > 10000
OPTION (FORCE ORDER);  -- JOIN en el orden escrito

-- =====================================================================
-- PARTE 5: PARAMETER SNIFFING - EL PROBLEMA
-- =====================================================================

/*
   PARAMETER SNIFFING:
   
   SQL Server compila un SP/consulta parametrizada basándose
   en el PRIMER valor del parámetro que ve.
   
   PROBLEMA:
   - Si el primer valor es atípico, el plan será subóptimo
   - Ejemplo: Cliente con 2 transacciones vs cliente con 50,000
   
   SÍNTOMAS:
   - SP rápido a veces, lento otras
   - Performance inconsistente con mismos parámetros
   - DBCC FREEPROCCACHE "arregla" temporalmente
*/

-- Crear SP para demostrar el problema
CREATE OR ALTER PROCEDURE dbo.sp_TransaccionesPorCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.Nombre,
        cu.NumeroCuenta,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.ClienteID = @ClienteID
    ORDER BY t.FechaTransaccion DESC;
END;
GO

-- Escenario: Cliente 1 tiene 5 transacciones, Cliente 999 tiene 50,000

-- Primera ejecución con cliente pequeño
EXEC dbo.sp_TransaccionesPorCliente @ClienteID = 1;
-- El plan se compila optimizado para "pocas filas"

-- Segunda ejecución con cliente grande
EXEC dbo.sp_TransaccionesPorCliente @ClienteID = 999;
-- USA EL MISMO PLAN (puede ser ineficiente)

-- =====================================================================
-- PARTE 6: SOLUCIONES PARA PARAMETER SNIFFING
-- =====================================================================

/*
   SOLUCIONES:
   
   1. OPTION (RECOMPILE) - Nuevo plan cada vez
   2. OPTION (OPTIMIZE FOR) - Optimizar para valor típico
   3. OPTION (OPTIMIZE FOR UNKNOWN) - Usar promedios
   4. Variables locales - Rompe el sniffing (cuidado)
   5. Plan Guides - Forzar hints sin cambiar código
   6. Query Store - Forzar plan específico
*/

-- SOLUCIÓN 1: RECOMPILE
CREATE OR ALTER PROCEDURE dbo.sp_TransaccionesPorCliente_v1
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.Nombre,
        cu.NumeroCuenta,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.ClienteID = @ClienteID
    ORDER BY t.FechaTransaccion DESC
    OPTION (RECOMPILE);  -- Nuevo plan cada ejecución
END;
GO

-- SOLUCIÓN 2: OPTIMIZE FOR valor típico
CREATE OR ALTER PROCEDURE dbo.sp_TransaccionesPorCliente_v2
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.Nombre,
        cu.NumeroCuenta,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.ClienteID = @ClienteID
    ORDER BY t.FechaTransaccion DESC
    OPTION (OPTIMIZE FOR (@ClienteID = 500));  -- Optimiza para cliente "promedio"
END;
GO

-- SOLUCIÓN 3: Variables locales (menos recomendado)
CREATE OR ALTER PROCEDURE dbo.sp_TransaccionesPorCliente_v3
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variable local "rompe" el sniffing
    DECLARE @LocalClienteID INT = @ClienteID;
    
    SELECT 
        c.Nombre,
        cu.NumeroCuenta,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.ClienteID = @LocalClienteID  -- Usa variable local
    ORDER BY t.FechaTransaccion DESC;
END;
GO

-- =====================================================================
-- PARTE 7: QUERY STORE - MONITOREO Y PLAN FORCING
-- =====================================================================

/*
   QUERY STORE (SQL Server 2016+):
   
   - Captura automáticamente consultas, planes y métricas
   - Permite comparar rendimiento entre planes
   - Permite FORZAR un plan específico
   - Detecta regresiones de planes
   
   BENEFICIOS:
   - Persiste información aunque se reinicie SQL Server
   - No requiere modificar código
   - Herramienta integrada en SSMS
*/

-- 7.1 Verificar si Query Store está habilitado
SELECT 
    name AS DatabaseName,
    is_query_store_on AS QueryStoreEnabled,
    query_store_options.desired_state_desc,
    query_store_options.actual_state_desc,
    query_store_options.readonly_reason
FROM sys.databases d
LEFT JOIN sys.database_query_store_options query_store_options
    ON d.database_id = query_store_options.database_id
WHERE d.name = 'BancoDB';

-- 7.2 Habilitar Query Store (si está deshabilitado)
ALTER DATABASE BancoDB SET QUERY_STORE = ON;

ALTER DATABASE BancoDB SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO
);

-- 7.3 Ver consultas capturadas
SELECT TOP 20
    q.query_id,
    q.query_hash,
    t.query_sql_text,
    rs.count_executions,
    rs.avg_duration / 1000.0 AS avg_duration_ms,
    rs.avg_logical_io_reads,
    rs.last_execution_time
FROM sys.query_store_query q
INNER JOIN sys.query_store_query_text t ON q.query_text_id = t.query_text_id
INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE t.query_sql_text NOT LIKE '%sys.%'
ORDER BY rs.avg_duration DESC;

-- 7.4 Ver planes para una consulta específica
DECLARE @QueryID INT = 1;  -- Reemplazar con query_id real

SELECT 
    p.plan_id,
    p.query_id,
    p.engine_version,
    p.is_forced_plan,
    p.last_execution_time,
    rs.count_executions,
    rs.avg_duration / 1000.0 AS avg_duration_ms,
    rs.avg_logical_io_reads
FROM sys.query_store_plan p
INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE p.query_id = @QueryID
ORDER BY rs.avg_duration;

-- 7.5 FORZAR un plan específico
-- sp_query_store_force_plan @query_id, @plan_id
-- EXEC sp_query_store_force_plan @query_id = 1, @plan_id = 2;

-- 7.6 QUITAR forcing de un plan
-- EXEC sp_query_store_unforce_plan @query_id = 1, @plan_id = 2;

-- =====================================================================
-- PARTE 8: PLAN GUIDES
-- =====================================================================

/*
   PLAN GUIDES:
   
   Permiten aplicar hints SIN MODIFICAR el código fuente.
   Útil cuando:
   - No puedes cambiar la aplicación
   - Consultas vienen de ORM/herramienta
   - Necesitas arreglo rápido sin deployment
   
   TIPOS:
   - OBJECT: Para SPs, funciones, triggers
   - SQL: Para consultas ad-hoc específicas
   - TEMPLATE: Para familia de consultas similares
*/

-- 8.1 Crear Plan Guide para un SP
EXEC sp_create_plan_guide
    @name = N'PG_TransaccionesPorCliente',
    @stmt = N'SELECT 
        c.Nombre,
        cu.NumeroCuenta,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE c.ClienteID = @ClienteID
    ORDER BY t.FechaTransaccion DESC',
    @type = N'OBJECT',
    @module_or_batch = N'dbo.sp_TransaccionesPorCliente',
    @params = NULL,
    @hints = N'OPTION (OPTIMIZE FOR (@ClienteID = 500))';

-- 8.2 Ver Plan Guides existentes
SELECT 
    name,
    scope_type_desc,
    is_disabled,
    query_text
FROM sys.plan_guides
WHERE is_disabled = 0;

-- 8.3 Deshabilitar/Habilitar Plan Guide
EXEC sp_control_plan_guide 
    @operation = N'DISABLE', 
    @name = N'PG_TransaccionesPorCliente';

EXEC sp_control_plan_guide 
    @operation = N'ENABLE', 
    @name = N'PG_TransaccionesPorCliente';

-- 8.4 Eliminar Plan Guide
-- EXEC sp_control_plan_guide @operation = N'DROP', @name = N'PG_TransaccionesPorCliente';

-- =====================================================================
-- PARTE 9: FORCESEEK Y FORCESCAN
-- =====================================================================

/*
   FORCESEEK:
   - Obliga al optimizer a usar Index Seek
   - Útil cuando tienes un buen índice pero SQL elige Scan
   
   FORCESCAN:
   - Obliga al optimizer a usar Index Scan
   - Útil cuando Seek + Key Lookup es más caro que Scan
   
   ⚠️ PRECAUCIÓN: Solo usar cuando tienes evidencia clara
*/

-- 9.1 FORCESEEK
-- Crear índice para demo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CLIENTES_Nombre_Demo')
    CREATE NONCLUSTERED INDEX IX_CLIENTES_Nombre_Demo ON CLIENTES(Nombre);

-- Forzar Seek aunque el optimizer prefiera Scan
SELECT ClienteID, Nombre, Email
FROM CLIENTES WITH (FORCESEEK)
WHERE Nombre LIKE 'Juan%';

-- También puedes especificar el índice
SELECT ClienteID, Nombre, Email
FROM CLIENTES WITH (FORCESEEK, INDEX(IX_CLIENTES_Nombre_Demo))
WHERE Nombre LIKE 'Juan%';

-- 9.2 FORCESCAN
-- Forzar Scan cuando tienes razón para evitar Seeks múltiples
SELECT ClienteID, Nombre
FROM CLIENTES WITH (FORCESCAN)
WHERE ClienteID % 2 = 0;  -- 50% de filas - Scan es mejor

-- =====================================================================
-- PARTE 10: HINTS DE PARALELISMO - MAXDOP
-- =====================================================================

/*
   MAXDOP (Maximum Degree of Parallelism):
   
   - Controla cuántos CPUs puede usar una consulta
   - MAXDOP 1 = Sin paralelismo (serial)
   - MAXDOP 0 = Usar todos los CPUs disponibles
   - MAXDOP n = Usar máximo n CPUs
   
   CUÁNDO USAR MAXDOP 1:
   - Consultas OLTP pequeñas (evita overhead de paralelismo)
   - Cuando muchas consultas compiten por CPU
   - En servidores con pocas CPUs
   
   CUÁNDO PERMITIR PARALELISMO:
   - Consultas analíticas grandes
   - Procesamiento batch
   - Reportes pesados
*/

-- 10.1 Consulta serial (sin paralelismo)
SELECT 
    TipoTransaccion,
    YEAR(FechaTransaccion) AS Anio,
    MONTH(FechaTransaccion) AS Mes,
    COUNT(*) AS TotalTX,
    SUM(Monto) AS MontoTotal
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= '2023-01-01'
GROUP BY TipoTransaccion, YEAR(FechaTransaccion), MONTH(FechaTransaccion)
ORDER BY Anio, Mes
OPTION (MAXDOP 1);

-- 10.2 Permitir paralelismo completo
SELECT 
    TipoTransaccion,
    YEAR(FechaTransaccion) AS Anio,
    MONTH(FechaTransaccion) AS Mes,
    COUNT(*) AS TotalTX,
    SUM(Monto) AS MontoTotal
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= '2023-01-01'
GROUP BY TipoTransaccion, YEAR(FechaTransaccion), MONTH(FechaTransaccion)
ORDER BY Anio, Mes
OPTION (MAXDOP 0);  -- Usa todos los CPUs

-- 10.3 Ver configuración de MAXDOP del servidor
EXEC sp_configure 'max degree of parallelism';

-- =====================================================================
-- PARTE 11: CASO PRÁCTICO - ESTABILIZANDO EL CORE BANCARIO
-- =====================================================================

/*
   ESCENARIO:
   El SP de "Consulta de Movimientos" es crítico pero inestable.
   A veces tarda 50ms, otras veces 15 segundos.
   
   DIAGNÓSTICO:
   - Parameter sniffing (clientes pequeños vs grandes)
   - Plan variable según el primer parámetro
   
   SOLUCIÓN IMPLEMENTADA:
   1. Query Store para monitorear
   2. Identificar el mejor plan
   3. Forzar ese plan
   4. Monitorear resultados
*/

-- Paso 1: Crear el SP crítico
CREATE OR ALTER PROCEDURE dbo.sp_ConsultaMovimientos_Critico
    @ClienteID INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Defaults para fechas
    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -3, GETDATE()));
    SET @FechaFin = ISNULL(@FechaFin, GETDATE());
    
    SELECT 
        c.ClienteID,
        c.Nombre,
        c.Email,
        cu.NumeroCuenta,
        cu.TipoCuenta,
        cu.Saldo AS SaldoActual,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion,
        t.Descripcion,
        SUM(t.Monto) OVER (
            PARTITION BY cu.CuentaID 
            ORDER BY t.FechaTransaccion
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS SaldoAcumulado
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
        AND t.FechaTransaccion BETWEEN @FechaInicio AND @FechaFin
    WHERE c.ClienteID = @ClienteID
    ORDER BY cu.NumeroCuenta, t.FechaTransaccion;
END;
GO

-- Paso 2: Ejecutar con diferentes parámetros para generar planes
EXEC dbo.sp_ConsultaMovimientos_Critico @ClienteID = 1;
EXEC dbo.sp_ConsultaMovimientos_Critico @ClienteID = 100;
EXEC dbo.sp_ConsultaMovimientos_Critico @ClienteID = 500;

-- Paso 3: Analizar en Query Store
SELECT 
    q.query_id,
    p.plan_id,
    t.query_sql_text,
    rs.count_executions,
    rs.avg_duration / 1000.0 AS avg_ms,
    rs.min_duration / 1000.0 AS min_ms,
    rs.max_duration / 1000.0 AS max_ms,
    rs.avg_logical_io_reads
FROM sys.query_store_query q
INNER JOIN sys.query_store_query_text t ON q.query_text_id = t.query_text_id
INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE t.query_sql_text LIKE '%ConsultaMovimientos%'
ORDER BY rs.avg_duration DESC;

-- Paso 4: Si identificamos el mejor plan, lo forzamos
-- EXEC sp_query_store_force_plan @query_id = X, @plan_id = Y;

-- ALTERNATIVA: Versión con RECOMPILE para casos extremos
CREATE OR ALTER PROCEDURE dbo.sp_ConsultaMovimientos_Estable
    @ClienteID INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -3, GETDATE()));
    SET @FechaFin = ISNULL(@FechaFin, GETDATE());
    
    SELECT 
        c.ClienteID,
        c.Nombre,
        c.Email,
        cu.NumeroCuenta,
        cu.TipoCuenta,
        cu.Saldo AS SaldoActual,
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion,
        t.Descripcion
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
        AND t.FechaTransaccion BETWEEN @FechaInicio AND @FechaFin
    WHERE c.ClienteID = @ClienteID
    ORDER BY cu.NumeroCuenta, t.FechaTransaccion
    OPTION (RECOMPILE);  -- Plan siempre óptimo para el parámetro
END;
GO

-- =====================================================================
-- LIMPIEZA (ejecutar al final si deseas)
-- =====================================================================
/*
DROP PROCEDURE IF EXISTS dbo.sp_TransaccionesPorCliente;
DROP PROCEDURE IF EXISTS dbo.sp_TransaccionesPorCliente_v1;
DROP PROCEDURE IF EXISTS dbo.sp_TransaccionesPorCliente_v2;
DROP PROCEDURE IF EXISTS dbo.sp_TransaccionesPorCliente_v3;
DROP PROCEDURE IF EXISTS dbo.sp_ConsultaMovimientos_Critico;
DROP PROCEDURE IF EXISTS dbo.sp_ConsultaMovimientos_Estable;
DROP INDEX IF EXISTS IX_TX_Monto_Demo ON TRANSACCIONES_BANCARIAS;
DROP INDEX IF EXISTS IX_CLIENTES_Nombre_Demo ON CLIENTES;
EXEC sp_control_plan_guide @operation = N'DROP ALL';
*/

-- =====================================================================
-- RESUMEN DE LA SESIÓN
-- =====================================================================
/*
   HINTS - RESUMEN:
   
   1. JOIN Hints: LOOP, HASH, MERGE
      - Solo usar cuando hay evidencia clara
   
   2. TABLE Hints: NOLOCK, INDEX, FORCESEEK
      - NOLOCK: Riesgo de dirty reads
      - INDEX: Forzar índice específico
   
   3. OPTION Hints:
      - RECOMPILE: Nuevo plan cada vez
      - OPTIMIZE FOR: Plan para valor específico
      - MAXDOP: Control de paralelismo
   
   4. Parameter Sniffing:
      - Problema: Plan subóptimo por primer valor
      - Soluciones: RECOMPILE, OPTIMIZE FOR, Variables locales
   
   5. Query Store:
      - Monitorear rendimiento automáticamente
      - Forzar planes sin cambiar código
   
   6. Plan Guides:
      - Aplicar hints sin modificar aplicación
   
   REGLA DE ORO:
   Los hints son "último recurso". Primero:
   1. Crear/mejorar índices
   2. Reescribir la consulta
   3. Actualizar estadísticas
   Solo entonces considerar hints.
   
   PRÓXIMA SESIÓN:
   - Optimización de Índices (desfragmentación, rebuild, reorganize)
*/
