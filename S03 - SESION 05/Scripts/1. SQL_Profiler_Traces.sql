-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 5
-- SQL PROFILER & TRACES
-- Enfoque: Identificar el SP que "cuelga" la DB
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- PARTE 0: PREPARACIÓN DEL AMBIENTE
-- ============================================================

-- Crear tabla de auditoría para registrar consultas lentas
IF OBJECT_ID('AUDITORIA_CONSULTAS') IS NOT NULL DROP TABLE AUDITORIA_CONSULTAS;

CREATE TABLE AUDITORIA_CONSULTAS (
    AuditoriaID INT IDENTITY(1,1) PRIMARY KEY,
    FechaHora DATETIME2 DEFAULT SYSDATETIME(),
    NombreSP NVARCHAR(256),
    TextoSQL NVARCHAR(MAX),
    DuracionMS INT,
    LecturasLogicas BIGINT,
    EscriturasLogicas BIGINT,
    CPU_MS INT,
    Usuario NVARCHAR(128),
    HostName NVARCHAR(128),
    AppName NVARCHAR(128)
);
GO

-- Crear SPs de prueba para monitoreo
CREATE OR ALTER PROCEDURE SP_ConsultaRapida
AS
BEGIN
    SET NOCOUNT ON;
    -- Consulta optimizada con índice
    SELECT TOP 10 CLIENTEID, NOMBRE, APELLIDO 
    FROM CLIENTES 
    WHERE CLIENTEID > 0;
END
GO

CREATE OR ALTER PROCEDURE SP_ConsultaLenta
AS
BEGIN
    SET NOCOUNT ON;
    -- Simulamos consulta pesada con WAITFOR
    WAITFOR DELAY '00:00:02';  -- 2 segundos de delay
    
    -- Consulta que genera muchas lecturas lógicas
    SELECT c.CLIENTEID, c.NOMBRE, cu.NUMEROCUENTA, cu.SALDO,
           (SELECT COUNT(*) FROM TRANSACCIONES_BANCARIAS tb WHERE tb.CUENTA_ORIGEN = cu.CUENTAID) AS TotalTx
    FROM CLIENTES c
    CROSS JOIN CUENTAS cu  -- Cross join intencional para generar carga
    WHERE cu.SALDO > 1000;
END
GO

CREATE OR ALTER PROCEDURE SP_ReporteMensual
    @MesNumero INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Consulta compleja con múltiples joins
    SELECT 
        c.NOMBRE + ' ' + c.APELLIDO AS Cliente,
        cu.NUMEROCUENTA,
        cu.TIPOCUENTA,
        cu.SALDO AS SaldoActual,
        ISNULL(SUM(CASE WHEN tb.TIPO = 'DEPOSITO' THEN tb.MONTO ELSE 0 END), 0) AS TotalDepositos,
        ISNULL(SUM(CASE WHEN tb.TIPO = 'RETIRO' THEN tb.MONTO ELSE 0 END), 0) AS TotalRetiros,
        ISNULL(SUM(CASE WHEN tb.TIPO = 'TRANSFERENCIA' THEN tb.MONTO ELSE 0 END), 0) AS TotalTransferencias,
        COUNT(tb.TRANSACCIONID) AS CantidadMovimientos
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.CLIENTEID = cu.CLIENTEID
    LEFT JOIN TRANSACCIONES_BANCARIAS tb ON cu.CUENTAID = tb.CUENTA_ORIGEN
    WHERE cu.ESTADO = 'ACTIVA'
      AND (MONTH(tb.FECHA) = @MesNumero OR tb.FECHA IS NULL)
    GROUP BY c.NOMBRE, c.APELLIDO, cu.NUMEROCUENTA, cu.TIPOCUENTA, cu.SALDO
    ORDER BY c.APELLIDO, c.NOMBRE;
END
GO

CREATE OR ALTER PROCEDURE SP_TransferenciaMasiva
    @CuentaOrigen INT,
    @MontoTotal DECIMAL(15,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- SP problemático: Usa cursor (ejemplo de mala práctica)
    DECLARE @CuentaID INT;
    DECLARE @MontoPorCuenta DECIMAL(15,2);
    
    DECLARE curCuentas CURSOR FOR
        SELECT CUENTAID FROM CUENTAS WHERE CUENTAID != @CuentaOrigen AND ESTADO = 'ACTIVA';
    
    -- Calcular monto por cuenta
    SELECT @MontoPorCuenta = @MontoTotal / COUNT(*) 
    FROM CUENTAS WHERE CUENTAID != @CuentaOrigen AND ESTADO = 'ACTIVA';
    
    OPEN curCuentas;
    FETCH NEXT FROM curCuentas INTO @CuentaID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Transferencia individual (ineficiente)
        UPDATE CUENTAS SET SALDO = SALDO + @MontoPorCuenta WHERE CUENTAID = @CuentaID;
        
        WAITFOR DELAY '00:00:00.100';  -- Simular latencia
        
        FETCH NEXT FROM curCuentas INTO @CuentaID;
    END
    
    CLOSE curCuentas;
    DEALLOCATE curCuentas;
    
    UPDATE CUENTAS SET SALDO = SALDO - @MontoTotal WHERE CUENTAID = @CuentaOrigen;
END
GO

PRINT '✅ Ambiente de prueba preparado para Profiler';
GO

-- ============================================================
-- PARTE 1: TEORÍA - SQL PROFILER FUNDAMENTALS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 1: FUNDAMENTOS DE SQL PROFILER';
PRINT '============================================';

/*
╔══════════════════════════════════════════════════════════════╗
║                 ¿QUÉ ES SQL PROFILER?                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  SQL Profiler es una herramienta gráfica de SQL Server      ║
║  para monitorear eventos del Motor de Base de Datos.         ║
║                                                              ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  USOS PRINCIPALES:                                       │ ║
║  │  • Identificar consultas lentas                          │ ║
║  │  • Detectar Deadlocks                                    │ ║
║  │  • Capturar parámetros de SPs                            │ ║
║  │  • Auditar actividad de usuarios                         │ ║
║  │  • Diagnosticar problemas de rendimiento                 │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  ⚠️ IMPORTANTE:                                               ║
║  SQL Profiler está DEPRECATED desde SQL Server 2012.        ║
║  Microsoft recomienda usar Extended Events (XEvents).       ║
║  Sin embargo, sigue siendo útil para diagnósticos rápidos.  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║              EVENTOS MÁS IMPORTANTES                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  CATEGORÍA: TSQL                                             ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  • SQL:BatchStarting    → Inicio de un batch             │ ║
║  │  • SQL:BatchCompleted   → Fin de un batch + métricas     │ ║
║  │  • SQL:StmtStarting     → Inicio de cada statement       │ ║
║  │  • SQL:StmtCompleted    → Fin de statement + métricas    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  CATEGORÍA: Stored Procedures                                ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  • SP:Starting          → Inicio de un SP                │ ║
║  │  • SP:Completed         → Fin de SP + métricas           │ ║
║  │  • SP:StmtStarting      → Inicio de statement en SP      │ ║
║  │  • SP:StmtCompleted     → Fin de statement en SP         │ ║
║  │  • RPC:Completed        → Llamadas RPC completadas       │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  CATEGORÍA: Locks                                            ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  • Lock:Deadlock        → Ocurrió un Deadlock            │ ║
║  │  • Lock:Deadlock Chain  → Cadena de deadlock             │ ║
║  │  • Lock:Timeout         → Timeout esperando lock         │ ║
║  │  • Lock:Escalation      → Escalación de bloqueo          │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  CATEGORÍA: Performance                                      ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  • Showplan XML         → Plan de ejecución XML          │ ║
║  │  • Performance Stats    → Estadísticas de rendimiento    │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║              COLUMNAS CLAVE PARA ANÁLISIS                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  COLUMNA           │ SIGNIFICADO                         │ ║
║  ├─────────────────────────────────────────────────────────┤ ║
║  │  Duration          │ Tiempo total en microsegundos       │ ║
║  │  CPU               │ Tiempo de CPU en milisegundos       │ ║
║  │  Reads             │ Lecturas lógicas de páginas         │ ║
║  │  Writes            │ Escrituras lógicas de páginas       │ ║
║  │  TextData          │ Texto SQL o nombre del SP           │ ║
║  │  ObjectName        │ Nombre del objeto (SP, función)     │ ║
║  │  LoginName         │ Login de SQL Server                 │ ║
║  │  ApplicationName   │ Nombre de la aplicación cliente     │ ║
║  │  HostName          │ Nombre del equipo cliente           │ ║
║  │  SPID              │ ID del proceso de servidor          │ ║
║  │  StartTime         │ Hora de inicio del evento           │ ║
║  │  EndTime           │ Hora de fin del evento              │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  ⚡ TIP SENIOR:                                               ║
║  Para diagnóstico rápido, ordena por:                        ║
║  1. Duration DESC → Consultas más lentas                     ║
║  2. Reads DESC    → Consultas con más I/O                    ║
║  3. CPU DESC      → Consultas que más CPU consumen           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- ============================================================
-- PARTE 2: CREAR TRACE CON T-SQL (Server-Side Trace)
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 2: SERVER-SIDE TRACE CON T-SQL';
PRINT '============================================';

/*
    Los Server-Side Traces son más eficientes que Profiler GUI
    porque se ejecutan directamente en el servidor.
    
    Ventajas:
    - Menor overhead que Profiler GUI
    - Se pueden programar y automatizar
    - Escriben directamente a archivo
    - No requieren conexión GUI constante
*/

-- DEMO 1: Crear un Trace completo para monitoreo
-- (Ejecutar como sysadmin)

DECLARE @TraceID INT;
DECLARE @FilePath NVARCHAR(256) = N'C:\Temp\BancoDB_Trace';  -- Sin extensión .trc
DECLARE @MaxFileSize BIGINT = 100;  -- 100 MB máximo por archivo

-- Verificar si existe la carpeta (crear si no existe)
-- EXEC xp_cmdshell 'mkdir C:\Temp 2>nul';

-- Crear el trace
EXEC sp_trace_create 
    @traceid = @TraceID OUTPUT,
    @options = 2,               -- TRACE_FILE_ROLLOVER (crea nuevo archivo al llegar al máximo)
    @tracefile = @FilePath,
    @maxfilesize = @MaxFileSize;

PRINT 'Trace creado con ID: ' + CAST(@TraceID AS VARCHAR(10));

-- Ahora agregamos los eventos que queremos capturar
-- Evento: SQL:BatchCompleted (EventClass = 12)
EXEC sp_trace_setevent @TraceID, 12, 1, 1;   -- TextData
EXEC sp_trace_setevent @TraceID, 12, 3, 1;   -- DatabaseID
EXEC sp_trace_setevent @TraceID, 12, 12, 1;  -- SPID
EXEC sp_trace_setevent @TraceID, 12, 13, 1;  -- Duration
EXEC sp_trace_setevent @TraceID, 12, 14, 1;  -- StartTime
EXEC sp_trace_setevent @TraceID, 12, 15, 1;  -- EndTime
EXEC sp_trace_setevent @TraceID, 12, 16, 1;  -- Reads
EXEC sp_trace_setevent @TraceID, 12, 17, 1;  -- Writes
EXEC sp_trace_setevent @TraceID, 12, 18, 1;  -- CPU

-- Evento: SP:Completed (EventClass = 43)
EXEC sp_trace_setevent @TraceID, 43, 1, 1;   -- TextData
EXEC sp_trace_setevent @TraceID, 43, 3, 1;   -- DatabaseID  
EXEC sp_trace_setevent @TraceID, 43, 12, 1;  -- SPID
EXEC sp_trace_setevent @TraceID, 43, 13, 1;  -- Duration
EXEC sp_trace_setevent @TraceID, 43, 14, 1;  -- StartTime
EXEC sp_trace_setevent @TraceID, 43, 16, 1;  -- Reads
EXEC sp_trace_setevent @TraceID, 43, 17, 1;  -- Writes
EXEC sp_trace_setevent @TraceID, 43, 18, 1;  -- CPU
EXEC sp_trace_setevent @TraceID, 43, 34, 1;  -- ObjectName

-- Evento: RPC:Completed (EventClass = 10) - Para llamadas desde aplicaciones
EXEC sp_trace_setevent @TraceID, 10, 1, 1;   -- TextData
EXEC sp_trace_setevent @TraceID, 10, 13, 1;  -- Duration
EXEC sp_trace_setevent @TraceID, 10, 16, 1;  -- Reads
EXEC sp_trace_setevent @TraceID, 10, 18, 1;  -- CPU

-- ========================================
-- FILTROS: Solo capturar lo relevante
-- ========================================

-- Filtro: Solo base de datos BancoDB
DECLARE @DatabaseID INT;
SELECT @DatabaseID = database_id FROM sys.databases WHERE name = 'BancoDB';

EXEC sp_trace_setfilter @TraceID, 3, 0, 0, @DatabaseID;  -- DatabaseID = BancoDB

-- Filtro: Duración > 1000 microsegundos (1 ms) - Eliminar ruido
EXEC sp_trace_setfilter @TraceID, 13, 0, 4, 1000;  -- Duration >= 1000 microsegundos

-- Filtro: Excluir SQL Profiler (evitar capturarnos a nosotros mismos)
EXEC sp_trace_setfilter @TraceID, 10, 0, 7, N'SQL Server Profiler';  -- NOT LIKE

-- ========================================
-- INICIAR EL TRACE
-- ========================================
EXEC sp_trace_setstatus @TraceID, 1;  -- 1 = Iniciar
PRINT 'Trace iniciado. ID: ' + CAST(@TraceID AS VARCHAR(10));

GO

-- ============================================================
-- DEMO 2: VERIFICAR TRACES ACTIVOS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 2: VERIFICAR TRACES ACTIVOS';
PRINT '============================================';

-- Ver todos los traces activos
SELECT 
    id AS TraceID,
    CASE 
        WHEN status = 0 THEN 'Detenido'
        WHEN status = 1 THEN 'Ejecutando'
    END AS Estado,
    path AS ArchivoTrace,
    max_size AS TamMaxMB,
    start_time AS Inicio,
    event_count AS EventosCapturados
FROM sys.traces;

-- Ver definición de un trace específico
SELECT * FROM sys.fn_trace_geteventinfo(1); -- Cambiar 1 por el ID del trace

GO

-- ============================================================
-- DEMO 3: GENERAR ACTIVIDAD PARA CAPTURAR
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 3: GENERAR ACTIVIDAD PARA CAPTURAR';
PRINT '============================================';

-- Ejecutar diferentes SPs para generar variedad de traces
PRINT 'Ejecutando SP_ConsultaRapida...';
EXEC SP_ConsultaRapida;

PRINT 'Ejecutando SP_ConsultaLenta (tarda ~2 segundos)...';
EXEC SP_ConsultaLenta;

PRINT 'Ejecutando SP_ReporteMensual...';
EXEC SP_ReporteMensual @MesNumero = 3;

-- Consulta ad-hoc
PRINT 'Ejecutando consulta ad-hoc compleja...';
SELECT 
    c.CLIENTEID,
    c.NOMBRE + ' ' + c.APELLIDO AS NombreCompleto,
    COUNT(cu.CUENTAID) AS TotalCuentas,
    SUM(cu.SALDO) AS SaldoTotal
FROM CLIENTES c
LEFT JOIN CUENTAS cu ON c.CLIENTEID = cu.CLIENTEID
GROUP BY c.CLIENTEID, c.NOMBRE, c.APELLIDO
HAVING SUM(cu.SALDO) > 10000
ORDER BY SaldoTotal DESC;

PRINT 'Actividad generada. Revisa el trace.';
GO

-- ============================================================
-- DEMO 4: DETENER Y LEER EL TRACE
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 4: DETENER Y ANALIZAR TRACE';
PRINT '============================================';

-- Obtener el ID del trace que creamos
DECLARE @TraceID INT;
SELECT TOP 1 @TraceID = id 
FROM sys.traces 
WHERE path LIKE '%BancoDB_Trace%';

IF @TraceID IS NOT NULL
BEGIN
    -- Detener el trace
    EXEC sp_trace_setstatus @TraceID, 0;  -- 0 = Detener
    PRINT 'Trace detenido. ID: ' + CAST(@TraceID AS VARCHAR(10));
    
    -- Cerrar y eliminar la definición del trace
    EXEC sp_trace_setstatus @TraceID, 2;  -- 2 = Cerrar
    PRINT 'Trace cerrado.';
END

GO

-- Leer archivo de trace con fn_trace_gettable
-- (Cambia la ruta según donde guardaste el archivo)
/*
SELECT 
    RowNumber,
    TextData,
    Duration / 1000 AS DuracionMS,         -- Convertir a milisegundos
    Reads AS LecturasLogicas,
    Writes AS EscriturasLogicas,
    CPU AS CPU_MS,
    StartTime,
    ObjectName,
    LoginName,
    HostName,
    ApplicationName
FROM fn_trace_gettable(N'C:\Temp\BancoDB_Trace.trc', DEFAULT)
WHERE Duration IS NOT NULL
ORDER BY Duration DESC;
*/

GO

-- ============================================================
-- PARTE 3: SCRIPT PRÁCTICO - ENCONTRAR SP PROBLEMÁTICO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 3: ENCONTRAR EL SP QUE CUELGA LA DB';
PRINT '============================================';

/*
    ESCENARIO REAL:
    El equipo de operaciones reporta que la base de datos
    se pone lenta todos los días a las 3:00 PM.
    
    OBJETIVO:
    Crear un trace que capture solo consultas lentas
    y identificar cuál SP es el culpable.
*/

-- SP para crear trace de detección de consultas lentas
CREATE OR ALTER PROCEDURE SP_IniciarMonitoreoLentos
    @DuracionMinimaMS INT = 1000,           -- Solo > 1 segundo
    @ArchivoSalida NVARCHAR(256) = N'C:\Temp\QuerysLentas'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TraceID INT;
    DECLARE @DuracionMicrosegundos BIGINT = @DuracionMinimaMS * 1000;
    
    -- Crear trace
    EXEC sp_trace_create 
        @traceid = @TraceID OUTPUT,
        @options = 2,
        @tracefile = @ArchivoSalida,
        @maxfilesize = 50;
    
    -- Eventos: SQL:BatchCompleted y SP:Completed
    -- SQL:BatchCompleted (12)
    EXEC sp_trace_setevent @TraceID, 12, 1, 1;   -- TextData
    EXEC sp_trace_setevent @TraceID, 12, 12, 1;  -- SPID
    EXEC sp_trace_setevent @TraceID, 12, 13, 1;  -- Duration
    EXEC sp_trace_setevent @TraceID, 12, 14, 1;  -- StartTime
    EXEC sp_trace_setevent @TraceID, 12, 16, 1;  -- Reads
    EXEC sp_trace_setevent @TraceID, 12, 18, 1;  -- CPU
    EXEC sp_trace_setevent @TraceID, 12, 8, 1;   -- HostName
    EXEC sp_trace_setevent @TraceID, 12, 10, 1;  -- ApplicationName
    EXEC sp_trace_setevent @TraceID, 12, 11, 1;  -- LoginName
    
    -- SP:Completed (43)
    EXEC sp_trace_setevent @TraceID, 43, 1, 1;   -- TextData
    EXEC sp_trace_setevent @TraceID, 43, 12, 1;  -- SPID
    EXEC sp_trace_setevent @TraceID, 43, 13, 1;  -- Duration
    EXEC sp_trace_setevent @TraceID, 43, 14, 1;  -- StartTime
    EXEC sp_trace_setevent @TraceID, 43, 16, 1;  -- Reads
    EXEC sp_trace_setevent @TraceID, 43, 18, 1;  -- CPU
    EXEC sp_trace_setevent @TraceID, 43, 34, 1;  -- ObjectName
    EXEC sp_trace_setevent @TraceID, 43, 8, 1;   -- HostName
    EXEC sp_trace_setevent @TraceID, 43, 10, 1;  -- ApplicationName
    
    -- RPC:Completed (10)
    EXEC sp_trace_setevent @TraceID, 10, 1, 1;   -- TextData
    EXEC sp_trace_setevent @TraceID, 10, 13, 1;  -- Duration
    EXEC sp_trace_setevent @TraceID, 10, 16, 1;  -- Reads
    EXEC sp_trace_setevent @TraceID, 10, 18, 1;  -- CPU
    EXEC sp_trace_setevent @TraceID, 10, 34, 1;  -- ObjectName
    
    -- FILTRO CLAVE: Solo consultas lentas
    EXEC sp_trace_setfilter @TraceID, 13, 0, 4, @DuracionMicrosegundos;
    
    -- Excluir herramientas de monitoreo
    EXEC sp_trace_setfilter @TraceID, 10, 0, 7, N'SQL Server Profiler';
    EXEC sp_trace_setfilter @TraceID, 10, 0, 7, N'Microsoft SQL Server Management Studio%';
    
    -- Iniciar
    EXEC sp_trace_setstatus @TraceID, 1;
    
    SELECT 
        @TraceID AS TraceID,
        'MONITOREO INICIADO' AS Estado,
        @DuracionMinimaMS AS UmbralMS,
        @ArchivoSalida + '.trc' AS ArchivoSalida;
END
GO

-- SP para detener el monitoreo y analizar resultados
CREATE OR ALTER PROCEDURE SP_DetenerYAnalizarMonitoreo
    @TraceID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Si no se especifica, buscar el trace activo
    IF @TraceID IS NULL
        SELECT TOP 1 @TraceID = id FROM sys.traces 
        WHERE path LIKE '%QuerysLentas%' AND status = 1;
    
    IF @TraceID IS NULL
    BEGIN
        PRINT 'No hay traces de monitoreo activos.';
        RETURN;
    END
    
    -- Obtener la ruta del archivo
    DECLARE @TracePath NVARCHAR(256);
    SELECT @TracePath = path FROM sys.traces WHERE id = @TraceID;
    
    -- Detener y cerrar
    EXEC sp_trace_setstatus @TraceID, 0;
    EXEC sp_trace_setstatus @TraceID, 2;
    
    PRINT 'Trace detenido. Analizando resultados...';
    PRINT '';
    
    -- Analizar el archivo de trace
    SELECT 
        ROW_NUMBER() OVER (ORDER BY Duration DESC) AS Ranking,
        CASE 
            WHEN ObjectName IS NOT NULL THEN ObjectName
            ELSE LEFT(CAST(TextData AS NVARCHAR(100)), 50) + '...'
        END AS Consulta,
        Duration / 1000 AS DuracionMS,
        Reads AS LecturasLogicas,
        CPU AS CPU_MS,
        LoginName AS Usuario,
        HostName AS Equipo,
        ApplicationName AS Aplicacion,
        StartTime
    FROM fn_trace_gettable(@TracePath, DEFAULT)
    WHERE Duration IS NOT NULL
    ORDER BY Duration DESC;
    
    -- Resumen por SP/Consulta
    PRINT 'RESUMEN POR STORED PROCEDURE:';
    SELECT 
        ISNULL(ObjectName, 'Ad-Hoc Query') AS TipoConsulta,
        COUNT(*) AS Ejecuciones,
        AVG(Duration / 1000) AS PromedioDuracionMS,
        MAX(Duration / 1000) AS MaxDuracionMS,
        SUM(Reads) AS TotalLecturas,
        SUM(CPU) AS TotalCPU_MS
    FROM fn_trace_gettable(@TracePath, DEFAULT)
    WHERE Duration IS NOT NULL
    GROUP BY ObjectName
    ORDER BY SUM(Duration) DESC;
END
GO

PRINT '✅ SPs de monitoreo creados: SP_IniciarMonitoreoLentos, SP_DetenerYAnalizarMonitoreo';
GO

-- ============================================================
-- PARTE 4: CONSULTAS ÚTILES PARA ANÁLISIS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 4: CONSULTAS PARA ANÁLISIS DE TRACES';
PRINT '============================================';

-- Ver todas las clases de eventos disponibles
SELECT 
    trace_event_id AS EventID,
    name AS NombreEvento,
    category_id AS CategoriaID
FROM sys.trace_events
WHERE category_id IN (4, 8, 10, 11, 12)  -- TSQL, Stored Procedures, Locks, Performance
ORDER BY category_id, trace_event_id;

-- Ver columnas disponibles para capturar
SELECT 
    trace_column_id AS ColumnID,
    name AS NombreColumna,
    type_name AS TipoDato
FROM sys.trace_columns
ORDER BY trace_column_id;

GO

-- ============================================================
-- PARTE 5: ALTERNATIVA MODERNA - sys.dm_exec_query_stats
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 5: ALTERNATIVA SIN TRACE (DMVs)';
PRINT '============================================';

-- En lugar de traces, podemos usar DMVs para análisis rápido

-- TOP 10 consultas más lentas por duración promedio
SELECT TOP 10
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1) AS TextoSQL,
    qs.execution_count AS Ejecuciones,
    qs.total_elapsed_time / 1000 AS TotalDuracionMS,
    qs.total_elapsed_time / qs.execution_count / 1000 AS PromDuracionMS,
    qs.total_logical_reads AS TotalLecturas,
    qs.total_logical_reads / qs.execution_count AS PromLecturas,
    qs.total_worker_time / 1000 AS TotalCPU_MS,
    qs.creation_time AS CompiladoDesde,
    qs.last_execution_time AS UltimaEjecucion
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.dbid = DB_ID('BancoDB')
ORDER BY qs.total_elapsed_time DESC;

-- TOP 10 consultas con más lecturas lógicas
SELECT TOP 10
    OBJECT_NAME(st.objectid, st.dbid) AS NombreObjeto,
    SUBSTRING(st.text, 1, 100) AS InicioQuery,
    qs.execution_count AS Ejecuciones,
    qs.total_logical_reads AS TotalLecturas,
    qs.total_logical_reads / qs.execution_count AS PromedioLecturas,
    qs.total_elapsed_time / 1000 AS TotalDuracionMS
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.dbid = DB_ID('BancoDB')
  AND qs.total_logical_reads > 1000
ORDER BY qs.total_logical_reads DESC;

-- Ver SPs más ejecutados
SELECT TOP 10
    OBJECT_NAME(ps.object_id) AS NombreSP,
    ps.execution_count AS Ejecuciones,
    ps.total_elapsed_time / 1000 AS TotalDuracionMS,
    ps.total_elapsed_time / ps.execution_count / 1000 AS PromDuracionMS,
    ps.total_logical_reads AS TotalLecturas,
    ps.total_logical_writes AS TotalEscrituras,
    ps.cached_time AS EnCacheDesde,
    ps.last_execution_time AS UltimaEjecucion
FROM sys.dm_exec_procedure_stats ps
WHERE OBJECT_NAME(ps.object_id) IS NOT NULL
  AND database_id = DB_ID('BancoDB')
ORDER BY ps.total_elapsed_time DESC;

GO

-- ============================================================
-- PARTE 6: TEMPLATE DE TRACE PARA DEADLOCKS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 6: TRACE PARA CAPTURAR DEADLOCKS';
PRINT '============================================';

CREATE OR ALTER PROCEDURE SP_IniciarTraceDeadlocks
    @ArchivoSalida NVARCHAR(256) = N'C:\Temp\Deadlocks_Trace'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TraceID INT;
    
    EXEC sp_trace_create 
        @traceid = @TraceID OUTPUT,
        @options = 2,
        @tracefile = @ArchivoSalida,
        @maxfilesize = 100;
    
    -- Evento: Deadlock Graph (EventClass = 148)
    -- Este evento captura el grafo XML del deadlock
    EXEC sp_trace_setevent @TraceID, 148, 1, 1;   -- TextData (XML del deadlock)
    EXEC sp_trace_setevent @TraceID, 148, 12, 1;  -- SPID
    EXEC sp_trace_setevent @TraceID, 148, 14, 1;  -- StartTime
    
    -- Evento: Lock:Deadlock (EventClass = 25)
    EXEC sp_trace_setevent @TraceID, 25, 1, 1;    -- TextData
    EXEC sp_trace_setevent @TraceID, 25, 12, 1;   -- SPID
    EXEC sp_trace_setevent @TraceID, 25, 14, 1;   -- StartTime
    EXEC sp_trace_setevent @TraceID, 25, 11, 1;   -- LoginName
    EXEC sp_trace_setevent @TraceID, 25, 8, 1;    -- HostName
    
    -- Evento: Lock:Deadlock Chain (EventClass = 59)
    EXEC sp_trace_setevent @TraceID, 59, 1, 1;    -- TextData
    EXEC sp_trace_setevent @TraceID, 59, 12, 1;   -- SPID
    EXEC sp_trace_setevent @TraceID, 59, 14, 1;   -- StartTime
    
    EXEC sp_trace_setstatus @TraceID, 1;
    
    SELECT 
        @TraceID AS TraceID,
        'MONITOREO DE DEADLOCKS INICIADO' AS Estado,
        @ArchivoSalida + '.trc' AS ArchivoSalida;
END
GO

PRINT '✅ SP_IniciarTraceDeadlocks creado';
GO

-- ============================================================
-- RESUMEN EJECUTIVO
-- ============================================================
PRINT '';
PRINT '╔══════════════════════════════════════════════════════════════╗';
PRINT '║                 RESUMEN - SQL PROFILER & TRACES              ║';
PRINT '╠══════════════════════════════════════════════════════════════╣';
PRINT '║                                                              ║';
PRINT '║  HERRAMIENTAS DISPONIBLES:                                   ║';
PRINT '║  • SQL Profiler GUI → Diagnóstico rápido (desarrollo)        ║';
PRINT '║  • Server-Side Traces → Producción (menor overhead)          ║';
PRINT '║  • DMVs → Análisis histórico sin trace activo                ║';
PRINT '║                                                              ║';
PRINT '║  EVENTOS CLAVE:                                              ║';
PRINT '║  • SQL:BatchCompleted → Todas las consultas                  ║';
PRINT '║  • SP:Completed → Stored Procedures                          ║';
PRINT '║  • RPC:Completed → Llamadas desde aplicaciones               ║';
PRINT '║  • Deadlock Graph → Capturar deadlocks                       ║';
PRINT '║                                                              ║';
PRINT '║  FILTROS RECOMENDADOS:                                       ║';
PRINT '║  • Duration > 1000 μs (eliminar ruido)                       ║';
PRINT '║  • DatabaseID = tu_base_datos                                ║';
PRINT '║  • Excluir herramientas de monitoreo                         ║';
PRINT '║                                                              ║';
PRINT '║  ⚡ PRÓXIMA SESIÓN: Extended Events (XEvents)                 ║';
PRINT '║  → Reemplazo moderno y más eficiente del Profiler            ║';
PRINT '║                                                              ║';
PRINT '╚══════════════════════════════════════════════════════════════╝';
GO
