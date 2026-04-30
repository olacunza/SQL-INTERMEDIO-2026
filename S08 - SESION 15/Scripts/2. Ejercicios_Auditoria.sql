/*
================================================================================
        SQL INTERMEDIO 2026 - SESIÓN 15: EJERCICIOS
        AUDITORÍA Y COMPLIANCE - PRÁCTICA
================================================================================
Base de datos: BancoDB
Nivel: Intermedio-Avanzado

INSTRUCCIONES:
    • Cada ejercicio incluye el problema y su solución
    • Intenta resolver antes de ver la solución
    • Los ejercicios están ordenados por complejidad
    • Ejecuta en un ambiente de desarrollo, NO en producción
================================================================================
*/

USE BancoDB;
GO

-- ============================================================================
-- EJERCICIO 1: TABLA DE AUDITORÍA BÁSICA
-- Crear estructura para registrar cambios en CLIENTES
-- Nivel: Básico
-- ============================================================================

/*
PROBLEMA:
Crea una tabla de auditoría llamada AUD_CLIENTES que registre:
- ID de auditoría (autoincremental)
- Tipo de operación (INSERT, UPDATE, DELETE)
- ID del cliente afectado
- Datos anteriores y nuevos (como XML o JSON)
- Usuario que realizó el cambio
- Fecha y hora del cambio
- Nombre de la aplicación
- Host desde donde se conectó
*/

-- SOLUCIÓN EJERCICIO 1:

-- Eliminar si existe
IF OBJECT_ID('Auditoria.AUD_CLIENTES', 'U') IS NOT NULL
    DROP TABLE Auditoria.AUD_CLIENTES;

-- Crear esquema de auditoría si no existe
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Auditoria')
    EXEC('CREATE SCHEMA Auditoria');
GO

CREATE TABLE Auditoria.AUD_CLIENTES (
    AuditID             BIGINT IDENTITY(1,1) PRIMARY KEY,
    TipoOperacion       CHAR(1) NOT NULL,       -- I=Insert, U=Update, D=Delete
    ClienteID           INT NOT NULL,
    DatosAnteriores     NVARCHAR(MAX) NULL,     -- JSON con valores anteriores
    DatosNuevos         NVARCHAR(MAX) NULL,     -- JSON con valores nuevos
    UsuarioDB           NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
    UsuarioApp          NVARCHAR(128) NULL,     -- Si la app envía usuario
    FechaHora           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    NombreHost          NVARCHAR(128) NOT NULL DEFAULT HOST_NAME(),
    NombreApp           NVARCHAR(128) NOT NULL DEFAULT APP_NAME(),
    DireccionIP         VARCHAR(48) NULL,
    
    CONSTRAINT CK_AUD_CLIENTES_TipoOp 
        CHECK (TipoOperacion IN ('I', 'U', 'D'))
);
GO

-- Índices para consultas de auditoría
CREATE NONCLUSTERED INDEX IX_AUD_CLIENTES_ClienteID 
    ON Auditoria.AUD_CLIENTES(ClienteID);
    
CREATE NONCLUSTERED INDEX IX_AUD_CLIENTES_FechaHora 
    ON Auditoria.AUD_CLIENTES(FechaHora);
GO

PRINT 'Ejercicio 1 completado: Tabla AUD_CLIENTES creada.';
GO

-- ============================================================================
-- EJERCICIO 2: TRIGGER DE AUDITORÍA COMPLETO
-- Implementar trigger que capture todos los cambios en CLIENTES
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
Crear un trigger AFTER INSERT, UPDATE, DELETE en la tabla CLIENTES que:
- Registre cada operación en AUD_CLIENTES
- Capture los datos anteriores (para UPDATE y DELETE)
- Capture los datos nuevos (para INSERT y UPDATE)
- Identifique automáticamente el tipo de operación
- Use formato JSON para los datos
*/

-- SOLUCIÓN EJERCICIO 2:

-- Verificar si tabla CLIENTES existe (si no, crearla para el ejercicio)
IF OBJECT_ID('dbo.CLIENTES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CLIENTES (
        ClienteID       INT IDENTITY(1,1) PRIMARY KEY,
        Nombre          NVARCHAR(100) NOT NULL,
        Apellido        NVARCHAR(100) NOT NULL,
        Email           NVARCHAR(200),
        Telefono        VARCHAR(20),
        FechaNacimiento DATE,
        Direccion       NVARCHAR(300),
        FechaRegistro   DATETIME2 DEFAULT SYSDATETIME(),
        Estado          VARCHAR(20) DEFAULT 'ACTIVO'
    );
END
GO

-- Crear el trigger de auditoría
CREATE OR ALTER TRIGGER TR_CLIENTES_Auditoria
ON dbo.CLIENTES
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TipoOperacion CHAR(1);
    DECLARE @HayInserted BIT = CASE WHEN EXISTS(SELECT 1 FROM inserted) THEN 1 ELSE 0 END;
    DECLARE @HayDeleted BIT = CASE WHEN EXISTS(SELECT 1 FROM deleted) THEN 1 ELSE 0 END;
    
    -- Determinar tipo de operación
    IF @HayInserted = 1 AND @HayDeleted = 0
        SET @TipoOperacion = 'I';  -- INSERT
    ELSE IF @HayInserted = 1 AND @HayDeleted = 1
        SET @TipoOperacion = 'U';  -- UPDATE
    ELSE IF @HayInserted = 0 AND @HayDeleted = 1
        SET @TipoOperacion = 'D';  -- DELETE
    
    -- Registrar INSERT
    IF @TipoOperacion = 'I'
    BEGIN
        INSERT INTO Auditoria.AUD_CLIENTES (
            TipoOperacion, ClienteID, DatosAnteriores, DatosNuevos
        )
        SELECT 
            'I',
            i.ClienteID,
            NULL,
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i;
    END
    
    -- Registrar UPDATE
    IF @TipoOperacion = 'U'
    BEGIN
        INSERT INTO Auditoria.AUD_CLIENTES (
            TipoOperacion, ClienteID, DatosAnteriores, DatosNuevos
        )
        SELECT 
            'U',
            i.ClienteID,
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i
        INNER JOIN deleted d ON i.ClienteID = d.ClienteID;
    END
    
    -- Registrar DELETE
    IF @TipoOperacion = 'D'
    BEGIN
        INSERT INTO Auditoria.AUD_CLIENTES (
            TipoOperacion, ClienteID, DatosAnteriores, DatosNuevos
        )
        SELECT 
            'D',
            d.ClienteID,
            (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            NULL
        FROM deleted d;
    END
END;
GO

PRINT 'Ejercicio 2 completado: Trigger TR_CLIENTES_Auditoria creado.';
GO

-- ============================================================================
-- EJERCICIO 3: PRUEBA DEL TRIGGER DE AUDITORÍA
-- Ejecutar operaciones y verificar registros
-- Nivel: Básico
-- ============================================================================

/*
PROBLEMA:
Realiza las siguientes operaciones y verifica que se registren en AUD_CLIENTES:
1. Insertar un nuevo cliente
2. Actualizar el email del cliente
3. Eliminar el cliente
4. Consultar la tabla de auditoría para ver los 3 registros
*/

-- SOLUCIÓN EJERCICIO 3:

-- Limpiar auditoría previa para este ejercicio
-- DELETE FROM Auditoria.AUD_CLIENTES WHERE ClienteID > 1000;

-- 3.1 INSERT - Nuevo cliente
INSERT INTO dbo.CLIENTES (Nombre, Apellido, Email, Telefono)
VALUES ('María', 'González', 'maria.gonzalez@email.com', '555-0101');

DECLARE @NuevoClienteID INT = SCOPE_IDENTITY();
PRINT 'Cliente insertado con ID: ' + CAST(@NuevoClienteID AS VARCHAR);

-- 3.2 UPDATE - Cambiar email
UPDATE dbo.CLIENTES 
SET Email = 'maria.g.nuevo@email.com',
    Telefono = '555-0199'
WHERE ClienteID = @NuevoClienteID;

PRINT 'Cliente actualizado';

-- 3.3 DELETE - Eliminar cliente
DELETE FROM dbo.CLIENTES 
WHERE ClienteID = @NuevoClienteID;

PRINT 'Cliente eliminado';

-- 3.4 Verificar auditoría
SELECT 
    AuditID,
    TipoOperacion,
    CASE TipoOperacion 
        WHEN 'I' THEN 'INSERT'
        WHEN 'U' THEN 'UPDATE'
        WHEN 'D' THEN 'DELETE'
    END AS Operacion,
    ClienteID,
    LEFT(DatosAnteriores, 100) AS DatosAnteriores,
    LEFT(DatosNuevos, 100) AS DatosNuevos,
    UsuarioDB,
    FechaHora
FROM Auditoria.AUD_CLIENTES
WHERE ClienteID = @NuevoClienteID
ORDER BY AuditID;
GO

-- ============================================================================
-- EJERCICIO 4: TABLA TEMPORAL (SYSTEM-VERSIONED)
-- Crear tabla con historial automático
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
Crear una tabla CUENTAS_TEMPORAL con versionado de sistema que:
- Tenga columnas: CuentaID, ClienteID, NumeroCuenta, Saldo, TipoCuenta, Estado
- Mantenga historial automático de todos los cambios
- Permita consultar "point-in-time" (estado en un momento específico)
*/

-- SOLUCIÓN EJERCICIO 4:

-- Eliminar si existe (con historial)
IF OBJECT_ID('dbo.CUENTAS_TEMPORAL', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CUENTAS_TEMPORAL SET (SYSTEM_VERSIONING = OFF);
    DROP TABLE IF EXISTS dbo.CUENTAS_TEMPORAL;
    DROP TABLE IF EXISTS dbo.CUENTAS_TEMPORAL_History;
END
GO

-- Crear tabla temporal con versionado de sistema
CREATE TABLE dbo.CUENTAS_TEMPORAL (
    CuentaID        INT IDENTITY(1,1) PRIMARY KEY,
    ClienteID       INT NOT NULL,
    NumeroCuenta    VARCHAR(20) NOT NULL,
    Saldo           DECIMAL(18,2) NOT NULL DEFAULT 0,
    TipoCuenta      VARCHAR(20) NOT NULL,
    Estado          VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    
    -- Columnas requeridas para System-Versioning
    ValidoDesde     DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidoHasta     DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    
    PERIOD FOR SYSTEM_TIME (ValidoDesde, ValidoHasta)
)
WITH (
    SYSTEM_VERSIONING = ON (
        HISTORY_TABLE = dbo.CUENTAS_TEMPORAL_History,
        HISTORY_RETENTION_PERIOD = 2 YEARS
    )
);
GO

-- Índice en tabla de historial
CREATE NONCLUSTERED INDEX IX_CUENTAS_History_CuentaID 
    ON dbo.CUENTAS_TEMPORAL_History(CuentaID, ValidoDesde, ValidoHasta);
GO

PRINT 'Ejercicio 4 completado: Tabla temporal CUENTAS_TEMPORAL creada.';
GO

-- ============================================================================
-- EJERCICIO 5: OPERACIONES CON TEMPORAL TABLES
-- Realizar operaciones y consultar historial
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
1. Insertar una cuenta nueva
2. Realizar varias actualizaciones de saldo (simular transacciones)
3. Usar FOR SYSTEM_TIME para consultar:
   - Estado actual
   - Estado en un momento específico
   - Todo el historial de cambios
*/

-- SOLUCIÓN EJERCICIO 5:

-- 5.1 Insertar cuenta
INSERT INTO dbo.CUENTAS_TEMPORAL (ClienteID, NumeroCuenta, Saldo, TipoCuenta)
VALUES (1, '1234-5678-9012', 10000.00, 'AHORROS');

DECLARE @CuentaEjemplo INT = SCOPE_IDENTITY();
PRINT 'Cuenta creada con ID: ' + CAST(@CuentaEjemplo AS VARCHAR);

-- Pequeña pausa para generar diferencia temporal
WAITFOR DELAY '00:00:01';

-- 5.2 Primera actualización - depósito
UPDATE dbo.CUENTAS_TEMPORAL 
SET Saldo = Saldo + 5000.00
WHERE CuentaID = @CuentaEjemplo;
PRINT 'Depósito de 5000 realizado';

WAITFOR DELAY '00:00:01';

-- 5.3 Segunda actualización - retiro
UPDATE dbo.CUENTAS_TEMPORAL 
SET Saldo = Saldo - 2000.00
WHERE CuentaID = @CuentaEjemplo;
PRINT 'Retiro de 2000 realizado';

WAITFOR DELAY '00:00:01';

-- 5.4 Tercera actualización - cambio de estado
UPDATE dbo.CUENTAS_TEMPORAL 
SET Estado = 'PREMIUM'
WHERE CuentaID = @CuentaEjemplo;
PRINT 'Estado cambiado a PREMIUM';

-- 5.5 Consultar estado ACTUAL
PRINT '--- Estado Actual ---';
SELECT CuentaID, NumeroCuenta, Saldo, Estado, ValidoDesde
FROM dbo.CUENTAS_TEMPORAL
WHERE CuentaID = @CuentaEjemplo;

-- 5.6 Consultar TODO el historial (ALL)
PRINT '--- Historial Completo ---';
SELECT 
    CuentaID, 
    Saldo, 
    Estado,
    ValidoDesde,
    ValidoHasta,
    CASE 
        WHEN ValidoHasta = '9999-12-31 23:59:59.9999999' THEN 'ACTUAL'
        ELSE 'HISTÓRICO'
    END AS Version
FROM dbo.CUENTAS_TEMPORAL
FOR SYSTEM_TIME ALL
WHERE CuentaID = @CuentaEjemplo
ORDER BY ValidoDesde;
GO

-- ============================================================================
-- EJERCICIO 6: CONSULTAS POINT-IN-TIME
-- Consultar estado de datos en momentos específicos
-- Nivel: Intermedio-Avanzado
-- ============================================================================

/*
PROBLEMA:
Un auditor necesita saber:
1. ¿Cuál era el saldo de todas las cuentas hace 5 minutos?
2. ¿Qué cambios ocurrieron entre dos momentos específicos?
3. ¿Cuál era el estado de una cuenta en una fecha/hora exacta?
*/

-- SOLUCIÓN EJERCICIO 6:

-- 6.1 Saldo de cuentas hace 5 minutos
DECLARE @Hace5Min DATETIME2 = DATEADD(MINUTE, -5, SYSDATETIME());

SELECT 
    CuentaID, 
    NumeroCuenta, 
    Saldo, 
    Estado,
    ValidoDesde,
    ValidoHasta
FROM dbo.CUENTAS_TEMPORAL
FOR SYSTEM_TIME AS OF @Hace5Min;

-- 6.2 Cambios entre dos momentos (BETWEEN)
DECLARE @Inicio DATETIME2 = DATEADD(HOUR, -1, SYSDATETIME());
DECLARE @Fin DATETIME2 = SYSDATETIME();

SELECT 
    CuentaID, 
    Saldo, 
    Estado,
    ValidoDesde,
    ValidoHasta
FROM dbo.CUENTAS_TEMPORAL
FOR SYSTEM_TIME BETWEEN @Inicio AND @Fin
ORDER BY CuentaID, ValidoDesde;

-- 6.3 Versiones contenidas en un rango (CONTAINED IN)
-- Retorna solo versiones que empezaron Y terminaron dentro del rango
SELECT 
    CuentaID, 
    Saldo, 
    Estado,
    ValidoDesde,
    ValidoHasta
FROM dbo.CUENTAS_TEMPORAL
FOR SYSTEM_TIME CONTAINED IN (@Inicio, @Fin)
ORDER BY ValidoDesde;

-- 6.4 Todas las versiones que existieron en algún momento del rango
SELECT 
    CuentaID, 
    Saldo, 
    Estado,
    ValidoDesde,
    ValidoHasta
FROM dbo.CUENTAS_TEMPORAL
FOR SYSTEM_TIME FROM @Inicio TO @Fin
ORDER BY ValidoDesde;
GO

-- ============================================================================
-- EJERCICIO 7: AUDITORÍA DE TRANSACCIONES SOSPECHOSAS
-- Detectar patrones de fraude usando auditoría
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Crear un procedimiento que detecte transacciones sospechosas basándose en:
1. Múltiples transacciones en segundos (posible ataque)
2. Montos inusuales (>3 desviaciones estándar)
3. Transacciones fuera de horario laboral
4. Misma cuenta, múltiples ubicaciones en poco tiempo
*/

-- SOLUCIÓN EJERCICIO 7:

-- Tabla para el ejercicio si no existe
IF OBJECT_ID('Auditoria.TRANSACCIONES_LOG', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.TRANSACCIONES_LOG (
        LogID               BIGINT IDENTITY(1,1) PRIMARY KEY,
        CuentaID            INT NOT NULL,
        TipoTransaccion     VARCHAR(20) NOT NULL,
        Monto               DECIMAL(18,2) NOT NULL,
        FechaHora           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        IPOrigen            VARCHAR(48),
        Ubicacion           VARCHAR(100),
        DispositivoID       VARCHAR(100),
        ResultadoValidacion VARCHAR(20)
    );
    
    -- Insertar datos de ejemplo
    INSERT INTO Auditoria.TRANSACCIONES_LOG 
        (CuentaID, TipoTransaccion, Monto, FechaHora, IPOrigen, Ubicacion)
    VALUES 
        (1, 'RETIRO', 500.00, DATEADD(SECOND, -10, SYSDATETIME()), '192.168.1.1', 'Ciudad A'),
        (1, 'RETIRO', 500.00, DATEADD(SECOND, -8, SYSDATETIME()), '192.168.1.1', 'Ciudad A'),
        (1, 'RETIRO', 500.00, DATEADD(SECOND, -6, SYSDATETIME()), '192.168.1.2', 'Ciudad B'),
        (1, 'RETIRO', 50000.00, DATEADD(SECOND, -4, SYSDATETIME()), '192.168.1.3', 'Ciudad C'),
        (2, 'DEPOSITO', 100.00, DATEADD(HOUR, -2, SYSDATETIME()), '10.0.0.1', 'Ciudad A'),
        (2, 'RETIRO', 1000.00, DATEADD(MINUTE, -30, SYSDATETIME()), '10.0.0.1', 'Ciudad A');
END
GO

-- Procedimiento de detección de fraude
CREATE OR ALTER PROCEDURE Auditoria.SP_DetectarTransaccionesSospechosas
    @VentanaMinutos INT = 5,
    @UmbralTransacciones INT = 3,
    @DesviacionesEstandar DECIMAL(5,2) = 3.0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Tabla temporal para resultados
    CREATE TABLE #Alertas (
        AlertaID INT IDENTITY(1,1),
        CuentaID INT,
        TipoAlerta VARCHAR(50),
        Descripcion NVARCHAR(500),
        Severidad VARCHAR(20),
        FechaDeteccion DATETIME2 DEFAULT SYSDATETIME()
    );
    
    -- 1. MÚLTIPLES TRANSACCIONES EN POCO TIEMPO
    INSERT INTO #Alertas (CuentaID, TipoAlerta, Descripcion, Severidad)
    SELECT 
        CuentaID,
        'ALTA_FRECUENCIA',
        'Se detectaron ' + CAST(COUNT(*) AS VARCHAR) + 
        ' transacciones en los últimos ' + CAST(@VentanaMinutos AS VARCHAR) + ' minutos',
        'ALTA'
    FROM Auditoria.TRANSACCIONES_LOG
    WHERE FechaHora >= DATEADD(MINUTE, -@VentanaMinutos, SYSDATETIME())
    GROUP BY CuentaID
    HAVING COUNT(*) >= @UmbralTransacciones;
    
    -- 2. MONTOS INUSUALES (outliers)
    WITH EstadisticasCuenta AS (
        SELECT 
            CuentaID,
            AVG(Monto) AS MontoPromedio,
            STDEV(Monto) AS DesviacionEstandar
        FROM Auditoria.TRANSACCIONES_LOG
        WHERE FechaHora >= DATEADD(MONTH, -3, SYSDATETIME())
        GROUP BY CuentaID
        HAVING COUNT(*) >= 10
    )
    INSERT INTO #Alertas (CuentaID, TipoAlerta, Descripcion, Severidad)
    SELECT 
        t.CuentaID,
        'MONTO_INUSUAL',
        'Transacción de ' + FORMAT(t.Monto, 'C') + 
        ' excede ' + CAST(@DesviacionesEstandar AS VARCHAR) + 
        ' desviaciones estándar (promedio: ' + FORMAT(e.MontoPromedio, 'C') + ')',
        'MEDIA'
    FROM Auditoria.TRANSACCIONES_LOG t
    INNER JOIN EstadisticasCuenta e ON t.CuentaID = e.CuentaID
    WHERE t.FechaHora >= DATEADD(DAY, -1, SYSDATETIME())
      AND t.Monto > (e.MontoPromedio + (@DesviacionesEstandar * e.DesviacionEstandar));
    
    -- 3. TRANSACCIONES FUERA DE HORARIO (antes de 6am o después de 10pm)
    INSERT INTO #Alertas (CuentaID, TipoAlerta, Descripcion, Severidad)
    SELECT 
        CuentaID,
        'FUERA_HORARIO',
        'Transacción de ' + FORMAT(Monto, 'C') + 
        ' a las ' + FORMAT(FechaHora, 'HH:mm:ss'),
        'BAJA'
    FROM Auditoria.TRANSACCIONES_LOG
    WHERE FechaHora >= DATEADD(DAY, -1, SYSDATETIME())
      AND (DATEPART(HOUR, FechaHora) < 6 OR DATEPART(HOUR, FechaHora) >= 22);
    
    -- 4. MÚLTIPLES UBICACIONES EN POCO TIEMPO (impossible travel)
    ;WITH UbicacionesRecientes AS (
        SELECT 
            CuentaID,
            Ubicacion,
            FechaHora,
            LAG(Ubicacion) OVER (PARTITION BY CuentaID ORDER BY FechaHora) AS UbicacionAnterior,
            LAG(FechaHora) OVER (PARTITION BY CuentaID ORDER BY FechaHora) AS FechaAnterior
        FROM Auditoria.TRANSACCIONES_LOG
        WHERE FechaHora >= DATEADD(HOUR, -1, SYSDATETIME())
    )
    INSERT INTO #Alertas (CuentaID, TipoAlerta, Descripcion, Severidad)
    SELECT 
        CuentaID,
        'UBICACION_IMPOSIBLE',
        'Transacción en "' + Ubicacion + '" solo ' + 
        CAST(DATEDIFF(SECOND, FechaAnterior, FechaHora) AS VARCHAR) + 
        ' segundos después de "' + UbicacionAnterior + '"',
        'CRITICA'
    FROM UbicacionesRecientes
    WHERE Ubicacion <> UbicacionAnterior
      AND DATEDIFF(MINUTE, FechaAnterior, FechaHora) < 30;
    
    -- Retornar alertas ordenadas por severidad
    SELECT 
        AlertaID,
        CuentaID,
        TipoAlerta,
        Descripcion,
        Severidad,
        FechaDeteccion
    FROM #Alertas
    ORDER BY 
        CASE Severidad 
            WHEN 'CRITICA' THEN 1 
            WHEN 'ALTA' THEN 2 
            WHEN 'MEDIA' THEN 3 
            ELSE 4 
        END,
        FechaDeteccion DESC;
    
    DROP TABLE #Alertas;
END;
GO

-- Ejecutar detección
EXEC Auditoria.SP_DetectarTransaccionesSospechosas 
    @VentanaMinutos = 5, 
    @UmbralTransacciones = 3;
GO

-- ============================================================================
-- EJERCICIO 8: REPORTE DE COMPLIANCE
-- Generar reporte de auditoría para reguladores
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Crear un procedimiento que genere un reporte de compliance que incluya:
1. Resumen de actividad por tipo de operación
2. Usuarios con más modificaciones
3. Operaciones en horarios inusuales
4. Tablas más modificadas
5. Estadísticas de retención de datos de auditoría
*/

-- SOLUCIÓN EJERCICIO 8:

CREATE OR ALTER PROCEDURE Auditoria.SP_ReporteCompliance
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Valores por defecto: último mes
    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)));
    SET @FechaFin = ISNULL(@FechaFin, CAST(GETDATE() AS DATE));
    
    PRINT '=====================================================';
    PRINT '       REPORTE DE COMPLIANCE - BANCODB';
    PRINT '=====================================================';
    PRINT 'Período: ' + CONVERT(VARCHAR, @FechaInicio, 103) + 
          ' a ' + CONVERT(VARCHAR, @FechaFin, 103);
    PRINT '-----------------------------------------------------';
    
    -- 1. RESUMEN DE ACTIVIDAD POR TIPO
    PRINT '';
    PRINT '1. RESUMEN DE ACTIVIDAD POR TIPO DE OPERACIÓN';
    PRINT '-----------------------------------------------------';
    
    SELECT 
        CASE TipoOperacion
            WHEN 'I' THEN 'INSERT'
            WHEN 'U' THEN 'UPDATE'
            WHEN 'D' THEN 'DELETE'
        END AS Operacion,
        COUNT(*) AS TotalOperaciones,
        COUNT(DISTINCT UsuarioDB) AS UsuariosUnicos,
        MIN(FechaHora) AS PrimeraOperacion,
        MAX(FechaHora) AS UltimaOperacion
    FROM Auditoria.AUD_CLIENTES
    WHERE CAST(FechaHora AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY TipoOperacion
    ORDER BY TotalOperaciones DESC;
    
    -- 2. USUARIOS CON MÁS MODIFICACIONES
    PRINT '';
    PRINT '2. TOP 10 USUARIOS CON MÁS MODIFICACIONES';
    PRINT '-----------------------------------------------------';
    
    SELECT TOP 10
        UsuarioDB,
        COUNT(*) AS TotalModificaciones,
        SUM(CASE WHEN TipoOperacion = 'I' THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN TipoOperacion = 'U' THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN TipoOperacion = 'D' THEN 1 ELSE 0 END) AS Deletes
    FROM Auditoria.AUD_CLIENTES
    WHERE CAST(FechaHora AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY UsuarioDB
    ORDER BY TotalModificaciones DESC;
    
    -- 3. OPERACIONES EN HORARIOS INUSUALES
    PRINT '';
    PRINT '3. OPERACIONES FUERA DE HORARIO LABORAL (6PM-8AM)';
    PRINT '-----------------------------------------------------';
    
    SELECT 
        UsuarioDB,
        COUNT(*) AS OperacionesFueraHorario,
        STRING_AGG(CONVERT(VARCHAR, FechaHora, 120), ', ') AS Horarios
    FROM Auditoria.AUD_CLIENTES
    WHERE CAST(FechaHora AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (DATEPART(HOUR, FechaHora) < 8 OR DATEPART(HOUR, FechaHora) >= 18)
    GROUP BY UsuarioDB
    HAVING COUNT(*) > 0
    ORDER BY OperacionesFueraHorario DESC;
    
    -- 4. ACTIVIDAD POR DÍA DE LA SEMANA
    PRINT '';
    PRINT '4. DISTRIBUCIÓN POR DÍA DE LA SEMANA';
    PRINT '-----------------------------------------------------';
    
    SELECT 
        DATENAME(WEEKDAY, FechaHora) AS DiaSemana,
        DATEPART(WEEKDAY, FechaHora) AS NumDia,
        COUNT(*) AS TotalOperaciones
    FROM Auditoria.AUD_CLIENTES
    WHERE CAST(FechaHora AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY DATENAME(WEEKDAY, FechaHora), DATEPART(WEEKDAY, FechaHora)
    ORDER BY NumDia;
    
    -- 5. ESTADÍSTICAS DE RETENCIÓN
    PRINT '';
    PRINT '5. ESTADÍSTICAS DE RETENCIÓN DE AUDITORÍA';
    PRINT '-----------------------------------------------------';
    
    SELECT 
        'AUD_CLIENTES' AS Tabla,
        COUNT(*) AS TotalRegistros,
        MIN(FechaHora) AS RegistroMasAntiguo,
        MAX(FechaHora) AS RegistroMasReciente,
        DATEDIFF(DAY, MIN(FechaHora), MAX(FechaHora)) AS DiasDeHistorial
    FROM Auditoria.AUD_CLIENTES;
    
    PRINT '';
    PRINT '=====================================================';
    PRINT '       FIN DEL REPORTE DE COMPLIANCE';
    PRINT '=====================================================';
END;
GO

-- Ejecutar reporte
EXEC Auditoria.SP_ReporteCompliance;
GO

-- ============================================================================
-- EJERCICIO 9: CONFIGURAR SQL SERVER AUDIT
-- Crear auditoría nativa para eventos de login y permisos
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Configurar SQL Server Audit para registrar:
1. Intentos de login fallidos
2. Cambios de permisos en la base de datos
3. Acceso a tablas sensibles (CLIENTES, CUENTAS)

NOTA: Requiere permisos de administrador y verificar que el directorio existe
*/

-- SOLUCIÓN EJERCICIO 9:

/*
-- PASO 1: Crear Server Audit (nivel servidor)
-- NOTA: Descomentar y ajustar ruta según tu ambiente

CREATE SERVER AUDIT AUD_BancoDB_Security
TO FILE (
    FILEPATH = 'C:\SQLAudit\',
    MAXSIZE = 100 MB,
    MAX_ROLLOVER_FILES = 10,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

-- PASO 2: Habilitar Server Audit
ALTER SERVER AUDIT AUD_BancoDB_Security WITH (STATE = ON);
GO

-- PASO 3: Crear Server Audit Specification (eventos de servidor)
CREATE SERVER AUDIT SPECIFICATION AUD_ServerSpec_Logins
FOR SERVER AUDIT AUD_BancoDB_Security
ADD (FAILED_LOGIN_GROUP),           -- Logins fallidos
ADD (SUCCESSFUL_LOGIN_GROUP),       -- Logins exitosos
ADD (SERVER_PERMISSION_CHANGE_GROUP); -- Cambios de permisos servidor
GO

ALTER SERVER AUDIT SPECIFICATION AUD_ServerSpec_Logins WITH (STATE = ON);
GO

-- PASO 4: Crear Database Audit Specification (eventos de BD)
USE BancoDB;
GO

CREATE DATABASE AUDIT SPECIFICATION AUD_DBSpec_Sensibles
FOR SERVER AUDIT AUD_BancoDB_Security
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.CLIENTES BY public),
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.CUENTAS BY public),
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP);
GO

ALTER DATABASE AUDIT SPECIFICATION AUD_DBSpec_Sensibles WITH (STATE = ON);
GO
*/

-- Consultar auditorías configuradas (sin necesidad de crearlas)
SELECT 
    a.name AS AuditName,
    a.type_desc AS AuditType,
    a.on_failure_desc AS OnFailure,
    CASE a.is_state_enabled WHEN 1 THEN 'ENABLED' ELSE 'DISABLED' END AS Estado
FROM sys.server_audits a;

-- Consultar especificaciones de servidor
SELECT 
    s.name AS SpecName,
    a.name AS AuditName,
    CASE s.is_state_enabled WHEN 1 THEN 'ENABLED' ELSE 'DISABLED' END AS Estado
FROM sys.server_audit_specifications s
LEFT JOIN sys.server_audits a ON s.audit_guid = a.audit_guid;
GO

-- ============================================================================
-- EJERCICIO 10: LIMPIEZA Y RETENCIÓN DE DATOS DE AUDITORÍA
-- Implementar política de retención automática
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Crear procedimiento para:
1. Archivar registros de auditoría antiguos (>90 días) a tabla de archivo
2. Eliminar registros archivados de la tabla principal
3. Registrar la operación de limpieza
4. Generar estadísticas de espacio recuperado

NOTA: En producción esto se ejecutaría como Job de SQL Agent
*/

-- SOLUCIÓN EJERCICIO 10:

-- Tabla de archivo para auditoría histórica
IF OBJECT_ID('Auditoria.AUD_CLIENTES_Archivo', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.AUD_CLIENTES_Archivo (
        AuditID             BIGINT PRIMARY KEY,
        TipoOperacion       CHAR(1) NOT NULL,
        ClienteID           INT NOT NULL,
        DatosAnteriores     NVARCHAR(MAX) NULL,
        DatosNuevos         NVARCHAR(MAX) NULL,
        UsuarioDB           NVARCHAR(128) NOT NULL,
        UsuarioApp          NVARCHAR(128) NULL,
        FechaHora           DATETIME2 NOT NULL,
        NombreHost          NVARCHAR(128) NOT NULL,
        NombreApp           NVARCHAR(128) NOT NULL,
        DireccionIP         VARCHAR(48) NULL,
        FechaArchivado      DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

-- Log de operaciones de mantenimiento
IF OBJECT_ID('Auditoria.LOG_Mantenimiento', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.LOG_Mantenimiento (
        LogID               INT IDENTITY(1,1) PRIMARY KEY,
        Operacion           VARCHAR(50) NOT NULL,
        TablaAfectada       NVARCHAR(128) NOT NULL,
        RegistrosAfectados  INT NOT NULL,
        FechaEjecucion      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        DuracionMs          INT NULL,
        Detalles            NVARCHAR(500) NULL
    );
END
GO

-- Procedimiento de retención
CREATE OR ALTER PROCEDURE Auditoria.SP_RetencionAuditoria
    @DiasRetencion INT = 90,
    @TamañoBatch INT = 10000,
    @SoloSimular BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaCorte DATETIME2 = DATEADD(DAY, -@DiasRetencion, SYSDATETIME());
    DECLARE @TotalRegistros INT;
    DECLARE @RegistrosArchivados INT = 0;
    DECLARE @RegistrosEliminados INT = 0;
    DECLARE @InicioOp DATETIME2 = SYSDATETIME();
    DECLARE @BatchActual INT;
    
    -- Contar registros a procesar
    SELECT @TotalRegistros = COUNT(*)
    FROM Auditoria.AUD_CLIENTES
    WHERE FechaHora < @FechaCorte;
    
    PRINT '=====================================================';
    PRINT '  PROCESO DE RETENCIÓN DE AUDITORÍA';
    PRINT '=====================================================';
    PRINT 'Fecha de corte: ' + CONVERT(VARCHAR, @FechaCorte, 120);
    PRINT 'Registros a procesar: ' + CAST(@TotalRegistros AS VARCHAR);
    PRINT 'Modo: ' + CASE WHEN @SoloSimular = 1 THEN 'SIMULACIÓN' ELSE 'EJECUCIÓN REAL' END;
    PRINT '-----------------------------------------------------';
    
    IF @SoloSimular = 1
    BEGIN
        PRINT 'SIMULACIÓN: No se realizarán cambios.';
        RETURN;
    END
    
    IF @TotalRegistros = 0
    BEGIN
        PRINT 'No hay registros para archivar.';
        RETURN;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Archivar en batches
        WHILE @RegistrosArchivados < @TotalRegistros
        BEGIN
            -- Insertar batch en archivo
            INSERT INTO Auditoria.AUD_CLIENTES_Archivo (
                AuditID, TipoOperacion, ClienteID, DatosAnteriores, 
                DatosNuevos, UsuarioDB, UsuarioApp, FechaHora, 
                NombreHost, NombreApp, DireccionIP
            )
            SELECT TOP (@TamañoBatch)
                AuditID, TipoOperacion, ClienteID, DatosAnteriores, 
                DatosNuevos, UsuarioDB, UsuarioApp, FechaHora, 
                NombreHost, NombreApp, DireccionIP
            FROM Auditoria.AUD_CLIENTES
            WHERE FechaHora < @FechaCorte
              AND AuditID NOT IN (SELECT AuditID FROM Auditoria.AUD_CLIENTES_Archivo)
            ORDER BY AuditID;
            
            SET @BatchActual = @@ROWCOUNT;
            SET @RegistrosArchivados += @BatchActual;
            
            PRINT 'Archivados: ' + CAST(@RegistrosArchivados AS VARCHAR) + 
                  ' de ' + CAST(@TotalRegistros AS VARCHAR);
            
            IF @BatchActual < @TamañoBatch
                BREAK;
        END
        
        -- Eliminar registros archivados de tabla principal
        DELETE FROM Auditoria.AUD_CLIENTES
        WHERE FechaHora < @FechaCorte
          AND AuditID IN (SELECT AuditID FROM Auditoria.AUD_CLIENTES_Archivo);
        
        SET @RegistrosEliminados = @@ROWCOUNT;
        
        -- Registrar operación
        INSERT INTO Auditoria.LOG_Mantenimiento (
            Operacion, TablaAfectada, RegistrosAfectados, DuracionMs, Detalles
        )
        VALUES (
            'RETENCION_AUDITORIA',
            'AUD_CLIENTES',
            @RegistrosArchivados,
            DATEDIFF(MILLISECOND, @InicioOp, SYSDATETIME()),
            'Archivados: ' + CAST(@RegistrosArchivados AS VARCHAR) + 
            ', Eliminados: ' + CAST(@RegistrosEliminados AS VARCHAR) +
            ', Fecha corte: ' + CONVERT(VARCHAR, @FechaCorte, 120)
        );
        
        COMMIT TRANSACTION;
        
        PRINT '-----------------------------------------------------';
        PRINT 'COMPLETADO:';
        PRINT '  Registros archivados: ' + CAST(@RegistrosArchivados AS VARCHAR);
        PRINT '  Registros eliminados: ' + CAST(@RegistrosEliminados AS VARCHAR);
        PRINT '  Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioOp, SYSDATETIME()) AS VARCHAR) + ' ms';
        PRINT '=====================================================';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        
        INSERT INTO Auditoria.LOG_Mantenimiento (
            Operacion, TablaAfectada, RegistrosAfectados, Detalles
        )
        VALUES (
            'RETENCION_AUDITORIA_ERROR',
            'AUD_CLIENTES',
            0,
            'Error: ' + ERROR_MESSAGE()
        );
        
        THROW;
    END CATCH
END;
GO

-- Probar en modo simulación
EXEC Auditoria.SP_RetencionAuditoria 
    @DiasRetencion = 90, 
    @SoloSimular = 1;
GO

-- ============================================================================
-- LIMPIEZA DE OBJETOS DE EJERCICIOS (OPCIONAL)
-- ============================================================================

/*
-- Descomentar para limpiar objetos creados en los ejercicios

-- Deshabilitar versionado antes de eliminar tabla temporal
IF OBJECT_ID('dbo.CUENTAS_TEMPORAL', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CUENTAS_TEMPORAL SET (SYSTEM_VERSIONING = OFF);
    DROP TABLE dbo.CUENTAS_TEMPORAL;
    DROP TABLE IF EXISTS dbo.CUENTAS_TEMPORAL_History;
END

-- Eliminar trigger
DROP TRIGGER IF EXISTS dbo.TR_CLIENTES_Auditoria;

-- Eliminar procedimientos
DROP PROCEDURE IF EXISTS Auditoria.SP_DetectarTransaccionesSospechosas;
DROP PROCEDURE IF EXISTS Auditoria.SP_ReporteCompliance;
DROP PROCEDURE IF EXISTS Auditoria.SP_RetencionAuditoria;

-- Eliminar tablas de auditoría
DROP TABLE IF EXISTS Auditoria.AUD_CLIENTES;
DROP TABLE IF EXISTS Auditoria.AUD_CLIENTES_Archivo;
DROP TABLE IF EXISTS Auditoria.LOG_Mantenimiento;
DROP TABLE IF EXISTS Auditoria.TRANSACCIONES_LOG;

-- Eliminar esquema (si está vacío)
-- DROP SCHEMA IF EXISTS Auditoria;
*/

PRINT '';
PRINT '=====================================================';
PRINT '   EJERCICIOS DE AUDITORÍA Y COMPLIANCE COMPLETADOS';
PRINT '   SQL Intermedio 2026 - Sesión 15';
PRINT '=====================================================';
GO
