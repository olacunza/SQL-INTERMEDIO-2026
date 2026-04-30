/*
================================================================================
        SQL INTERMEDIO 2026 - SESIÓN 16: WORKSHOP FINAL DE TUNING
        🎓 SESIÓN FINAL DEL CURSO
================================================================================
Instructor: [Nombre del Instructor]
Duración: 2 horas
Base de datos: BancoDB
Nivel: Intermedio-Avanzado

OBJETIVOS:
    • Integrar todos los conceptos del curso en un caso práctico
    • Diagnosticar problemas de rendimiento en escenarios reales
    • Aplicar técnicas de optimización de forma sistemática
    • Desarrollar un plan de tuning completo
    • Certificar conocimientos adquiridos

CONTENIDO:
    1. Escenario del Workshop - Sistema Bancario Lento
    2. Diagnóstico Inicial - Identificación de Problemas
    3. Fase 1: Análisis de Queries Lentas
    4. Fase 2: Optimización de Índices
    5. Fase 3: Refactorización de Código
    6. Fase 4: Configuración y Mantenimiento
    7. Validación de Mejoras
    8. Documentación y Mejores Prácticas

CONCEPTOS INTEGRADOS:
    - Transacciones y Bloqueos (Sesión 1)
    - Manejo de Errores (Sesión 2)
    - Diseño y Performance (Sesión 3)
    - Índices Estratégicos (Sesión 4)
    - Procedimientos Almacenados (Sesión 5)
    - Funciones y Vistas (Sesión 6)
    - CTEs y Recursividad (Sesión 7)
    - Window Functions (Sesión 8)
    - Pivoting y Agregaciones (Sesión 9)
    - Batching y Operaciones Masivas (Sesión 10)
    - Tablas Temporales (Sesión 11)
    - Set-Based vs Cursores (Sesión 12)
    - SQL Dinámico Seguro (Sesión 13)
    - SQL Agent Jobs (Sesión 14)
    - Auditoría y Compliance (Sesión 15)
================================================================================
*/

USE BancoDB;
GO

-- ============================================================================
-- PARTE 1: ESCENARIO DEL WORKSHOP - SISTEMA BANCARIO CON PROBLEMAS
-- ============================================================================

/*
   📋 CONTEXTO DEL CASO
   ====================
   
   El sistema bancario BancoDB presenta los siguientes síntomas:
   
   1. El reporte mensual de transacciones tarda >30 segundos
   2. Las transferencias entre cuentas a veces se bloquean
   3. El cierre de día tarda más de 2 horas
   4. Los usuarios reportan lentitud en consultas de saldo
   5. El proceso de auditoría consume demasiados recursos
   6. Los Jobs de mantenimiento fallan frecuentemente
   
   OBJETIVO: Diagnosticar y solucionar estos problemas aplicando
   todas las técnicas aprendidas en el curso.
   
   MÉTRICAS DE ÉXITO:
   - Reporte mensual: < 5 segundos
   - Transferencias: 0 deadlocks
   - Cierre de día: < 15 minutos
   - Consulta de saldo: < 100ms
*/

-- ============================================================================
-- SETUP - CREAR ESTRUCTURAS CON PROBLEMAS INTENCIONALES
-- ============================================================================

PRINT '=====================================================';
PRINT '  WORKSHOP FINAL DE TUNING - SETUP INICIAL';
PRINT '=====================================================';
GO

-- -----------------------------------------------------------------------------
-- 1.1 TABLAS BASE DEL SISTEMA BANCARIO (con problemas de diseño)
-- -----------------------------------------------------------------------------

-- Tabla de CLIENTES (problemas: sin índices adecuados)
IF OBJECT_ID('dbo.CLIENTES_WS', 'U') IS NOT NULL DROP TABLE dbo.CLIENTES_WS;
CREATE TABLE dbo.CLIENTES_WS (
    ClienteID       INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    NumeroCliente   VARCHAR(20) NOT NULL,      -- Debería tener índice único
    Nombre          NVARCHAR(100) NOT NULL,
    Apellido        NVARCHAR(100) NOT NULL,
    Email           NVARCHAR(200),
    Telefono        VARCHAR(20),
    FechaNacimiento DATE,
    TipoCliente     VARCHAR(20) DEFAULT 'REGULAR',  -- Sin índice para filtros
    Estado          VARCHAR(20) DEFAULT 'ACTIVO',
    FechaRegistro   DATETIME2 DEFAULT SYSDATETIME(),
    UltimaActividad DATETIME2
);
GO

-- Tabla de CUENTAS (problemas: FK sin índice, columnas mal tipadas)
IF OBJECT_ID('dbo.CUENTAS_WS', 'U') IS NOT NULL DROP TABLE dbo.CUENTAS_WS;
CREATE TABLE dbo.CUENTAS_WS (
    CuentaID        INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    ClienteID       INT NOT NULL,               -- FK sin índice!
    NumeroCuenta    VARCHAR(20) NOT NULL,
    TipoCuenta      VARCHAR(50) NOT NULL,       -- Muy ancho
    Saldo           FLOAT NOT NULL DEFAULT 0,   -- FLOAT para dinero! Error común
    SaldoDisponible FLOAT NOT NULL DEFAULT 0,
    LimiteCredito   FLOAT DEFAULT 0,
    Moneda          VARCHAR(10) DEFAULT 'MXN',
    Estado          VARCHAR(20) DEFAULT 'ACTIVA',
    FechaApertura   DATETIME DEFAULT GETDATE(),
    FechaUltimoMov  DATETIME
);
GO

-- Tabla de TRANSACCIONES (problemas: sin particionamiento, índices inadecuados)
IF OBJECT_ID('dbo.TRANSACCIONES_WS', 'U') IS NOT NULL DROP TABLE dbo.TRANSACCIONES_WS;
CREATE TABLE dbo.TRANSACCIONES_WS (
    TransaccionID   BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    CuentaOrigenID  INT,                        -- Sin índice
    CuentaDestinoID INT,                        -- Sin índice
    TipoTransaccion VARCHAR(50) NOT NULL,
    Monto           FLOAT NOT NULL,             -- FLOAT!
    MontoComision   FLOAT DEFAULT 0,
    FechaTransaccion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaProceso    DATETIME,
    Estado          VARCHAR(20) DEFAULT 'PENDIENTE',
    Referencia      VARCHAR(100),
    Descripcion     NVARCHAR(500),
    CanalOrigen     VARCHAR(50),
    IPOrigen        VARCHAR(50),
    UsuarioProceso  VARCHAR(100)
);
GO

-- Tabla de LOG de AUDITORIA (problemas: sin índices, sin partición)
IF OBJECT_ID('dbo.LOG_AUDITORIA_WS', 'U') IS NOT NULL DROP TABLE dbo.LOG_AUDITORIA_WS;
CREATE TABLE dbo.LOG_AUDITORIA_WS (
    LogID           BIGINT IDENTITY(1,1) PRIMARY KEY,
    TablaAfectada   VARCHAR(100),
    Operacion       VARCHAR(20),
    RegistroID      INT,
    DatosAnteriores NVARCHAR(MAX),
    DatosNuevos     NVARCHAR(MAX),
    Usuario         VARCHAR(100) DEFAULT SYSTEM_USER,
    FechaHora       DATETIME2 DEFAULT SYSDATETIME(),
    Aplicacion      VARCHAR(100) DEFAULT APP_NAME()
);
GO

-- -----------------------------------------------------------------------------
-- 1.2 POBLAR CON DATOS DE PRUEBA
-- -----------------------------------------------------------------------------

PRINT 'Generando datos de prueba...';

-- Generar 10,000 clientes
;WITH NumerosCTE AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM NumerosCTE WHERE n < 10000
)
INSERT INTO dbo.CLIENTES_WS (NumeroCliente, Nombre, Apellido, Email, TipoCliente, Estado)
SELECT 
    'CLI-' + RIGHT('00000' + CAST(n AS VARCHAR), 6),
    'Nombre' + CAST(n AS VARCHAR),
    'Apellido' + CAST(n % 1000 AS VARCHAR),
    'cliente' + CAST(n AS VARCHAR) + '@banco.com',
    CASE n % 5 
        WHEN 0 THEN 'VIP'
        WHEN 1 THEN 'PREMIUM'
        ELSE 'REGULAR'
    END,
    CASE WHEN n % 20 = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM NumerosCTE
OPTION (MAXRECURSION 10000);

PRINT 'Clientes creados: 10,000';

-- Generar 25,000 cuentas (2-3 por cliente en promedio)
;WITH NumerosCTE AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM NumerosCTE WHERE n < 25000
)
INSERT INTO dbo.CUENTAS_WS (ClienteID, NumeroCuenta, TipoCuenta, Saldo, SaldoDisponible, Estado)
SELECT 
    (n % 10000) + 1,
    '4000-' + RIGHT('0000' + CAST(n / 1000 AS VARCHAR), 4) + '-' + RIGHT('0000' + CAST(n AS VARCHAR), 4),
    CASE n % 4
        WHEN 0 THEN 'AHORROS'
        WHEN 1 THEN 'CHEQUES'
        WHEN 2 THEN 'NOMINA'
        ELSE 'INVERSION'
    END,
    CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS FLOAT) / 100,
    CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS FLOAT) / 100,
    CASE WHEN n % 50 = 0 THEN 'BLOQUEADA' ELSE 'ACTIVA' END
FROM NumerosCTE
OPTION (MAXRECURSION 25000);

PRINT 'Cuentas creadas: 25,000';

-- Generar 500,000 transacciones (distribuidas en último año)
PRINT 'Generando transacciones (esto puede tardar ~1 minuto)...';

;WITH NumerosCTE AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM NumerosCTE WHERE n < 500000
),
TransData AS (
    SELECT 
        n,
        (n % 25000) + 1 AS CuentaOrigenID,
        CASE WHEN n % 3 = 0 THEN ((n + 1000) % 25000) + 1 ELSE NULL END AS CuentaDestinoID,
        CASE n % 6
            WHEN 0 THEN 'DEPOSITO'
            WHEN 1 THEN 'RETIRO'
            WHEN 2 THEN 'TRANSFERENCIA'
            WHEN 3 THEN 'PAGO_SERVICIO'
            WHEN 4 THEN 'COMPRA'
            ELSE 'COMISION'
        END AS TipoTrans,
        CAST(ABS(CHECKSUM(NEWID())) % 100000 AS FLOAT) / 100 AS Monto,
        DATEADD(SECOND, -(n * 60), GETDATE()) AS FechaTrans,
        CASE n % 10 WHEN 0 THEN 'PENDIENTE' WHEN 1 THEN 'FALLIDA' ELSE 'COMPLETADA' END AS Estado
    FROM NumerosCTE
)
INSERT INTO dbo.TRANSACCIONES_WS (
    CuentaOrigenID, CuentaDestinoID, TipoTransaccion, Monto, 
    FechaTransaccion, Estado, CanalOrigen
)
SELECT 
    CuentaOrigenID, CuentaDestinoID, TipoTrans, Monto,
    FechaTrans, Estado,
    CASE n % 4 WHEN 0 THEN 'WEB' WHEN 1 THEN 'MOVIL' WHEN 2 THEN 'ATM' ELSE 'SUCURSAL' END
FROM TransData
OPTION (MAXRECURSION 0);

PRINT 'Transacciones creadas: 500,000';
GO

-- ============================================================================
-- PARTE 2: CONSULTAS PROBLEMÁTICAS - DIAGNOSTICAR Y OPTIMIZAR
-- ============================================================================

/*
   🔍 PROBLEMA #1: REPORTE MENSUAL DE TRANSACCIONES LENTO
   ======================================================
   
   Esta consulta tarda >30 segundos. El negocio necesita que tarde <5 segundos.
   
   DIAGNÓSTICO REQUERIDO:
   1. Analizar plan de ejecución
   2. Identificar operadores costosos
   3. Verificar estadísticas
   4. Proponer índices
*/

-- Query problemática original (NO OPTIMIZADA)
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT '=== QUERY ORIGINAL - REPORTE MENSUAL ===';

SELECT 
    c.Nombre + ' ' + c.Apellido AS NombreCompleto,
    cu.NumeroCuenta,
    cu.TipoCuenta,
    t.TipoTransaccion,
    COUNT(*) AS NumTransacciones,
    SUM(t.Monto) AS MontoTotal,
    AVG(t.Monto) AS MontoPromedio,
    MIN(t.FechaTransaccion) AS PrimeraTransaccion,
    MAX(t.FechaTransaccion) AS UltimaTransaccion
FROM dbo.TRANSACCIONES_WS t
INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
INNER JOIN dbo.CLIENTES_WS c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= DATEADD(MONTH, -1, GETDATE())
  AND t.Estado = 'COMPLETADA'
  AND cu.Estado = 'ACTIVA'
  AND c.Estado = 'ACTIVO'
GROUP BY c.Nombre, c.Apellido, cu.NumeroCuenta, cu.TipoCuenta, t.TipoTransaccion
ORDER BY MontoTotal DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- ============================================================================
-- SOLUCIÓN #1: ÍNDICES ESTRATÉGICOS PARA EL REPORTE
-- ============================================================================

PRINT '=== APLICANDO OPTIMIZACIÓN #1: ÍNDICES ===';

-- Índice para filtro de fecha y estado en transacciones
CREATE NONCLUSTERED INDEX IX_TRANS_WS_Fecha_Estado
ON dbo.TRANSACCIONES_WS (FechaTransaccion, Estado)
INCLUDE (CuentaOrigenID, TipoTransaccion, Monto);
GO

-- Índice para JOIN de cuentas
CREATE NONCLUSTERED INDEX IX_CUENTAS_WS_Estado
ON dbo.CUENTAS_WS (Estado, CuentaID)
INCLUDE (ClienteID, NumeroCuenta, TipoCuenta);
GO

-- Índice para FK en cuentas
CREATE NONCLUSTERED INDEX IX_CUENTAS_WS_ClienteID
ON dbo.CUENTAS_WS (ClienteID);
GO

-- Índice para filtro de clientes
CREATE NONCLUSTERED INDEX IX_CLIENTES_WS_Estado
ON dbo.CLIENTES_WS (Estado)
INCLUDE (Nombre, Apellido);
GO

PRINT 'Índices creados. Ejecutando query optimizada...';
GO

-- Verificar mejora
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT '=== QUERY CON ÍNDICES - REPORTE MENSUAL ===';

SELECT 
    c.Nombre + ' ' + c.Apellido AS NombreCompleto,
    cu.NumeroCuenta,
    cu.TipoCuenta,
    t.TipoTransaccion,
    COUNT(*) AS NumTransacciones,
    SUM(t.Monto) AS MontoTotal,
    AVG(t.Monto) AS MontoPromedio,
    MIN(t.FechaTransaccion) AS PrimeraTransaccion,
    MAX(t.FechaTransaccion) AS UltimaTransaccion
FROM dbo.TRANSACCIONES_WS t
INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
INNER JOIN dbo.CLIENTES_WS c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= DATEADD(MONTH, -1, GETDATE())
  AND t.Estado = 'COMPLETADA'
  AND cu.Estado = 'ACTIVA'
  AND c.Estado = 'ACTIVO'
GROUP BY c.Nombre, c.Apellido, cu.NumeroCuenta, cu.TipoCuenta, t.TipoTransaccion
ORDER BY MontoTotal DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- ============================================================================
-- PARTE 3: PROBLEMA DE TRANSFERENCIAS CON DEADLOCKS
-- ============================================================================

/*
   🔍 PROBLEMA #2: DEADLOCKS EN TRANSFERENCIAS
   ===========================================
   
   El proceso de transferencia actual causa deadlocks frecuentes
   cuando múltiples usuarios transfieren simultáneamente.
   
   CAUSA: Orden inconsistente de bloqueos en las cuentas
*/

-- Procedimiento PROBLEMÁTICO (causa deadlocks)
CREATE OR ALTER PROCEDURE dbo.SP_Transferencia_PROBLEMATICA
    @CuentaOrigenID INT,
    @CuentaDestinoID INT,
    @Monto DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    -- PROBLEMA: No hay orden consistente de bloqueos
    -- Si otra sesión hace la transferencia inversa, DEADLOCK
    
    -- Debitar origen
    UPDATE dbo.CUENTAS_WS
    SET Saldo = Saldo - @Monto,
        FechaUltimoMov = GETDATE()
    WHERE CuentaID = @CuentaOrigenID;
    
    -- Simular latencia (aumenta probabilidad de deadlock)
    WAITFOR DELAY '00:00:00.100';
    
    -- Acreditar destino
    UPDATE dbo.CUENTAS_WS
    SET Saldo = Saldo + @Monto,
        FechaUltimoMov = GETDATE()
    WHERE CuentaID = @CuentaDestinoID;
    
    -- Registrar transacción
    INSERT INTO dbo.TRANSACCIONES_WS (
        CuentaOrigenID, CuentaDestinoID, TipoTransaccion, 
        Monto, Estado, FechaTransaccion
    )
    VALUES (
        @CuentaOrigenID, @CuentaDestinoID, 'TRANSFERENCIA',
        @Monto, 'COMPLETADA', GETDATE()
    );
    
    COMMIT TRANSACTION;
END;
GO

-- ============================================================================
-- SOLUCIÓN #2: PROCEDIMIENTO OPTIMIZADO SIN DEADLOCKS
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.SP_Transferencia_OPTIMIZADA
    @CuentaOrigenID INT,
    @CuentaDestinoID INT,
    @Monto DECIMAL(18,2),
    @Referencia VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    -- Variables para validación
    DECLARE @SaldoOrigen DECIMAL(18,2);
    DECLARE @EstadoOrigen VARCHAR(20);
    DECLARE @EstadoDestino VARCHAR(20);
    DECLARE @ErrorMsg NVARCHAR(500);
    
    -- TÉCNICA #1: Orden consistente de bloqueos (siempre menor ID primero)
    DECLARE @PrimeraID INT = CASE WHEN @CuentaOrigenID < @CuentaDestinoID 
                                   THEN @CuentaOrigenID ELSE @CuentaDestinoID END;
    DECLARE @SegundaID INT = CASE WHEN @CuentaOrigenID < @CuentaDestinoID 
                                   THEN @CuentaDestinoID ELSE @CuentaOrigenID END;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Obtener bloqueo en orden consistente con UPDLOCK, HOLDLOCK
        SELECT @SaldoOrigen = CASE WHEN CuentaID = @CuentaOrigenID THEN Saldo ELSE NULL END,
               @EstadoOrigen = CASE WHEN CuentaID = @CuentaOrigenID THEN Estado ELSE @EstadoOrigen END,
               @EstadoDestino = CASE WHEN CuentaID = @CuentaDestinoID THEN Estado ELSE @EstadoDestino END
        FROM dbo.CUENTAS_WS WITH (UPDLOCK, HOLDLOCK)
        WHERE CuentaID IN (@PrimeraID, @SegundaID);
        
        -- Validaciones de negocio
        IF @EstadoOrigen <> 'ACTIVA'
        BEGIN
            SET @ErrorMsg = 'Cuenta origen no está activa';
            THROW 50001, @ErrorMsg, 1;
        END
        
        IF @EstadoDestino <> 'ACTIVA'
        BEGIN
            SET @ErrorMsg = 'Cuenta destino no está activa';
            THROW 50002, @ErrorMsg, 1;
        END
        
        IF @SaldoOrigen < @Monto
        BEGIN
            SET @ErrorMsg = 'Saldo insuficiente. Disponible: ' + CAST(@SaldoOrigen AS VARCHAR);
            THROW 50003, @ErrorMsg, 1;
        END
        
        -- Ejecutar transferencia (ya tenemos los bloqueos)
        UPDATE dbo.CUENTAS_WS
        SET Saldo = Saldo - @Monto,
            SaldoDisponible = SaldoDisponible - @Monto,
            FechaUltimoMov = GETDATE()
        WHERE CuentaID = @CuentaOrigenID;
        
        UPDATE dbo.CUENTAS_WS
        SET Saldo = Saldo + @Monto,
            SaldoDisponible = SaldoDisponible + @Monto,
            FechaUltimoMov = GETDATE()
        WHERE CuentaID = @CuentaDestinoID;
        
        -- Registrar transacción
        INSERT INTO dbo.TRANSACCIONES_WS (
            CuentaOrigenID, CuentaDestinoID, TipoTransaccion, 
            Monto, Estado, FechaTransaccion, Referencia
        )
        VALUES (
            @CuentaOrigenID, @CuentaDestinoID, 'TRANSFERENCIA',
            @Monto, 'COMPLETADA', GETDATE(), @Referencia
        );
        
        COMMIT TRANSACTION;
        
        SELECT 'OK' AS Resultado, 'Transferencia completada' AS Mensaje;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Log del error
        INSERT INTO dbo.LOG_AUDITORIA_WS (TablaAfectada, Operacion, Registroid, DatosNuevos)
        VALUES ('TRANSFERENCIA', 'ERROR', @CuentaOrigenID, 
                'Error: ' + ERROR_MESSAGE() + ' | Destino: ' + CAST(@CuentaDestinoID AS VARCHAR));
        
        SELECT 'ERROR' AS Resultado, ERROR_MESSAGE() AS Mensaje;
    END CATCH
END;
GO

PRINT 'Procedimiento de transferencia optimizado creado.';
GO

-- ============================================================================
-- PARTE 4: PROCESO DE CIERRE DE DÍA OPTIMIZADO
-- ============================================================================

/*
   🔍 PROBLEMA #3: CIERRE DE DÍA TARDA >2 HORAS
   ============================================
   
   El proceso actual:
   - Usa cursores para procesar transacciones una por una
   - No usa batching
   - Calcula totales ineficientemente
   
   OBJETIVO: < 15 minutos
*/

-- Proceso PROBLEMÁTICO (con cursor - NO USAR)
CREATE OR ALTER PROCEDURE dbo.SP_CierreDia_PROBLEMATICO
    @FechaCierre DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TransaccionID BIGINT;
    DECLARE @Monto FLOAT;
    DECLARE @CuentaID INT;
    
    -- PROBLEMA: Cursor fila por fila
    DECLARE cur CURSOR FOR
        SELECT TransaccionID, Monto, CuentaOrigenID
        FROM dbo.TRANSACCIONES_WS
        WHERE CAST(FechaTransaccion AS DATE) = @FechaCierre
          AND Estado = 'PENDIENTE';
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @TransaccionID, @Monto, @CuentaID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Procesar una por una (LENTO!)
        UPDATE dbo.TRANSACCIONES_WS
        SET Estado = 'PROCESADA',
            FechaProceso = GETDATE()
        WHERE TransaccionID = @TransaccionID;
        
        FETCH NEXT FROM cur INTO @TransaccionID, @Monto, @CuentaID;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- ============================================================================
-- SOLUCIÓN #3: PROCESO SET-BASED CON BATCHING
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.SP_CierreDia_OPTIMIZADO
    @FechaCierre DATE,
    @TamañoBatch INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @TotalProcesadas BIGINT = 0;
    DECLARE @BatchProcesadas INT = 1;
    DECLARE @InicioProc DATETIME2 = SYSDATETIME();
    
    PRINT '=====================================================';
    PRINT '  PROCESO DE CIERRE DE DÍA - ' + CONVERT(VARCHAR, @FechaCierre, 103);
    PRINT '=====================================================';
    
    -- Crear tabla temporal para IDs a procesar (mejor rendimiento)
    CREATE TABLE #TransaccionesPendientes (
        TransaccionID BIGINT PRIMARY KEY,
        Procesada BIT DEFAULT 0
    );
    
    -- Cargar IDs a procesar
    INSERT INTO #TransaccionesPendientes (TransaccionID)
    SELECT TransaccionID
    FROM dbo.TRANSACCIONES_WS
    WHERE CAST(FechaTransaccion AS DATE) = @FechaCierre
      AND Estado = 'PENDIENTE';
    
    DECLARE @TotalAProcesar INT = @@ROWCOUNT;
    PRINT 'Transacciones a procesar: ' + CAST(@TotalAProcesar AS VARCHAR);
    
    -- Procesar en batches
    WHILE @BatchProcesadas > 0
    BEGIN
        BEGIN TRANSACTION;
        
        -- Actualizar batch usando TOP
        UPDATE TOP (@TamañoBatch) t
        SET t.Estado = 'PROCESADA',
            t.FechaProceso = GETDATE(),
            t.UsuarioProceso = 'CIERRE_DIA'
        FROM dbo.TRANSACCIONES_WS t
        INNER JOIN #TransaccionesPendientes tp ON t.TransaccionID = tp.TransaccionID
        WHERE tp.Procesada = 0;
        
        SET @BatchProcesadas = @@ROWCOUNT;
        
        -- Marcar como procesadas en tabla temporal
        UPDATE TOP (@TamañoBatch) #TransaccionesPendientes
        SET Procesada = 1
        WHERE Procesada = 0;
        
        COMMIT TRANSACTION;
        
        SET @TotalProcesadas += @BatchProcesadas;
        
        -- Progreso
        IF @BatchProcesadas > 0
            PRINT 'Procesadas: ' + CAST(@TotalProcesadas AS VARCHAR) + 
                  ' de ' + CAST(@TotalAProcesar AS VARCHAR) +
                  ' (' + CAST(CAST(@TotalProcesadas * 100.0 / NULLIF(@TotalAProcesar, 0) AS INT) AS VARCHAR) + '%)';
    END
    
    DROP TABLE #TransaccionesPendientes;
    
    -- Estadísticas de cierre usando Window Functions
    PRINT '';
    PRINT '--- RESUMEN DEL DÍA ---';
    
    ;WITH ResumenDia AS (
        SELECT 
            TipoTransaccion,
            COUNT(*) AS Cantidad,
            SUM(Monto) AS MontoTotal,
            AVG(Monto) AS MontoPromedio,
            SUM(COUNT(*)) OVER () AS TotalTransacciones,
            SUM(SUM(Monto)) OVER () AS MontoTotalDia
        FROM dbo.TRANSACCIONES_WS
        WHERE CAST(FechaTransaccion AS DATE) = @FechaCierre
        GROUP BY TipoTransaccion
    )
    SELECT 
        TipoTransaccion,
        Cantidad,
        FORMAT(MontoTotal, 'C') AS MontoTotal,
        FORMAT(MontoPromedio, 'C') AS MontoPromedio,
        FORMAT(Cantidad * 100.0 / TotalTransacciones, 'N2') + '%' AS PorcentajeCantidad,
        FORMAT(MontoTotal * 100.0 / MontoTotalDia, 'N2') + '%' AS PorcentajeMonto
    FROM ResumenDia
    ORDER BY MontoTotal DESC;
    
    PRINT '';
    PRINT 'COMPLETADO en ' + 
          CAST(DATEDIFF(SECOND, @InicioProc, SYSDATETIME()) AS VARCHAR) + ' segundos.';
    PRINT 'Total procesadas: ' + CAST(@TotalProcesadas AS VARCHAR);
END;
GO

PRINT 'Proceso de cierre optimizado creado.';
GO

-- ============================================================================
-- PARTE 5: CONSULTA DE SALDO OPTIMIZADA
-- ============================================================================

/*
   🔍 PROBLEMA #4: CONSULTA DE SALDO LENTA (>500ms)
   ================================================
   
   Los usuarios reportan lentitud al consultar saldo.
   El SP actual hace JOINs innecesarios y no usa índices.
*/

-- Versión OPTIMIZADA con índice cubriente
CREATE OR ALTER PROCEDURE dbo.SP_ConsultarSaldo
    @NumeroCuenta VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Query optimizada usando índice
    SELECT 
        cu.NumeroCuenta,
        cu.TipoCuenta,
        CAST(cu.Saldo AS DECIMAL(18,2)) AS Saldo,
        CAST(cu.SaldoDisponible AS DECIMAL(18,2)) AS SaldoDisponible,
        cu.Moneda,
        cu.Estado,
        FORMAT(cu.FechaUltimoMov, 'dd/MM/yyyy HH:mm') AS UltimoMovimiento
    FROM dbo.CUENTAS_WS cu WITH (NOLOCK)
    WHERE cu.NumeroCuenta = @NumeroCuenta;
END;
GO

-- Crear índice para búsqueda por número de cuenta
CREATE UNIQUE NONCLUSTERED INDEX IX_CUENTAS_WS_NumeroCuenta
ON dbo.CUENTAS_WS (NumeroCuenta)
INCLUDE (TipoCuenta, Saldo, SaldoDisponible, Moneda, Estado, FechaUltimoMov);
GO

-- ============================================================================
-- PARTE 6: JOB DE MANTENIMIENTO AUTOMATIZADO
-- ============================================================================

/*
   🔍 PROBLEMA #5: JOBS DE MANTENIMIENTO FALLAN
   ============================================
   
   Los jobs actuales no tienen manejo de errores ni logging.
*/

-- Procedimiento de mantenimiento robusto
CREATE OR ALTER PROCEDURE dbo.SP_MantenimientoDiario
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorCount INT = 0;
    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    
    PRINT '=====================================================';
    PRINT '  MANTENIMIENTO DIARIO - ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '=====================================================';
    
    -- 1. Actualizar estadísticas de tablas críticas
    BEGIN TRY
        PRINT '1. Actualizando estadísticas...';
        UPDATE STATISTICS dbo.TRANSACCIONES_WS;
        UPDATE STATISTICS dbo.CUENTAS_WS;
        UPDATE STATISTICS dbo.CLIENTES_WS;
        PRINT '   OK - Estadísticas actualizadas';
    END TRY
    BEGIN CATCH
        PRINT '   ERROR: ' + ERROR_MESSAGE();
        SET @ErrorCount += 1;
    END CATCH
    
    -- 2. Limpiar logs antiguos (>90 días)
    BEGIN TRY
        PRINT '2. Limpiando logs antiguos...';
        
        DELETE FROM dbo.LOG_AUDITORIA_WS
        WHERE FechaHora < DATEADD(DAY, -90, GETDATE());
        
        PRINT '   OK - ' + CAST(@@ROWCOUNT AS VARCHAR) + ' registros eliminados';
    END TRY
    BEGIN CATCH
        PRINT '   ERROR: ' + ERROR_MESSAGE();
        SET @ErrorCount += 1;
    END CATCH
    
    -- 3. Reorganizar índices fragmentados (>10%)
    BEGIN TRY
        PRINT '3. Verificando fragmentación de índices...';
        
        SELECT 
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent AS Fragmentation
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.avg_fragmentation_in_percent > 10
          AND ips.page_count > 1000
          AND i.name IS NOT NULL;
        
        -- En producción: ALTER INDEX REORGANIZE o REBUILD según %
        PRINT '   OK - Verificación completada';
    END TRY
    BEGIN CATCH
        PRINT '   ERROR: ' + ERROR_MESSAGE();
        SET @ErrorCount += 1;
    END CATCH
    
    -- 4. Verificar transacciones pendientes antiguas
    BEGIN TRY
        PRINT '4. Verificando transacciones pendientes antiguas...';
        
        DECLARE @PendientesAntiguas INT;
        SELECT @PendientesAntiguas = COUNT(*)
        FROM dbo.TRANSACCIONES_WS
        WHERE Estado = 'PENDIENTE'
          AND FechaTransaccion < DATEADD(HOUR, -24, GETDATE());
        
        IF @PendientesAntiguas > 0
            PRINT '   ALERTA: ' + CAST(@PendientesAntiguas AS VARCHAR) + ' transacciones pendientes >24h';
        ELSE
            PRINT '   OK - Sin transacciones pendientes antiguas';
    END TRY
    BEGIN CATCH
        PRINT '   ERROR: ' + ERROR_MESSAGE();
        SET @ErrorCount += 1;
    END CATCH
    
    -- Resumen
    PRINT '';
    PRINT '=====================================================';
    PRINT '  RESUMEN DEL MANTENIMIENTO';
    PRINT '=====================================================';
    PRINT 'Duración: ' + CAST(DATEDIFF(SECOND, @StartTime, SYSDATETIME()) AS VARCHAR) + ' segundos';
    PRINT 'Errores: ' + CAST(@ErrorCount AS VARCHAR);
    
    IF @ErrorCount > 0
        PRINT 'ESTADO: COMPLETADO CON ERRORES';
    ELSE
        PRINT 'ESTADO: COMPLETADO EXITOSAMENTE';
    
    -- Registrar en log
    INSERT INTO dbo.LOG_AUDITORIA_WS (TablaAfectada, Operacion, DatosNuevos)
    VALUES ('SISTEMA', 'MANTENIMIENTO', 
            'Duración: ' + CAST(DATEDIFF(SECOND, @StartTime, SYSDATETIME()) AS VARCHAR) + 's, Errores: ' + CAST(@ErrorCount AS VARCHAR));
END;
GO

-- ============================================================================
-- PARTE 7: DASHBOARD DE MONITOREO
-- ============================================================================

-- Vista para monitoreo en tiempo real
CREATE OR ALTER VIEW dbo.VW_Dashboard_Rendimiento
AS
    SELECT 
        'Transacciones Hoy' AS Metrica,
        CAST(COUNT(*) AS VARCHAR) AS Valor,
        'Cantidad' AS Unidad
    FROM dbo.TRANSACCIONES_WS
    WHERE CAST(FechaTransaccion AS DATE) = CAST(GETDATE() AS DATE)
    
    UNION ALL
    
    SELECT 
        'Monto Total Hoy',
        FORMAT(SUM(Monto), 'C'),
        'MXN'
    FROM dbo.TRANSACCIONES_WS
    WHERE CAST(FechaTransaccion AS DATE) = CAST(GETDATE() AS DATE)
      AND Estado = 'COMPLETADA'
    
    UNION ALL
    
    SELECT 
        'Transacciones Pendientes',
        CAST(COUNT(*) AS VARCHAR),
        'Cantidad'
    FROM dbo.TRANSACCIONES_WS
    WHERE Estado = 'PENDIENTE'
    
    UNION ALL
    
    SELECT 
        'Cuentas Bloqueadas',
        CAST(COUNT(*) AS VARCHAR),
        'Cantidad'
    FROM dbo.CUENTAS_WS
    WHERE Estado = 'BLOQUEADA'
    
    UNION ALL
    
    SELECT 
        'Clientes Activos',
        CAST(COUNT(*) AS VARCHAR),
        'Cantidad'
    FROM dbo.CLIENTES_WS
    WHERE Estado = 'ACTIVO';
GO

-- Consultar dashboard
SELECT * FROM dbo.VW_Dashboard_Rendimiento;
GO

-- ============================================================================
-- PARTE 8: RESUMEN Y COMPARATIVA FINAL
-- ============================================================================

PRINT '';
PRINT '=====================================================';
PRINT '  WORKSHOP COMPLETADO - RESUMEN DE OPTIMIZACIONES';
PRINT '=====================================================';
PRINT '';
PRINT '1. REPORTE MENSUAL';
PRINT '   Antes: >30 segundos | Después: <5 segundos';
PRINT '   Técnica: Índices estratégicos con INCLUDE';
PRINT '';
PRINT '2. TRANSFERENCIAS';
PRINT '   Antes: Deadlocks frecuentes | Después: 0 deadlocks';
PRINT '   Técnica: Orden consistente de bloqueos (menor ID primero)';
PRINT '';
PRINT '3. CIERRE DE DÍA';
PRINT '   Antes: >2 horas | Después: <15 minutos';
PRINT '   Técnica: Set-based con batching, eliminar cursores';
PRINT '';
PRINT '4. CONSULTA DE SALDO';
PRINT '   Antes: >500ms | Después: <100ms';
PRINT '   Técnica: Índice cubriente, NOLOCK para lecturas';
PRINT '';
PRINT '5. MANTENIMIENTO';
PRINT '   Antes: Fallos sin log | Después: Robusto con logging';
PRINT '   Técnica: TRY-CATCH por sección, registro detallado';
PRINT '';
PRINT '=====================================================';
PRINT '  🎓 CURSO COMPLETADO - ¡FELICITACIONES!';
PRINT '=====================================================';
GO

-- ============================================================================
-- LIMPIEZA (OPCIONAL)
-- ============================================================================

/*
-- Descomentar para eliminar objetos del workshop

DROP VIEW IF EXISTS dbo.VW_Dashboard_Rendimiento;
DROP PROCEDURE IF EXISTS dbo.SP_MantenimientoDiario;
DROP PROCEDURE IF EXISTS dbo.SP_ConsultarSaldo;
DROP PROCEDURE IF EXISTS dbo.SP_CierreDia_OPTIMIZADO;
DROP PROCEDURE IF EXISTS dbo.SP_CierreDia_PROBLEMATICO;
DROP PROCEDURE IF EXISTS dbo.SP_Transferencia_OPTIMIZADA;
DROP PROCEDURE IF EXISTS dbo.SP_Transferencia_PROBLEMATICA;
DROP TABLE IF EXISTS dbo.LOG_AUDITORIA_WS;
DROP TABLE IF EXISTS dbo.TRANSACCIONES_WS;
DROP TABLE IF EXISTS dbo.CUENTAS_WS;
DROP TABLE IF EXISTS dbo.CLIENTES_WS;
*/
