-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 2
-- EJERCICIOS PRÁCTICOS: MANEJO DE ERRORES PRO
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: COMPLETAR EL SP_RETIRO_ROBUSTO
-- ============================================================

-- Solución propuesta
CREATE OR ALTER PROCEDURE SP_RETIRO_ROBUSTO
    @NumeroCuenta NVARCHAR(20),
    @Monto DECIMAL(15,2),
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    -- Variables de control
    DECLARE @Intentos INT = 0;
    DECLARE @MaxIntentos INT = 3;
    DECLARE @Exito BIT = 0;
    
    -- Variables de error
    DECLARE @ErrorNumber INT;
    DECLARE @ErrorMessage NVARCHAR(4000);
    
    -- Variables de negocio
    DECLARE @CuentaID INT;
    DECLARE @SaldoActual DECIMAL(15,2);
    DECLARE @Estado NVARCHAR(10);
    DECLARE @TipoCuenta NVARCHAR(20);
    DECLARE @RetiroDiario DECIMAL(15,2);
    DECLARE @LimiteRetiroDiario DECIMAL(15,2) = 10000.00;
    
    -- Datos para log
    DECLARE @DatosContexto NVARCHAR(MAX);
    
    -- ======== VALIDACIONES PREVIAS (fuera de transacción) ========
    
    -- Validar monto
    IF @Monto <= 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 'El monto debe ser mayor a cero' AS Mensaje;
        RETURN;
    END
    
    -- Buscar cuenta
    SELECT 
        @CuentaID = CUENTAID,
        @SaldoActual = SALDO,
        @Estado = ESTADO,
        @TipoCuenta = TIPOCUENTA
    FROM CUENTAS 
    WHERE NUMEROCUENTA = @NumeroCuenta;
    
    IF @CuentaID IS NULL
    BEGIN
        SELECT 'ERROR' AS Resultado, 'Cuenta no encontrada' AS Mensaje;
        RETURN;
    END
    
    IF @Estado <> 'ACTIVA'
    BEGIN
        SELECT 'ERROR' AS Resultado, CONCAT('Cuenta ', @Estado) AS Mensaje;
        RETURN;
    END
    
    IF @TipoCuenta = 'PLAZO FIJO'
    BEGIN
        SELECT 'ERROR' AS Resultado, 'No se permiten retiros de cuentas a plazo fijo' AS Mensaje;
        RETURN;
    END
    
    IF @SaldoActual < @Monto
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               CONCAT('Saldo insuficiente. Disponible: S/. ', @SaldoActual) AS Mensaje;
        RETURN;
    END
    
    -- BONUS: Validar límite de retiro diario
    SELECT @RetiroDiario = ISNULL(SUM(MONTO), 0)
    FROM TRANSACCIONES_BANCARIAS
    WHERE CUENTA_ORIGEN = @CuentaID
      AND TIPO = 'RETIRO'
      AND CAST(FECHA AS DATE) = CAST(GETDATE() AS DATE);
    
    IF (@RetiroDiario + @Monto) > @LimiteRetiroDiario
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               CONCAT('Excede límite diario de retiro. Disponible hoy: S/. ', 
                      @LimiteRetiroDiario - @RetiroDiario) AS Mensaje;
        RETURN;
    END
    
    -- Preparar datos de contexto
    SET @DatosContexto = CONCAT(
        '{"cuenta":"', @NumeroCuenta, 
        '","monto":', @Monto,
        ',"empleado":', @EmpleadoID, '}'
    );
    
    -- ======== LOOP DE REINTENTOS ========
    WHILE @Intentos < @MaxIntentos AND @Exito = 0
    BEGIN
        SET @Intentos = @Intentos + 1;
        
        BEGIN TRY
            BEGIN TRANSACTION;
                
                -- Re-verificar saldo con bloqueo (por si cambió)
                SELECT @SaldoActual = SALDO 
                FROM CUENTAS WITH (UPDLOCK, ROWLOCK) 
                WHERE CUENTAID = @CuentaID;
                
                IF @SaldoActual < @Monto
                    THROW 50001, 'Saldo insuficiente (verificación concurrente)', 1;
                
                -- Realizar retiro
                UPDATE CUENTAS 
                SET SALDO = SALDO - @Monto 
                WHERE CUENTAID = @CuentaID;
                
                -- Registrar transacción
                INSERT INTO TRANSACCIONES_BANCARIAS 
                    (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
                VALUES 
                    (@CuentaID, NULL, 'RETIRO', @Monto, @EmpleadoID, 'COMPLETADA');
                
            COMMIT TRANSACTION;
            
            SET @Exito = 1;
            
            SELECT 
                'ÉXITO' AS Resultado,
                @NumeroCuenta AS Cuenta,
                @Monto AS MontoRetirado,
                @SaldoActual - @Monto AS NuevoSaldo;
                
        END TRY
        BEGIN CATCH
            SET @ErrorNumber = ERROR_NUMBER();
            SET @ErrorMessage = ERROR_MESSAGE();
            
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
            
            -- ¿Es deadlock? Reintentar
            IF @ErrorNumber = 1205
            BEGIN
                IF @Intentos < @MaxIntentos
                BEGIN
                    -- Log del reintento
                    INSERT INTO LOG_ERRORES (ErrorNumber, ErrorMessage, ErrorProcedure, DatosAdicionales)
                    VALUES (@ErrorNumber, @ErrorMessage, 'SP_RETIRO_ROBUSTO', 
                            CONCAT(@DatosContexto, ',"intento":', @Intentos));
                    
                    -- Backoff exponencial
                    DECLARE @Espera VARCHAR(12) = '00:00:0' + CAST(POWER(2, @Intentos - 1) AS VARCHAR);
                    WAITFOR DELAY @Espera;
                END
            END
            ELSE
            BEGIN
                -- Error no transitorio: registrar y salir
                INSERT INTO LOG_ERRORES (ErrorNumber, ErrorMessage, ErrorProcedure, DatosAdicionales)
                VALUES (@ErrorNumber, @ErrorMessage, 'SP_RETIRO_ROBUSTO', @DatosContexto);
                
                SELECT 'ERROR' AS Resultado, @ErrorMessage AS Mensaje;
                RETURN;
            END
        END CATCH
    END
    
    -- Si agotamos reintentos
    IF @Exito = 0
    BEGIN
        SELECT 'ERROR' AS Resultado, 
               CONCAT('Operación fallida después de ', @MaxIntentos, ' intentos por deadlock') AS Mensaje;
    END
END
GO

-- Pruebas
PRINT 'Prueba: Retiro válido';
EXEC SP_RETIRO_ROBUSTO @NumeroCuenta = '1001-0001-0001', @Monto = 200, @EmpleadoID = 1;

GO

-- ============================================================
-- EJERCICIO 2: SP_DEPOSITO_CON_VALIDACION
-- ============================================================

CREATE OR ALTER PROCEDURE SP_DEPOSITO_CON_VALIDACION
    @NumeroCuenta NVARCHAR(20),
    @Monto DECIMAL(15,2),
    @Origen NVARCHAR(50),  -- 'EFECTIVO', 'CHEQUE', 'TRANSFERENCIA'
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @CuentaID INT;
    DECLARE @Estado NVARCHAR(10);
    DECLARE @SaldoPrevio DECIMAL(15,2);
    DECLARE @SaldoNuevo DECIMAL(15,2);
    
    BEGIN TRY
        -- Validaciones
        IF @Monto <= 0
            THROW 50001, 'El monto debe ser mayor a cero', 1;
        
        IF @Monto > 50000 AND @Origen = 'EFECTIVO'
            THROW 50002, 'Depósitos en efectivo mayores a S/. 50,000 requieren autorización especial', 1;
        
        IF @Origen NOT IN ('EFECTIVO', 'CHEQUE', 'TRANSFERENCIA')
            THROW 50003, 'Origen de depósito no válido', 1;
        
        SELECT 
            @CuentaID = CUENTAID,
            @Estado = ESTADO,
            @SaldoPrevio = SALDO
        FROM CUENTAS 
        WHERE NUMEROCUENTA = @NumeroCuenta;
        
        IF @CuentaID IS NULL
            THROW 50004, 'Cuenta no encontrada', 1;
        
        IF @Estado <> 'ACTIVA'
            THROW 50005, 'La cuenta no está activa', 1;
        
        -- Transacción
        BEGIN TRANSACTION;
            
            UPDATE CUENTAS 
            SET SALDO = SALDO + @Monto 
            WHERE CUENTAID = @CuentaID;
            
            SELECT @SaldoNuevo = SALDO FROM CUENTAS WHERE CUENTAID = @CuentaID;
            
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
            VALUES 
                (NULL, @CuentaID, 'DEPOSITO', @Monto, @EmpleadoID, 'COMPLETADA');
            
        COMMIT TRANSACTION;
        
        SELECT 
            'ÉXITO' AS Resultado,
            @NumeroCuenta AS Cuenta,
            @Origen AS OrigenDeposito,
            @SaldoPrevio AS SaldoAnterior,
            @Monto AS MontoDepositado,
            @SaldoNuevo AS NuevoSaldo;
            
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        
        EXEC SP_RegistrarError;
        
        SELECT 
            'ERROR' AS Resultado,
            ERROR_NUMBER() AS Codigo,
            ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
GO

-- Pruebas
PRINT 'Depósito en efectivo:';
EXEC SP_DEPOSITO_CON_VALIDACION @NumeroCuenta = '1001-0002-0001', @Monto = 1500, @Origen = 'EFECTIVO', @EmpleadoID = 2;

PRINT 'Depósito mayor a límite:';
EXEC SP_DEPOSITO_CON_VALIDACION @NumeroCuenta = '1001-0002-0001', @Monto = 75000, @Origen = 'EFECTIVO', @EmpleadoID = 2;

GO

-- ============================================================
-- EJERCICIO 3: TRANSACCIONES ANIDADAS
-- ============================================================

-- Demostrar comportamiento de transacciones anidadas
CREATE OR ALTER PROCEDURE SP_Demo_TransaccionesAnidadas
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '=== DEMO: Transacciones Anidadas ===';
    PRINT CONCAT('@@TRANCOUNT inicial: ', @@TRANCOUNT);
    
    BEGIN TRY
        BEGIN TRANSACTION Tran1;
        PRINT CONCAT('Después de BEGIN TRAN 1: @@TRANCOUNT = ', @@TRANCOUNT);
        
            BEGIN TRANSACTION Tran2;
            PRINT CONCAT('Después de BEGIN TRAN 2: @@TRANCOUNT = ', @@TRANCOUNT);
            
                BEGIN TRANSACTION Tran3;
                PRINT CONCAT('Después de BEGIN TRAN 3: @@TRANCOUNT = ', @@TRANCOUNT);
                
                COMMIT TRANSACTION Tran3;
                PRINT CONCAT('Después de COMMIT 3: @@TRANCOUNT = ', @@TRANCOUNT);
            
            COMMIT TRANSACTION Tran2;
            PRINT CONCAT('Después de COMMIT 2: @@TRANCOUNT = ', @@TRANCOUNT);
        
        COMMIT TRANSACTION Tran1;
        PRINT CONCAT('Después de COMMIT 1: @@TRANCOUNT = ', @@TRANCOUNT);
        
        PRINT '¡Todas las transacciones completadas!';
        
    END TRY
    BEGIN CATCH
        PRINT CONCAT('Error! @@TRANCOUNT = ', @@TRANCOUNT);
        
        -- Un solo ROLLBACK revierte TODAS las transacciones anidadas
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT CONCAT('Después de ROLLBACK: @@TRANCOUNT = ', @@TRANCOUNT);
        END
        
        THROW;
    END CATCH
END
GO

EXEC SP_Demo_TransaccionesAnidadas;

GO

-- ============================================================
-- EJERCICIO 4: SAVEPOINTS
-- ============================================================

CREATE OR ALTER PROCEDURE SP_Demo_Savepoints
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SaldoCuenta1 DECIMAL(15,2);
    DECLARE @SaldoCuenta2 DECIMAL(15,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Operación 1: Débito
        UPDATE CUENTAS SET SALDO = SALDO - 100 WHERE CUENTAID = 1;
        PRINT 'Operación 1 completada: Débito de 100';
        
        -- Savepoint después del débito exitoso
        SAVE TRANSACTION Savepoint_Despues_Debito;
        PRINT 'Savepoint creado';
        
        -- Operación 2: Intentar crédito (puede fallar)
        BEGIN TRY
            -- Simular un error
            IF 1 = 1
                THROW 50001, 'Error simulado en crédito', 1;
            
            UPDATE CUENTAS SET SALDO = SALDO + 100 WHERE CUENTAID = 2;
        END TRY
        BEGIN CATCH
            PRINT CONCAT('Error en Operación 2: ', ERROR_MESSAGE());
            
            -- Rollback SOLO hasta el savepoint
            ROLLBACK TRANSACTION Savepoint_Despues_Debito;
            PRINT 'Rollback hasta savepoint (Operación 1 se mantiene en memoria)';
            
            -- Operación alternativa
            UPDATE CUENTAS SET SALDO = SALDO + 100 WHERE CUENTAID = 3;
            PRINT 'Operación alternativa: Crédito a cuenta 3';
        END CATCH
        
        COMMIT TRANSACTION;
        PRINT 'Transacción completada';
        
        -- Ver resultado
        SELECT CUENTAID, SALDO FROM CUENTAS WHERE CUENTAID IN (1, 2, 3);
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Nota: Este ejemplo muestra savepoints pero hay un problema conceptual
-- El savepoint no persiste el débito, solo marca un punto de retorno
-- Si luego hay ROLLBACK TRANSACTION completo, TODO se revierte

GO

-- ============================================================
-- EJERCICIO 5: ERRORES PERSONALIZADOS CON sp_addmessage
-- ============================================================

-- Crear mensajes de error personalizados
IF EXISTS (SELECT * FROM sys.messages WHERE message_id = 60001)
    EXEC sp_dropmessage @msgnum = 60001, @lang = 'us_english';

EXEC sp_addmessage 
    @msgnum = 60001,
    @severity = 16,
    @msgtext = 'Error bancario: La cuenta %s no tiene saldo suficiente. Disponible: %s',
    @lang = 'us_english';

GO

-- Usar el mensaje personalizado
BEGIN TRY
    DECLARE @Cuenta VARCHAR(20) = '1001-0001-0001';
    DECLARE @Saldo VARCHAR(20) = '1,500.00';
    
    RAISERROR(60001, 16, 1, @Cuenta, @Saldo);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

GO

-- ============================================================
-- QUIZ DE AUTOEVALUACIÓN
-- ============================================================
/*
PREGUNTA 1: ¿Qué retorna XACT_STATE() cuando hay un deadlock?
a) 0
b) 1
c) -1
d) NULL

PREGUNTA 2: ¿Qué diferencia hay entre THROW y RAISERROR?
a) No hay diferencia
b) THROW siempre usa severidad 16
c) RAISERROR no puede usar parámetros
d) THROW es más lento

PREGUNTA 3: ¿Cuál de estos errores NO justifica un reintento?
a) 1205 (Deadlock)
b) 1222 (Lock timeout)
c) 547 (FK violation)
d) -2 (Connection timeout)

PREGUNTA 4: Con XACT_ABORT ON, ¿qué pasa si hay un error en una transacción?
a) La ejecución continúa
b) Solo se registra en el log
c) La transacción se revierte automáticamente
d) Se envía un email al DBA

PREGUNTA 5: ¿ERROR_MESSAGE() funciona fuera de un bloque CATCH?
a) Sí, siempre
b) No, retorna NULL
c) Solo si hay un error previo
d) Depende de la versión de SQL Server

RESPUESTAS:
1. c) -1 (transacción condenada)
2. b) THROW siempre usa severidad 16
3. c) 547 (FK violation - error de datos, no transitorio)
4. c) La transacción se revierte automáticamente
5. b) No, retorna NULL (solo funciona dentro de CATCH)
*/

PRINT 'Fin de los ejercicios prácticos - Sesión 2';
