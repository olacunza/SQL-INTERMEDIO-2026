-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 2
-- MANEJO DE ERRORES PRO
-- Enfoque: Resiliencia ante Fallos Críticos
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- PARTE 0: CREAR TABLA DE LOG DE ERRORES
-- ============================================================

IF OBJECT_ID('LOG_ERRORES') IS NOT NULL DROP TABLE LOG_ERRORES;

CREATE TABLE LOG_ERRORES (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    FechaHora DATETIME2 DEFAULT SYSDATETIME(),
    ErrorNumber INT,
    ErrorMessage NVARCHAR(4000),
    ErrorSeverity INT,
    ErrorState INT,
    ErrorProcedure NVARCHAR(128),
    ErrorLine INT,
    Usuario NVARCHAR(128) DEFAULT SYSTEM_USER,
    HostName NVARCHAR(128) DEFAULT HOST_NAME(),
    AplicacionCliente NVARCHAR(128) DEFAULT APP_NAME(),
    DatosAdicionales NVARCHAR(MAX)  -- JSON con datos de contexto
);

GO

-- SP auxiliar para registrar errores
CREATE OR ALTER PROCEDURE SP_RegistrarError
    @DatosAdicionales NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Esta operación debe SER AUTÓNOMA (no depender de la transacción actual)
    INSERT INTO LOG_ERRORES (
        ErrorNumber, ErrorMessage, ErrorSeverity, 
        ErrorState, ErrorProcedure, ErrorLine, DatosAdicionales
    )
    VALUES (
        ERROR_NUMBER(), 
        ERROR_MESSAGE(), 
        ERROR_SEVERITY(),
        ERROR_STATE(), 
        ERROR_PROCEDURE(), 
        ERROR_LINE(),
        @DatosAdicionales
    );
END
GO

PRINT '✅ Tabla LOG_ERRORES y SP_RegistrarError creados';
GO

-- ============================================================
-- DEMO 1: FUNCIONES DE ERROR
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 1: FUNCIONES DE ERROR';
PRINT '============================================';

-- Provocar un error de división por cero
BEGIN TRY
    DECLARE @Resultado INT = 100 / 0;  -- Error!
    PRINT 'Esto nunca se ejecuta';
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER() AS NumeroError,
        ERROR_MESSAGE() AS MensajeError,
        ERROR_SEVERITY() AS Severidad,
        ERROR_STATE() AS Estado,
        ERROR_LINE() AS Linea,
        ERROR_PROCEDURE() AS Procedimiento;
END CATCH

GO

-- ============================================================
-- DEMO 2: XACT_STATE() EN ACCIÓN
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 2: XACT_STATE() EN ACCIÓN';
PRINT '============================================';

-- CASO 1: Sin transacción
PRINT 'CASO 1: Sin transacción activa';
SELECT XACT_STATE() AS [XACT_STATE], @@TRANCOUNT AS [TRANCOUNT];

-- CASO 2: Con transacción activa normal
PRINT 'CASO 2: Con transacción activa';
BEGIN TRANSACTION;
SELECT XACT_STATE() AS [XACT_STATE], @@TRANCOUNT AS [TRANCOUNT];
ROLLBACK TRANSACTION;

-- CASO 3: Transacción "doomed" (condenada)
PRINT 'CASO 3: Transacción condenada (XACT_STATE = -1)';
SET XACT_ABORT ON;  -- Esto causa que errores condenen la transacción
BEGIN TRY
    BEGIN TRANSACTION;
        -- Esto causará un error
        INSERT INTO CUENTAS (CLIENTEID, NUMEROCUENTA, TIPOCUENTA, SALDO)
        VALUES (999999, '0000-0000-0000', 'AHORRO', 100);  -- FK violation si cliente no existe
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT 
        'Dentro del CATCH' AS Ubicacion,
        XACT_STATE() AS [XACT_STATE], 
        @@TRANCOUNT AS [TRANCOUNT],
        ERROR_MESSAGE() AS Error;
    
    -- Intentar COMMIT en una transacción condenada FALLA
    IF XACT_STATE() = -1
    BEGIN
        PRINT 'Transacción CONDENADA: Solo podemos hacer ROLLBACK';
        ROLLBACK TRANSACTION;
    END
    ELSE IF XACT_STATE() = 1
    BEGIN
        PRINT 'Transacción activa: Podríamos hacer COMMIT o ROLLBACK';
        ROLLBACK TRANSACTION;
    END
END CATCH
SET XACT_ABORT OFF;

GO

-- ============================================================
-- DEMO 3: DIFERENCIA ENTRE XACT_ABORT ON Y OFF
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 3: XACT_ABORT ON vs OFF';
PRINT '============================================';

-- Con XACT_ABORT OFF (default)
PRINT 'CON XACT_ABORT OFF:';
SET XACT_ABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
        -- Operación 1: Exitosa
        UPDATE CUENTAS SET SALDO = SALDO WHERE CUENTAID = 1;
        
        -- Operación 2: Error (violación de constraint)
        UPDATE CUENTAS SET SALDO = -99999999 WHERE CUENTAID = 1; -- Podría fallar si hay CHECK
        
        -- Con XACT_ABORT OFF, llegamos aquí
        PRINT 'Esta línea SÍ se ejecuta con XACT_ABORT OFF';
        
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT 
        'XACT_ABORT OFF' AS Modo,
        XACT_STATE() AS [XACT_STATE],
        ERROR_MESSAGE() AS Error;
    
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH

GO

-- Con XACT_ABORT ON
PRINT 'CON XACT_ABORT ON:';
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
        -- Provocar un error que condene la transacción
        INSERT INTO CUENTAS (CLIENTEID, NUMEROCUENTA, TIPOCUENTA, SALDO)
        VALUES (999999, 'TEST-ERROR', 'AHORRO', 100);  -- FK violation
        
        PRINT 'Esta línea NUNCA se ejecuta con XACT_ABORT ON';
        
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT 
        'XACT_ABORT ON' AS Modo,
        XACT_STATE() AS [XACT_STATE],
        ERROR_MESSAGE() AS Error;
    
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH
SET XACT_ABORT OFF;

GO

-- ============================================================
-- DEMO 4: PATRÓN DE REINTENTO (RETRY PATTERN)
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 4: PATRÓN DE REINTENTO';
PRINT '============================================';

CREATE OR ALTER PROCEDURE SP_TransferenciaConReintento
    @CuentaOrigen INT,
    @CuentaDestino INT,
    @Monto DECIMAL(15,2),
    @EmpleadoID INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @Intentos INT = 0;
    DECLARE @MaxIntentos INT = 3;
    DECLARE @Exito BIT = 0;
    DECLARE @ErrorNumber INT;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @UltimoError NVARCHAR(4000);
    
    -- Errores transitorios que justifican reintento
    DECLARE @ErroresTransitorios TABLE (ErrorNumber INT);
    INSERT INTO @ErroresTransitorios VALUES (1205), (1222), (-2), (8645);
    
    WHILE @Intentos < @MaxIntentos AND @Exito = 0
    BEGIN
        SET @Intentos = @Intentos + 1;
        
        BEGIN TRY
            BEGIN TRANSACTION;
            
                -- Validaciones
                DECLARE @SaldoOrigen DECIMAL(15,2);
                SELECT @SaldoOrigen = SALDO FROM CUENTAS WHERE CUENTAID = @CuentaOrigen;
                
                IF @SaldoOrigen IS NULL
                    THROW 50001, 'Cuenta origen no existe', 1;
                
                IF @SaldoOrigen < @Monto
                    THROW 50002, 'Saldo insuficiente', 1;
                
                -- Transferencia
                UPDATE CUENTAS SET SALDO = SALDO - @Monto WHERE CUENTAID = @CuentaOrigen;
                UPDATE CUENTAS SET SALDO = SALDO + @Monto WHERE CUENTAID = @CuentaDestino;
                
                -- Registro
                INSERT INTO TRANSACCIONES_BANCARIAS 
                    (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID)
                VALUES 
                    (@CuentaOrigen, @CuentaDestino, 'TRANSFERENCIA', @Monto, @EmpleadoID);
            
            COMMIT TRANSACTION;
            
            SET @Exito = 1;
            
            SELECT 
                'ÉXITO' AS Resultado, 
                @Intentos AS IntentosRealizados,
                @Monto AS MontoTransferido;
                
        END TRY
        BEGIN CATCH
            SET @ErrorNumber = ERROR_NUMBER();
            SET @ErrorMessage = ERROR_MESSAGE();
            SET @UltimoError = @ErrorMessage;
            
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
            
            -- ¿Es un error transitorio?
            IF EXISTS (SELECT 1 FROM @ErroresTransitorios WHERE ErrorNumber = @ErrorNumber)
            BEGIN
                -- Registrar intento fallido
                DECLARE @DatosReintento NVARCHAR(MAX) = 
                    CONCAT('{"intento":', @Intentos, ',"error":', @ErrorNumber, '}');
                
                INSERT INTO LOG_ERRORES (ErrorNumber, ErrorMessage, ErrorSeverity, ErrorState, ErrorProcedure, DatosAdicionales)
                VALUES (@ErrorNumber, @ErrorMessage, ERROR_SEVERITY(), ERROR_STATE(), 'SP_TransferenciaConReintento', @DatosReintento);
                
                -- Backoff exponencial: 1s, 2s, 4s
                DECLARE @EsperaSegundos INT = POWER(2, @Intentos - 1);
                DECLARE @EsperaString VARCHAR(12) = '00:00:0' + CAST(@EsperaSegundos AS VARCHAR(2));
                
                PRINT CONCAT('Reintento ', @Intentos, ' de ', @MaxIntentos, 
                            '. Error transitorio: ', @ErrorNumber, 
                            '. Esperando ', @EsperaSegundos, ' segundos...');
                
                WAITFOR DELAY @EsperaString;
            END
            ELSE
            BEGIN
                -- Error NO transitorio: no reintentar
                PRINT CONCAT('Error NO transitorio (', @ErrorNumber, '): ', @ErrorMessage);
                
                -- Registrar error final
                EXEC SP_RegistrarError @DatosAdicionales = 'No transitorio - sin reintento';
                
                -- Salir del loop
                BREAK;
            END
        END CATCH
    END
    
    -- Si agotamos reintentos
    IF @Exito = 0
    BEGIN
        SELECT 
            'ERROR' AS Resultado,
            @Intentos AS IntentosRealizados,
            @UltimoError AS UltimoError;
    END
END
GO

-- Probar transferencia exitosa
PRINT 'Prueba 1: Transferencia exitosa';
EXEC SP_TransferenciaConReintento @CuentaOrigen = 1, @CuentaDestino = 2, @Monto = 100;

-- Probar con cuenta inexistente (error no transitorio)
PRINT 'Prueba 2: Cuenta inexistente (no reintenta)';
EXEC SP_TransferenciaConReintento @CuentaOrigen = 999, @CuentaDestino = 2, @Monto = 100;

-- Probar con saldo insuficiente (error no transitorio)
PRINT 'Prueba 3: Saldo insuficiente (no reintenta)';
EXEC SP_TransferenciaConReintento @CuentaOrigen = 5, @CuentaDestino = 2, @Monto = 999999;

GO

-- ============================================================
-- DEMO 5: THROW vs RAISERROR
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 5: THROW vs RAISERROR';
PRINT '============================================';

-- THROW: Simple y directo
PRINT 'THROW - Lanzar error personalizado:';
BEGIN TRY
    THROW 50001, 'Este es un error personalizado con THROW', 1;
END TRY
BEGIN CATCH
    SELECT 
        'THROW' AS Metodo,
        ERROR_NUMBER() AS Numero,
        ERROR_MESSAGE() AS Mensaje,
        ERROR_SEVERITY() AS Severidad;  -- Siempre 16 con THROW
END CATCH

GO

-- THROW: Re-lanzar error capturado
PRINT 'THROW - Re-lanzar error capturado:';
BEGIN TRY
    BEGIN TRY
        SELECT 1/0;  -- Error original
    END TRY
    BEGIN CATCH
        ;THROW;  -- Re-lanza el error original (notar el ; antes)
    END CATCH
END TRY
BEGIN CATCH
    SELECT 
        'THROW (re-lanzado)' AS Metodo,
        ERROR_NUMBER() AS Numero,
        ERROR_MESSAGE() AS Mensaje;
END CATCH

GO

-- RAISERROR: Más control
PRINT 'RAISERROR - Con formato y severidad:';
BEGIN TRY
    DECLARE @Cliente INT = 12345;
    DECLARE @Saldo DECIMAL(15,2) = 1000.50;
    
    -- Mensaje con parámetros
    RAISERROR('Cliente %d tiene saldo insuficiente: %.2f', 16, 1, @Cliente, @Saldo);
END TRY
BEGIN CATCH
    SELECT 
        'RAISERROR' AS Metodo,
        ERROR_NUMBER() AS Numero,
        ERROR_MESSAGE() AS Mensaje,
        ERROR_SEVERITY() AS Severidad;
END CATCH

GO

-- RAISERROR con severidad baja (warning, no error)
PRINT 'RAISERROR - Como WARNING (severidad 10):';
RAISERROR('Este es solo un warning informativo', 10, 1) WITH NOWAIT;
PRINT 'La ejecución continúa después del warning';

GO

-- ============================================================
-- DEMO 6: SP COMPLETO CON MANEJO ROBUSTO DE ERRORES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 6: SP BANCARIO CON MANEJO ROBUSTO';
PRINT '============================================';

CREATE OR ALTER PROCEDURE SP_TransferenciaRobusta
    @CuentaOrigen INT,
    @CuentaDestino INT,
    @Monto DECIMAL(15,2),
    @Concepto NVARCHAR(200) = 'Transferencia',
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    -- Variables para control
    DECLARE @ErrorNumber INT;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    DECLARE @ErrorLine INT;
    
    -- Variables de negocio
    DECLARE @SaldoOrigen DECIMAL(15,2);
    DECLARE @EstadoOrigen NVARCHAR(10);
    DECLARE @EstadoDestino NVARCHAR(10);
    DECLARE @TipoCuentaOrigen NVARCHAR(20);
    DECLARE @TransaccionID INT;
    
    -- Datos para logging
    DECLARE @DatosContexto NVARCHAR(MAX);
    SET @DatosContexto = CONCAT(
        '{"cuenta_origen":', @CuentaOrigen, 
        ',"cuenta_destino":', @CuentaDestino,
        ',"monto":', @Monto,
        ',"empleado":', @EmpleadoID,
        ',"concepto":"', @Concepto, '"}'
    );
    
    BEGIN TRY
        -- ==========================================
        -- VALIDACIONES PREVIAS (fuera de transacción)
        -- ==========================================
        
        -- Validar monto
        IF @Monto <= 0
            THROW 50001, 'El monto debe ser mayor a cero', 1;
        
        IF @Monto > 1000000
            THROW 50002, 'El monto excede el límite permitido por transacción', 1;
        
        -- Validar que no sea la misma cuenta
        IF @CuentaOrigen = @CuentaDestino
            THROW 50003, 'Las cuentas origen y destino deben ser diferentes', 1;
        
        -- Obtener datos de cuenta origen
        SELECT 
            @SaldoOrigen = SALDO,
            @EstadoOrigen = ESTADO,
            @TipoCuentaOrigen = TIPOCUENTA
        FROM CUENTAS 
        WHERE CUENTAID = @CuentaOrigen;
        
        IF @SaldoOrigen IS NULL
            THROW 50004, 'Cuenta origen no encontrada', 1;
        
        IF @EstadoOrigen <> 'ACTIVA'
        BEGIN
            DECLARE @MsgEstado NVARCHAR(200) = CONCAT('Cuenta origen está ', @EstadoOrigen);
            THROW 50005, @MsgEstado, 1;
        END
        
        IF @TipoCuentaOrigen = 'PLAZO FIJO'
            THROW 50006, 'No se permiten débitos de cuentas a plazo fijo', 1;
        
        IF @SaldoOrigen < @Monto
        BEGIN
            DECLARE @MsgSaldo NVARCHAR(200) = CONCAT('Saldo insuficiente. Disponible: ', @SaldoOrigen);
            THROW 50007, @MsgSaldo, 1;
        END
        
        -- Validar cuenta destino
        SELECT @EstadoDestino = ESTADO FROM CUENTAS WHERE CUENTAID = @CuentaDestino;
        
        IF @EstadoDestino IS NULL
            THROW 50008, 'Cuenta destino no encontrada', 1;
        
        IF @EstadoDestino <> 'ACTIVA'
            THROW 50009, 'Cuenta destino no está activa', 1;
        
        -- ==========================================
        -- TRANSACCIÓN (solo operaciones de modificación)
        -- ==========================================
        BEGIN TRANSACTION;
            
            -- Bloquear cuentas en orden consistente (prevención deadlock)
            DECLARE @Primera INT = IIF(@CuentaOrigen < @CuentaDestino, @CuentaOrigen, @CuentaDestino);
            DECLARE @Segunda INT = IIF(@CuentaOrigen < @CuentaDestino, @CuentaDestino, @CuentaOrigen);
            
            -- Obtener locks
            SELECT SALDO FROM CUENTAS WITH (UPDLOCK, ROWLOCK) WHERE CUENTAID = @Primera;
            SELECT SALDO FROM CUENTAS WITH (UPDLOCK, ROWLOCK) WHERE CUENTAID = @Segunda;
            
            -- Debitar
            UPDATE CUENTAS 
            SET SALDO = SALDO - @Monto 
            WHERE CUENTAID = @CuentaOrigen;
            
            -- Acreditar
            UPDATE CUENTAS 
            SET SALDO = SALDO + @Monto 
            WHERE CUENTAID = @CuentaDestino;
            
            -- Registrar transacción
            INSERT INTO TRANSACCIONES_BANCARIAS 
                (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO)
            VALUES 
                (@CuentaOrigen, @CuentaDestino, 'TRANSFERENCIA', @Monto, @EmpleadoID, 'COMPLETADA');
            
            SET @TransaccionID = SCOPE_IDENTITY();
            
        COMMIT TRANSACTION;
        
        -- ==========================================
        -- RESPUESTA EXITOSA
        -- ==========================================
        SELECT 
            'ÉXITO' AS Resultado,
            @TransaccionID AS TransaccionID,
            @Monto AS MontoTransferido,
            @SaldoOrigen - @Monto AS NuevoSaldoOrigen,
            GETDATE() AS FechaHora;
            
    END TRY
    BEGIN CATCH
        -- Capturar info del error PRIMERO
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();
        SET @ErrorLine = ERROR_LINE();
        
        -- Manejar transacción según su estado
        IF XACT_STATE() = -1
        BEGIN
            -- Transacción condenada: ROLLBACK obligatorio
            ROLLBACK TRANSACTION;
        END
        ELSE IF XACT_STATE() = 1
        BEGIN
            -- Transacción activa: hacemos ROLLBACK por el error
            ROLLBACK TRANSACTION;
        END
        -- Si XACT_STATE() = 0, no hay transacción que manejar
        
        -- Registrar error (fuera de transacción)
        INSERT INTO LOG_ERRORES (
            ErrorNumber, ErrorMessage, ErrorSeverity, 
            ErrorState, ErrorProcedure, ErrorLine, DatosAdicionales
        )
        VALUES (
            @ErrorNumber, @ErrorMessage, @ErrorSeverity,
            @ErrorState, 'SP_TransferenciaRobusta', @ErrorLine, @DatosContexto
        );
        
        -- Respuesta de error
        SELECT 
            'ERROR' AS Resultado,
            @ErrorNumber AS CodigoError,
            @ErrorMessage AS Mensaje,
            GETDATE() AS FechaHora;
        
        -- NO re-lanzamos para que el llamador pueda manejar la respuesta
        -- Si quieres propagar el error: THROW;
    END CATCH
END
GO

-- Pruebas del SP robusto
PRINT 'Prueba 1: Transferencia exitosa';
EXEC SP_TransferenciaRobusta 
    @CuentaOrigen = 1, 
    @CuentaDestino = 2, 
    @Monto = 500, 
    @Concepto = 'Pago de servicios',
    @EmpleadoID = 1;

PRINT 'Prueba 2: Monto negativo';
EXEC SP_TransferenciaRobusta @CuentaOrigen = 1, @CuentaDestino = 2, @Monto = -100, @EmpleadoID = 1;

PRINT 'Prueba 3: Misma cuenta origen y destino';
EXEC SP_TransferenciaRobusta @CuentaOrigen = 1, @CuentaDestino = 1, @Monto = 100, @EmpleadoID = 1;

PRINT 'Prueba 4: Cuenta inexistente';
EXEC SP_TransferenciaRobusta @CuentaOrigen = 999, @CuentaDestino = 2, @Monto = 100, @EmpleadoID = 1;

PRINT 'Prueba 5: Saldo insuficiente';
EXEC SP_TransferenciaRobusta @CuentaOrigen = 5, @CuentaDestino = 2, @Monto = 999999, @EmpleadoID = 1;

GO

-- ============================================================
-- VER LOG DE ERRORES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'LOG DE ERRORES REGISTRADOS';
PRINT '============================================';

SELECT 
    LogID,
    FechaHora,
    ErrorNumber,
    LEFT(ErrorMessage, 60) AS ErrorMessage,
    ErrorProcedure,
    DatosAdicionales
FROM LOG_ERRORES
ORDER BY LogID DESC;

GO

-- ============================================================
-- EJERCICIO: CREAR SP_RETIRO_ROBUSTO
-- ============================================================
/*
EJERCICIO: Crear un Stored Procedure SP_RETIRO_ROBUSTO que:

1. Reciba: @NumeroCuenta, @Monto, @EmpleadoID
2. Implemente todas las validaciones:
   - Monto positivo
   - Cuenta existe
   - Cuenta activa
   - No es plazo fijo
   - Saldo suficiente
3. Use XACT_STATE() correctamente
4. Registre errores en LOG_ERRORES
5. Tenga patrón de reintento para errores 1205 (deadlock)
6. Retorne un resultado estructurado (Resultado, Mensaje, NuevoSaldo)

BONUS: Agregar validación de monto máximo de retiro diario ($10,000)

Tip: Usa SP_TransferenciaRobusta como plantilla base.
*/

GO

-- ============================================================
-- CONSULTAS DE DIAGNÓSTICO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'CONSULTAS DE DIAGNÓSTICO';
PRINT '============================================';

-- Errores más frecuentes
SELECT 
    ErrorNumber,
    COUNT(*) AS Cantidad,
    MAX(ErrorMessage) AS UltimoMensaje
FROM LOG_ERRORES
GROUP BY ErrorNumber
ORDER BY COUNT(*) DESC;

-- Errores por hora
SELECT 
    DATEPART(HOUR, FechaHora) AS Hora,
    COUNT(*) AS CantidadErrores
FROM LOG_ERRORES
WHERE FechaHora >= DATEADD(DAY, -1, GETDATE())
GROUP BY DATEPART(HOUR, FechaHora)
ORDER BY Hora;

-- Errores por procedimiento
SELECT 
    ISNULL(ErrorProcedure, 'Ad-hoc') AS Procedimiento,
    COUNT(*) AS CantidadErrores
FROM LOG_ERRORES
GROUP BY ErrorProcedure
ORDER BY COUNT(*) DESC;

GO

PRINT '';
PRINT '============================================';
PRINT 'FIN DE LA SESIÓN 2';
PRINT '============================================';
