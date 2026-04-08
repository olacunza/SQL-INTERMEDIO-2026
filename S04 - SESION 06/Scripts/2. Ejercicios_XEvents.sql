-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 6
-- EJERCICIOS PRÁCTICOS: EXTENDED EVENTS (XEvents)
-- Enfoque: Monitoreo Ligero en Producción
-- ============================================================

USE BancoDB;
GO

/*
╔══════════════════════════════════════════════════════════════╗
║              INSTRUCCIONES GENERALES                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Estos ejercicios te guiarán a través de escenarios reales   ║
║  de monitoreo con Extended Events.                           ║
║                                                              ║
║  ⚠️ REQUISITOS:                                               ║
║  • Permisos de ALTER SERVER STATE                            ║
║  • Acceso a carpeta C:\Temp (o cambiar rutas)                ║
║  • Base de datos BancoDB con las tablas de sesiones previas  ║
║                                                              ║
║  NIVELES:                                                    ║
║  🟢 Básico    - Ejercicios 1-2                               ║
║  🟡 Intermedio - Ejercicios 3-4                               ║
║  🔴 Avanzado  - Ejercicios 5-6                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- ============================================================
-- LIMPIEZA INICIAL - Eliminar sesiones anteriores
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name LIKE 'Ejercicio%')
BEGIN
    DECLARE @sql NVARCHAR(MAX) = '';
    SELECT @sql = @sql + 'DROP EVENT SESSION ' + QUOTENAME(name) + ' ON SERVER;' + CHAR(13)
    FROM sys.server_event_sessions WHERE name LIKE 'Ejercicio%';
    EXEC sp_executesql @sql;
    PRINT '✅ Sesiones de ejercicios anteriores eliminadas';
END
GO

-- ============================================================
-- EJERCICIO 1: MI PRIMERA SESIÓN DE XEVENTS 🟢
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 1: Crear Sesión Básica de Monitoreo               ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  OBJETIVO:                                                   ║
║  Crear una sesión que capture consultas que duren más de     ║
║  500 milisegundos en la base de datos BancoDB.               ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Evento: sqlserver.sql_statement_completed                 ║
║  • Acciones: sql_text, database_name, username               ║
║  • Filtro: duration > 500ms (500,000 microsegundos)          ║
║  • Target: ring_buffer (2048 KB)                             ║
║  • Nombre: Ejercicio1_ConsultasLentas                        ║
║                                                              ║
║  PASOS:                                                      ║
║  1. Crear la sesión                                          ║
║  2. Iniciarla                                                ║
║  3. Ejecutar consultas de prueba                             ║
║  4. Leer los datos capturados                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================

-- Paso 1: Crear la sesión
-- CREATE EVENT SESSION Ejercicio1_ConsultasLentas
-- ON SERVER
-- ADD EVENT sqlserver.sql_statement_completed (
--     ACTION (...)
--     WHERE ...
-- )
-- ADD TARGET package0.ring_buffer (...)
-- WITH (...);



-- Paso 2: Iniciar la sesión
-- ALTER EVENT SESSION ... STATE = START;



-- Paso 3: Ejecutar consultas de prueba
PRINT 'Ejecutando consultas de prueba...';
WAITFOR DELAY '00:00:01';  -- 1 segundo de delay
SELECT COUNT(*) FROM CLIENTES CROSS JOIN CUENTAS;
GO

-- Paso 4: Leer datos capturados
-- (Completar la consulta)
/*
;WITH XEventData AS (
    SELECT CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    INNER JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'Ejercicio1_ConsultasLentas'
)
SELECT ...
FROM XEventData
CROSS APPLY TargetData.nodes('RingBufferTarget/event') AS xed(event_data);
*/

GO

-- SOLUCIÓN EJERCICIO 1:
-- =====================
/*
CREATE EVENT SESSION Ejercicio1_ConsultasLentas
ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username
    )
    WHERE duration > 500000
      AND sqlserver.database_name = N'BancoDB'
)
ADD TARGET package0.ring_buffer (SET max_memory = 2048)
WITH (
    MAX_MEMORY = 2048 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    STARTUP_STATE = OFF
);

ALTER EVENT SESSION Ejercicio1_ConsultasLentas ON SERVER STATE = START;
*/


-- ============================================================
-- EJERCICIO 2: GUARDAR EN ARCHIVO 🟢
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 2: Sesión con Event File                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  OBJETIVO:                                                   ║
║  Modificar el ejercicio 1 para guardar en archivo .xel       ║
║  en lugar de ring_buffer.                                    ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Archivo: C:\Temp\Ejercicio2_Consultas.xel                 ║
║  • Tamaño máximo: 25 MB                                      ║
║  • Máximo 3 archivos de rollover                             ║
║  • Agregar acción: query_hash                                ║
║  • Nombre: Ejercicio2_ArchivoConsultas                       ║
║                                                              ║
║  BONUS:                                                      ║
║  • Escribir consulta para leer el archivo .xel               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================





-- SOLUCIÓN EJERCICIO 2:
-- =====================
/*
CREATE EVENT SESSION Ejercicio2_ArchivoConsultas
ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.username,
        sqlserver.query_hash
    )
    WHERE duration > 500000
      AND sqlserver.database_name = N'BancoDB'
)
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Ejercicio2_Consultas.xel',
        max_file_size = 25,
        max_rollover_files = 3
)
WITH (
    MAX_MEMORY = 2048 KB,
    STARTUP_STATE = OFF
);

-- Leer archivo:
SELECT 
    event_data.value('(@timestamp)[1]', 'datetime2') AS FechaHora,
    event_data.value('(data[@name="duration"]/value)[1]', 'bigint') / 1000 AS DuracionMS,
    event_data.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS SQL_Text
FROM sys.fn_xe_file_target_read_file('C:\Temp\Ejercicio2_Consultas*.xel', NULL, NULL, NULL) f
CROSS APPLY (SELECT CAST(event_data AS XML)) AS x(event_data);
*/


-- ============================================================
-- EJERCICIO 3: CAPTURAR ERRORES 🟡
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 3: Sesión para Capturar Errores                   ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  El equipo de soporte reporta errores intermitentes en la    ║
║  aplicación de transferencias. Necesitas capturar todos      ║
║  los errores de SQL Server para diagnóstico.                 ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Evento: sqlserver.error_reported                          ║
║  • Capturar: sql_text, database_name, username, hostname     ║
║  • Filtro: severity >= 11 (errores de usuario)               ║
║  • Targets: ring_buffer + event_file                         ║
║  • Nombre: Ejercicio3_CapturaErrores                         ║
║                                                              ║
║  PRUEBA:                                                     ║
║  Ejecutar consultas que generen errores y verificar captura  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================

-- Crear la sesión



-- Iniciar


-- Generar algunos errores de prueba
BEGIN TRY
    SELECT 1/0;  -- Error de división por cero
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    INSERT INTO CLIENTES (CLIENTEID, NOMBRE) VALUES (1, 'Test');  -- Violación PK
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH

GO

-- Leer errores capturados



-- SOLUCIÓN EJERCICIO 3:
-- =====================
/*
CREATE EVENT SESSION Ejercicio3_CapturaErrores
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
    WHERE severity >= 11
)
ADD TARGET package0.ring_buffer (SET max_memory = 2048),
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Ejercicio3_Errores.xel',
        max_file_size = 10,
        max_rollover_files = 3
)
WITH (
    MAX_MEMORY = 2048 KB,
    EVENT_RETENTION_MODE = NO_EVENT_LOSS,
    STARTUP_STATE = OFF
);

ALTER EVENT SESSION Ejercicio3_CapturaErrores ON SERVER STATE = START;
*/


-- ============================================================
-- EJERCICIO 4: MONITOREO DE LOGINS 🟡
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 4: Auditoría de Accesos                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  Seguridad requiere un registro de todos los intentos de     ║
║  login (exitosos y fallidos) a la base de datos BancoDB.      ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Eventos:                                                  ║
║    - sqlserver.login        (logins exitosos)                ║
║    - sqlserver.login_failed (logins fallidos)                ║
║  • Capturar: client_hostname, client_app_name, username      ║
║  • Target: event_file (retención 7 días mínimo)              ║
║  • STARTUP_STATE = ON (iniciar automáticamente)              ║
║  • Nombre: Ejercicio4_AuditoriaLogins                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================





-- SOLUCIÓN EJERCICIO 4:
-- =====================
/*
CREATE EVENT SESSION Ejercicio4_AuditoriaLogins
ON SERVER
ADD EVENT sqlserver.login (
    ACTION (
        sqlserver.client_hostname,
        sqlserver.client_app_name,
        sqlserver.username,
        sqlserver.database_name
    )
),
ADD EVENT sqlserver.login_failed (
    ACTION (
        sqlserver.client_hostname,
        sqlserver.client_app_name
    )
)
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Ejercicio4_Logins.xel',
        max_file_size = 50,
        max_rollover_files = 14  -- 14 archivos para ~7 días
)
WITH (
    MAX_MEMORY = 2048 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    STARTUP_STATE = ON
);
*/


-- ============================================================
-- EJERCICIO 5: CAPTURA DE DEADLOCKS 🔴
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 5: Sistema de Captura de Deadlocks                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  El sistema de transferencias reporta errores 1205 (deadlock)║
║  de forma esporádica. Necesitas capturar el grafo completo   ║
║  para análisis.                                              ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Eventos:                                                  ║
║    - sqlserver.xml_deadlock_report (grafo XML completo)      ║
║    - sqlserver.lock_deadlock                                 ║
║  • NO perder eventos (NO_EVENT_LOSS)                         ║
║  • Escribir inmediatamente (MAX_DISPATCH_LATENCY = 1s)       ║
║  • Target: event_file con rollover                           ║
║  • STARTUP_STATE = ON                                        ║
║  • Nombre: Ejercicio5_Deadlocks                              ║
║                                                              ║
║  BONUS:                                                      ║
║  Crear SP para extraer y mostrar los deadlocks recientes     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================

-- Crear sesión



-- Crear SP para ver deadlocks
-- CREATE OR ALTER PROCEDURE SP_Ejercicio5_VerDeadlocks...



-- SCRIPT PARA PROVOCAR UN DEADLOCK (ejecutar en 2 sesiones separadas):
/*
    -- SESIÓN A: (ejecutar primero)
    BEGIN TRANSACTION;
    UPDATE CUENTAS SET SALDO = SALDO + 1 WHERE CUENTAID = 1;
    WAITFOR DELAY '00:00:05';
    UPDATE CUENTAS SET SALDO = SALDO - 1 WHERE CUENTAID = 2;
    COMMIT;
    
    -- SESIÓN B: (ejecutar inmediatamente después de A)
    BEGIN TRANSACTION;
    UPDATE CUENTAS SET SALDO = SALDO + 1 WHERE CUENTAID = 2;
    WAITFOR DELAY '00:00:05';
    UPDATE CUENTAS SET SALDO = SALDO - 1 WHERE CUENTAID = 1;
    COMMIT;
*/

GO

-- SOLUCIÓN EJERCICIO 5:
-- =====================
/*
CREATE EVENT SESSION Ejercicio5_Deadlocks
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report (
    ACTION (
        sqlserver.database_name,
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
)
ADD TARGET package0.ring_buffer (SET max_memory = 4096),
ADD TARGET package0.event_file (
    SET filename = N'C:\Temp\Ejercicio5_Deadlocks.xel',
        max_file_size = 25,
        max_rollover_files = 10
)
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = NO_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 1 SECONDS,
    STARTUP_STATE = ON
);

ALTER EVENT SESSION Ejercicio5_Deadlocks ON SERVER STATE = START;

-- SP para ver deadlocks:
CREATE OR ALTER PROCEDURE SP_Ejercicio5_VerDeadlocks @Horas INT = 24
AS
BEGIN
    ;WITH DeadlockXML AS (
        SELECT CAST(target_data AS XML) AS Data
        FROM sys.dm_xe_session_targets t
        JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
        WHERE s.name = 'Ejercicio5_Deadlocks' AND t.target_name = 'ring_buffer'
    )
    SELECT 
        e.value('(@timestamp)[1]', 'datetime2') AS FechaHora,
        e.value('(data[@name="xml_report"]/value)[1]', 'nvarchar(max)') AS DeadlockGraph
    FROM DeadlockXML
    CROSS APPLY Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS x(e)
    WHERE e.value('(@timestamp)[1]', 'datetime2') > DATEADD(HOUR, -@Horas, GETUTCDATE());
END
*/


-- ============================================================
-- EJERCICIO 6: SESIÓN COMPLETA DE PRODUCCIÓN 🔴
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 6: Diseñar Sesión para Producción                 ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  Como DBA Senior, debes diseñar UNA sesión integral que      ║
║  monitoree todos los aspectos críticos del Core Bancario     ║
║  con el MÍNIMO overhead posible.                             ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║                                                              ║
║  1. CONSULTAS LENTAS (> 3 segundos):                         ║
║     - sql_statement_completed                                ║
║     - rpc_completed                                          ║
║                                                              ║
║  2. DEADLOCKS:                                               ║
║     - xml_deadlock_report                                    ║
║                                                              ║
║  3. ERRORES CRÍTICOS (severity >= 16):                       ║
║     - error_reported                                         ║
║                                                              ║
║  4. LOGINS FALLIDOS:                                         ║
║     - login_failed                                           ║
║                                                              ║
║  CONFIGURACIÓN:                                              ║
║  • Targets: ring_buffer (8 MB) + event_file (500 MB total)   ║
║  • STARTUP_STATE = ON                                        ║
║  • Nombre: Ejercicio6_MonitorProduccion                      ║
║                                                              ║
║  ENTREGABLE:                                                 ║
║  • Script completo de la sesión                              ║
║  • SP para consultar cada tipo de evento                     ║
║  • Documentación de impacto estimado                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================

-- Crear la sesión completa



-- SP para ver consultas lentas
-- CREATE OR ALTER PROCEDURE SP_Ej6_ConsultasLentas...



-- SP para ver errores
-- CREATE OR ALTER PROCEDURE SP_Ej6_Errores...



-- SP para ver logins fallidos
-- CREATE OR ALTER PROCEDURE SP_Ej6_LoginsFallidos...



-- DOCUMENTACIÓN:
/*
╔════════════════════════════════════════════════════════════════════╗
║  DOCUMENTACIÓN - SESIÓN: Ejercicio6_MonitorProduccion              ║
╠════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  EVENTOS MONITOREADOS:                                             ║
║  ──────────────────────                                            ║
║  1. ________________________________                               ║
║  2. ________________________________                               ║
║  3. ________________________________                               ║
║  4. ________________________________                               ║
║                                                                    ║
║  FILTROS APLICADOS:                                                ║
║  ──────────────────                                                ║
║  • _______________________________________                         ║
║  • _______________________________________                         ║
║                                                                    ║
║  IMPACTO ESTIMADO EN PRODUCCIÓN:                                   ║
║  ────────────────────────────────                                  ║
║  • CPU: ____% adicional                                            ║
║  • Memoria: ____ MB                                                ║
║  • I/O: ____ MB/hora aproximadamente                               ║
║                                                                    ║
║  RETENCIÓN DE DATOS:                                               ║
║  ───────────────────                                               ║
║  • Ring buffer: _____ eventos aprox.                               ║
║  • Archivos: _____ días de histórico                               ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
*/


-- ============================================================
-- EJERCICIO BONUS: DASHBOARD DE MONITOREO
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO BONUS: SP Dashboard de Salud                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Crear un SP que muestre un "dashboard" con:                 ║
║                                                              ║
║  1. Sesiones de XEvents activas                              ║
║  2. Últimos 5 errores (últimas 2 horas)                      ║
║  3. Últimas 5 consultas lentas (últimas 2 horas)             ║
║  4. Cantidad de deadlocks (últimas 24 horas)                 ║
║  5. Logins fallidos (últimas 24 horas)                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

CREATE OR ALTER PROCEDURE SP_DashboardXEvents
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '╔══════════════════════════════════════════════════════════════╗';
    PRINT '║        DASHBOARD DE MONITOREO - EXTENDED EVENTS             ║';
    PRINT '║        Generado: ' + CONVERT(VARCHAR(20), GETDATE(), 120) + '                  ║';
    PRINT '╚══════════════════════════════════════════════════════════════╝';
    PRINT '';
    
    -- 1. Sesiones activas
    PRINT '▶ SESIONES DE XEVENTS ACTIVAS:';
    PRINT '────────────────────────────────';
    
    SELECT 
        s.name AS Sesion,
        CASE WHEN xs.name IS NOT NULL THEN '🟢 RUNNING' ELSE '🔴 STOPPED' END AS Estado,
        s.startup_state AS AutoStart
    FROM sys.server_event_sessions s
    LEFT JOIN sys.dm_xe_sessions xs ON s.name = xs.name
    WHERE s.name NOT LIKE 'system%'
    ORDER BY s.name;
    
    -- 2. Conteo de eventos por sesión (si hay ring_buffers)
    PRINT '';
    PRINT '▶ EVENTOS EN RING BUFFER:';
    PRINT '──────────────────────────';
    
    SELECT 
        s.name AS Sesion,
        t.target_name AS Target,
        CAST(t.target_data AS XML).value('(RingBufferTarget/@eventCount)[1]', 'int') AS EventosCapturados
    FROM sys.dm_xe_session_targets t
    INNER JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
    WHERE t.target_name = 'ring_buffer';
    
    PRINT '';
    PRINT '════════════════════════════════════════════════════════════════';
END
GO

PRINT '✅ SP_DashboardXEvents creado';
GO

-- Ejecutar el dashboard
EXEC SP_DashboardXEvents;
GO

-- ============================================================
-- LIMPIEZA FINAL
-- ============================================================

-- Script para detener y eliminar todas las sesiones de ejercicios
CREATE OR ALTER PROCEDURE SP_LimpiarSesionesEjercicios
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX) = '';
    DECLARE @nombre NVARCHAR(128);
    
    -- Primero detener las que están ejecutando
    DECLARE curSesiones CURSOR FOR
        SELECT s.name
        FROM sys.server_event_sessions s
        INNER JOIN sys.dm_xe_sessions xs ON s.name = xs.name
        WHERE s.name LIKE 'Ejercicio%' OR s.name LIKE 'Monitor%';
    
    OPEN curSesiones;
    FETCH NEXT FROM curSesiones INTO @nombre;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = 'ALTER EVENT SESSION ' + QUOTENAME(@nombre) + ' ON SERVER STATE = STOP;';
        BEGIN TRY
            EXEC sp_executesql @sql;
            PRINT 'Sesión ' + @nombre + ' detenida.';
        END TRY
        BEGIN CATCH
            PRINT 'Error deteniendo ' + @nombre + ': ' + ERROR_MESSAGE();
        END CATCH
        FETCH NEXT FROM curSesiones INTO @nombre;
    END
    
    CLOSE curSesiones;
    DEALLOCATE curSesiones;
    
    -- Luego eliminar
    DECLARE curEliminar CURSOR FOR
        SELECT name FROM sys.server_event_sessions
        WHERE name LIKE 'Ejercicio%';
    
    OPEN curEliminar;
    FETCH NEXT FROM curEliminar INTO @nombre;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = 'DROP EVENT SESSION ' + QUOTENAME(@nombre) + ' ON SERVER;';
        BEGIN TRY
            EXEC sp_executesql @sql;
            PRINT 'Sesión ' + @nombre + ' eliminada.';
        END TRY
        BEGIN CATCH
            PRINT 'Error eliminando ' + @nombre + ': ' + ERROR_MESSAGE();
        END CATCH
        FETCH NEXT FROM curEliminar INTO @nombre;
    END
    
    CLOSE curEliminar;
    DEALLOCATE curEliminar;
    
    PRINT '';
    PRINT '✅ Limpieza completada.';
END
GO

-- Ejecutar limpieza (descomentar cuando sea necesario)
-- EXEC SP_LimpiarSesionesEjercicios;


-- ============================================================
PRINT '';
PRINT '╔══════════════════════════════════════════════════════════════╗';
PRINT '║         EJERCICIOS COMPLETADOS - SESIÓN 6                    ║';
PRINT '╠══════════════════════════════════════════════════════════════╣';
PRINT '║                                                              ║';
PRINT '║  APRENDISTE:                                                 ║';
PRINT '║  ✓ Crear sesiones de Extended Events                         ║';
PRINT '║  ✓ Configurar eventos, acciones y predicados                 ║';
PRINT '║  ✓ Usar ring_buffer para diagnóstico rápido                  ║';
PRINT '║  ✓ Usar event_file para histórico                            ║';
PRINT '║  ✓ Capturar deadlocks con grafo XML completo                 ║';
PRINT '║  ✓ Diseñar sesiones de producción con bajo overhead          ║';
PRINT '║                                                              ║';
PRINT '║  PRÓXIMA SESIÓN:                                             ║';
PRINT '║  Execution Plans I - Index Scan vs Index Seek                ║';
PRINT '║                                                              ║';
PRINT '╚══════════════════════════════════════════════════════════════╝';
GO
