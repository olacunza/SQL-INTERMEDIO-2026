/***************************************************************
 * EJERCICIOS - SESIÓN 14: SQL AGENT JOBS Y AUTOMATIZACIÓN
 * Curso: SQL Server Intermedio 2026
 * 
 * Base de datos: BancoDB + msdb
 * 
 * INSTRUCCIONES:
 * - Completar cada ejercicio según las especificaciones
 * - Usar los procedimientos sp_add_job, sp_add_jobstep, etc.
 * - Considerar manejo de errores y notificaciones
 * - Las soluciones están al final del archivo
 *
 * NOTA: Requiere permisos de sysadmin o SQLAgentOperatorRole
 ***************************************************************/

USE msdb;
GO

-- ============================================================
-- EJERCICIO 1: JOB DE BACKUP DIFERENCIAL
-- ============================================================
/*
   OBJETIVO: Crear un job que realice backup diferencial de BancoDB
   
   REQUISITOS:
   - Nombre: BancoDB_Backup_Diferencial
   - Descripción apropiada
   - El archivo debe incluir fecha/hora en el nombre
   - Ruta: C:\SQLBackups\
   - Schedule: Cada 4 horas, de Lunes a Viernes
   - Reintentar 1 vez si falla, esperando 5 minutos
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 2: JOB CON MÚLTIPLES STEPS
-- ============================================================
/*
   OBJETIVO: Crear un job de verificación de integridad
   
   REQUISITOS:
   - Nombre: BancoDB_Verificar_Integridad
   - Step 1: DBCC CHECKDB en BancoDB
   - Step 2: Si Step 1 OK, registrar en tabla de log
   - Step 3: Si Step 1 FALLA, ejecutar un paso de notificación
   - Schedule: Cada domingo a las 5 AM
   - Flujo: Success → Step 2, Fail → Step 3
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 3: JOB DE MONITOREO DE ESPACIO
-- ============================================================
/*
   OBJETIVO: Job que monitorea espacio en disco y alerta si < 20%
   
   REQUISITOS:
   - Nombre: Monitor_Espacio_Disco
   - Verificar espacio libre en todas las unidades
   - Si alguna unidad tiene menos de 20% libre:
     - Registrar en tabla LOG_ALERTAS
     - Intentar limpieza de backups antiguos (> 30 días)
   - Schedule: Cada 2 horas, todos los días
   - Crear la tabla LOG_ALERTAS si no existe
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 4: SCHEDULE COMPLEJO
-- ============================================================
/*
   OBJETIVO: Crear un schedule reutilizable para horario laboral
   
   REQUISITOS:
   - Nombre: Horario_Laboral_Cada_15min
   - Ejecutar cada 15 minutos
   - Solo de 8 AM a 6 PM
   - Solo Lunes a Viernes
   - Este schedule será usado por múltiples jobs
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 5: OPERATOR Y ALERTAS
-- ============================================================
/*
   OBJETIVO: Configurar sistema de notificaciones
   
   REQUISITOS:
   - Crear Operator: "Equipo_Operaciones" con email operaciones@banco.com
   - Crear Alerta para error de deadlock (error 1205)
   - La alerta debe notificar al operator
   - Crear Alerta para severidad 19+ (errores fatales)
   - Ambas alertas deben estar habilitadas
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 6: JOB DE LIMPIEZA DE LOGS
-- ============================================================
/*
   OBJETIVO: Limpiar datos antiguos de varias tablas de log
   
   REQUISITOS:
   - Nombre: BancoDB_Limpiar_Logs
   - Step 1: Limpiar LOG_ERRORES_JOBS > 90 días
   - Step 2: Limpiar LOG_ALERTAS > 180 días  
   - Step 3: Shrink del log de transacciones si > 1GB
   - Cada step debe continuar al siguiente independiente del resultado
   - Step 4 final: Registrar que la limpieza se completó
   - Schedule: Primer día de cada mes a las 2 AM
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 7: CONSULTA DE HISTORIAL
-- ============================================================
/*
   OBJETIVO: Crear procedimiento para consultar historial de jobs
   
   REQUISITOS:
   - Nombre: sp_HistorialJobs
   - Parámetros:
     - @JobName (opcional): filtrar por nombre (parcial)
     - @Estado: 'Todos', 'Exito', 'Fallo', 'EnProgreso'
     - @Dias: últimos X días (default 7)
   - Mostrar: JobName, Status, FechaEjecucion, Duracion, Mensaje
   - Ordenar por fecha descendente
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE sp_HistorialJobs
    @JobName NVARCHAR(128) = NULL,
    @Estado NVARCHAR(20) = 'Todos',
    @Dias INT = 7
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 8: JOB CON DEPENDENCIA DE OTRO JOB
-- ============================================================
/*
   OBJETIVO: Crear un job que solo se ejecute si otro terminó OK
   
   ESCENARIO:
   - Job "BancoDB_ETL_Carga" solo debe ejecutarse si 
     "BancoDB_Backup_Diario" terminó exitosamente hoy
   
   REQUISITOS:
   - Nombre: BancoDB_ETL_Carga
   - Step 1: Verificar que backup de hoy existe y fue exitoso
   - Step 2: Si OK, ejecutar la carga de datos
   - Step 3: Si backup no existe/falló, terminar con error
   - Schedule: Diario a las 1 AM (después del backup de medianoche)
*/

-- Tu código aquí:


-- ============================================================
-- EJERCICIO 9: DASHBOARD DE JOBS
-- ============================================================
/*
   OBJETIVO: Crear vista o procedimiento para dashboard de jobs
   
   REQUISITOS:
   - Mostrar todos los jobs de BancoDB
   - Estado actual: Habilitado/Deshabilitado
   - Última ejecución y resultado
   - Próxima ejecución programada
   - Promedio de duración de las últimas 5 ejecuciones
   - % de éxito en el último mes
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE sp_DashboardJobs
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 10: JOB DE PROCESO BATCH NOCTURNO
-- ============================================================
/*
   OBJETIVO: Crear el job más completo del curso
   
   ESCENARIO: Proceso batch nocturno del banco
   
   REQUISITOS:
   - Nombre: BancoDB_Proceso_Batch_Nocturno
   - Step 1: Validar que no hay transacciones pendientes
   - Step 2: Calcular intereses diarios para cuentas de ahorro
   - Step 3: Detectar y marcar cuentas con saldo negativo > 30 días
   - Step 4: Generar reporte de actividad sospechosa
   - Step 5: Backup de log de transacciones
   - Step 6: Enviar resumen por email (simular con PRINT)
   
   FLUJO:
   - Step 1 falla → Step 6 (notificar y terminar)
   - Steps 2-5 continúan independiente de resultado parcial
   - Step 6 siempre se ejecuta al final
   
   SCHEDULE: Diario a las 2 AM
   NOTIFICACIÓN: Operator "Equipo_Operaciones" en caso de fallo
*/

-- Tu código aquí:


-- ============================================================
-- ============================================================
--                    SOLUCIONES
-- ============================================================
-- ============================================================

-- ============================================================
-- SOLUCIÓN EJERCICIO 1
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Backup_Diferencial_Sol',
    @enabled = 1,
    @description = N'Backup diferencial de BancoDB cada 4 horas en días laborales',
    @category_name = N'Database Maintenance';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Backup_Diferencial_Sol',
    @step_name = N'Ejecutar Backup Diferencial',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @BackupFile NVARCHAR(500);
        SET @BackupFile = ''C:\SQLBackups\BancoDB_Diff_'' 
                        + FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'') + ''.bak'';
        
        BACKUP DATABASE BancoDB 
        TO DISK = @BackupFile
        WITH DIFFERENTIAL, COMPRESSION, STATS = 10;
        
        PRINT ''Backup diferencial completado: '' + @BackupFile;
    ',
    @database_name = N'master',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Backup_Diferencial_Sol',
    @name = N'Cada_4h_LunVie',
    @enabled = 1,
    @freq_type = 8,              -- Semanal
    @freq_interval = 62,         -- Lun-Vie
    @freq_subday_type = 8,       -- Cada X horas
    @freq_subday_interval = 4,   -- 4 horas
    @active_start_time = 0;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Backup_Diferencial_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 2
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @enabled = 1,
    @description = N'Verificación semanal de integridad de BancoDB';
GO

-- Step 1: DBCC CHECKDB
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @step_name = N'1_CHECKDB',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'DBCC CHECKDB (BancoDB) WITH NO_INFOMSGS, ALL_ERRORMSGS;',
    @database_name = N'master',
    @on_success_action = 3,  -- Next step
    @on_success_step_id = 2,
    @on_fail_action = 4,     -- Go to step
    @on_fail_step_id = 3;
GO

-- Step 2: Registrar éxito
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @step_name = N'2_Registrar_Exito',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = ''LOG_INTEGRIDAD'')
            CREATE TABLE BancoDB.dbo.LOG_INTEGRIDAD (ID INT IDENTITY, Fecha DATETIME, Resultado VARCHAR(20), Mensaje VARCHAR(500));
        
        INSERT INTO BancoDB.dbo.LOG_INTEGRIDAD VALUES (GETDATE(), ''OK'', ''CHECKDB completado sin errores'');
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 1;
GO

-- Step 3: Notificar fallo
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @step_name = N'3_Notificar_Fallo',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = ''LOG_INTEGRIDAD'')
            CREATE TABLE BancoDB.dbo.LOG_INTEGRIDAD (ID INT IDENTITY, Fecha DATETIME, Resultado VARCHAR(20), Mensaje VARCHAR(500));
        
        INSERT INTO BancoDB.dbo.LOG_INTEGRIDAD VALUES (GETDATE(), ''ERROR'', ''CHECKDB detectó errores - Revisar inmediatamente'');
        
        PRINT ''ALERTA: Error de integridad detectado en BancoDB'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 2,  -- Quit with failure
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @name = N'Domingo_5AM',
    @enabled = 1,
    @freq_type = 8,
    @freq_interval = 1,  -- Domingo
    @freq_recurrence_factor = 1,
    @active_start_time = 50000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Verificar_Integridad_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 3
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'Monitor_Espacio_Disco_Sol',
    @enabled = 1,
    @description = N'Monitorea espacio en disco y alerta si < 20%';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Monitor_Espacio_Disco_Sol',
    @step_name = N'Verificar_Espacio',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        -- Crear tabla de alertas si no existe
        IF NOT EXISTS (SELECT 1 FROM BancoDB.sys.tables WHERE name = ''LOG_ALERTAS'')
        BEGIN
            CREATE TABLE BancoDB.dbo.LOG_ALERTAS (
                AlertaID INT IDENTITY PRIMARY KEY,
                FechaAlerta DATETIME DEFAULT GETDATE(),
                TipoAlerta VARCHAR(50),
                Detalle VARCHAR(500)
            );
        END;
        
        -- Verificar espacio
        DECLARE @Unidad CHAR(1);
        DECLARE @PctLibre DECIMAL(5,2);
        
        DECLARE cur CURSOR FOR
            SELECT DISTINCT LEFT(physical_name, 1), 
                   CAST(100.0 * (SELECT available_bytes FROM sys.dm_os_volume_stats(database_id, file_id)) /
                        (SELECT total_bytes FROM sys.dm_os_volume_stats(database_id, file_id)) AS DECIMAL(5,2))
            FROM sys.master_files;
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @Unidad, @PctLibre;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @PctLibre < 20
            BEGIN
                INSERT INTO BancoDB.dbo.LOG_ALERTAS (TipoAlerta, Detalle)
                VALUES (''ESPACIO_DISCO'', 
                        ''Unidad '' + @Unidad + '': tiene solo '' + CAST(@PctLibre AS VARCHAR(10)) + ''% libre'');
                
                PRINT ''ALERTA: Unidad '' + @Unidad + '' con '' + CAST(@PctLibre AS VARCHAR(10)) + ''% libre'';
            END;
            
            FETCH NEXT FROM cur INTO @Unidad, @PctLibre;
        END;
        
        CLOSE cur;
        DEALLOCATE cur;
    ',
    @database_name = N'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'Monitor_Espacio_Disco_Sol',
    @name = N'Cada_2h',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 2;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Monitor_Espacio_Disco_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 4
-- ============================================================
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Horario_Laboral_Cada_15min_Sol',
    @enabled = 1,
    @freq_type = 8,              -- Semanal
    @freq_interval = 62,         -- Lun(2)+Mar(4)+Mie(8)+Jue(16)+Vie(32)
    @freq_subday_type = 4,       -- Cada X minutos
    @freq_subday_interval = 15,  -- 15 minutos
    @active_start_time = 80000,  -- 08:00:00
    @active_end_time = 180000;   -- 18:00:00
GO

-- Para adjuntar a un job existente:
-- EXEC msdb.dbo.sp_attach_schedule @job_name = 'MiJob', @schedule_name = 'Horario_Laboral_Cada_15min_Sol';


-- ============================================================
-- SOLUCIÓN EJERCICIO 5
-- ============================================================
-- Crear Operator
EXEC msdb.dbo.sp_add_operator
    @name = N'Equipo_Operaciones_Sol',
    @enabled = 1,
    @email_address = N'operaciones@banco.com';
GO

-- Alerta para deadlock
EXEC msdb.dbo.sp_add_alert
    @name = N'Alerta_Deadlock_Sol',
    @message_id = 1205,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 60,
    @notification_message = N'Se detectó un deadlock en la base de datos';
GO

EXEC msdb.dbo.sp_add_notification
    @alert_name = N'Alerta_Deadlock_Sol',
    @operator_name = N'Equipo_Operaciones_Sol',
    @notification_method = 1;
GO

-- Alerta para severidad 19+
EXEC msdb.dbo.sp_add_alert
    @name = N'Alerta_Error_Fatal_Sol',
    @message_id = 0,
    @severity = 19,
    @enabled = 1,
    @delay_between_responses = 60,
    @notification_message = N'Error fatal detectado - Revisar inmediatamente';
GO

EXEC msdb.dbo.sp_add_notification
    @alert_name = N'Alerta_Error_Fatal_Sol',
    @operator_name = N'Equipo_Operaciones_Sol',
    @notification_method = 1;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 6
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @enabled = 1,
    @description = N'Limpieza mensual de tablas de log';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @step_name = N'1_Limpiar_ErroresJobs',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        IF EXISTS (SELECT 1 FROM BancoDB.sys.tables WHERE name = ''LOG_ERRORES_JOBS'')
            DELETE FROM BancoDB.dbo.LOG_ERRORES_JOBS WHERE FechaError < DATEADD(DAY, -90, GETDATE());
        PRINT ''Step 1: LOG_ERRORES_JOBS limpiado'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;  -- Continuar aunque falle
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @step_name = N'2_Limpiar_Alertas',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        IF EXISTS (SELECT 1 FROM BancoDB.sys.tables WHERE name = ''LOG_ALERTAS'')
            DELETE FROM BancoDB.dbo.LOG_ALERTAS WHERE FechaAlerta < DATEADD(DAY, -180, GETDATE());
        PRINT ''Step 2: LOG_ALERTAS limpiado'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @step_name = N'3_Shrink_Log',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @LogSizeMB INT;
        SELECT @LogSizeMB = size * 8 / 1024 
        FROM BancoDB.sys.database_files WHERE type = 1;
        
        IF @LogSizeMB > 1024
        BEGIN
            DBCC SHRINKFILE (BancoDB_log, 500);
            PRINT ''Log reducido de '' + CAST(@LogSizeMB AS VARCHAR(10)) + '' MB'';
        END
        ELSE
            PRINT ''Log size OK: '' + CAST(@LogSizeMB AS VARCHAR(10)) + '' MB'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @step_name = N'4_Registrar_Completado',
    @step_id = 4,
    @subsystem = N'TSQL',
    @command = N'
        PRINT ''Limpieza de logs completada: '' + CONVERT(VARCHAR(20), GETDATE(), 120);
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 1;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @name = N'Mensual_Dia1_2AM',
    @enabled = 1,
    @freq_type = 16,         -- Mensual día específico
    @freq_interval = 1,      -- Día 1
    @freq_recurrence_factor = 1,
    @active_start_time = 20000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Limpiar_Logs_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 7
-- ============================================================
CREATE OR ALTER PROCEDURE sp_HistorialJobs_Solucion
    @JobName NVARCHAR(128) = NULL,
    @Estado NVARCHAR(20) = 'Todos',
    @Dias INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        j.name AS JobName,
        CASE h.run_status
            WHEN 0 THEN 'Fallo'
            WHEN 1 THEN 'Exito'
            WHEN 2 THEN 'Reintento'
            WHEN 3 THEN 'Cancelado'
            WHEN 4 THEN 'EnProgreso'
        END AS Status,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS FechaEjecucion,
        STUFF(STUFF(RIGHT('000000' + CAST(h.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS Duracion,
        LEFT(h.message, 200) AS Mensaje
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE h.step_id = 0  -- Solo outcome del job
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) > DATEADD(DAY, -@Dias, GETDATE())
      AND (@JobName IS NULL OR j.name LIKE '%' + @JobName + '%')
      AND (@Estado = 'Todos' 
           OR (@Estado = 'Exito' AND h.run_status = 1)
           OR (@Estado = 'Fallo' AND h.run_status = 0)
           OR (@Estado = 'EnProgreso' AND h.run_status = 4))
    ORDER BY h.run_date DESC, h.run_time DESC;
END;
GO

-- Test
EXEC sp_HistorialJobs_Solucion @Dias = 30;
EXEC sp_HistorialJobs_Solucion @Estado = 'Fallo', @Dias = 7;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 8
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @enabled = 1,
    @description = N'ETL que solo se ejecuta si el backup del día fue exitoso';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @step_name = N'1_Verificar_Backup',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @BackupExitoso BIT = 0;
        
        -- Verificar si backup de hoy fue exitoso
        SELECT @BackupExitoso = 1
        FROM msdb.dbo.sysjobhistory h
        INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
        WHERE j.name = ''BancoDB_Backup_Diario''
          AND h.step_id = 0
          AND h.run_status = 1
          AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= CAST(GETDATE() AS DATE);
        
        IF @BackupExitoso = 0
        BEGIN
            RAISERROR(''El backup de hoy no existe o falló. ETL cancelado.'', 16, 1);
        END;
        
        PRINT ''Backup verificado OK - Procediendo con ETL'';
    ',
    @database_name = N'msdb',
    @on_success_action = 3,
    @on_fail_action = 4,
    @on_fail_step_id = 3;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @step_name = N'2_Ejecutar_Carga',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Aquí iría la lógica de ETL
        PRINT ''Ejecutando carga de datos...'';
        PRINT ''ETL completado exitosamente'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @step_name = N'3_Error_No_Backup',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'
        PRINT ''ERROR: ETL no ejecutado porque el backup no está disponible'';
    ',
    @database_name = N'master',
    @on_success_action = 2,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @name = N'Diario_1AM',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 10000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_ETL_Carga_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 9
-- ============================================================
CREATE OR ALTER PROCEDURE sp_DashboardJobs_Solucion
AS
BEGIN
    SET NOCOUNT ON;
    
    ;WITH UltimaEjecucion AS (
        SELECT 
            job_id,
            MAX(msdb.dbo.agent_datetime(run_date, run_time)) AS UltimaFecha
        FROM msdb.dbo.sysjobhistory
        WHERE step_id = 0
        GROUP BY job_id
    ),
    ProxEjecucion AS (
        SELECT 
            job_id,
            MIN(msdb.dbo.agent_datetime(next_run_date, next_run_time)) AS ProximaFecha
        FROM msdb.dbo.sysjobschedules
        WHERE next_run_date > 0
        GROUP BY job_id
    ),
    Ultimas5 AS (
        SELECT 
            job_id,
            AVG(run_duration) AS PromDuracion
        FROM (
            SELECT job_id, run_duration,
                   ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) AS rn
            FROM msdb.dbo.sysjobhistory
            WHERE step_id = 0
        ) x
        WHERE rn <= 5
        GROUP BY job_id
    ),
    Exitos AS (
        SELECT 
            job_id,
            CAST(100.0 * SUM(CASE WHEN run_status = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS PctExito
        FROM msdb.dbo.sysjobhistory
        WHERE step_id = 0
          AND msdb.dbo.agent_datetime(run_date, run_time) > DATEADD(MONTH, -1, GETDATE())
        GROUP BY job_id
    )
    SELECT 
        j.name AS JobName,
        CASE j.enabled WHEN 1 THEN 'Habilitado' ELSE 'Deshabilitado' END AS Estado,
        ue.UltimaFecha AS UltimaEjecucion,
        CASE h.run_status 
            WHEN 1 THEN '✅ OK' 
            WHEN 0 THEN '❌ Fallo' 
            ELSE '?' 
        END AS UltimoResultado,
        pe.ProximaFecha AS ProximaEjecucion,
        STUFF(STUFF(RIGHT('000000' + CAST(u5.PromDuracion AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS PromDuracion,
        ISNULL(e.PctExito, 0) AS PctExitoMes
    FROM msdb.dbo.sysjobs j
    LEFT JOIN UltimaEjecucion ue ON j.job_id = ue.job_id
    LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id 
        AND msdb.dbo.agent_datetime(h.run_date, h.run_time) = ue.UltimaFecha
        AND h.step_id = 0
    LEFT JOIN ProxEjecucion pe ON j.job_id = pe.job_id
    LEFT JOIN Ultimas5 u5 ON j.job_id = u5.job_id
    LEFT JOIN Exitos e ON j.job_id = e.job_id
    WHERE j.name LIKE 'BancoDB%'
    ORDER BY j.name;
END;
GO

EXEC sp_DashboardJobs_Solucion;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 10 (Job completo)
-- ============================================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @enabled = 1,
    @description = N'Proceso batch nocturno completo del banco',
    @notify_level_email = 2,
    @notify_email_operator_name = N'Equipo_Operaciones_Sol';
GO

-- Step 1: Validar transacciones pendientes
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'1_Validar_Pendientes',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        DECLARE @Pendientes INT;
        SELECT @Pendientes = COUNT(*)
        FROM TRANSACCIONES_BANCARIAS
        WHERE Estado = ''Pendiente''
          AND FechaTransaccion < CAST(GETDATE() AS DATE);
        
        IF @Pendientes > 0
        BEGIN
            RAISERROR(''Hay %d transacciones pendientes sin procesar'', 16, 1, @Pendientes);
        END;
        
        PRINT ''Validación OK: No hay transacciones pendientes'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 4,
    @on_fail_step_id = 6;
GO

-- Step 2: Calcular intereses
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'2_Calcular_Intereses',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Calcular interés diario para cuentas de ahorro (tasa anual 3%)
        UPDATE CUENTAS
        SET Saldo = Saldo + (Saldo * 0.03 / 365)
        WHERE TipoCuenta = ''Ahorros''
          AND Estado = ''Activa''
          AND Saldo > 0;
        
        PRINT ''Intereses calculados para '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' cuentas'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;  -- Continuar aunque falle
GO

-- Step 3: Detectar saldos negativos
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'3_Detectar_Saldos_Negativos',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Marcar cuentas problemáticas
        UPDATE CUENTAS
        SET Estado = ''Bloqueada''
        WHERE Saldo < 0
          AND FechaApertura < DATEADD(DAY, -30, GETDATE())
          AND Estado <> ''Bloqueada'';
        
        PRINT ''Cuentas marcadas: '' + CAST(@@ROWCOUNT AS VARCHAR(10));
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

-- Step 4: Reporte actividad sospechosa
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'4_Detectar_Sospechosos',
    @step_id = 4,
    @subsystem = N'TSQL',
    @command = N'
        USE BancoDB;
        
        -- Detectar transacciones sospechosas (ejemplo: > 50000)
        DECLARE @Sospechosas INT;
        SELECT @Sospechosas = COUNT(*)
        FROM TRANSACCIONES_BANCARIAS
        WHERE Monto > 50000
          AND FechaTransaccion = CAST(GETDATE()-1 AS DATE);
        
        IF @Sospechosas > 0
            PRINT ''ALERTA: '' + CAST(@Sospechosas AS VARCHAR(10)) + '' transacciones sospechosas detectadas'';
        ELSE
            PRINT ''No se detectaron transacciones sospechosas'';
    ',
    @database_name = N'BancoDB',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

-- Step 5: Backup de log
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'5_Backup_Log',
    @step_id = 5,
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @LogFile NVARCHAR(500);
        SET @LogFile = ''C:\SQLBackups\BancoDB_Log_'' + FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'') + ''.trn'';
        
        BACKUP LOG BancoDB TO DISK = @LogFile WITH COMPRESSION;
        PRINT ''Log backup: '' + @LogFile;
    ',
    @database_name = N'master',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

-- Step 6: Resumen final (siempre se ejecuta)
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @step_name = N'6_Enviar_Resumen',
    @step_id = 6,
    @subsystem = N'TSQL',
    @command = N'
        -- Aquí iría sp_send_dbmail en producción
        PRINT ''=============================================='';
        PRINT ''RESUMEN PROCESO BATCH NOCTURNO'';
        PRINT ''Fecha: '' + CONVERT(VARCHAR(20), GETDATE(), 120);
        PRINT ''=============================================='';
        PRINT ''Proceso batch completado. Ver logs para detalles.'';
    ',
    @database_name = N'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @name = N'Diario_2AM',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 20000;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol',
    @server_name = N'(LOCAL)';
GO


-- ============================================================
-- LIMPIEZA DE JOBS DE SOLUCIONES (Descomentar para ejecutar)
-- ============================================================
/*
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Backup_Diferencial_Sol';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Verificar_Integridad_Sol';
EXEC msdb.dbo.sp_delete_job @job_name = N'Monitor_Espacio_Disco_Sol';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Limpiar_Logs_Sol';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_ETL_Carga_Sol';
EXEC msdb.dbo.sp_delete_job @job_name = N'BancoDB_Proceso_Batch_Nocturno_Sol';

EXEC msdb.dbo.sp_delete_operator @name = N'Equipo_Operaciones_Sol';
EXEC msdb.dbo.sp_delete_alert @name = N'Alerta_Deadlock_Sol';
EXEC msdb.dbo.sp_delete_alert @name = N'Alerta_Error_Fatal_Sol';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'Horario_Laboral_Cada_15min_Sol';
*/

PRINT '✓ Ejercicios de SQL Agent completados';
GO
