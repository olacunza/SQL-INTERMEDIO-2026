/*
================================================================================
        SQL INTERMEDIO 2026 - SESIÓN 15: AUDITORÍA Y COMPLIANCE
================================================================================
Instructor: [Nombre del Instructor]
Duración: 2 horas
Base de datos: BancoDB
Nivel: Intermedio-Avanzado

OBJETIVOS:
    • Comprender las estrategias de auditoría en SQL Server
    • Implementar SQL Server Audit para compliance
    • Crear triggers de auditoría personalizados
    • Configurar Temporal Tables para historial automático
    • Entender Change Data Capture (CDC)
    • Aplicar normativas de compliance bancario

CONTENIDO:
    1. Introducción a la Auditoría de Datos
    2. SQL Server Audit (Feature nativo)
    3. Triggers de Auditoría
    4. Temporal Tables (System-Versioned)
    5. Change Data Capture (CDC)
    6. Compliance Bancario
    7. Reportes de Auditoría
    8. Mejores Prácticas
================================================================================
*/

USE BancoDB;
GO

-- ============================================================================
-- PARTE 1: INTRODUCCIÓN A LA AUDITORÍA DE DATOS
-- ============================================================================

/*
   ¿POR QUÉ AUDITAR EN UN SISTEMA BANCARIO?
   =========================================
   
   1. REGULACIONES LEGALES:
      - PCI-DSS (datos de tarjetas)
      - SOX (Sarbanes-Oxley)
      - GDPR (protección de datos)
      - Normativas bancarias locales
   
   2. DETECCIÓN DE FRAUDE:
      - Transacciones sospechosas
      - Accesos no autorizados
      - Modificaciones indebidas
   
   3. TRAZABILIDAD:
      - ¿Quién hizo qué?
      - ¿Cuándo lo hizo?
      - ¿Desde dónde?
      - ¿Cuál era el valor anterior?
   
   MÉTODOS DE AUDITORÍA EN SQL SERVER:
   ===================================
   
   ┌─────────────────────┬────────────────────┬───────────────────────┐
   │ Método              │ Uso Principal      │ Complejidad           │
   ├─────────────────────┼────────────────────┼───────────────────────┤
   │ SQL Server Audit    │ Compliance formal  │ Media                 │
   │ Triggers            │ Personalizado      │ Alta                  │
   │ Temporal Tables     │ Historial datos    │ Baja                  │
   │ CDC                 │ Replicación/ETL    │ Media-Alta            │
   │ Change Tracking     │ Sincronización     │ Baja                  │
   └─────────────────────┴────────────────────┴───────────────────────┘
*/

-- ============================================================================
-- PARTE 2: SQL SERVER AUDIT (FEATURE NATIVO)
-- ============================================================================

/*
   SQL SERVER AUDIT - ARQUITECTURA
   ================================
   
   Server Audit ──► Audit Specification ──► Audit Actions
        │
        ├── File Target (más común)
        ├── Windows Event Log (Security/Application)
        └── Windows Security Log
   
   TIPOS DE ESPECIFICACIONES:
   - Server Audit Specification: Eventos a nivel de servidor
   - Database Audit Specification: Eventos a nivel de base de datos
*/

-- -----------------------------------------------------------------------------
-- 2.1 CREAR SERVER AUDIT (Destino de los logs)
-- -----------------------------------------------------------------------------

-- Crear directorio para archivos de auditoría (ejecutar como admin)
-- EXEC xp_cmdshell 'mkdir C:\SQLAudit';

-- Crear el Server Audit
CREATE SERVER AUDIT AUD_BancoDB_Compliance
TO FILE (
    FILEPATH = 'C:\SQLAudit\',
    MAXSIZE = 100 MB,
    MAX_ROLLOVER_FILES = 10,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,         -- Milisegundos antes de escribir
    ON_FAILURE = CONTINUE       -- CONTINUE o SHUTDOWN
);
GO

-- Habilitar el Server Audit
ALTER SERVER AUDIT AUD_BancoDB_Compliance
WITH (STATE = ON);
GO

-- -----------------------------------------------------------------------------
-- 2.2 CREAR DATABASE AUDIT SPECIFICATION
-- -----------------------------------------------------------------------------

-- Auditar operaciones en BancoDB
USE BancoDB;
GO

CREATE DATABASE AUDIT SPECIFICATION DAS_BancoDB_Transacciones
FOR SERVER AUDIT AUD_BancoDB_Compliance
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo BY public),
ADD (EXECUTE ON SCHEMA::dbo BY public)
WITH (STATE = ON);
GO

-- -----------------------------------------------------------------------------
-- 2.3 CREAR SERVER AUDIT SPECIFICATION
-- -----------------------------------------------------------------------------

-- Auditar eventos a nivel de servidor
USE master;
GO

CREATE SERVER AUDIT SPECIFICATION SAS_Logins_Seguridad
FOR SERVER AUDIT AUD_BancoDB_Compliance
ADD (FAILED_LOGIN_GROUP),               -- Logins fallidos
ADD (SUCCESSFUL_LOGIN_GROUP),           -- Logins exitosos
ADD (LOGIN_CHANGE_PASSWORD_GROUP),      -- Cambios de contraseña
ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),  -- Cambios en roles
ADD (DATABASE_PERMISSION_CHANGE_GROUP)  -- Cambios de permisos
WITH (STATE = ON);
GO

-- -----------------------------------------------------------------------------
-- 2.4 CONSULTAR LOGS DE AUDITORÍA
-- -----------------------------------------------------------------------------

USE BancoDB;
GO

-- Ver eventos de auditoría (requiere archivo existente)
SELECT 
    event_time,
    action_id,
    succeeded,
    session_server_principal_name AS Usuario,
    server_instance_name AS Servidor,
    database_name AS BaseDatos,
    schema_name AS Esquema,
    object_name AS Objeto,
    statement AS Sentencia
FROM sys.fn_get_audit_file('C:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO

-- Ver audits configurados
SELECT 
    name AS AuditName,
    type_desc AS TargetType,
    is_state_enabled AS Habilitado,
    create_date AS FechaCreacion
FROM sys.server_audits;
GO

-- Ver especificaciones de base de datos
SELECT 
    a.name AS AuditSpecName,
    d.audit_action_name AS Accion,
    d.class_desc AS Clase,
    d.is_group AS EsGrupo
FROM sys.database_audit_specifications a
JOIN sys.database_audit_specification_details d ON a.database_specification_id = d.database_specification_id;
GO

-- ============================================================================
-- PARTE 3: TRIGGERS DE AUDITORÍA
-- ============================================================================

/*
   TRIGGERS DE AUDITORÍA
   ======================
   
   Ventajas:
   - Control total sobre qué se registra
   - Puede capturar valores antes/después
   - Lógica personalizada
   
   Desventajas:
   - Impacto en performance
   - Mantenimiento adicional
   - Puede ser saltado por BULK INSERT sin FIRE_TRIGGERS
*/

-- -----------------------------------------------------------------------------
-- 3.1 TABLA DE AUDITORÍA CENTRALIZADA
-- -----------------------------------------------------------------------------

-- Crear tabla de auditoría
CREATE TABLE dbo.AUDITORIA_CAMBIOS (
    AuditoriaID         BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaHora           DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    Usuario             NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
    HostName            NVARCHAR(128) NOT NULL DEFAULT HOST_NAME(),
    AplicacionCliente   NVARCHAR(128) NULL DEFAULT APP_NAME(),
    Operacion           CHAR(1) NOT NULL,  -- I=Insert, U=Update, D=Delete
    NombreTabla         NVARCHAR(128) NOT NULL,
    NombreEsquema       NVARCHAR(128) NOT NULL DEFAULT 'dbo',
    ClaveRegistro       NVARCHAR(500) NOT NULL,
    DatosAnteriores     NVARCHAR(MAX) NULL,
    DatosNuevos         NVARCHAR(MAX) NULL,
    DireccionIP         VARCHAR(50) NULL,
    CONSTRAINT CK_Operacion CHECK (Operacion IN ('I', 'U', 'D'))
);
GO

-- Índices para consultas frecuentes
CREATE NONCLUSTERED INDEX IX_Auditoria_FechaHora 
ON dbo.AUDITORIA_CAMBIOS(FechaHora DESC);

CREATE NONCLUSTERED INDEX IX_Auditoria_Tabla_Fecha 
ON dbo.AUDITORIA_CAMBIOS(NombreTabla, FechaHora DESC);

CREATE NONCLUSTERED INDEX IX_Auditoria_Usuario 
ON dbo.AUDITORIA_CAMBIOS(Usuario, FechaHora DESC);
GO

-- -----------------------------------------------------------------------------
-- 3.2 TRIGGER DE AUDITORÍA PARA CUENTAS
-- -----------------------------------------------------------------------------

CREATE OR ALTER TRIGGER TR_CUENTAS_Auditoria
ON dbo.CUENTAS
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operacion CHAR(1);
    DECLARE @DatosAnteriores NVARCHAR(MAX);
    DECLARE @DatosNuevos NVARCHAR(MAX);
    
    -- Determinar tipo de operación
    IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
        SET @Operacion = 'U';
    ELSE IF EXISTS(SELECT 1 FROM inserted)
        SET @Operacion = 'I';
    ELSE
        SET @Operacion = 'D';
    
    -- Para INSERT
    IF @Operacion = 'I'
    BEGIN
        INSERT INTO dbo.AUDITORIA_CAMBIOS (
            Operacion, NombreTabla, ClaveRegistro, DatosNuevos
        )
        SELECT 
            'I',
            'CUENTAS',
            CAST(i.CuentaID AS NVARCHAR(50)),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i;
    END
    
    -- Para DELETE
    ELSE IF @Operacion = 'D'
    BEGIN
        INSERT INTO dbo.AUDITORIA_CAMBIOS (
            Operacion, NombreTabla, ClaveRegistro, DatosAnteriores
        )
        SELECT 
            'D',
            'CUENTAS',
            CAST(d.CuentaID AS NVARCHAR(50)),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM deleted d;
    END
    
    -- Para UPDATE
    ELSE
    BEGIN
        INSERT INTO dbo.AUDITORIA_CAMBIOS (
            Operacion, NombreTabla, ClaveRegistro, DatosAnteriores, DatosNuevos
        )
        SELECT 
            'U',
            'CUENTAS',
            CAST(i.CuentaID AS NVARCHAR(50)),
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i
        INNER JOIN deleted d ON i.CuentaID = d.CuentaID;
    END
END;
GO

-- -----------------------------------------------------------------------------
-- 3.3 TRIGGER DE AUDITORÍA GENÉRICO (Reutilizable)
-- -----------------------------------------------------------------------------

-- Procedimiento para crear triggers de auditoría automáticamente
CREATE OR ALTER PROCEDURE dbo.sp_CrearTriggerAuditoria
    @NombreTabla NVARCHAR(128),
    @NombreEsquema NVARCHAR(128) = 'dbo'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @NombreTrigger NVARCHAR(256);
    DECLARE @ColumnaPK NVARCHAR(128);
    
    -- Obtener columna de clave primaria
    SELECT TOP 1 @ColumnaPK = c.name
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.is_primary_key = 1
      AND i.object_id = OBJECT_ID(@NombreEsquema + '.' + @NombreTabla);
    
    IF @ColumnaPK IS NULL
    BEGIN
        RAISERROR('La tabla %s.%s no tiene clave primaria definida.', 16, 1, @NombreEsquema, @NombreTabla);
        RETURN;
    END
    
    SET @NombreTrigger = 'TR_' + @NombreTabla + '_Auditoria';
    
    -- Eliminar trigger existente si existe
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.triggers WHERE name = ''' + @NombreTrigger + ''')
                DROP TRIGGER ' + @NombreEsquema + '.' + @NombreTrigger;
    EXEC sp_executesql @SQL;
    
    -- Crear trigger de auditoría
    SET @SQL = '
    CREATE TRIGGER ' + @NombreEsquema + '.' + @NombreTrigger + '
    ON ' + @NombreEsquema + '.' + @NombreTabla + '
    AFTER INSERT, UPDATE, DELETE
    AS
    BEGIN
        SET NOCOUNT ON;
        
        DECLARE @Operacion CHAR(1);
        
        IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
            SET @Operacion = ''U'';
        ELSE IF EXISTS(SELECT 1 FROM inserted)
            SET @Operacion = ''I'';
        ELSE
            SET @Operacion = ''D'';
        
        IF @Operacion = ''I''
            INSERT INTO dbo.AUDITORIA_CAMBIOS (Operacion, NombreTabla, NombreEsquema, ClaveRegistro, DatosNuevos)
            SELECT ''I'', ''' + @NombreTabla + ''', ''' + @NombreEsquema + ''', 
                   CAST(i.' + @ColumnaPK + ' AS NVARCHAR(500)),
                   (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM inserted i;
        ELSE IF @Operacion = ''D''
            INSERT INTO dbo.AUDITORIA_CAMBIOS (Operacion, NombreTabla, NombreEsquema, ClaveRegistro, DatosAnteriores)
            SELECT ''D'', ''' + @NombreTabla + ''', ''' + @NombreEsquema + ''',
                   CAST(d.' + @ColumnaPK + ' AS NVARCHAR(500)),
                   (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM deleted d;
        ELSE
            INSERT INTO dbo.AUDITORIA_CAMBIOS (Operacion, NombreTabla, NombreEsquema, ClaveRegistro, DatosAnteriores, DatosNuevos)
            SELECT ''U'', ''' + @NombreTabla + ''', ''' + @NombreEsquema + ''',
                   CAST(i.' + @ColumnaPK + ' AS NVARCHAR(500)),
                   (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                   (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            FROM inserted i
            INNER JOIN deleted d ON i.' + @ColumnaPK + ' = d.' + @ColumnaPK + ';
    END';
    
    EXEC sp_executesql @SQL;
    
    PRINT 'Trigger ' + @NombreTrigger + ' creado exitosamente.';
END;
GO

-- Ejemplo: Crear triggers para múltiples tablas
-- EXEC dbo.sp_CrearTriggerAuditoria @NombreTabla = 'CLIENTES';
-- EXEC dbo.sp_CrearTriggerAuditoria @NombreTabla = 'TRANSACCIONES_BANCARIAS';
-- EXEC dbo.sp_CrearTriggerAuditoria @NombreTabla = 'EMPLEADOS';

-- -----------------------------------------------------------------------------
-- 3.4 TRIGGER PARA AUDITAR COLUMNAS SENSIBLES
-- -----------------------------------------------------------------------------

-- Auditar cambios en saldo (columna crítica)
CREATE OR ALTER TRIGGER TR_CUENTAS_AuditoriaSaldo
ON dbo.CUENTAS
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo auditar si el saldo cambió
    IF UPDATE(Saldo)
    BEGIN
        INSERT INTO dbo.AUDITORIA_CAMBIOS (
            Operacion, 
            NombreTabla, 
            ClaveRegistro, 
            DatosAnteriores, 
            DatosNuevos
        )
        SELECT 
            'U',
            'CUENTAS_SALDO',
            CAST(i.CuentaID AS NVARCHAR(50)),
            JSON_OBJECT('Saldo': d.Saldo),
            JSON_OBJECT('Saldo': i.Saldo, 'Diferencia': i.Saldo - d.Saldo)
        FROM inserted i
        INNER JOIN deleted d ON i.CuentaID = d.CuentaID
        WHERE i.Saldo <> d.Saldo;
    END
END;
GO

-- ============================================================================
-- PARTE 4: TEMPORAL TABLES (SYSTEM-VERSIONED)
-- ============================================================================

/*
   TEMPORAL TABLES (SQL Server 2016+)
   ===================================
   
   - Historial automático de cambios
   - Sistema mantiene dos tablas:
     * Tabla actual (datos vigentes)
     * Tabla de historial (versiones anteriores)
   
   - Columnas PERIOD requeridas:
     * ValidFrom (inicio validez)
     * ValidTo (fin validez)
   
   Sintaxis de consulta temporal:
   - FOR SYSTEM_TIME AS OF 'fecha'
   - FOR SYSTEM_TIME BETWEEN fecha1 AND fecha2
   - FOR SYSTEM_TIME FROM fecha1 TO fecha2
   - FOR SYSTEM_TIME CONTAINED IN (fecha1, fecha2)
   - FOR SYSTEM_TIME ALL
*/

-- -----------------------------------------------------------------------------
-- 4.1 CREAR TEMPORAL TABLE DESDE CERO
-- -----------------------------------------------------------------------------

-- Crear tabla temporal de límites de crédito
CREATE TABLE dbo.LIMITES_CREDITO (
    LimiteID            INT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
    CuentaID            INT NOT NULL,
    LimiteCredito       DECIMAL(18,2) NOT NULL,
    LimiteDiario        DECIMAL(18,2) NOT NULL,
    TasaInteres         DECIMAL(5,4) NOT NULL,
    AprobadoPor         INT NULL,  -- EmpleadoID
    Notas               NVARCHAR(500) NULL,
    
    -- Columnas temporales (SQL Server las gestiona automáticamente)
    ValidFrom           DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo             DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    
    -- Definir período temporal
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.LIMITES_CREDITO_Historial));
GO

-- Insertar datos de prueba
INSERT INTO dbo.LIMITES_CREDITO (CuentaID, LimiteCredito, LimiteDiario, TasaInteres, Notas)
VALUES 
    (1, 50000.00, 5000.00, 0.0850, 'Cliente preferencial'),
    (2, 25000.00, 2500.00, 0.1200, 'Cliente estándar'),
    (3, 100000.00, 10000.00, 0.0650, 'Cliente VIP');
GO

-- Esperar y hacer cambios para generar historial
WAITFOR DELAY '00:00:02';

-- Actualizar límites
UPDATE dbo.LIMITES_CREDITO
SET LimiteCredito = 75000.00, Notas = 'Aumento por buen historial'
WHERE CuentaID = 1;
GO

WAITFOR DELAY '00:00:02';

UPDATE dbo.LIMITES_CREDITO
SET TasaInteres = 0.0750
WHERE CuentaID = 1;
GO

-- -----------------------------------------------------------------------------
-- 4.2 CONSULTAS TEMPORALES
-- -----------------------------------------------------------------------------

-- Ver datos actuales
SELECT * FROM dbo.LIMITES_CREDITO;

-- Ver todo el historial
SELECT * FROM dbo.LIMITES_CREDITO FOR SYSTEM_TIME ALL
WHERE CuentaID = 1
ORDER BY ValidFrom;

-- Ver estado en un momento específico
DECLARE @FechaHistorica DATETIME2 = DATEADD(SECOND, -3, SYSUTCDATETIME());

SELECT * FROM dbo.LIMITES_CREDITO 
FOR SYSTEM_TIME AS OF @FechaHistorica
WHERE CuentaID = 1;
GO

-- Ver cambios en un rango de tiempo
SELECT 
    LimiteID,
    CuentaID,
    LimiteCredito,
    TasaInteres,
    ValidFrom,
    ValidTo,
    CASE 
        WHEN ValidTo = '9999-12-31 23:59:59.9999999' THEN 'Vigente'
        ELSE 'Histórico'
    END AS Estado
FROM dbo.LIMITES_CREDITO 
FOR SYSTEM_TIME BETWEEN '2026-01-01' AND '2026-12-31'
WHERE CuentaID = 1
ORDER BY ValidFrom;
GO

-- -----------------------------------------------------------------------------
-- 4.3 CONVERTIR TABLA EXISTENTE A TEMPORAL
-- -----------------------------------------------------------------------------

-- Paso 1: Agregar columnas temporales a tabla existente
-- (Ejemplo con una tabla hipotética TASAS_INTERES)
/*
ALTER TABLE dbo.TASAS_INTERES
ADD 
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START 
        CONSTRAINT DF_Tasas_ValidFrom DEFAULT SYSUTCDATETIME() NOT NULL,
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END 
        CONSTRAINT DF_Tasas_ValidTo DEFAULT CONVERT(DATETIME2, '9999-12-31 23:59:59.9999999') NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO

-- Paso 2: Habilitar versionado
ALTER TABLE dbo.TASAS_INTERES
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.TASAS_INTERES_Historial));
GO
*/

-- -----------------------------------------------------------------------------
-- 4.4 AUDITORÍA CON TEMPORAL TABLES - CASOS DE USO BANCARIO
-- -----------------------------------------------------------------------------

-- Procedimiento para auditar cambios en límites de crédito
CREATE OR ALTER PROCEDURE dbo.sp_ReporteCambiosLimitesCredito
    @CuentaID INT = NULL,
    @FechaDesde DATETIME2 = NULL,
    @FechaHasta DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @FechaDesde IS NULL SET @FechaDesde = DATEADD(MONTH, -1, SYSUTCDATETIME());
    IF @FechaHasta IS NULL SET @FechaHasta = SYSUTCDATETIME();
    
    SELECT 
        lc.CuentaID,
        lc.LimiteCredito,
        lc.TasaInteres,
        lc.Notas,
        lc.ValidFrom AS InicioVigencia,
        lc.ValidTo AS FinVigencia,
        CASE 
            WHEN lc.ValidTo = '9999-12-31 23:59:59.9999999' THEN 'Vigente'
            ELSE 'Histórico'
        END AS Estado,
        DATEDIFF(DAY, lc.ValidFrom, 
            CASE WHEN lc.ValidTo = '9999-12-31 23:59:59.9999999' 
                 THEN SYSUTCDATETIME() 
                 ELSE lc.ValidTo END) AS DiasVigente
    FROM dbo.LIMITES_CREDITO FOR SYSTEM_TIME ALL lc
    WHERE (@CuentaID IS NULL OR lc.CuentaID = @CuentaID)
      AND lc.ValidFrom >= @FechaDesde
      AND lc.ValidFrom <= @FechaHasta
    ORDER BY lc.CuentaID, lc.ValidFrom DESC;
END;
GO

-- Ejecutar reporte
EXEC dbo.sp_ReporteCambiosLimitesCredito @CuentaID = 1;
GO

-- ============================================================================
-- PARTE 5: CHANGE DATA CAPTURE (CDC)
-- ============================================================================

/*
   CHANGE DATA CAPTURE
   ====================
   
   - Captura cambios INSERT, UPDATE, DELETE
   - Almacena en tablas del sistema (cdc.*)
   - Ideal para ETL e integración con Data Warehouse
   - Requiere SQL Server Agent habilitado
   
   Diferencias con Temporal Tables:
   - CDC: Enfocado en replicación/ETL
   - Temporal: Enfocado en consultas de punto en el tiempo
*/

-- -----------------------------------------------------------------------------
-- 5.1 HABILITAR CDC EN LA BASE DE DATOS
-- -----------------------------------------------------------------------------

-- Habilitar CDC en BancoDB
USE BancoDB;
GO

EXEC sys.sp_cdc_enable_db;
GO

-- Verificar habilitación
SELECT name, is_cdc_enabled
FROM sys.databases
WHERE name = 'BancoDB';
GO

-- -----------------------------------------------------------------------------
-- 5.2 HABILITAR CDC EN TABLAS ESPECÍFICAS
-- -----------------------------------------------------------------------------

-- Habilitar CDC en tabla TRANSACCIONES_BANCARIAS
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'TRANSACCIONES_BANCARIAS',
    @role_name = N'cdc_reader',
    @capture_instance = N'dbo_TRANSACCIONES_BANCARIAS',
    @supports_net_changes = 1,
    @filegroup_name = N'PRIMARY';
GO

-- Habilitar CDC en tabla CLIENTES
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'CLIENTES',
    @role_name = N'cdc_reader',
    @capture_instance = N'dbo_CLIENTES',
    @supports_net_changes = 1;
GO

-- -----------------------------------------------------------------------------
-- 5.3 CONSULTAR CAMBIOS CAPTURADOS
-- -----------------------------------------------------------------------------

-- Ver tablas con CDC habilitado
SELECT 
    t.name AS Tabla,
    ct.capture_instance AS InstanciaCaptura,
    ct.create_date AS FechaCreacion
FROM sys.tables t
INNER JOIN cdc.change_tables ct ON t.object_id = ct.source_object_id;
GO

-- Función para obtener LSN de tiempo
DECLARE @from_lsn BINARY(10);
DECLARE @to_lsn BINARY(10);
DECLARE @from_time DATETIME = DATEADD(HOUR, -1, GETDATE());

SET @from_lsn = sys.fn_cdc_map_time_to_lsn('smallest greater than', @from_time);
SET @to_lsn = sys.fn_cdc_get_max_lsn();

-- Ver todos los cambios en la última hora
SELECT 
    __$operation AS Operacion,  -- 1=Delete, 2=Insert, 3=Update(antes), 4=Update(después)
    CASE __$operation 
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 3 THEN 'UPDATE (antes)'
        WHEN 4 THEN 'UPDATE (después)'
    END AS TipoOperacion,
    *
FROM cdc.fn_cdc_get_all_changes_dbo_CLIENTES(@from_lsn, @to_lsn, 'all');
GO

-- Obtener cambios netos (result final, sin intermedios)
DECLARE @from_lsn BINARY(10);
DECLARE @to_lsn BINARY(10);
DECLARE @from_time DATETIME = DATEADD(HOUR, -1, GETDATE());

SET @from_lsn = sys.fn_cdc_map_time_to_lsn('smallest greater than', @from_time);
SET @to_lsn = sys.fn_cdc_get_max_lsn();

SELECT *
FROM cdc.fn_cdc_get_net_changes_dbo_CLIENTES(@from_lsn, @to_lsn, 'all');
GO

-- -----------------------------------------------------------------------------
-- 5.4 PROCEDIMIENTO PARA PROCESAR CAMBIOS CDC
-- -----------------------------------------------------------------------------

-- Crear tabla para procesar cambios incrementales
CREATE TABLE dbo.CDC_PROCESO_LOG (
    ProcesoID       INT IDENTITY(1,1) PRIMARY KEY,
    InstanciaCaptura NVARCHAR(128) NOT NULL,
    UltimoLSN       BINARY(10) NOT NULL,
    FechaProceso    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    RegistrosProcesados INT NOT NULL DEFAULT 0
);
GO

-- Procedimiento para procesar cambios incrementales
CREATE OR ALTER PROCEDURE dbo.sp_ProcesarCambiosCDC
    @InstanciaCaptura NVARCHAR(128) = 'dbo_CLIENTES'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @from_lsn BINARY(10);
    DECLARE @to_lsn BINARY(10);
    DECLARE @ultimo_lsn BINARY(10);
    DECLARE @registros INT = 0;
    
    -- Obtener último LSN procesado
    SELECT TOP 1 @ultimo_lsn = UltimoLSN
    FROM dbo.CDC_PROCESO_LOG
    WHERE InstanciaCaptura = @InstanciaCaptura
    ORDER BY ProcesoID DESC;
    
    -- Si es primera vez, comenzar desde el mínimo
    IF @ultimo_lsn IS NULL
        SET @from_lsn = sys.fn_cdc_get_min_lsn(@InstanciaCaptura);
    ELSE
        SET @from_lsn = sys.fn_cdc_increment_lsn(@ultimo_lsn);
    
    SET @to_lsn = sys.fn_cdc_get_max_lsn();
    
    -- Verificar que hay cambios para procesar
    IF @from_lsn <= @to_lsn
    BEGIN
        -- Aquí procesarías los cambios según tu lógica de negocio
        -- Por ejemplo: exportar a Data Warehouse, enviar a sistema externo, etc.
        
        PRINT 'Procesando cambios desde LSN: ' + CONVERT(VARCHAR(50), @from_lsn, 1);
        PRINT 'Hasta LSN: ' + CONVERT(VARCHAR(50), @to_lsn, 1);
        
        -- Registrar proceso
        INSERT INTO dbo.CDC_PROCESO_LOG (InstanciaCaptura, UltimoLSN, RegistrosProcesados)
        VALUES (@InstanciaCaptura, @to_lsn, @registros);
    END
    ELSE
        PRINT 'No hay cambios nuevos para procesar.';
END;
GO

-- ============================================================================
-- PARTE 6: COMPLIANCE BANCARIO
-- ============================================================================

/*
   REGULACIONES COMUNES EN BANCA
   ==============================
   
   PCI-DSS (Payment Card Industry Data Security Standard):
   - Encriptar datos de tarjetas
   - Acceso restringido y auditado
   - Retención de logs 1 año mínimo
   
   SOX (Sarbanes-Oxley):
   - Control de acceso financiero
   - Trazabilidad de cambios
   - Segregación de funciones
   
   GDPR (General Data Protection Regulation):
   - Derecho al olvido
   - Consentimiento explícito
   - Portabilidad de datos
*/

-- -----------------------------------------------------------------------------
-- 6.1 RESTRICCIÓN DE ACCESO A DATOS SENSIBLES
-- -----------------------------------------------------------------------------

-- Crear esquema para datos sensibles
CREATE SCHEMA Confidencial AUTHORIZATION dbo;
GO

-- Mover datos sensibles
/*
ALTER SCHEMA Confidencial TRANSFER dbo.DATOS_TARJETAS;
*/

-- Crear rol específico para acceso a datos sensibles
CREATE ROLE rol_DatosSensibles;
GO

-- Otorgar permisos mínimos necesarios
GRANT SELECT ON SCHEMA::Confidencial TO rol_DatosSensibles;
GO

-- -----------------------------------------------------------------------------
-- 6.2 ENMASCARAMIENTO DINÁMICO DE DATOS (DDM)
-- -----------------------------------------------------------------------------

-- Agregar máscara a datos sensibles
/*
ALTER TABLE dbo.CLIENTES
ALTER COLUMN NumeroDocumento ADD MASKED WITH (FUNCTION = 'partial(0,"****",4)');

ALTER TABLE dbo.CLIENTES
ALTER COLUMN Telefono ADD MASKED WITH (FUNCTION = 'partial(0,"***-***-",4)');

ALTER TABLE dbo.CLIENTES
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
*/

-- Ver columnas enmascaradas
SELECT 
    t.name AS Tabla,
    c.name AS Columna,
    c.is_masked AS EnmascaradO,
    mc.masking_function AS FuncionMascara
FROM sys.masked_columns mc
INNER JOIN sys.columns c ON mc.object_id = c.object_id AND mc.column_id = c.column_id
INNER JOIN sys.tables t ON c.object_id = t.object_id;
GO

-- -----------------------------------------------------------------------------
-- 6.3 ROW-LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------

-- Crear tabla de sucursales con acceso restringido
CREATE TABLE dbo.SUCURSALES_CONFIDENCIAL (
    SucursalID      INT PRIMARY KEY,
    NombreSucursal  NVARCHAR(100),
    PresupuestoAnual DECIMAL(18,2),
    GerenteID       INT
);
GO

-- Insertar datos de prueba
INSERT INTO dbo.SUCURSALES_CONFIDENCIAL VALUES
(1, 'Sucursal Centro', 5000000.00, 101),
(2, 'Sucursal Norte', 3500000.00, 102),
(3, 'Sucursal Sur', 4200000.00, 103);
GO

-- Crear función de filtro
CREATE FUNCTION dbo.fn_FiltroSucursal(@GerenteID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN 
    SELECT 1 AS Acceso
    WHERE @GerenteID = CAST(SESSION_CONTEXT(N'GerenteID') AS INT)
       OR IS_MEMBER('db_owner') = 1;
GO

-- Crear política de seguridad
CREATE SECURITY POLICY pol_SucursalAcceso
ADD FILTER PREDICATE dbo.fn_FiltroSucursal(GerenteID) ON dbo.SUCURSALES_CONFIDENCIAL
WITH (STATE = ON);
GO

-- Ejemplo de uso:
-- EXEC sp_set_session_context @key = N'GerenteID', @value = 101;
-- SELECT * FROM dbo.SUCURSALES_CONFIDENCIAL;  -- Solo verá su sucursal

-- -----------------------------------------------------------------------------
-- 6.4 RETENCIÓN Y PURGA DE DATOS DE AUDITORÍA
-- -----------------------------------------------------------------------------

-- Procedimiento para purgar datos antiguos según política de retención
CREATE OR ALTER PROCEDURE dbo.sp_PurgarAuditoriaAntigua
    @DiasRetencion INT = 365,  -- 1 año por defecto (PCI-DSS)
    @RegistrosMaxPorLote INT = 10000,
    @ModoSimulacion BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaCorte DATETIME2 = DATEADD(DAY, -@DiasRetencion, SYSUTCDATETIME());
    DECLARE @RegistrosAEliminar INT;
    DECLARE @RegistrosEliminados INT = 0;
    
    -- Contar registros a eliminar
    SELECT @RegistrosAEliminar = COUNT(*)
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora < @FechaCorte;
    
    PRINT 'Fecha de corte: ' + CONVERT(VARCHAR(30), @FechaCorte, 121);
    PRINT 'Registros a eliminar: ' + CAST(@RegistrosAEliminar AS VARCHAR(20));
    
    IF @ModoSimulacion = 1
    BEGIN
        PRINT '*** MODO SIMULACIÓN - No se eliminaron registros ***';
        RETURN;
    END
    
    -- Eliminar en lotes
    WHILE EXISTS (SELECT 1 FROM dbo.AUDITORIA_CAMBIOS WHERE FechaHora < @FechaCorte)
    BEGIN
        DELETE TOP (@RegistrosMaxPorLote)
        FROM dbo.AUDITORIA_CAMBIOS
        WHERE FechaHora < @FechaCorte;
        
        SET @RegistrosEliminados += @@ROWCOUNT;
        
        PRINT 'Registros eliminados hasta ahora: ' + CAST(@RegistrosEliminados AS VARCHAR(20));
        
        -- Pequeña pausa para no bloquear
        WAITFOR DELAY '00:00:00.100';
    END
    
    PRINT 'Purga completada. Total eliminados: ' + CAST(@RegistrosEliminados AS VARCHAR(20));
    
    -- Registrar la purga
    INSERT INTO dbo.AUDITORIA_CAMBIOS (Operacion, NombreTabla, ClaveRegistro, DatosNuevos)
    VALUES ('D', 'AUDITORIA_PURGA', 'SISTEMA', 
            JSON_OBJECT('FechaCorte': CONVERT(VARCHAR(30), @FechaCorte, 121), 
                        'RegistrosEliminados': @RegistrosEliminados));
END;
GO

-- Ejecutar en modo simulación
EXEC dbo.sp_PurgarAuditoriaAntigua @DiasRetencion = 365, @ModoSimulacion = 1;
GO

-- ============================================================================
-- PARTE 7: REPORTES DE AUDITORÍA
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 7.1 DASHBOARD DE ACTIVIDAD DE AUDITORÍA
-- -----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.sp_DashboardAuditoria
    @DiasAtras INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaDesde DATETIME2 = DATEADD(DAY, -@DiasAtras, SYSUTCDATETIME());
    
    -- Resumen por tabla
    PRINT '=== ACTIVIDAD POR TABLA ===';
    SELECT 
        NombreTabla,
        SUM(CASE WHEN Operacion = 'I' THEN 1 ELSE 0 END) AS Inserciones,
        SUM(CASE WHEN Operacion = 'U' THEN 1 ELSE 0 END) AS Actualizaciones,
        SUM(CASE WHEN Operacion = 'D' THEN 1 ELSE 0 END) AS Eliminaciones,
        COUNT(*) AS TotalOperaciones
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
    GROUP BY NombreTabla
    ORDER BY TotalOperaciones DESC;
    
    -- Resumen por usuario
    PRINT '=== ACTIVIDAD POR USUARIO ===';
    SELECT 
        Usuario,
        COUNT(*) AS TotalOperaciones,
        COUNT(DISTINCT NombreTabla) AS TablasAfectadas,
        MIN(FechaHora) AS PrimeraActividad,
        MAX(FechaHora) AS UltimaActividad
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
    GROUP BY Usuario
    ORDER BY TotalOperaciones DESC;
    
    -- Actividad por hora del día
    PRINT '=== DISTRIBUCIÓN HORARIA ===';
    SELECT 
        DATEPART(HOUR, FechaHora) AS Hora,
        COUNT(*) AS Operaciones
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
    GROUP BY DATEPART(HOUR, FechaHora)
    ORDER BY Hora;
    
    -- Actividad por día
    PRINT '=== ACTIVIDAD DIARIA ===';
    SELECT 
        CAST(FechaHora AS DATE) AS Fecha,
        COUNT(*) AS Operaciones
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
    GROUP BY CAST(FechaHora AS DATE)
    ORDER BY Fecha;
END;
GO

-- Ejecutar dashboard
EXEC dbo.sp_DashboardAuditoria @DiasAtras = 30;
GO

-- -----------------------------------------------------------------------------
-- 7.2 REPORTE DE CAMBIOS EN REGISTRO ESPECÍFICO
-- -----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.sp_HistorialCambiosRegistro
    @NombreTabla NVARCHAR(128),
    @ClaveRegistro NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        FechaHora,
        Usuario,
        HostName,
        AplicacionCliente,
        CASE Operacion
            WHEN 'I' THEN 'Inserción'
            WHEN 'U' THEN 'Actualización'
            WHEN 'D' THEN 'Eliminación'
        END AS TipoOperacion,
        DatosAnteriores,
        DatosNuevos
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE NombreTabla = @NombreTabla
      AND ClaveRegistro = @ClaveRegistro
    ORDER BY FechaHora DESC;
END;
GO

-- Ejemplo de uso
-- EXEC dbo.sp_HistorialCambiosRegistro 'CUENTAS', '12345';

-- -----------------------------------------------------------------------------
-- 7.3 REPORTE DE ACTIVIDAD SOSPECHOSA
-- -----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.sp_ActividadSospechosa
    @UmbralOperacionesPorHora INT = 100,
    @HorasAtras INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaDesde DATETIME2 = DATEADD(HOUR, -@HorasAtras, SYSUTCDATETIME());
    
    PRINT '=== USUARIOS CON ALTA ACTIVIDAD ===';
    SELECT 
        Usuario,
        HostName,
        COUNT(*) AS TotalOperaciones,
        COUNT(DISTINCT NombreTabla) AS TablasAccedidas
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
    GROUP BY Usuario, HostName
    HAVING COUNT(*) > @UmbralOperacionesPorHora
    ORDER BY TotalOperaciones DESC;
    
    PRINT '=== ACTIVIDAD FUERA DE HORARIO (22:00 - 06:00) ===';
    SELECT 
        Usuario,
        HostName,
        NombreTabla,
        Operacion,
        FechaHora,
        ClaveRegistro
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
      AND (DATEPART(HOUR, FechaHora) >= 22 OR DATEPART(HOUR, FechaHora) < 6)
    ORDER BY FechaHora DESC;
    
    PRINT '=== ELIMINACIONES MASIVAS ===';
    SELECT 
        Usuario,
        NombreTabla,
        COUNT(*) AS Eliminaciones,
        MIN(FechaHora) AS Primera,
        MAX(FechaHora) AS Ultima
    FROM dbo.AUDITORIA_CAMBIOS
    WHERE FechaHora >= @FechaDesde
      AND Operacion = 'D'
    GROUP BY Usuario, NombreTabla
    HAVING COUNT(*) > 10
    ORDER BY Eliminaciones DESC;
END;
GO

-- Ejecutar reporte
EXEC dbo.sp_ActividadSospechosa @UmbralOperacionesPorHora = 50, @HorasAtras = 48;
GO

-- ============================================================================
-- PARTE 8: MEJORES PRÁCTICAS
-- ============================================================================

/*
   ╔══════════════════════════════════════════════════════════════════════════╗
   ║                    MEJORES PRÁCTICAS DE AUDITORÍA                        ║
   ╠══════════════════════════════════════════════════════════════════════════╣
   ║                                                                          ║
   ║  1. DISEÑO                                                               ║
   ║     • Definir qué auditar según regulación y riesgo                     ║
   ║     • Separar datos de auditoría en filegroup/disco distinto            ║
   ║     • Usar índices apropiados para consultas frecuentes                 ║
   ║                                                                          ║
   ║  2. PERFORMANCE                                                          ║
   ║     • Triggers: mínima lógica, capturar y salir                        ║
   ║     • CDC: usar jobs nocturnos para procesar cambios                   ║
   ║     • Temporal Tables: partitionar historial por fecha                  ║
   ║                                                                          ║
   ║  3. RETENCIÓN                                                            ║
   ║     • Definir política clara (PCI-DSS = 1 año mínimo)                  ║
   ║     • Automatizar purga con jobs programados                           ║
   ║     • Archivar a almacenamiento frío si es necesario                   ║
   ║                                                                          ║
   ║  4. SEGURIDAD                                                            ║
   ║     • Proteger tablas de auditoría contra modificación                 ║
   ║     • Separar permisos de lectura de auditoría                         ║
   ║     • No permitir TRUNCATE en tablas de auditoría                      ║
   ║                                                                          ║
   ║  5. MONITOREO                                                            ║
   ║     • Alertas para actividad inusual                                   ║
   ║     • Reportes periódicos a seguridad/compliance                       ║
   ║     • Dashboard en tiempo real para operaciones críticas              ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝
*/

-- -----------------------------------------------------------------------------
-- 8.1 PROTEGER TABLAS DE AUDITORÍA
-- -----------------------------------------------------------------------------

-- Denegar modificaciones directas a tabla de auditoría
DENY DELETE, UPDATE, TRUNCATE ON dbo.AUDITORIA_CAMBIOS TO PUBLIC;
GO

-- Solo el proceso de purga (rol específico) puede eliminar
CREATE ROLE rol_AuditoriaPurga;
GRANT DELETE ON dbo.AUDITORIA_CAMBIOS TO rol_AuditoriaPurga;
GO

-- -----------------------------------------------------------------------------
-- 8.2 CREAR JOB DE PURGA AUTOMÁTICA
-- -----------------------------------------------------------------------------

/*
-- Crear job para purgar auditoría antigua (ejecutar en msdb)
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'BancoDB - Purga Auditoria Mensual',
    @enabled = 1,
    @description = N'Elimina registros de auditoría mayores a 1 año';

EXEC sp_add_jobstep
    @job_name = N'BancoDB - Purga Auditoria Mensual',
    @step_name = N'Ejecutar Purga',
    @subsystem = N'TSQL',
    @command = N'EXEC dbo.sp_PurgarAuditoriaAntigua @DiasRetencion = 365, @ModoSimulacion = 0;',
    @database_name = N'BancoDB';

EXEC sp_add_jobschedule
    @job_name = N'BancoDB - Purga Auditoria Mensual',
    @name = N'Primer domingo del mes',
    @freq_type = 32,
    @freq_interval = 1,
    @freq_relative_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 30000;

EXEC sp_add_jobserver
    @job_name = N'BancoDB - Purga Auditoria Mensual',
    @server_name = N'(LOCAL)';
GO
*/

-- ============================================================================
-- LIMPIEZA DE OBJETOS DE DEMOSTRACIÓN
-- ============================================================================

/*
-- Deshabilitar SQL Server Audit
ALTER DATABASE AUDIT SPECIFICATION DAS_BancoDB_Transacciones WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION DAS_BancoDB_Transacciones;

ALTER SERVER AUDIT SPECIFICATION SAS_Logins_Seguridad WITH (STATE = OFF);
DROP SERVER AUDIT SPECIFICATION SAS_Logins_Seguridad;

ALTER SERVER AUDIT AUD_BancoDB_Compliance WITH (STATE = OFF);
DROP SERVER AUDIT AUD_BancoDB_Compliance;

-- Deshabilitar CDC
EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'TRANSACCIONES_BANCARIAS', @capture_instance = N'dbo_TRANSACCIONES_BANCARIAS';
EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'CLIENTES', @capture_instance = N'dbo_CLIENTES';
EXEC sys.sp_cdc_disable_db;

-- Deshabilitar Temporal Table
ALTER TABLE dbo.LIMITES_CREDITO SET (SYSTEM_VERSIONING = OFF);
DROP TABLE dbo.LIMITES_CREDITO;
DROP TABLE dbo.LIMITES_CREDITO_Historial;

-- Eliminar otros objetos
DROP TABLE IF EXISTS dbo.AUDITORIA_CAMBIOS;
DROP TABLE IF EXISTS dbo.CDC_PROCESO_LOG;
DROP TABLE IF EXISTS dbo.SUCURSALES_CONFIDENCIAL;
DROP FUNCTION IF EXISTS dbo.fn_FiltroSucursal;
DROP SECURITY POLICY IF EXISTS pol_SucursalAcceso;
DROP TRIGGER IF EXISTS dbo.TR_CUENTAS_Auditoria;
DROP TRIGGER IF EXISTS dbo.TR_CUENTAS_AuditoriaSaldo;
*/

-- ============================================================================
-- FIN DE LA SESIÓN 15
-- ============================================================================

PRINT '================================================';
PRINT '  Sesión 15 Completada: Auditoría y Compliance  ';
PRINT '================================================';
PRINT '';
PRINT 'Temas cubiertos:';
PRINT '  ✓ SQL Server Audit';
PRINT '  ✓ Triggers de Auditoría';
PRINT '  ✓ Temporal Tables';
PRINT '  ✓ Change Data Capture (CDC)';
PRINT '  ✓ Compliance Bancario';
PRINT '  ✓ Reportes de Auditoría';
PRINT '';
PRINT 'Próxima sesión: Workshop Final de Tuning';
GO
