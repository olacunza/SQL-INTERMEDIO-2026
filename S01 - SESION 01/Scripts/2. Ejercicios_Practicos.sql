-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 1
-- EJERCICIOS INTERACTIVOS: TRANSACCIONES Y BLOQUEOS
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: TRANSFERENCIA CON VALIDACIONES COMPLETAS
-- ============================================================
/*
Crear un Stored Procedure llamado SP_TRANSFERENCIA_COMPLETA que:
1. Reciba: @CuentaOrigen, @CuentaDestino, @Monto, @EmpleadoID
2. Valide que ambas cuentas existan
3. Valide que ambas cuentas estén ACTIVAS
4. Valide que la cuenta origen tenga saldo suficiente
5. Valide que el monto sea mayor a 0
6. Si la cuenta origen es PLAZO FIJO, no permita retiros
7. Registre la transacción
8. Retorne un mensaje de éxito o error apropiado
*/

-- SOLUCIÓN:
CREATE OR ALTER PROCEDURE SP_TRANSFERENCIA_COMPLETA
    @CuentaOrigen INT,
    @CuentaDestino INT,
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables para validaciones
    DECLARE @SaldoOrigen DECIMAL(15,2);
    DECLARE @EstadoOrigen NVARCHAR(10);
    DECLARE @EstadoDestino NVARCHAR(10);
    DECLARE @TipoOrigen NVARCHAR(20);
    DECLARE @ExisteOrigen BIT = 0;
    DECLARE @ExisteDestino BIT = 0;
    
    -- Validar monto positivo
    IF @Monto <= 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 'El monto debe ser mayor a cero' AS Mensaje;
        RETURN;
    END
    
    -- Verificar cuenta origen
    SELECT 
        @ExisteOrigen = 1,
        @SaldoOrigen = SALDO,
        @EstadoOrigen = ESTADO,
        @TipoOrigen = TIPOCUENTA
    FROM CUENTAS 
    WHERE CUENTAID = @CuentaOrigen;
    
    IF @ExisteOrigen = 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 'La cuenta origen no existe' AS Mensaje;
        RETURN;
    END
    
    -- Verificar cuenta destino
    SELECT 
        @ExisteDestino = 1,
        @EstadoDestino = ESTADO
    FROM CUENTAS 
    WHERE CUENTAID = @CuentaDestino;
    
    IF @ExisteDestino = 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 'La cuenta destino no existe' AS Mensaje;
        RETURN;
    END
    
    -- Validar estados
    IF @EstadoOrigen <> 'ACTIVA'
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'La cuenta origen está ' + @EstadoOrigen AS Mensaje;
        RETURN;
    END
    
    IF @EstadoDestino <> 'ACTIVA'
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'La cuenta destino está ' + @EstadoDestino AS Mensaje;
        RETURN;
    END
    
    -- Validar tipo de cuenta origen
    IF @TipoOrigen = 'PLAZO FIJO'
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'No se permiten retiros de cuentas a PLAZO FIJO' AS Mensaje;
        RETURN;
    END
    
    -- Validar saldo
    IF @SaldoOrigen < @Monto
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'Saldo insuficiente. Disponible: S/. ' + CAST(@SaldoOrigen AS VARCHAR) AS Mensaje;
        RETURN;
    END
    
    -- Si todas las validaciones pasan, ejecutar transferencia
    BEGIN TRY
        BEGIN TRANSACTION;
            
            -- Debitar
            UPDATE CUENTAS 
            SET SALDO = SALDO - @Monto 
            WHERE CUENTAID = @CuentaOrigen;
            
            -- Acreditar
            UPDATE CUENTAS 
            SET SALDO = SALDO + @Monto 
            WHERE CUENTAID = @CuentaDestino;
            
            -- Registrar
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
            VALUES 
                (@CuentaOrigen, @CuentaDestino, 'TRANSFERENCIA', @Monto, @EmpleadoID, 'COMPLETADA');
            
        COMMIT TRANSACTION;
        
        SELECT 'ÉXITO' AS Resultado, 
               'Transferencia de S/. ' + CAST(@Monto AS VARCHAR) + ' completada' AS Mensaje;
               
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;
        
        SELECT 'ERROR' AS Resultado, 
               ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
GO

-- Pruebas del SP
PRINT 'Prueba 1: Transferencia válida';
EXEC SP_TRANSFERENCIA_COMPLETA @CuentaOrigen = 1, @CuentaDestino = 2, @Monto = 500, @EmpleadoID = 1;

PRINT 'Prueba 2: Monto negativo';
EXEC SP_TRANSFERENCIA_COMPLETA @CuentaOrigen = 1, @CuentaDestino = 2, @Monto = -100, @EmpleadoID = 1;

PRINT 'Prueba 3: Cuenta inexistente';
EXEC SP_TRANSFERENCIA_COMPLETA @CuentaOrigen = 999, @CuentaDestino = 2, @Monto = 100, @EmpleadoID = 1;

PRINT 'Prueba 4: Desde Plazo Fijo';
EXEC SP_TRANSFERENCIA_COMPLETA @CuentaOrigen = 4, @CuentaDestino = 2, @Monto = 100, @EmpleadoID = 1;

PRINT 'Prueba 5: Saldo insuficiente';
EXEC SP_TRANSFERENCIA_COMPLETA @CuentaOrigen = 5, @CuentaDestino = 2, @Monto = 999999, @EmpleadoID = 1;

GO

-- ============================================================
-- EJERCICIO 2: DEPÓSITO CON AUDITORÍA
-- ============================================================

CREATE OR ALTER PROCEDURE SP_DEPOSITO
    @NumeroCuenta NVARCHAR(20),
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CuentaID INT;
    DECLARE @Estado NVARCHAR(10);
    DECLARE @SaldoAnterior DECIMAL(15,2);
    DECLARE @SaldoNuevo DECIMAL(15,2);
    
    -- Validar monto
    IF @Monto <= 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 'El monto debe ser mayor a cero' AS Mensaje;
        RETURN;
    END
    
    -- Buscar cuenta por número
    SELECT 
        @CuentaID = CUENTAID,
        @Estado = ESTADO,
        @SaldoAnterior = SALDO
    FROM CUENTAS 
    WHERE NUMEROCUENTA = @NumeroCuenta;
    
    IF @CuentaID IS NULL
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'Cuenta no encontrada: ' + @NumeroCuenta AS Mensaje;
        RETURN;
    END
    
    IF @Estado <> 'ACTIVA'
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               'La cuenta está ' + @Estado AS Mensaje;
        RETURN;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
            
            -- Acreditar
            UPDATE CUENTAS 
            SET SALDO = SALDO + @Monto 
            WHERE CUENTAID = @CuentaID;
            
            -- Obtener nuevo saldo
            SELECT @SaldoNuevo = SALDO FROM CUENTAS WHERE CUENTAID = @CuentaID;
            
            -- Registrar transacción (depósito no tiene cuenta origen)
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
            VALUES 
                (NULL, @CuentaID, 'DEPOSITO', @Monto, @EmpleadoID, 'COMPLETADA');
            
        COMMIT TRANSACTION;
        
        SELECT 'ÉXITO' AS Resultado,
               @NumeroCuenta AS Cuenta,
               @SaldoAnterior AS SaldoAnterior,
               @Monto AS MontoDepositado,
               @SaldoNuevo AS SaldoActual;
               
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;
        
        SELECT 'ERROR' AS Resultado, 
               ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
GO

-- Probar depósito
EXEC SP_DEPOSITO @NumeroCuenta = '1001-0005-0001', @Monto = 2500.50, @EmpleadoID = 2;

GO

-- ============================================================
-- EJERCICIO 3: RETIRO CON BLOQUEO EXPLÍCITO
-- ============================================================
/*
Este SP usa UPDLOCK para prevenir condiciones de carrera
cuando dos cajeros intentan retirar del mismo cliente simultáneamente
*/

CREATE OR ALTER PROCEDURE SP_RETIRO_SEGURO
    @NumeroCuenta NVARCHAR(20),
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    
    DECLARE @CuentaID INT;
    DECLARE @SaldoActual DECIMAL(15,2);
    DECLARE @Estado NVARCHAR(10);
    DECLARE @TipoCuenta NVARCHAR(20);
    
    BEGIN TRY
        BEGIN TRANSACTION;
            
            -- Bloquear la fila INMEDIATAMENTE para evitar race condition
            SELECT 
                @CuentaID = CUENTAID,
                @SaldoActual = SALDO,
                @Estado = ESTADO,
                @TipoCuenta = TIPOCUENTA
            FROM CUENTAS WITH (UPDLOCK, ROWLOCK)  -- Bloqueo explícito
            WHERE NUMEROCUENTA = @NumeroCuenta;
            
            -- Validaciones
            IF @CuentaID IS NULL
            BEGIN
                RAISERROR('Cuenta no encontrada', 16, 1);
            END
            
            IF @Estado <> 'ACTIVA'
            BEGIN
                RAISERROR('Cuenta no está activa', 16, 1);
            END
            
            IF @TipoCuenta = 'PLAZO FIJO'
            BEGIN
                RAISERROR('No se permiten retiros de cuentas a plazo fijo', 16, 1);
            END
            
            IF @SaldoActual < @Monto
            BEGIN
                DECLARE @MsgError NVARCHAR(200) = 'Saldo insuficiente. Disponible: S/. ' + CAST(@SaldoActual AS VARCHAR);
                RAISERROR(@MsgError, 16, 1);
            END
            
            -- Realizar retiro
            UPDATE CUENTAS 
            SET SALDO = SALDO - @Monto 
            WHERE CUENTAID = @CuentaID;
            
            -- Registrar
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
            VALUES 
                (@CuentaID, NULL, 'RETIRO', @Monto, @EmpleadoID, 'COMPLETADA');
            
        COMMIT TRANSACTION;
        
        SELECT 'ÉXITO' AS Resultado,
               @NumeroCuenta AS Cuenta,
               @Monto AS MontoRetirado,
               @SaldoActual - @Monto AS SaldoActual;
               
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;
        
        SELECT 'ERROR' AS Resultado, 
               ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
GO

-- Probar retiro
EXEC SP_RETIRO_SEGURO @NumeroCuenta = '1001-0001-0001', @Monto = 500, @EmpleadoID = 1;

GO

-- ============================================================
-- EJERCICIO 4: SIMULACIÓN DE DIRTY READ
-- Ejecutar en 2 sesiones
-- ============================================================

/*
======== SESIÓN 1 - EJECUTAR PRIMERO ========
USE BancoDB;

PRINT 'Iniciando transacción...';
BEGIN TRANSACTION;
    
    -- Actualizar saldo a 0 (pero NO confirmar)
    UPDATE CUENTAS SET SALDO = 0 WHERE CUENTAID = 1;
    
    PRINT 'Saldo actualizado a 0 (SIN COMMIT). Ejecute Sesión 2 ahora.';
    PRINT 'Esperando 15 segundos antes de ROLLBACK...';
    
    WAITFOR DELAY '00:00:15';
    
ROLLBACK TRANSACTION;
PRINT 'ROLLBACK ejecutado. El saldo NUNCA fue 0 realmente.';

-- Verificar saldo real
SELECT CUENTAID, SALDO FROM CUENTAS WHERE CUENTAID = 1;


======== SESIÓN 2 - EJECUTAR MIENTRAS SESIÓN 1 ESPERA ========
USE BancoDB;

-- PARTE A: Con NOLOCK (DIRTY READ - PELIGROSO!)
PRINT '=== Leyendo CON NOLOCK (Read Uncommitted) ===';
SELECT 
    'DIRTY READ!' AS [ADVERTENCIA],
    CUENTAID, 
    SALDO,
    'Este valor podría revertirse!' AS [Nota]
FROM CUENTAS WITH (NOLOCK) 
WHERE CUENTAID = 1;

-- PARTE B: Sin NOLOCK (SEGURO - pero espera)
PRINT '=== Leyendo SIN NOLOCK (Read Committed) ===';
PRINT 'Esta consulta esperará hasta que Sesión 1 termine...';
SELECT 
    'Lectura SEGURA' AS [Estado],
    CUENTAID, 
    SALDO,
    'Este es el valor REAL confirmado' AS [Nota]
FROM CUENTAS 
WHERE CUENTAID = 1;

PRINT 'Consulta completada después de que Sesión 1 terminó';

*/

GO

-- ============================================================
-- EJERCICIO 5: DETECCIÓN DE DEADLOCKS EN SYSTEM_HEALTH
-- ============================================================

-- Query para ver deadlocks recientes del Extended Event system_health
SELECT 
    XEvent.query('(event/data[@name="xml_report"]/value/deadlock)[1]') AS DeadlockGraph,
    XEvent.value('(event/@timestamp)[1]', 'datetime2') AS FechaHora
FROM (
    SELECT CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'system_health' AND st.target_name = 'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(XEvent)
ORDER BY XEvent.value('(event/@timestamp)[1]', 'datetime2') DESC;

GO

-- ============================================================
-- EJERCICIO 6: REPORTE DE TRANSACCIONES DEL DÍA
-- ============================================================

CREATE OR ALTER PROCEDURE SP_REPORTE_TRANSACCIONES_DIA
    @Fecha DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Si no se especifica fecha, usar hoy
    IF @Fecha IS NULL
        SET @Fecha = CAST(GETDATE() AS DATE);
    
    -- Resumen del día (usando NOLOCK porque es solo lectura de histórico)
    SELECT 
        @Fecha AS Fecha,
        COUNT(*) AS TotalTransacciones,
        SUM(CASE WHEN TIPO = 'DEPOSITO' THEN 1 ELSE 0 END) AS Depositos,
        SUM(CASE WHEN TIPO = 'RETIRO' THEN 1 ELSE 0 END) AS Retiros,
        SUM(CASE WHEN TIPO = 'TRANSFERENCIA' THEN 1 ELSE 0 END) AS Transferencias,
        SUM(MONTO) AS MontoTotal
    FROM TRANSACCIONES_BANCARIAS WITH (NOLOCK)  -- OK para reportes históricos
    WHERE CAST(FECHA AS DATE) = @Fecha;
    
    -- Detalle
    SELECT 
        T.TRANSACCIONID,
        CO.NUMEROCUENTA AS CuentaOrigen,
        CD.NUMEROCUENTA AS CuentaDestino,
        T.TIPO,
        T.MONTO,
        T.FECHA,
        E.NOMBRE + ' ' + E.APELLIDO AS Empleado,
        T.ESTADO
    FROM TRANSACCIONES_BANCARIAS T WITH (NOLOCK)
    LEFT JOIN CUENTAS CO ON T.CUENTA_ORIGEN = CO.CUENTAID
    LEFT JOIN CUENTAS CD ON T.CUENTA_DESTINO = CD.CUENTAID
    LEFT JOIN EMPLEADOS E ON T.EMPLEADOID = E.EMPLEADOID
    WHERE CAST(T.FECHA AS DATE) = @Fecha
    ORDER BY T.FECHA DESC;
END
GO

-- Ejecutar reporte
EXEC SP_REPORTE_TRANSACCIONES_DIA;

GO

-- ============================================================
-- EJERCICIO FINAL: QUIZ DE AUTOEVALUACIÓN
-- ============================================================
/*
Responde las siguientes preguntas:

1. ¿Qué nivel de aislamiento usarías para un reporte de saldos diarios?
   a) READ UNCOMMITTED
   b) READ COMMITTED
   c) SERIALIZABLE
   
2. ¿Por qué es peligroso usar NOLOCK en una consulta de saldo en cajero?
   
3. Si dos transferencias se ejecutan: A→B y B→A simultáneamente
   ¿Cómo prevendrías el deadlock?
   
4. ¿Cuál es la diferencia entre ROLLBACK TRANSACTION y ROLLBACK TRAN?
   
5. Al activar RCSI, ¿qué recurso de SQL Server incrementa su uso?

RESPUESTAS:
1. b) READ COMMITTED - Es el balance entre precisión y rendimiento
2. Podrías mostrar un saldo que en realidad se va a revertir (dirty read)
3. Ordenamiento consistente: siempre bloquear primero A, luego B (por ID menor)
4. No hay diferencia, TRAN es abreviación de TRANSACTION
5. TempDB - almacena las versiones de filas (Version Store)
*/

PRINT 'Fin de los ejercicios. ¡Practica con los escenarios de deadlock!';
