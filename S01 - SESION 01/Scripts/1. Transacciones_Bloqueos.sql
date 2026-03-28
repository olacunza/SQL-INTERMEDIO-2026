-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 1
-- TRANSACCIONES Y BLOQUEOS
-- Enfoque: Integridad Financiera Bancaria
-- ============================================================

USE master;
GO

-- ============================================================
-- PARTE 0: PREPARACIÓN DEL AMBIENTE
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'BancoDB')
BEGIN
    CREATE DATABASE BancoDB;
END
GO

USE BancoDB;
GO

-- ============================================================
-- TABLAS BASE (Basadas en tu estructura existente)
-- ============================================================

-- CLIENTES
IF OBJECT_ID('TRANSACCIONES_BANCARIAS') IS NOT NULL DROP TABLE TRANSACCIONES_BANCARIAS;
IF OBJECT_ID('CUENTAS') IS NOT NULL DROP TABLE CUENTAS;
IF OBJECT_ID('CLIENTES') IS NOT NULL DROP TABLE CLIENTES;
IF OBJECT_ID('EMPLEADOS') IS NOT NULL DROP TABLE EMPLEADOS;

CREATE TABLE CLIENTES (
    CLIENTEID INT PRIMARY KEY IDENTITY(1,1),
    NOMBRE NVARCHAR(50),
    APELLIDO NVARCHAR(50),
    EMAIL NVARCHAR(100),
    TELEFONO NVARCHAR(20),
    DNI NVARCHAR(15)
);

CREATE TABLE EMPLEADOS (
    EMPLEADOID INT PRIMARY KEY IDENTITY(1,1),
    NOMBRE NVARCHAR(50),
    APELLIDO NVARCHAR(50),
    PUESTO NVARCHAR(50),
    SALARIO DECIMAL(10,2)
);

-- TABLA DE CUENTAS BANCARIAS (Nueva para ejercicios bancarios)
CREATE TABLE CUENTAS (
    CUENTAID INT PRIMARY KEY IDENTITY(1,1),
    CLIENTEID INT FOREIGN KEY REFERENCES CLIENTES(CLIENTEID),
    NUMEROCUENTA NVARCHAR(20) UNIQUE,
    TIPOCUENTA NVARCHAR(20), -- 'AHORRO', 'CORRIENTE', 'PLAZO FIJO'
    SALDO DECIMAL(15,2) DEFAULT 0,
    ESTADO NVARCHAR(10) DEFAULT 'ACTIVA', -- 'ACTIVA', 'BLOQUEADA', 'CERRADA'
    FECHA_APERTURA DATE DEFAULT GETDATE()
);

-- TABLA DE TRANSACCIONES BANCARIAS
CREATE TABLE TRANSACCIONES_BANCARIAS (
    TRANSACCIONID INT PRIMARY KEY IDENTITY(1,1),
    CUENTA_ORIGEN INT FOREIGN KEY REFERENCES CUENTAS(CUENTAID),
    CUENTA_DESTINO INT FOREIGN KEY REFERENCES CUENTAS(CUENTAID),
    TIPO NVARCHAR(20), -- 'DEPOSITO', 'RETIRO', 'TRANSFERENCIA'
    MONTO DECIMAL(15,2),
    FECHA DATETIME DEFAULT GETDATE(),
    EMPLEADOID INT FOREIGN KEY REFERENCES EMPLEADOS(EMPLEADOID),
    ESTADO NVARCHAR(15) DEFAULT 'COMPLETADA' -- 'COMPLETADA', 'PENDIENTE', 'REVERTIDA'
);

GO

-- ============================================================
-- INSERTAR DATA DE PRUEBA
-- ============================================================

-- Clientes
INSERT INTO CLIENTES (NOMBRE, APELLIDO, EMAIL, TELEFONO, DNI) VALUES
('Juan', 'Perez', 'juan.perez@email.com', '999111111', '12345678'),
('Maria', 'Lopez', 'maria.lopez@email.com', '999222222', '23456789'),
('Carlos', 'Ramirez', 'carlos.ramirez@email.com', '999333333', '34567890'),
('Ana', 'Torres', 'ana.torres@email.com', '999444444', '45678901'),
('Luis', 'Fernandez', 'luis.fernandez@email.com', '999555555', '56789012'),
('Pedro', 'Castro', 'pedro.castro@email.com', '999666666', '67890123'),
('Rosa', 'Gutierrez', 'rosa.gutierrez@email.com', '999777777', '78901234'),
('Diego', 'Sanchez', 'diego.sanchez@email.com', '999888888', '89012345'),
('Lucia', 'Mendoza', 'lucia.mendoza@email.com', '999999999', '90123456'),
('Hector', 'Garcia', 'hector.garcia@email.com', '998111111', '01234567');

-- Empleados
INSERT INTO EMPLEADOS (NOMBRE, APELLIDO, PUESTO, SALARIO) VALUES
('Alberto', 'Martinez', 'Cajero', 1500.00),
('Julia', 'Ramirez', 'Asesor', 2500.00),
('Fernando', 'Gomez', 'Gerente', 5500.00),
('Claudia', 'Ruiz', 'Cajero', 1600.00),
('Manuel', 'Alvarez', 'Supervisor', 3200.00);

-- Cuentas Bancarias
INSERT INTO CUENTAS (CLIENTEID, NUMEROCUENTA, TIPOCUENTA, SALDO, ESTADO) VALUES
(1, '1001-0001-0001', 'AHORRO', 15000.00, 'ACTIVA'),
(1, '1001-0001-0002', 'CORRIENTE', 8500.00, 'ACTIVA'),
(2, '1001-0002-0001', 'AHORRO', 25000.00, 'ACTIVA'),
(3, '1001-0003-0001', 'PLAZO FIJO', 50000.00, 'ACTIVA'),
(4, '1001-0004-0001', 'AHORRO', 3200.00, 'ACTIVA'),
(5, '1001-0005-0001', 'CORRIENTE', 12000.00, 'ACTIVA'),
(6, '1001-0006-0001', 'AHORRO', 7800.00, 'ACTIVA'),
(7, '1001-0007-0001', 'AHORRO', 45000.00, 'ACTIVA'),
(8, '1001-0008-0001', 'CORRIENTE', 18500.00, 'ACTIVA'),
(9, '1001-0009-0001', 'AHORRO', 92000.00, 'ACTIVA'),
(10, '1001-0010-0001', 'PLAZO FIJO', 150000.00, 'ACTIVA');

GO

-- ============================================================
-- DEMO 1: PROPIEDADES ACID EN ACCIÓN
-- ============================================================
PRINT '============================================';
PRINT 'DEMO 1: PROPIEDADES ACID';
PRINT '============================================';

-- Verificar saldos antes
SELECT 'SALDOS ANTES DE TRANSFERENCIA' AS [Estado];
SELECT CUENTAID, NUMEROCUENTA, SALDO FROM CUENTAS WHERE CUENTAID IN (1, 3);

-- ATOMICIDAD: Transferencia exitosa
BEGIN TRANSACTION;
    
    DECLARE @MontoTransferencia DECIMAL(15,2) = 5000.00;
    DECLARE @CuentaOrigen INT = 1;
    DECLARE @CuentaDestino INT = 3;
    
    -- Debitar de cuenta origen
    UPDATE CUENTAS 
    SET SALDO = SALDO - @MontoTransferencia 
    WHERE CUENTAID = @CuentaOrigen;
    
    -- Acreditar en cuenta destino
    UPDATE CUENTAS 
    SET SALDO = SALDO + @MontoTransferencia 
    WHERE CUENTAID = @CuentaDestino;
    
    -- Registrar transacción
    INSERT INTO TRANSACCIONES_BANCARIAS (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID)
    VALUES (@CuentaOrigen, @CuentaDestino, 'TRANSFERENCIA', @MontoTransferencia, 1);

COMMIT TRANSACTION;

-- Verificar saldos después
SELECT 'SALDOS DESPUÉS DE TRANSFERENCIA EXITOSA' AS [Estado];
SELECT CUENTAID, NUMEROCUENTA, SALDO FROM CUENTAS WHERE CUENTAID IN (1, 3);

GO

-- ============================================================
-- DEMO 2: ROLLBACK - Cuando algo falla
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 2: ROLLBACK POR SALDO INSUFICIENTE';
PRINT '============================================';

-- Intentar transferir más de lo que hay en la cuenta
BEGIN TRY
    BEGIN TRANSACTION;
        
        DECLARE @Monto DECIMAL(15,2) = 999999.00; -- Monto excesivo
        DECLARE @Origen INT = 5;
        DECLARE @Destino INT = 6;
        
        -- Verificar saldo suficiente
        DECLARE @SaldoActual DECIMAL(15,2);
        SELECT @SaldoActual = SALDO FROM CUENTAS WHERE CUENTAID = @Origen;
        
        IF @SaldoActual < @Monto
        BEGIN
            RAISERROR('ERROR: Saldo insuficiente. Saldo actual: %s', 16, 1, @SaldoActual);
        END
        
        UPDATE CUENTAS SET SALDO = SALDO - @Monto WHERE CUENTAID = @Origen;
        UPDATE CUENTAS SET SALDO = SALDO + @Monto WHERE CUENTAID = @Destino;
        
    COMMIT TRANSACTION;
    PRINT 'Transferencia exitosa';
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    PRINT 'TRANSACCIÓN REVERTIDA (ROLLBACK)';
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH

-- Verificar que los saldos NO cambiaron
SELECT 'SALDOS DESPUÉS DEL ROLLBACK (sin cambios)' AS [Estado];
SELECT CUENTAID, NUMEROCUENTA, SALDO FROM CUENTAS WHERE CUENTAID IN (5, 6);

GO

-- ============================================================
-- DEMO 3: NIVELES DE AISLAMIENTO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 3: NIVELES DE AISLAMIENTO';
PRINT '============================================';

-- Ver nivel de aislamiento actual
SELECT 
    'Nivel de Aislamiento Actual' AS [Descripcion],
    CASE transaction_isolation_level 
        WHEN 0 THEN 'Unspecified' 
        WHEN 1 THEN 'ReadUncommitted' 
        WHEN 2 THEN 'ReadCommitted' 
        WHEN 3 THEN 'RepeatableRead' 
        WHEN 4 THEN 'Serializable' 
        WHEN 5 THEN 'Snapshot' 
    END AS NivelAislamiento
FROM sys.dm_exec_sessions 
WHERE session_id = @@SPID;

GO

-- ============================================================
-- DEMO 3A: DIRTY READ (READ UNCOMMITTED)
-- EJECUTAR EN DOS SESIONES SEPARADAS
-- ============================================================

/*
-- ========== SESIÓN 1 ==========
BEGIN TRANSACTION;
    -- Actualizar saldo (sin confirmar)
    UPDATE CUENTAS SET SALDO = 0 WHERE CUENTAID = 1;
    
    PRINT 'Saldo modificado a 0 (sin confirmar). Espere 10 segundos...';
    WAITFOR DELAY '00:00:10';
    
    -- Revertir el cambio
    ROLLBACK TRANSACTION;
    PRINT 'Cambio REVERTIDO. El saldo nunca fue 0 realmente.';

-- ========== SESIÓN 2 (ejecutar mientras Sesión 1 espera) ==========
-- Con READ UNCOMMITTED (peligroso!)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT 'DIRTY READ - Esto es peligroso!' AS [Advertencia], 
       CUENTAID, SALDO 
FROM CUENTAS 
WHERE CUENTAID = 1;
-- Verás SALDO = 0 aunque ese dato NUNCA se confirmó!

-- Con READ COMMITTED (seguro)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT 'READ COMMITTED - Esto espera o da el valor real' AS [Info], 
       CUENTAID, SALDO 
FROM CUENTAS 
WHERE CUENTAID = 1;
-- Esta consulta ESPERA hasta que la Sesión 1 termine
*/

GO

-- ============================================================
-- DEMO 4: DEADLOCK
-- EJECUTAR EN DOS SESIONES SEPARADAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 4: PROVOCAR UN DEADLOCK';
PRINT '============================================';

/*
INSTRUCCIONES PARA PROVOCAR DEADLOCK:
=====================================

-- ========== SESIÓN 1 ==========
USE BancoDB;
BEGIN TRANSACTION;
    PRINT 'Sesión 1: Bloqueando Cuenta 1...';
    UPDATE CUENTAS SET SALDO = SALDO - 100 WHERE CUENTAID = 1;
    
    PRINT 'Sesión 1: Esperando 5 segundos...';
    WAITFOR DELAY '00:00:05';
    
    PRINT 'Sesión 1: Intentando bloquear Cuenta 2...';
    UPDATE CUENTAS SET SALDO = SALDO + 100 WHERE CUENTAID = 2;
COMMIT TRANSACTION;
PRINT 'Sesión 1: Completada';

-- ========== SESIÓN 2 (ejecutar inmediatamente después) ==========
USE BancoDB;
BEGIN TRANSACTION;
    PRINT 'Sesión 2: Bloqueando Cuenta 2...';
    UPDATE CUENTAS SET SALDO = SALDO - 200 WHERE CUENTAID = 2;
    
    PRINT 'Sesión 2: Esperando 5 segundos...';
    WAITFOR DELAY '00:00:05';
    
    PRINT 'Sesión 2: Intentando bloquear Cuenta 1...';
    UPDATE CUENTAS SET SALDO = SALDO + 200 WHERE CUENTAID = 1;
COMMIT TRANSACTION;
PRINT 'Sesión 2: Completada';

-- RESULTADO: SQL Server detectará el deadlock y matará una de las sesiones
-- Error: "Transaction was deadlocked on lock resources with another process and has been chosen as the deadlock victim."
*/

GO

-- ============================================================
-- DEMO 5: SOLUCIÓN AL DEADLOCK - ORDENAMIENTO CONSISTENTE
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 5: PREVENCIÓN DE DEADLOCKS';
PRINT '============================================';

-- SP que PREVIENE deadlocks usando ordenamiento consistente
CREATE OR ALTER PROCEDURE SP_TRANSFERENCIA_SEGURA
    @CuentaOrigen INT,
    @CuentaDestino INT,
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PrimeraCuenta INT, @SegundaCuenta INT;
    DECLARE @EsInvertido BIT = 0;
    
    -- ESTRATEGIA: Siempre bloquear primero la cuenta con ID menor
    IF @CuentaOrigen < @CuentaDestino
    BEGIN
        SET @PrimeraCuenta = @CuentaOrigen;
        SET @SegundaCuenta = @CuentaDestino;
    END
    ELSE
    BEGIN
        SET @PrimeraCuenta = @CuentaDestino;
        SET @SegundaCuenta = @CuentaOrigen;
        SET @EsInvertido = 1;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
            
            -- Bloquear en orden consistente
            DECLARE @Saldo1 DECIMAL(15,2), @Saldo2 DECIMAL(15,2);
            
            SELECT @Saldo1 = SALDO FROM CUENTAS WITH (UPDLOCK, ROWLOCK) 
            WHERE CUENTAID = @PrimeraCuenta;
            
            SELECT @Saldo2 = SALDO FROM CUENTAS WITH (UPDLOCK, ROWLOCK) 
            WHERE CUENTAID = @SegundaCuenta;
            
            -- Validar saldo suficiente
            IF @EsInvertido = 0 AND @Saldo1 < @Monto
                RAISERROR('Saldo insuficiente en cuenta origen', 16, 1);
            
            IF @EsInvertido = 1 AND @Saldo2 < @Monto
                RAISERROR('Saldo insuficiente en cuenta origen', 16, 1);
            
            -- Realizar transferencia
            UPDATE CUENTAS SET SALDO = SALDO - @Monto WHERE CUENTAID = @CuentaOrigen;
            UPDATE CUENTAS SET SALDO = SALDO + @Monto WHERE CUENTAID = @CuentaDestino;
            
            -- Registrar
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID)
            VALUES 
                (@CuentaOrigen, @CuentaDestino, 'TRANSFERENCIA', @Monto, @EmpleadoID);
            
        COMMIT TRANSACTION;
        
        SELECT 'ÉXITO' AS Resultado, 
               'Transferencia completada' AS Mensaje,
               @Monto AS MontoTransferido;
               
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SELECT 'ERROR' AS Resultado, 
               ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
GO

-- Probar el SP
EXEC SP_TRANSFERENCIA_SEGURA 
    @CuentaOrigen = 7, 
    @CuentaDestino = 8, 
    @Monto = 1000.00, 
    @EmpleadoID = 1;

-- Verificar resultado
SELECT CUENTAID, NUMEROCUENTA, SALDO FROM CUENTAS WHERE CUENTAID IN (7, 8);

GO

-- ============================================================
-- DEMO 6: NOLOCK vs CONSULTA NORMAL
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 6: NOLOCK vs CONSULTA NORMAL';
PRINT '============================================';

-- Consulta con NOLOCK (puede dar datos "sucios")
SELECT 'Con NOLOCK (peligroso para datos financieros)' AS [Tipo];
SELECT * FROM CUENTAS WITH (NOLOCK) WHERE SALDO > 10000;

-- Consulta sin NOLOCK (espera si hay bloqueos)
SELECT 'Sin NOLOCK (seguro pero puede esperar)' AS [Tipo];
SELECT * FROM CUENTAS WHERE SALDO > 10000;

GO

-- ============================================================
-- DEMO 7: VERIFICAR Y ACTIVAR RCSI
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 7: READ COMMITTED SNAPSHOT ISOLATION';
PRINT '============================================';

-- Verificar estado actual de RCSI
SELECT 
    name AS BaseDeDatos,
    is_read_committed_snapshot_on AS RCSI_Activo,
    snapshot_isolation_state_desc AS Snapshot_Estado
FROM sys.databases 
WHERE name = 'BancoDB';

/*
-- Para activar RCSI (requiere que no haya conexiones activas a la DB)
-- IMPORTANTE: Ejecutar esto requiere ser el único conectado a la DB

USE master;
ALTER DATABASE BancoDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
USE BancoDB;

-- Verificar que se activó
SELECT name, is_read_committed_snapshot_on FROM sys.databases WHERE name = 'BancoDB';
*/

GO

-- ============================================================
-- DEMO 8: MONITOREO DE BLOQUEOS EN TIEMPO REAL
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 8: MONITOREO DE BLOQUEOS';
PRINT '============================================';

-- Ver bloqueos actuales
SELECT 
    L.request_session_id AS SesionID,
    DB_NAME(L.resource_database_id) AS BaseDatos,
    OBJECT_NAME(P.object_id) AS Tabla,
    L.resource_type AS TipoRecurso,
    L.request_mode AS ModoBloqueo,
    L.request_status AS Estado
FROM sys.dm_tran_locks L
LEFT JOIN sys.partitions P ON L.resource_associated_entity_id = P.hobt_id
WHERE L.resource_database_id = DB_ID('BancoDB')
    AND L.resource_type <> 'DATABASE';

GO

-- Ver sesiones bloqueadas
SELECT 
    blocking.session_id AS SesionBloqueadora,
    blocked.session_id AS SesionBloqueada,
    DB_NAME(blocked.database_id) AS BaseDatos,
    blocked.wait_time / 1000.0 AS SegundosEsperando,
    blocked.wait_type AS TipoEspera,
    blockedText.text AS QueryBloqueada,
    blockingText.text AS QueryBloqueadora
FROM sys.dm_exec_requests blocked
INNER JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blockedText
OUTER APPLY sys.dm_exec_sql_text(blocking.most_recent_sql_handle) blockingText
WHERE blocked.blocking_session_id > 0;

GO

-- ============================================================
-- EJERCICIO PRÁCTICO: COMPLETAR
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'EJERCICIO PRÁCTICO';
PRINT '============================================';

/*
EJERCICIO 1: Crear un SP para DEPÓSITO que cumpla con ACID
- Debe validar que la cuenta exista y esté activa
- Debe validar que el monto sea positivo
- Debe registrar la transacción
- Debe manejar errores con TRY...CATCH

CREATE OR ALTER PROCEDURE SP_DEPOSITO
    @CuentaDestino INT,
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    -- Tu código aquí
END

EJERCICIO 2: Crear un SP para RETIRO que:
- Valide saldo suficiente
- Use nivel de aislamiento adecuado
- Evite race conditions (dos retiros simultáneos)

EJERCICIO 3: Ejecutar las demos de deadlock en dos sesiones
- Documentar qué sesión fue elegida como "víctima"
- Identificar en el mensaje de error el recurso bloqueado

*/

GO

-- ============================================================
-- LIMPIEZA (Opcional)
-- ============================================================
/*
USE master;
DROP DATABASE BancoDB;
*/

PRINT '';
PRINT '============================================';
PRINT 'FIN DE LA SESIÓN 1';
PRINT '============================================';
