/***************************************************************
 * SESIÓN 14: SQL AGENT JOBS Y AUTOMATIZACIÓN
 * Curso: SQL Server Intermedio 2026
 * Semana 7 - Automatización de Tareas de Mantenimiento
 * 
 * Base de datos: BancoDB
 * 
 * CONTENIDO:
 *   1. Introducción al SQL Server Agent
 *   2. Creación de Jobs paso a paso
 *   3. Schedules (Programación)
 *   4. Steps y flujo de ejecución
 *   5. Operators y Notificaciones
 *   6. Alertas del sistema
 *   7. Jobs de mantenimiento bancario
 *   8. Monitoreo de Jobs
 *   9. Troubleshooting
 *  10. Mejores prácticas
 *
 * NOTA: Requiere permisos de sysadmin o SQLAgentOperatorRole
 ***************************************************************/

USE msdb;
GO

-- ============================================================
-- PARTE 1: INTRODUCCIÓN AL SQL SERVER AGENT
-- ============================================================
/*
   SQL Server Agent = Servicio de Windows para automatizar tareas
   
   COMPONENTES PRINCIPALES:
   ├── Jobs (Trabajos)
   │   ├── Steps (Pasos)
   │   └── Schedules (Horarios)
   ├── Operators (Destinatarios de notificaciones)
   ├── Alerts (Alertas ante eventos)
   └── Proxies (Credenciales para ejecutar)
   
   UBICACIÓN:
   - Base de datos: msdb
   - Tablas: sysjobs, sysjobsteps, sysjobschedules, etc.
   
   REQUISITOS:
   - Servicio SQL Server Agent debe estar ejecutándose
   - Permisos adecuados (SQLAgentUserRole, SQLAgentReaderRole, 
     SQLAgentOperatorRole o sysadmin)
*/

-- Verificar que SQL Server Agent está ejecutándose
SELECT 
    servicename,
    status_desc,
    startup_type_desc
FROM sys.dm_server_services
WHERE servicename LIKE '%Agent%';
GO

-- Ver jobs existentes
SELECT 
    j.job_id,
    j.name AS JobName,
    j.enabled,
    j.description,
    c.name AS Category,
    j.date_created,
    j.date_modified
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
ORDER BY j.name;
GO

-- ============================================================
-- PARTE 2: CREACIÓN DE JOBS - MÉTODO T-SQL
-- ============================================================
/*
   Procedimientos almacenados para gestionar jobs:
   
   sp_add_job              - Crear job
   sp_add_jobstep          - Agregar paso
   sp_add_jobschedule      - Agregar horario
   sp_add_jobserver        - Asignar servidor
   sp_update_job           - Modificar job
   sp_delete_job           - Eliminar job
   sp_start_job            - Ejecutar job manualmente
   sp_stop_job             - Detener job en ejecución
*/

-- ============================================================
-- EJEMPLO 1: Job de Backup Diario de BancoDB
-- ============================================================

-- Paso 1: Crear el Job
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Backup_Diario',
    @enabled = 1,
    @description = N'Realiza backup completo de BancoDB todos los días',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @notify_level_eventlog = 2,  -- En caso de fallo
    @notify_level_email = 0,
    @notify_level_page = 0,
    @delete_level = 0;  -- No eliminar nunca
GO

-- Paso 2: Agregar Step (la tarea específica)
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Backup_Diario',
    @step_name = N'Ejecutar Backup Completo',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @BackupPath NVARCHAR(500);
        DECLARE @BackupFile NVARCHAR(500);
        DECLARE @Fecha NVARCHAR(20);
        
        SET @Fecha = FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'');
        SET @BackupPath = ''C:\SQLBackups\'';
        SET @BackupFile = @BackupPath + ''BancoDB_Full_'' + @Fecha + ''.bak'';
        
        BACKUP DATABASE BancoDB 
        TO DISK = @BackupFile
        WITH COMPRESSION, 
             CHECKSUM,
             STATS = 10,
             NAME = ''BancoDB Full Backup'';
        
        -- Verificar integridad del backup
        RESTORE VERIFYONLY FROM DISK = @BackupFile;
        
        PRINT ''Backup completado: '' + @BackupFile;
    ',
    @database_name = N'master',
    @retry_attempts = 2,
    @retry_interval = 5,  -- minutos entre reintentos
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Paso 3: Agregar Schedule (horario)
EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Backup_Diario',
    @name = N'Diario_Medianoche',
    @enabled = 1,
    @freq_type = 4,           -- Diario
    @freq_interval = 1,       -- Cada 1 día
    @freq_subday_type = 1,    -- A hora específica
    @active_start_time = 0,   -- 00:00:00 (medianoche)
    @active_start_date = 20260101;
GO

-- Paso 4: Asignar al servidor local
EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Backup_Diario',
    @server_name = N'(LOCAL)';
GO

-- ============================================================
-- EJEMPLO 2: Job de Limpieza de Transacciones Antiguas
-- ============================================================

EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas',
    @enabled = 1,
    @description = N'Elimina transacciones con más de 5 años de antigüedad',
    @category_name = N'Database Maintenance';
GO

-- Step 1: Archivar antes de eliminar
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas',
    @step_name = N'Archivar Transacciones',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Crear tabla de archivo si no existe
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = ''TRANSACCIONES_ARCHIVO'')
        BEGIN
            SELECT * INTO TRANSACCIONES_ARCHIVO
            FROM TRANSACCIONES_BANCARIAS
            WHERE 1 = 0;  -- Solo estructura
        END;
        
        -- Archivar transacciones antiguas
        INSERT INTO TRANSACCIONES_ARCHIVO
        SELECT * FROM TRANSACCIONES_BANCARIAS
        WHERE FechaTransaccion < DATEADD(YEAR, -5, GETDATE())
          AND TransaccionID NOT IN (SELECT TransaccionID FROM TRANSACCIONES_ARCHIVO);
        
        PRINT ''Transacciones archivadas: '' + CAST(@@ROWCOUNT AS VARCHAR(10));
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;
GO

-- Step 2: Eliminar archivadas
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas',
    @step_name = N'Eliminar Archivadas',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        DECLARE @Eliminadas INT = 0;
        DECLARE @BatchSize INT = 10000;
        
        WHILE 1 = 1
        BEGIN
            DELETE TOP (@BatchSize) t
            FROM TRANSACCIONES_BANCARIAS t
            WHERE FechaTransaccion < DATEADD(YEAR, -5, GETDATE())
              AND EXISTS (SELECT 1 FROM TRANSACCIONES_ARCHIVO a 
                          WHERE a.TransaccionID = t.TransaccionID);
            
            SET @Eliminadas = @Eliminadas + @@ROWCOUNT;
            
            IF @@ROWCOUNT < @BatchSize
                BREAK;
            
            WAITFOR DELAY ''00:00:01'';  -- Pausa para no saturar
        END;
        
        PRINT ''Total eliminadas: '' + CAST(@Eliminadas AS VARCHAR(10));
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Una vez al mes, primer domingo a las 3 AM
EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas',
    @name = N'Mensual_PrimerDomingo',
    @enabled = 1,
    @freq_type = 32,          -- Mensual relativo
    @freq_interval = 1,       -- Domingo
    @freq_relative_interval = 1,  -- Primer
    @freq_recurrence_factor = 1,  -- Cada 1 mes
    @active_start_time = 30000;   -- 03:00:00
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas',
    @server_name = N'(LOCAL)';
GO

-- ============================================================
-- PARTE 3: TIPOS DE SCHEDULES (PROGRAMACIÓN)
-- ============================================================
/*
   @freq_type - Tipo de frecuencia:
   1  = Una vez
   4  = Diario
   8  = Semanal
   16 = Mensual (día específico)
   32 = Mensual relativo (ej: primer lunes)
   64 = Al inicio del SQL Agent
   128 = Cuando CPU idle
   
   @freq_subday_type - Subdivisión del día:
   1 = A hora específica
   2 = Cada X segundos
   4 = Cada X minutos
   8 = Cada X horas
   
   @freq_interval - Intervalo según freq_type:
   - Diario: cada cuántos días
   - Semanal: bitmap de días (1=Dom,2=Lun,4=Mar,8=Mie,16=Jue,32=Vie,64=Sab)
   - Mensual: día del mes (1-31)
   - Mensual relativo: 1-7 para día semana
*/

-- EJEMPLO: Schedule cada 30 minutos de 8 AM a 6 PM, Lunes a Viernes
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Cada_30min_Horario_Laboral',
    @enabled = 1,
    @freq_type = 8,              -- Semanal
    @freq_interval = 62,         -- Lun(2)+Mar(4)+Mie(8)+Jue(16)+Vie(32)=62
    @freq_subday_type = 4,       -- Cada X minutos
    @freq_subday_interval = 30,  -- 30 minutos
    @active_start_time = 80000,  -- 08:00:00
    @active_end_time = 180000;   -- 18:00:00
GO

-- EJEMPLO: Una sola vez
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Una_Vez_Migracion',
    @enabled = 1,
    @freq_type = 1,              -- Una vez
    @active_start_date = 20260501,
    @active_start_time = 220000; -- 22:00:00
GO

-- ============================================================
-- PARTE 4: JOBS CON MÚLTIPLES STEPS Y FLUJO DE CONTROL
-- ============================================================
/*
   @on_success_action / @on_fail_action:
   1 = Quit with success
   2 = Quit with failure
   3 = Go to next step
   4 = Go to specific step (usar @on_success_step_id/@on_fail_step_id)
*/

-- Job con flujo condicional
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @enabled = 1,
    @description = N'Proceso de cierre diario con validaciones';
GO

-- Step 1: Validar datos del día
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @step_name = N'1_Validar_Datos',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        DECLARE @ErrorCount INT;
        
        -- Verificar transacciones sin categorizar
        SELECT @ErrorCount = COUNT(*)
        FROM TRANSACCIONES_BANCARIAS
        WHERE FechaTransaccion = CAST(GETDATE() AS DATE)
          AND TipoTransaccion IS NULL;
        
        IF @ErrorCount > 0
        BEGIN
            RAISERROR(''Hay %d transacciones sin categorizar'', 16, 1, @ErrorCount);
        END;
        
        PRINT ''Validación completada OK'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,  -- Siguiente paso
    @on_fail_action = 4,     -- Ir a paso específico (paso de error)
    @on_fail_step_id = 4;    -- Ir al paso 4 (notificar error)
GO

-- Step 2: Calcular balances
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @step_name = N'2_Calcular_Balances',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Actualizar saldos de cuentas basado en transacciones del día
        UPDATE c
        SET Saldo = c.Saldo + ISNULL(t.NetoDia, 0)
        FROM CUENTAS c
        INNER JOIN (
            SELECT 
                CuentaID,
                SUM(CASE TipoTransaccion 
                    WHEN ''Deposito'' THEN Monto 
                    WHEN ''Retiro'' THEN -Monto 
                    ELSE 0 
                END) AS NetoDia
            FROM TRANSACCIONES_BANCARIAS
            WHERE FechaTransaccion = CAST(GETDATE() AS DATE)
            GROUP BY CuentaID
        ) t ON c.CuentaID = t.CuentaID;
        
        PRINT ''Balances actualizados: '' + CAST(@@ROWCOUNT AS VARCHAR(10));
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 4,
    @on_fail_step_id = 4;
GO

-- Step 3: Generar reporte
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @step_name = N'3_Generar_Reporte',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Guardar resumen del día
        INSERT INTO dbo.RESUMEN_DIARIO (Fecha, TotalTransacciones, MontoTotal, FechaGeneracion)
        SELECT 
            CAST(GETDATE() AS DATE),
            COUNT(*),
            SUM(Monto),
            GETDATE()
        FROM TRANSACCIONES_BANCARIAS
        WHERE FechaTransaccion = CAST(GETDATE() AS DATE);
        
        PRINT ''Reporte generado exitosamente'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,  -- Terminar con éxito
    @on_fail_action = 4,
    @on_fail_step_id = 4;
GO

-- Step 4: Notificar error (solo se ejecuta si hay fallo)
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @step_name = N'4_Notificar_Error',
    @step_id = 4,
    @subsystem = N'TSQL',
    @command = N'
        -- Registrar error en tabla de log
        INSERT INTO BancoDB.dbo.LOG_ERRORES_JOBS (JobName, FechaError, Mensaje)
        VALUES (''BancoDB_Proceso_Cierre_Diario'', GETDATE(), ''Error en proceso de cierre'');
        
        -- Aquí podría enviarse email con sp_send_dbmail
        PRINT ''Error registrado y notificado'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 2,  -- Terminar con fallo
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @name = N'Diario_11PM',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 230000;  -- 23:00:00
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Proceso_Cierre_Diario',
    @server_name = N'(LOCAL)';
GO

-- ============================================================
-- PARTE 5: OPERATORS (NOTIFICACIONES)
-- ============================================================
/*
   Operators = Destinatarios de notificaciones
   Pueden recibir: Email, Pager, Net send
   
   REQUISITO: Database Mail debe estar configurado
*/

-- Crear un Operator
EXEC msdb.dbo.sp_add_operator
    @name = N'DBA_Team',
    @enabled = 1,
    @email_address = N'dba@banco.com',
    @weekday_pager_start_time = 080000,
    @weekday_pager_end_time = 180000,
    @saturday_pager_start_time = 090000,
    @saturday_pager_end_time = 140000;
GO

-- Crear operador de emergencias 24/7
EXEC msdb.dbo.sp_add_operator
    @name = N'DBA_Emergencias',
    @enabled = 1,
    @email_address = N'dba-emergencias@banco.com';
GO

-- Asignar operador a un job existente
EXEC msdb.dbo.sp_update_job
    @job_name = N'BancoDB_Backup_Diario',
    @notify_level_email = 2,  -- En caso de fallo
    @notify_email_operator_name = N'DBA_Team';
GO

-- ============================================================
-- PARTE 6: ALERTAS DEL SISTEMA
-- ============================================================
/*
   Alertas = Respuestas automáticas a eventos
   Se disparan por:
   - Errores de SQL Server (severity, error number)
   - Condiciones de performance (contadores WMI)
   
   Acciones posibles:
   - Ejecutar un Job
   - Notificar a Operator
   - Ambas
*/

-- Alerta para errores de severidad alta (17-25)
EXEC msdb.dbo.sp_add_alert
    @name = N'Alerta_Error_Critico',
    @message_id = 0,
    @severity = 17,  -- 17-25 son críticos
    @enabled = 1,
    @delay_between_responses = 60,  -- segundos
    @include_event_description_in = 1,
    @notification_message = N'ERROR CRÍTICO en SQL Server - Revisar inmediatamente';
GO

-- Asignar notificación a la alerta
EXEC msdb.dbo.sp_add_notification
    @alert_name = N'Alerta_Error_Critico',
    @operator_name = N'DBA_Emergencias',
    @notification_method = 1;  -- 1=Email, 2=Pager, 4=NetSend
GO

-- Alerta para error específico (ej: 9002 - Transaction log full)
EXEC msdb.dbo.sp_add_alert
    @name = N'Alerta_Log_Lleno',
    @message_id = 9002,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 300,
    @notification_message = N'El log de transacciones está lleno - Acción requerida';
GO

EXEC msdb.dbo.sp_add_notification
    @alert_name = N'Alerta_Log_Lleno',
    @operator_name = N'DBA_Team',
    @notification_method = 1;
GO

-- Alerta que ejecuta un Job (auto-recovery)
EXEC msdb.dbo.sp_add_alert
    @name = N'Alerta_Espacio_Disco',
    @message_id = 0,
    @severity = 17,
    @enabled = 1,
    @delay_between_responses = 600,
    @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas';  -- Ejecutar limpieza
GO

-- ============================================================
-- PARTE 7: JOBS DE MANTENIMIENTO BANCARIO
-- ============================================================

-- Job: Actualizar estadísticas semanalmente
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Actualizar_Estadisticas',
    @enabled = 1,
    @description = N'Actualiza estadísticas de tablas principales de BancoDB';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Actualizar_Estadisticas',
    @step_name = N'Actualizar Stats',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Actualizar estadísticas de tablas principales
        UPDATE STATISTICS CLIENTES WITH FULLSCAN;
        UPDATE STATISTICS CUENTAS WITH FULLSCAN;
        UPDATE STATISTICS TRANSACCIONES_BANCARIAS WITH SAMPLE 50 PERCENT;
        
        PRINT ''Estadísticas actualizadas: '' + CONVERT(VARCHAR(20), GETDATE(), 120);
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Sábados a las 2 AM
EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Actualizar_Estadisticas',
    @name = N'Semanal_Sabado_2AM',
    @enabled = 1,
    @freq_type = 8,           -- Semanal
    @freq_interval = 64,      -- Sábado
    @freq_recurrence_factor = 1,
    @active_start_time = 20000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Actualizar_Estadisticas',
    @server_name = N'(LOCAL)';
GO

-- Job: Rebuild de índices mensual
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Rebuild_Indices',
    @enabled = 1,
    @description = N'Reorganiza o reconstruye índices fragmentados';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Rebuild_Indices',
    @step_name = N'Mantenimiento Indices',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        DECLARE @sql NVARCHAR(MAX);
        DECLARE @TableName NVARCHAR(256);
        DECLARE @IndexName NVARCHAR(256);
        DECLARE @Fragmentation FLOAT;
        
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT 
                OBJECT_NAME(ips.object_id) AS TableName,
                i.name AS IndexName,
                ips.avg_fragmentation_in_percent
            FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips
            INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
            WHERE ips.avg_fragmentation_in_percent > 10
              AND ips.page_count > 1000
              AND i.name IS NOT NULL
            ORDER BY ips.avg_fragmentation_in_percent DESC;
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @TableName, @IndexName, @Fragmentation;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Fragmentation > 30
            BEGIN
                SET @sql = ''ALTER INDEX '' + QUOTENAME(@IndexName) 
                         + '' ON '' + QUOTENAME(@TableName) + '' REBUILD WITH (ONLINE = ON)'';
                PRINT ''REBUILD: '' + @IndexName + '' ('' + CAST(@Fragmentation AS VARCHAR(10)) + ''%)'';
            END
            ELSE
            BEGIN
                SET @sql = ''ALTER INDEX '' + QUOTENAME(@IndexName) 
                         + '' ON '' + QUOTENAME(@TableName) + '' REORGANIZE'';
                PRINT ''REORGANIZE: '' + @IndexName + '' ('' + CAST(@Fragmentation AS VARCHAR(10)) + ''%)'';
            END;
            
            EXEC sp_executesql @sql;
            
            FETCH NEXT FROM cur INTO @TableName, @IndexName, @Fragmentation;
        END;
        
        CLOSE cur;
        DEALLOCATE cur;
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Primer domingo del mes a las 4 AM
EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Rebuild_Indices',
    @name = N'Mensual_PrimerDomingo_4AM',
    @enabled = 1,
    @freq_type = 32,
    @freq_interval = 1,
    @freq_relative_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 40000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Rebuild_Indices',
    @server_name = N'(LOCAL)';
GO

-- ============================================================
-- PARTE 8: MONITOREO DE JOBS
-- ============================================================

-- Ver historial de ejecución de jobs
SELECT 
    j.name AS JobName,
    h.step_name,
    h.run_status,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS StatusText,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE 'BancoDB%'
ORDER BY h.run_date DESC, h.run_time DESC;
GO

-- Ver jobs actualmente en ejecución
SELECT 
    j.name AS JobName,
    ja.start_execution_date,
    DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) AS MinutosEjecutando,
    ja.last_executed_step_id,
    js.step_name AS CurrentStep
FROM msdb.dbo.sysjobactivity ja
INNER JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
LEFT JOIN msdb.dbo.sysjobsteps js ON ja.job_id = js.job_id 
    AND ja.last_executed_step_id = js.step_id
WHERE ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions)
  AND ja.start_execution_date IS NOT NULL
  AND ja.stop_execution_date IS NULL;
GO

-- Resumen de jobs fallidos en las últimas 24 horas
SELECT 
    j.name AS JobName,
    COUNT(*) AS NumeroFallos,
    MAX(msdb.dbo.agent_datetime(h.run_date, h.run_time)) AS UltimoFallo
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE h.run_status = 0  -- Failed
  AND h.step_id = 0      -- Job outcome (no step)
  AND msdb.dbo.agent_datetime(h.run_date, h.run_time) > DATEADD(HOUR, -24, GETDATE())
GROUP BY j.name
ORDER BY NumeroFallos DESC;
GO

-- Procedimiento para monitoreo rápido
CREATE OR ALTER PROCEDURE sp_MonitorJobs
    @SoloFallidos BIT = 0,
    @Horas INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        j.name AS JobName,
        CASE h.run_status
            WHEN 0 THEN '❌ Failed'
            WHEN 1 THEN '✅ Success'
            WHEN 2 THEN '🔄 Retry'
            WHEN 3 THEN '⏹️ Canceled'
        END AS Status,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS FechaEjecucion,
        STUFF(STUFF(RIGHT('000000' + CAST(h.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS Duracion,
        h.message
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE h.step_id = 0  -- Solo resultado del job
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) > DATEADD(HOUR, -@Horas, GETDATE())
      AND (@SoloFallidos = 0 OR h.run_status = 0)
    ORDER BY h.run_date DESC, h.run_time DESC;
END;
GO

-- Ejecutar monitoreo
EXEC sp_MonitorJobs @Horas = 48;
EXEC sp_MonitorJobs @SoloFallidos = 1, @Horas = 168;  -- Última semana
GO

-- ============================================================
-- PARTE 9: TROUBLESHOOTING DE JOBS
-- ============================================================

-- Ver el mensaje de error del último fallo
SELECT TOP 1
    j.name AS JobName,
    h.step_name,
    h.message,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS FechaFallo
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name = 'BancoDB_Backup_Diario'
  AND h.run_status = 0
ORDER BY h.run_date DESC, h.run_time DESC;
GO

-- Ver próximas ejecuciones programadas
SELECT 
    j.name AS JobName,
    s.name AS ScheduleName,
    CASE s.freq_type
        WHEN 1 THEN 'Once'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly Relative'
        WHEN 64 THEN 'Agent Start'
        WHEN 128 THEN 'CPU Idle'
    END AS FrequencyType,
    js.next_run_date,
    js.next_run_time,
    msdb.dbo.agent_datetime(js.next_run_date, js.next_run_time) AS ProximaEjecucion
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
INNER JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.enabled = 1
  AND s.enabled = 1
  AND js.next_run_date > 0
ORDER BY js.next_run_date, js.next_run_time;
GO

-- Ejecutar job manualmente para testing
EXEC msdb.dbo.sp_start_job @job_name = 'BancoDB_Backup_Diario';
GO

-- Detener job si está corriendo demasiado tiempo
EXEC msdb.dbo.sp_stop_job @job_name = 'BancoDB_Backup_Diario';
GO

-- ============================================================
-- PARTE 10: MEJORES PRÁCTICAS
-- ============================================================
/*
   CHECKLIST DE JOBS:
   
   ✓ NAMING CONVENTION
     - Prefijo con nombre de BD: BancoDB_*
     - Descripción clara de la tarea
   
   ✓ MANEJO DE ERRORES
     - Configurar retry_attempts apropiados
     - Paso de notificación/log en caso de fallo
     - Alertas a operators para jobs críticos
   
   ✓ PROGRAMACIÓN
     - Evitar solapar jobs pesados
     - Considerar ventanas de baja actividad
     - No programar todo a medianoche
   
   ✓ MONITOREO
     - Revisar logs periódicamente
     - Dashboard de estado de jobs
     - Alertas proactivas
   
   ✓ DOCUMENTACIÓN
     - Descripción detallada en cada job
     - Documentar dependencias
     - Mantener runbook actualizado
*/

-- Crear tabla de documentación de jobs
USE BancoDB;
GO

CREATE TABLE dbo.JOBS_DOCUMENTACION (
    JobName NVARCHAR(128) PRIMARY KEY,
    Proposito NVARCHAR(MAX),
    Dependencias NVARCHAR(MAX),
    ContactoResponsable NVARCHAR(100),
    AccionSiFalla NVARCHAR(MAX),
    FechaUltimaRevision DATE,
    Notas NVARCHAR(MAX)
);
GO

INSERT INTO dbo.JOBS_DOCUMENTACION VALUES
('BancoDB_Backup_Diario', 
 'Backup completo de BancoDB para recuperación ante desastres',
 'Ninguna',
 'dba@banco.com',
 'Verificar espacio en disco. Revisar logs de SQL Server. Ejecutar manualmente.',
 '2026-01-15',
 'Los backups se retienen por 30 días'),
 
('BancoDB_Proceso_Cierre_Diario',
 'Cierre contable del día - Actualiza saldos y genera reportes',
 'Requiere que todas las transacciones del día estén procesadas',
 'operaciones@banco.com',
 'NO ejecutar manualmente sin validar. Contactar a operaciones primero.',
 '2026-01-15',
 'Crítico para conciliación bancaria');
GO

-- ============================================================
-- LIMPIEZA DE JOBS DE DEMO (Descomentar para ejecutar)
-- ============================================================
/*
-- Eliminar jobs de demo
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Backup_Diario';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Limpiar_Transacciones_Antiguas';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Proceso_Cierre_Diario';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Actualizar_Estadisticas';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Rebuild_Indices';

-- Eliminar operators
EXEC msdb.dbo.sp_delete_operator @name = N'DBA_Team';
EXEC msdb.dbo.sp_delete_operator @name = N'DBA_Emergencias';

-- Eliminar alertas
EXEC msdb.dbo.sp_delete_alert @name = N'Alerta_Error_Critico';
EXEC msdb.dbo.sp_delete_alert @name = N'Alerta_Log_Lleno';
EXEC msdb.dbo.sp_delete_alert @name = N'Alerta_Espacio_Disco';

-- Eliminar schedules huérfanos
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'Cada_30min_Horario_Laboral';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'Una_Vez_Migracion';
*/

-- ============================================================
-- RESUMEN DE LA SESIÓN
-- ============================================================
/*
   PUNTOS CLAVE:
   
   1. SQL Server Agent = Motor de automatización
      - Base de datos: msdb
      - Jobs, Steps, Schedules, Operators, Alerts
   
   2. Creación de Jobs:
      - sp_add_job → sp_add_jobstep → sp_add_jobschedule → sp_add_jobserver
      - Cada step puede tener flujo condicional
   
   3. Schedules:
      - freq_type: Diario(4), Semanal(8), Mensual(16,32)
      - Pueden ser reutilizables entre jobs
   
   4. Operators y Alertas:
      - Configurar Database Mail primero
      - Alertas automáticas por severidad o error específico
   
   5. Monitoreo:
      - sysjobhistory para historial
      - sysjobactivity para jobs en ejecución
      - sp_MonitorJobs para resumen rápido
   
   6. Mejores Prácticas:
      - Naming convention consistente
      - Documentación en descripción
      - Paso de notificación en fallos
      - Evitar solapar jobs pesados
*/

PRINT '✓ Sesión 14 completada: SQL Agent Jobs y Automatización';
GO
