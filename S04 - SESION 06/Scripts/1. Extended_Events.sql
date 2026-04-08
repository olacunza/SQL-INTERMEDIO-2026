-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 6
-- EXTENDED EVENTS (XEvents)
-- Enfoque: Reemplazo Moderno del Profiler
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- PARTE 0: INTRODUCCIÓN A EXTENDED EVENTS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 0: ¿QUÉ SON LOS EXTENDED EVENTS?';
PRINT '============================================';

/*
╔══════════════════════════════════════════════════════════════╗
║              EXTENDED EVENTS (XEvents)                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Extended Events es el sistema de monitoreo y diagnóstico    ║
║  de SQL Server desde la versión 2008. Es el REEMPLAZO        ║
║  oficial del SQL Profiler y Server-Side Traces.              ║
║                                                              ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  VENTAJAS SOBRE SQL PROFILER:                            │ ║
║  │                                                          │ ║
║  │  ✓ Menor overhead (hasta 10x menos impacto)              │ ║
║  │  ✓ Arquitectura unificada y extensible                   │ ║
║  │  ✓ Mejor integración con SSMS                            │ ║
║  │  ✓ Soporta Azure SQL Database                            │ ║
║  │  ✓ Más eventos y acciones disponibles                    │ ║
║  │  ✓ Filtrado más potente (predicados)                     │ ║
║  │  ✓ Múltiples destinos de salida (targets)                │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║              ARQUITECTURA DE XEVENTS                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ┌─────────────┐                                             ║
║  │   SESSION   │  ← Contenedor principal                     ║
║  └──────┬──────┘                                             ║
║         │                                                    ║
║    ┌────┴────┐                                               ║
║    ▼         ▼                                               ║
║  ┌─────┐  ┌─────────┐                                       ║
║  │EVENT│  │ TARGET  │                                       ║
║  └──┬──┘  └────┬────┘                                       ║
║     │          │                                             ║
║  ┌──┴──┐    ┌──┴──────────┐                                 ║
║  │     │    │             │                                  ║
║  ▼     ▼    ▼             ▼                                  ║
║ Action Predicate  ring_buffer  event_file                    ║
║ (qué    (filtro)  (memoria)    (archivo)                     ║
║ capturar)                                                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

    COMPONENTES:
    
    • SESSION: Contenedor que agrupa eventos y targets
    • EVENT: Lo que queremos capturar (ej: sql_statement_completed)
    • ACTION: Datos adicionales a capturar (ej: sql_text, database_name)
    • PREDICATE: Filtro para reducir lo capturado (ej: duration > 1000000)
    • TARGET: Donde guardar los datos (ring_buffer, event_file, etc.)
*/

-- ============================================================
-- PARTE 1: VER EVENTOS DISPONIBLES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 1: EXPLORAR EVENTOS DISPONIBLES';
PRINT '============================================';

-- Ver todos los paquetes de Extended Events
SELECT 
    p.name AS Paquete,
    p.description AS Descripcion,
    o.object_type AS TipoObjeto,
    COUNT(*) AS Cantidad
FROM sys.dm_xe_packages p
INNER JOIN sys.dm_xe_objects o ON p.guid = o.package_guid
GROUP BY p.name, p.description, o.object_type
ORDER BY p.name, o.object_type;

GO

-- Ver eventos más útiles para diagnóstico de performance
SELECT 
    p.name AS Paquete,
    o.name AS Evento,
    o.description AS Descripcion
FROM sys.dm_xe_packages p
INNER JOIN sys.dm_xe_objects o ON p.guid = o.package_guid
WHERE o.object_type = 'event'
  AND (
      o.name LIKE '%statement_completed%'
      OR o.name LIKE '%deadlock%'
      OR o.name LIKE '%error%'
      OR o.name LIKE '%wait%'
      OR o.name LIKE '%login%'
  )
ORDER BY o.name;

GO

-- Ver acciones disponibles (datos adicionales para capturar)
SELECT 
    p.name AS Paquete,
    o.name AS Accion,
    o.description AS Descripcion
FROM sys.dm_xe_packages p
INNER JOIN sys.dm_xe_objects o ON p.guid = o.package_guid
WHERE o.object_type = 'action'
ORDER BY o.name;

GO

-- ============================================================
-- PARTE 2: CREAR PRIMERA SESIÓN DE XEVENTS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 2: PRIMERA SESIÓN DE EXTENDED EVENTS';
PRINT '============================================';

-- Eliminar sesión si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'MonitorConsultasLentas')
    DROP EVENT SESSION MonitorConsultasLentas ON SERVER;
GO

-- Crear sesión para monitorear consultas lentas (> 1 segundo)
CREATE EVENT SESSION MonitorConsultasLentas
ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    -- ACCIONES: Datos adicionales a capturar
    ACTION (
        sqlserver.sql_text,           -- Texto completo de la consulta
        sqlserver.database_name,      -- Nombre de la base de datos
        sqlserver.username,           -- Usuario que ejecutó
        sqlserver.client_hostname,    -- Equipo cliente
        sqlserver.client_app_name,    -- Aplicación cliente
        sqlserver.session_id          -- SPID
    )
    -- PREDICADO: Filtro (duration en microsegundos)
    WHERE duration > 1000000          -- > 1 segundo (1,000,000 μs)
      AND sqlserver.database_name = N'BancoDB'
),
ADD EVENT sqlserver.sp_statement_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_app_name
    )
    WHERE duration > 1000000
      AND sqlserver.database_name = N'BancoDB'
)
-- TARGET: Donde guardar los datos
ADD TARGET package0.ring_buffer (
    SET max_memory = 4096              -- 4 MB en memoria
)
WITH (
    MAX_MEMORY = 4096 KB,              -- Memoria máxima de la sesión
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,  -- Permitir pérdida menor
    MAX_DISPATCH_LATENCY = 5 SECONDS,  -- Latencia máxima antes de escribir
    STARTUP_STATE = OFF                -- No iniciar automáticamente
);

GO

PRINT '✅ Sesión MonitorConsultasLentas creada';

-- Ver sesiones existentes
SELECT 
    name AS NombreSesion,
    CASE WHEN create_time IS NOT NULL THEN 'Creada' ELSE 'N/A' END AS Estado
FROM sys.server_event_sessions;

GO

-- ============================================================
-- PARTE 3: INICIAR Y PROBAR LA SESIÓN
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 3: INICIAR Y PROBAR LA SESIÓN';
PRINT '============================================';

-- Iniciar la sesión
ALTER EVENT SESSION MonitorConsultasLentas ON SERVER STATE = START;
PRINT '✅ Sesión iniciada';
GO

-- Generar algunas consultas lentas para capturar
PRINT 'Generando consultas lentas para capturar...';

-- Consulta lenta 1: WAITFOR
WAITFOR DELAY '00:00:02';
SELECT 'Consulta lenta 1 completada' AS Resultado;

-- Consulta lenta 2: Cross Join pesado
SELECT COUNT(*) AS TotalFilas
FROM CLIENTES c1
CROSS JOIN CLIENTES c2
CROSS JOIN CLIENTES c3;

-- Consulta lenta 3: Llamar SP con delay
IF OBJECT_ID('SP_ConsultaLenta') IS NOT NULL
    EXEC SP_ConsultaLenta;

PRINT '✅ Consultas de prueba ejecutadas';
GO

-- ============================================================
-- PARTE 4: LEER DATOS DEL RING_BUFFER
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 4: LEER DATOS CAPTURADOS';
PRINT '============================================';

-- Extraer datos del ring_buffer (XML)
;WITH XEventData AS (
    SELECT 
        CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    INNER JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'MonitorConsultasLentas'
      AND st.target_name = 'ring_buffer'
)
SELECT 
    event_data.value('(@name)[1]', 'VARCHAR(50)') AS NombreEvento,
    event_data.value('(@timestamp)[1]', 'DATETIME2') AS FechaHora,
    event_data.value('(data[@name="duration"]/value)[1]', 'BIGINT') / 1000 AS DuracionMS,
    event_data.value('(data[@name="cpu_time"]/value)[1]', 'BIGINT') / 1000 AS CPU_MS,
    event_data.value('(data[@name="logical_reads"]/value)[1]', 'BIGINT') AS LecturasLogicas,
    event_data.value('(data[@name="physical_reads"]/value)[1]', 'BIGINT') AS LecturasFisicas,
    event_data.value('(data[@name="writes"]/value)[1]', 'BIGINT') AS Escrituras,
    event_data.value('(action[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS BaseDatos,
    event_data.value('(action[@name="username"]/value)[1]', 'NVARCHAR(128)') AS Usuario,
    event_data.value('(action[@name="client_app_name"]/value)[1]', 'NVARCHAR(256)') AS Aplicacion,
    SUBSTRING(event_data.value('(action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)'), 1, 200) AS SQL_Text
FROM XEventData
CROSS APPLY TargetData.nodes('RingBufferTarget/event') AS xed(event_data)
ORDER BY event_data.value('(@timestamp)[1]', 'DATETIME2') DESC;

GO

-- ============================================================
-- PARTE 5: SESIÓN CON EVENT_FILE (ARCHIVO)
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 5: GUARDAR EN ARCHIVO (event_file)';
PRINT '============================================';

-- Eliminar sesión anterior si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'MonitorBancoDB_Archivo')
    DROP EVENT SESSION MonitorBancoDB_Archivo ON SERVER;
GO

-- Crear sesión que guarda en archivo
CREATE EVENT SESSION MonitorBancoDB_Archivo
ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_hostname,
        sqlserver.query_hash,         -- Hash único de la consulta
        sqlserver.query_plan_hash     -- Hash del plan de ejecución
    )
    WHERE duration > 500000           -- > 500ms
      AND sqlserver.database_name = N'BancoDB'
),
ADD EVENT sqlserver.rpc_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username
    )
    WHERE duration > 500000
      AND sqlserver.database_name = N'BancoDB'
)
-- TARGET: Archivo en disco
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\BancoDB_XEvents.xel',  -- Archivo .xel
        max_file_size = 50,                         -- 50 MB por archivo
        max_rollover_files = 5                      -- Máximo 5 archivos (250 MB total)
)
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 10 SECONDS,
    STARTUP_STATE = OFF
);

GO

PRINT '✅ Sesión MonitorBancoDB_Archivo creada';
GO

-- Iniciar la sesión
ALTER EVENT SESSION MonitorBancoDB_Archivo ON SERVER STATE = START;
PRINT '✅ Sesión de archivo iniciada';
GO

-- ============================================================
-- PARTE 6: LEER ARCHIVOS .XEL
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 6: LEER ARCHIVOS .XEL';
PRINT '============================================';

-- Función para leer archivos .xel
-- (Ejecutar después de generar algunos eventos)

/*
SELECT 
    event_data.value('(@name)[1]', 'varchar(50)') AS event_name,
    event_data.value('(@timestamp)[1]', 'datetime2') AS event_time,
    event_data.value('(data[@name="duration"]/value)[1]', 'bigint') / 1000 AS duration_ms,
    event_data.value('(data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads,
    event_data.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text
FROM sys.fn_xe_file_target_read_file(
    'C:\Temp\BancoDB_XEvents*.xel',  -- Patrón de archivos
    NULL, NULL, NULL
) AS f
CROSS APPLY (SELECT CAST(event_data AS XML)) AS x(event_data)
ORDER BY event_time DESC;
*/

-- Ejemplo de análisis agregado desde archivo
/*
SELECT 
    event_data.value('(action[@name="query_hash"]/value)[1]', 'varchar(50)') AS query_hash,
    COUNT(*) AS ejecuciones,
    AVG(event_data.value('(data[@name="duration"]/value)[1]', 'bigint') / 1000) AS avg_duration_ms,
    SUM(event_data.value('(data[@name="logical_reads"]/value)[1]', 'bigint')) AS total_reads
FROM sys.fn_xe_file_target_read_file('C:\Temp\BancoDB_XEvents*.xel', NULL, NULL, NULL) AS f
CROSS APPLY (SELECT CAST(event_data AS XML)) AS x(event_data)
GROUP BY event_data.value('(action[@name="query_hash"]/value)[1]', 'varchar(50)')
ORDER BY total_reads DESC;
*/

GO

-- ============================================================
-- PARTE 7: CAPTURAR DEADLOCKS CON XEVENTS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 7: CAPTURAR DEADLOCKS CON XEVENTS';
PRINT '============================================';

-- Eliminar sesión si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'CapturaDeadlocks')
    DROP EVENT SESSION CapturaDeadlocks ON SERVER;
GO

-- Crear sesión específica para Deadlocks
CREATE EVENT SESSION CapturaDeadlocks
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report (
    ACTION (
        sqlserver.database_name,
        sqlserver.client_hostname,
        sqlserver.username
    )
),
ADD EVENT sqlserver.lock_deadlock (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.session_id
    )
),
ADD EVENT sqlserver.lock_deadlock_chain (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name
    )
)
ADD TARGET package0.ring_buffer (
    SET max_memory = 4096
),
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Deadlocks.xel',
        max_file_size = 20,
        max_rollover_files = 10
)
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = NO_EVENT_LOSS,  -- NO perder eventos de deadlock
    MAX_DISPATCH_LATENCY = 1 SECONDS,      -- Escribir inmediatamente
    STARTUP_STATE = ON                      -- Iniciar con SQL Server
);

GO

-- Iniciar la sesión
ALTER EVENT SESSION CapturaDeadlocks ON SERVER STATE = START;
PRINT '✅ Sesión de captura de Deadlocks iniciada';
GO

-- Script para extraer deadlock graph del ring_buffer
CREATE OR ALTER PROCEDURE SP_VerDeadlocksRecientes
    @UltimasHoras INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    ;WITH DeadlockData AS (
        SELECT 
            CAST(target_data AS XML) AS TargetData
        FROM sys.dm_xe_session_targets st
        INNER JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
        WHERE s.name = 'CapturaDeadlocks'
          AND st.target_name = 'ring_buffer'
    )
    SELECT 
        event_data.value('(@timestamp)[1]', 'DATETIME2') AS FechaHoraDeadlock,
        event_data.value('(data[@name="xml_report"]/value)[1]', 'NVARCHAR(MAX)') AS DeadlockGraph
    FROM DeadlockData
    CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS xed(event_data)
    WHERE event_data.value('(@timestamp)[1]', 'DATETIME2') > DATEADD(HOUR, -@UltimasHoras, GETUTCDATE())
    ORDER BY event_data.value('(@timestamp)[1]', 'DATETIME2') DESC;
END
GO

PRINT '✅ SP_VerDeadlocksRecientes creado';
GO

-- ============================================================
-- PARTE 8: CAPTURAR ERRORES 404 Y OTROS ERRORES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 8: CAPTURAR ERRORES DE APLICACIÓN';
PRINT '============================================';

-- Eliminar sesión si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'CapturaErrores')
    DROP EVENT SESSION CapturaErrores ON SERVER;
GO

-- Crear sesión para capturar errores
CREATE EVENT SESSION CapturaErrores
ON SERVER
ADD EVENT sqlserver.error_reported (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_hostname,
        sqlserver.client_app_name,
        sqlserver.session_id
    )
    -- Capturar errores de severidad >= 11 (errores de usuario y sistema)
    WHERE severity >= 11
      AND sqlserver.database_name = N'BancoDB'
),
ADD EVENT sqlserver.user_event (
    -- Eventos personalizados que podemos disparar desde nuestro código
    ACTION (
        sqlserver.database_name,
        sqlserver.username
    )
)
ADD TARGET package0.ring_buffer (
    SET max_memory = 2048
),
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Errores_BancoDB.xel',
        max_file_size = 20,
        max_rollover_files = 5
)
WITH (
    MAX_MEMORY = 2048 KB,
    EVENT_RETENTION_MODE = NO_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 5 SECONDS,
    STARTUP_STATE = ON
);

GO

-- Iniciar la sesión
ALTER EVENT SESSION CapturaErrores ON SERVER STATE = START;
PRINT '✅ Sesión de captura de errores iniciada';
GO

-- SP para ver errores recientes
CREATE OR ALTER PROCEDURE SP_VerErroresRecientes
    @UltimasHoras INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    ;WITH ErrorData AS (
        SELECT 
            CAST(target_data AS XML) AS TargetData
        FROM sys.dm_xe_session_targets st
        INNER JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
        WHERE s.name = 'CapturaErrores'
          AND st.target_name = 'ring_buffer'
    )
    SELECT 
        event_data.value('(@timestamp)[1]', 'DATETIME2') AS FechaHora,
        event_data.value('(data[@name="error_number"]/value)[1]', 'INT') AS NumeroError,
        event_data.value('(data[@name="severity"]/value)[1]', 'INT') AS Severidad,
        event_data.value('(data[@name="message"]/value)[1]', 'NVARCHAR(MAX)') AS Mensaje,
        event_data.value('(action[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS BaseDatos,
        event_data.value('(action[@name="username"]/value)[1]', 'NVARCHAR(128)') AS Usuario,
        event_data.value('(action[@name="client_app_name"]/value)[1]', 'NVARCHAR(256)') AS Aplicacion,
        SUBSTRING(event_data.value('(action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)'), 1, 500) AS SQL_Text
    FROM ErrorData
    CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="error_reported"]') AS xed(event_data)
    WHERE event_data.value('(@timestamp)[1]', 'DATETIME2') > DATEADD(HOUR, -@UltimasHoras, GETUTCDATE())
    ORDER BY event_data.value('(@timestamp)[1]', 'DATETIME2') DESC;
END
GO

PRINT '✅ SP_VerErroresRecientes creado';
GO

-- ============================================================
-- PARTE 9: SESIÓN DE WAITS (ANÁLISIS DE ESPERAS)
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 9: ANÁLISIS DE ESPERAS (WAITS)';
PRINT '============================================';

-- Eliminar sesión si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'AnalisisWaits')
    DROP EVENT SESSION AnalisisWaits ON SERVER;
GO

-- Crear sesión para analizar esperas
CREATE EVENT SESSION AnalisisWaits
ON SERVER
ADD EVENT sqlos.wait_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.session_id
    )
    -- Solo esperas significativas (> 100ms)
    WHERE duration > 100000
      AND opcode = 1  -- Solo completed (no starting)
      -- Excluir waits de sistema que no son relevantes
      AND wait_type != 'WAITFOR'
      AND wait_type != 'LAZYWRITER_SLEEP'
      AND wait_type != 'CHECKPOINT_QUEUE'
),
ADD EVENT sqlos.wait_info (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name
    )
    WHERE duration > 100000
)
ADD TARGET package0.ring_buffer (
    SET max_memory = 4096
)
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_MULTIPLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    STARTUP_STATE = OFF
);

GO

PRINT '✅ Sesión AnalisisWaits creada';
GO

-- ============================================================
-- PARTE 10: ADMINISTRAR SESIONES DE XEVENTS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 10: ADMINISTRAR SESIONES';
PRINT '============================================';

-- Ver todas las sesiones de Extended Events
SELECT 
    s.name AS NombreSesion,
    CASE WHEN xs.name IS NOT NULL THEN 'EJECUTANDO' ELSE 'DETENIDA' END AS Estado,
    s.startup_state AS InicioAutomatico,
    s.event_retention_mode_desc AS ModoRetencion
FROM sys.server_event_sessions s
LEFT JOIN sys.dm_xe_sessions xs ON s.name = xs.name
ORDER BY s.name;

GO

-- Ver eventos configurados en cada sesión
SELECT 
    s.name AS Sesion,
    e.event_name AS Evento,
    e.event_predicate AS Filtro
FROM sys.server_event_sessions s
INNER JOIN sys.server_event_session_events e ON s.event_session_id = e.event_session_id
ORDER BY s.name, e.event_name;

GO

-- SP para gestionar sesiones rápidamente
CREATE OR ALTER PROCEDURE SP_GestionarXEventSession
    @NombreSesion NVARCHAR(128),
    @Accion VARCHAR(10)  -- 'START', 'STOP', 'DROP'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(500);
    
    IF @Accion = 'START'
    BEGIN
        SET @SQL = 'ALTER EVENT SESSION ' + QUOTENAME(@NombreSesion) + ' ON SERVER STATE = START;';
        EXEC sp_executesql @SQL;
        PRINT 'Sesión ' + @NombreSesion + ' iniciada.';
    END
    ELSE IF @Accion = 'STOP'
    BEGIN
        SET @SQL = 'ALTER EVENT SESSION ' + QUOTENAME(@NombreSesion) + ' ON SERVER STATE = STOP;';
        EXEC sp_executesql @SQL;
        PRINT 'Sesión ' + @NombreSesion + ' detenida.';
    END
    ELSE IF @Accion = 'DROP'
    BEGIN
        -- Primero detener si está ejecutando
        IF EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = @NombreSesion)
        BEGIN
            SET @SQL = 'ALTER EVENT SESSION ' + QUOTENAME(@NombreSesion) + ' ON SERVER STATE = STOP;';
            EXEC sp_executesql @SQL;
        END
        
        SET @SQL = 'DROP EVENT SESSION ' + QUOTENAME(@NombreSesion) + ' ON SERVER;';
        EXEC sp_executesql @SQL;
        PRINT 'Sesión ' + @NombreSesion + ' eliminada.';
    END
    ELSE
    BEGIN
        PRINT 'Acción no válida. Use: START, STOP o DROP';
    END
END
GO

PRINT '✅ SP_GestionarXEventSession creado';
GO

-- ============================================================
-- PARTE 11: PLANTILLA - SESIÓN PARA PRODUCCIÓN BANCARIA
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'PARTE 11: PLANTILLA PRODUCCIÓN BANCARIA';
PRINT '============================================';

-- Eliminar si existe
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'Monitor_CoreBancario')
    DROP EVENT SESSION Monitor_CoreBancario ON SERVER;
GO

-- Sesión completa para monitoreo de Core Bancario
CREATE EVENT SESSION Monitor_CoreBancario
ON SERVER

-- Evento 1: Consultas lentas (> 5 segundos)
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_hostname,
        sqlserver.client_app_name,
        sqlserver.query_hash,
        sqlserver.plan_handle
    )
    WHERE duration > 5000000  -- > 5 segundos
      AND sqlserver.database_name = N'BancoDB'
),

-- Evento 2: SPs completados (lentos)
ADD EVENT sqlserver.rpc_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_app_name
    )
    WHERE duration > 5000000
      AND sqlserver.database_name = N'BancoDB'
),

-- Evento 3: Deadlocks
ADD EVENT sqlserver.xml_deadlock_report (
    ACTION (
        sqlserver.database_name,
        sqlserver.username
    )
),

-- Evento 4: Timeouts de lock
ADD EVENT sqlserver.lock_timeout (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username
    )
    WHERE sqlserver.database_name = N'BancoDB'
),

-- Evento 5: Errores críticos (Severidad >= 16)
ADD EVENT sqlserver.error_reported (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.client_app_name
    )
    WHERE severity >= 16
      AND sqlserver.database_name = N'BancoDB'
),

-- Evento 6: Login fallidos
ADD EVENT sqlserver.login_failed (
    ACTION (
        sqlserver.client_hostname,
        sqlserver.client_app_name
    )
)

-- Targets: Ring buffer para consulta rápida + Archivo para histórico
ADD TARGET package0.ring_buffer (
    SET max_memory = 8192  -- 8 MB
),
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\CoreBancario_Monitor.xel',
        max_file_size = 100,      -- 100 MB por archivo
        max_rollover_files = 10   -- 1 GB total histórico
)
WITH (
    MAX_MEMORY = 8192 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 10 SECONDS,
    STARTUP_STATE = ON            -- Iniciar automáticamente con SQL Server
);

GO

PRINT '✅ Sesión Monitor_CoreBancario creada (plantilla producción)';
GO

-- ============================================================
-- RESUMEN EJECUTIVO
-- ============================================================
PRINT '';
PRINT '╔══════════════════════════════════════════════════════════════╗';
PRINT '║           RESUMEN - EXTENDED EVENTS (XEvents)                ║';
PRINT '╠══════════════════════════════════════════════════════════════╣';
PRINT '║                                                              ║';
PRINT '║  SESIONES CREADAS:                                           ║';
PRINT '║  • MonitorConsultasLentas → Ring buffer (memoria)            ║';
PRINT '║  • MonitorBancoDB_Archivo → Archivo .xel (disco)             ║';
PRINT '║  • CapturaDeadlocks       → Deadlocks + archivo              ║';
PRINT '║  • CapturaErrores         → Errores (severity >= 11)         ║';
PRINT '║  • AnalisisWaits          → Análisis de esperas              ║';
PRINT '║  • Monitor_CoreBancario   → Plantilla completa producción    ║';
PRINT '║                                                              ║';
PRINT '║  SPs DE UTILIDAD:                                            ║';
PRINT '║  • SP_VerDeadlocksRecientes(@UltimasHoras)                   ║';
PRINT '║  • SP_VerErroresRecientes(@UltimasHoras)                     ║';
PRINT '║  • SP_GestionarXEventSession(@Nombre, @Accion)               ║';
PRINT '║                                                              ║';
PRINT '║  EVENTOS MÁS ÚTILES:                                         ║';
PRINT '║  • sql_statement_completed → Consultas completadas           ║';
PRINT '║  • rpc_completed           → SPs desde aplicaciones          ║';
PRINT '║  • xml_deadlock_report     → Grafo de deadlock completo      ║';
PRINT '║  • error_reported          → Errores por severidad           ║';
PRINT '║  • wait_completed          → Análisis de esperas             ║';
PRINT '║                                                              ║';
PRINT '╚══════════════════════════════════════════════════════════════╝';
GO
