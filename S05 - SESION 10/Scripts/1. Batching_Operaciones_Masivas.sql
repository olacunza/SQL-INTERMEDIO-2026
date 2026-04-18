/*
=====================================================================
  SESIÓN 10: BATCHING Y OPERACIONES MASIVAS
  SQL Server Intermedio 2026
  
  Temas:
    1. ¿Por qué procesar por lotes?
    2. Problemas de operaciones masivas sin control
    3. DELETE masivo con chunking
    4. UPDATE masivo por lotes
    5. INSERT masivo: BULK INSERT y alternativas
    6. MERGE: La navaja suiza de operaciones masivas
    7. TRY_CONVERT y TRY_CAST para datos sucios
    8. TRY_PARSE para conversiones culturales
    9. Transacciones y checkpoints
   10. Monitoreo de progreso
   11. Caso práctico: Purga de transacciones históricas
   
  Base de datos: BancoDB
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- PARTE 1: ¿POR QUÉ PROCESAR POR LOTES?
-- =====================================================================
/*
   PROBLEMAS DE OPERACIONES MASIVAS SIN CONTROL:
   
   1. BLOQUEOS EXTENSOS:
      DELETE FROM Transacciones WHERE Fecha < '2020-01-01'
      → Bloquea TODA la tabla durante minutos/horas
      → Otras operaciones esperan
   
   2. LOG DE TRANSACCIONES DESBORDADO:
      → Una transacción gigante = log gigante
      → Posible llenado del disco
      → Recovery model FULL: backup de log enorme
   
   3. ESCALAMIENTO DE BLOQUEOS:
      SQL Server escala de row → page → table lock
      → >5000 locks = escalamiento probable
   
   4. TIMEOUT EN APLICACIONES:
      → Conexiones que esperan indefinidamente
      → Errores en producción
   
   SOLUCIÓN: BATCHING (Procesamiento por Lotes)
   
   ┌─────────────────────────────────────────────────────────────────┐
   │  EN LUGAR DE:           │  HACER:                              │
   │  DELETE 1,000,000 rows  │  DELETE 10,000 rows × 100 iteraciones│
   │  1 transacción gigante  │  100 transacciones pequeñas          │
   │  Lock por minutos       │  Locks de segundos cada una          │
   └─────────────────────────────────────────────────────────────────┘
*/

-- =====================================================================
-- PARTE 2: PROBLEMAS DE OPERACIONES MASIVAS - DEMOSTRACIÓN
-- =====================================================================

-- Crear tabla de prueba con muchos registros
CREATE TABLE #DatosMasivos (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Descripcion VARCHAR(100),
    Monto DECIMAL(15,2),
    Estado CHAR(1)
);

-- Insertar 100,000 registros de prueba
INSERT INTO #DatosMasivos (Fecha, Descripcion, Monto, Estado)
SELECT TOP 100000
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1825, GETDATE()),  -- Últimos 5 años
    'Transaccion de prueba ' + CAST(ROW_NUMBER() OVER(ORDER BY a.object_id) AS VARCHAR),
    ROUND(RAND(CHECKSUM(NEWID())) * 10000, 2),
    CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN 'A' WHEN 1 THEN 'P' ELSE 'C' END
FROM sys.objects a, sys.objects b;

-- Ver distribución por año
SELECT 
    YEAR(Fecha) AS Año,
    COUNT(*) AS Registros
FROM #DatosMasivos
GROUP BY YEAR(Fecha)
ORDER BY Año;

-- =====================================================================
-- PARTE 3: DELETE MASIVO CON CHUNKING
-- =====================================================================
/*
   TÉCNICA DE CHUNKING:
   - Procesar N registros por iteración
   - WHILE loop hasta completar
   - Pausa opcional entre lotes (WAITFOR)
   - Log de progreso
*/

-- MALO: DELETE sin control
-- DELETE FROM #DatosMasivos WHERE Fecha < DATEADD(YEAR, -3, GETDATE());
-- ↑ Bloquea toda la tabla, log enorme

-- BUENO: DELETE con chunking
DECLARE @BatchSize INT = 5000;          -- Registros por lote
DECLARE @RowsAffected INT = 1;          -- Para controlar el loop
DECLARE @TotalDeleted INT = 0;          -- Contador total
DECLARE @FechaCorte DATE = DATEADD(YEAR, -3, GETDATE());

PRINT 'Iniciando purga de registros anteriores a: ' + CAST(@FechaCorte AS VARCHAR);
PRINT 'Tamaño de lote: ' + CAST(@BatchSize AS VARCHAR);
PRINT '----------------------------------------';

WHILE @RowsAffected > 0
BEGIN
    DELETE TOP (@BatchSize) 
    FROM #DatosMasivos 
    WHERE Fecha < @FechaCorte;
    
    SET @RowsAffected = @@ROWCOUNT;
    SET @TotalDeleted = @TotalDeleted + @RowsAffected;
    
    IF @RowsAffected > 0
    BEGIN
        PRINT 'Lote eliminado: ' + CAST(@RowsAffected AS VARCHAR) + 
              ' | Total acumulado: ' + CAST(@TotalDeleted AS VARCHAR) +
              ' | ' + CONVERT(VARCHAR, GETDATE(), 120);
        
        -- Pequeña pausa para liberar recursos (opcional)
        -- WAITFOR DELAY '00:00:00.100';  -- 100ms
    END
END

PRINT '----------------------------------------';
PRINT 'COMPLETADO. Total eliminado: ' + CAST(@TotalDeleted AS VARCHAR);

-- Verificar resultado
SELECT COUNT(*) AS RegistrosRestantes FROM #DatosMasivos;

-- =====================================================================
-- PARTE 4: UPDATE MASIVO POR LOTES
-- =====================================================================
/*
   Misma técnica aplicada a UPDATE:
   - Especialmente importante cuando UPDATE causa crecimiento de registro
   - Evita page splits masivos
*/

-- Agregar columna para demostración
ALTER TABLE #DatosMasivos ADD Procesado BIT DEFAULT 0;
GO

-- UPDATE masivo con chunking
DECLARE @BatchSize INT = 10000;
DECLARE @RowsAffected INT = 1;
DECLARE @TotalUpdated INT = 0;

WHILE @RowsAffected > 0
BEGIN
    UPDATE TOP (@BatchSize) #DatosMasivos
    SET Procesado = 1,
        Descripcion = Descripcion + ' [Procesado]'
    WHERE Procesado = 0
      AND Estado = 'A';
    
    SET @RowsAffected = @@ROWCOUNT;
    SET @TotalUpdated = @TotalUpdated + @RowsAffected;
    
    IF @RowsAffected > 0
        PRINT 'Actualizados: ' + CAST(@RowsAffected AS VARCHAR) + 
              ' | Total: ' + CAST(@TotalUpdated AS VARCHAR);
END

PRINT 'Total registros actualizados: ' + CAST(@TotalUpdated AS VARCHAR);

-- =====================================================================
-- PARTE 5: INSERT MASIVO - TÉCNICAS
-- =====================================================================
/*
   OPCIONES PARA INSERT MASIVO:
   
   1. INSERT...SELECT con TOP
   2. BULK INSERT (desde archivo)
   3. INSERT con OUTPUT para logging
   4. Tabla temporal como staging
   
   OPTIMIZACIONES:
   - TABLOCK: Minimiza logging
   - Desactivar índices temporalmente
   - Recovery model BULK_LOGGED
*/

-- Crear tabla destino
CREATE TABLE #DestinoMasivo (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Monto DECIMAL(15,2),
    Origen VARCHAR(50)
);

-- INSERT masivo con batching y OUTPUT
DECLARE @BatchSize INT = 25000;
DECLARE @Offset INT = 0;
DECLARE @TotalInserted INT = 0;
DECLARE @RowsInserted INT = 1;

-- Tabla para log de IDs insertados
DECLARE @InsertedIDs TABLE (ID INT);

WHILE @RowsInserted > 0
BEGIN
    DELETE FROM @InsertedIDs;
    
    INSERT INTO #DestinoMasivo (Fecha, Monto, Origen)
    OUTPUT INSERTED.ID INTO @InsertedIDs
    SELECT TOP (@BatchSize) 
        Fecha,
        Monto,
        'Migración Batch'
    FROM #DatosMasivos
    WHERE ID > @Offset
    ORDER BY ID;
    
    SET @RowsInserted = @@ROWCOUNT;
    
    -- Obtener último ID procesado
    SELECT @Offset = MAX(ID) 
    FROM #DestinoMasivo 
    WHERE ID IN (SELECT ID FROM @InsertedIDs);
    
    SET @TotalInserted = @TotalInserted + @RowsInserted;
    
    IF @RowsInserted > 0
        PRINT 'Insertados: ' + CAST(@RowsInserted AS VARCHAR) + 
              ' | Total: ' + CAST(@TotalInserted AS VARCHAR) +
              ' | Último offset: ' + CAST(ISNULL(@Offset, 0) AS VARCHAR);
END

-- Verificar
SELECT COUNT(*) AS TotalEnDestino FROM #DestinoMasivo;

-- =====================================================================
-- PARTE 6: MERGE - LA NAVAJA SUIZA
-- =====================================================================
/*
   MERGE permite en UNA sentencia:
   - INSERT si no existe
   - UPDATE si existe
   - DELETE si condición
   
   Ideal para:
   - Sincronización de datos
   - Dimensiones en DW (SCD Type 1/2)
   - Upsert patterns
*/

-- Crear tabla de referencia
CREATE TABLE #ProductosRef (
    ProductoID INT PRIMARY KEY,
    Nombre VARCHAR(100),
    Precio DECIMAL(10,2),
    Activo BIT,
    UltimaActualizacion DATETIME
);

-- Datos existentes
INSERT INTO #ProductosRef VALUES 
(1, 'Cuenta Corriente', 15.00, 1, GETDATE()),
(2, 'Cuenta Ahorro', 0.00, 1, GETDATE()),
(3, 'Tarjeta Crédito', 50.00, 1, GETDATE());

-- Datos fuente (algunos nuevos, algunos actualizados)
CREATE TABLE #ProductosStaging (
    ProductoID INT,
    Nombre VARCHAR(100),
    Precio DECIMAL(10,2)
);

INSERT INTO #ProductosStaging VALUES
(1, 'Cuenta Corriente Premium', 20.00),  -- Actualizar
(2, 'Cuenta Ahorro', 0.00),               -- Sin cambios
(4, 'Tarjeta Débito', 0.00),              -- Nuevo
(5, 'Crédito Personal', 75.00);           -- Nuevo

-- MERGE con todas las operaciones
MERGE INTO #ProductosRef AS Target
USING #ProductosStaging AS Source
ON Target.ProductoID = Source.ProductoID

-- Si existe y es diferente: UPDATE
WHEN MATCHED AND (Target.Nombre <> Source.Nombre OR Target.Precio <> Source.Precio)
THEN UPDATE SET 
    Target.Nombre = Source.Nombre,
    Target.Precio = Source.Precio,
    Target.UltimaActualizacion = GETDATE()

-- Si no existe en Target: INSERT
WHEN NOT MATCHED BY TARGET
THEN INSERT (ProductoID, Nombre, Precio, Activo, UltimaActualizacion)
     VALUES (Source.ProductoID, Source.Nombre, Source.Precio, 1, GETDATE())

-- Si no existe en Source: marcar inactivo
WHEN NOT MATCHED BY SOURCE AND Target.Activo = 1
THEN UPDATE SET Target.Activo = 0

-- OUTPUT para auditoría
OUTPUT 
    $action AS Accion,
    INSERTED.ProductoID,
    INSERTED.Nombre AS NuevoNombre,
    DELETED.Nombre AS NombreAnterior,
    INSERTED.Precio AS NuevoPrecio,
    DELETED.Precio AS PrecioAnterior;

-- Ver resultado
SELECT * FROM #ProductosRef;

-- =====================================================================
-- MERGE CON BATCHING (para tablas grandes)
-- =====================================================================
DECLARE @MergeBatchSize INT = 10000;
DECLARE @ProcessedRows INT = 1;
DECLARE @TotalProcessed INT = 0;

WHILE @ProcessedRows > 0
BEGIN
    ;WITH SourceBatch AS (
        SELECT TOP (@MergeBatchSize) *
        FROM #ProductosStaging s
        WHERE NOT EXISTS (
            SELECT 1 FROM #ProductosRef r 
            WHERE r.ProductoID = s.ProductoID 
              AND r.Nombre = s.Nombre 
              AND r.Precio = s.Precio
        )
    )
    MERGE INTO #ProductosRef AS Target
    USING SourceBatch AS Source
    ON Target.ProductoID = Source.ProductoID
    WHEN MATCHED THEN UPDATE SET 
        Target.Nombre = Source.Nombre,
        Target.Precio = Source.Precio,
        Target.UltimaActualizacion = GETDATE()
    WHEN NOT MATCHED BY TARGET THEN 
        INSERT (ProductoID, Nombre, Precio, Activo, UltimaActualizacion)
        VALUES (Source.ProductoID, Source.Nombre, Source.Precio, 1, GETDATE());
    
    SET @ProcessedRows = @@ROWCOUNT;
    SET @TotalProcessed = @TotalProcessed + @ProcessedRows;
    
    IF @ProcessedRows > 0
        PRINT 'Procesados en MERGE: ' + CAST(@ProcessedRows AS VARCHAR);
END

-- =====================================================================
-- PARTE 7: TRY_CONVERT Y TRY_CAST
-- =====================================================================
/*
   PROBLEMA: Datos sucios que causan errores de conversión
   
   CAST/CONVERT tradicional:
   SELECT CAST('abc' AS INT)  → ERROR!
   
   TRY_CAST/TRY_CONVERT:
   SELECT TRY_CAST('abc' AS INT)  → NULL (sin error)
   
   USO: Limpieza de datos, importaciones, ETL
*/

-- Tabla con datos sucios (simulación de import)
CREATE TABLE #DatosSucios (
    ID INT IDENTITY,
    FechaTexto VARCHAR(50),
    MontoTexto VARCHAR(50),
    CantidadTexto VARCHAR(50)
);

INSERT INTO #DatosSucios VALUES
('2024-01-15', '1500.50', '10'),
('15/01/2024', '2,500.00', '20'),       -- Formato diferente
('enero 2024', 'mil quinientos', 'diez'), -- Texto
('2024-13-45', '-500', '0'),             -- Fecha inválida
(NULL, NULL, NULL),
('2024-06-30', '999.99', '5abc');        -- Cantidad mixta

-- CAST tradicional fallaría
-- SELECT CAST(FechaTexto AS DATE) FROM #DatosSucios;  -- ERROR!

-- TRY_CONVERT maneja errores gracefully
SELECT 
    ID,
    FechaTexto,
    TRY_CONVERT(DATE, FechaTexto, 120) AS FechaConvertida,
    MontoTexto,
    TRY_CONVERT(DECIMAL(10,2), REPLACE(MontoTexto, ',', '')) AS MontoConvertido,
    CantidadTexto,
    TRY_CONVERT(INT, CantidadTexto) AS CantidadConvertida,
    -- Identificar registros problemáticos
    CASE 
        WHEN TRY_CONVERT(DATE, FechaTexto, 120) IS NULL AND FechaTexto IS NOT NULL 
        THEN 'Fecha inválida'
        WHEN TRY_CONVERT(DECIMAL(10,2), REPLACE(MontoTexto, ',', '')) IS NULL AND MontoTexto IS NOT NULL 
        THEN 'Monto inválido'
        WHEN TRY_CONVERT(INT, CantidadTexto) IS NULL AND CantidadTexto IS NOT NULL 
        THEN 'Cantidad inválida'
        ELSE 'OK'
    END AS Estado
FROM #DatosSucios;

-- Insertar solo datos válidos
INSERT INTO #DestinoLimpio (Fecha, Monto, Cantidad)
SELECT 
    TRY_CONVERT(DATE, FechaTexto, 120),
    TRY_CONVERT(DECIMAL(10,2), REPLACE(MontoTexto, ',', '')),
    TRY_CONVERT(INT, CantidadTexto)
FROM #DatosSucios
WHERE TRY_CONVERT(DATE, FechaTexto, 120) IS NOT NULL
  AND TRY_CONVERT(DECIMAL(10,2), REPLACE(MontoTexto, ',', '')) IS NOT NULL;

-- =====================================================================
-- PARTE 8: TRY_PARSE PARA CONVERSIONES CULTURALES
-- =====================================================================
/*
   TRY_PARSE: Convierte strings a fecha/número usando cultura específica
   
   Útil para:
   - Datos de diferentes regiones
   - Formatos de fecha locales
   - Números con separadores culturales
*/

-- Ejemplos de TRY_PARSE con diferentes culturas
SELECT 
    '15/01/2024' AS TextoOriginal,
    TRY_PARSE('15/01/2024' AS DATE USING 'es-ES') AS FechaEspañol,
    TRY_PARSE('01/15/2024' AS DATE USING 'en-US') AS FechaUSA,
    TRY_PARSE('15 de enero de 2024' AS DATE USING 'es-ES') AS FechaTextoES;

-- Números con formato cultural
SELECT 
    '1.234,56' AS TextoOriginal,
    TRY_PARSE('1.234,56' AS DECIMAL(10,2) USING 'es-ES') AS NumeroEspañol,
    '1,234.56' AS TextoOriginal2,
    TRY_PARSE('1,234.56' AS DECIMAL(10,2) USING 'en-US') AS NumeroUSA;

-- Procesamiento masivo con detección de cultura
CREATE TABLE #DatosMulticulturales (
    ID INT IDENTITY,
    FechaTexto VARCHAR(50),
    MontoTexto VARCHAR(50),
    PaisOrigen CHAR(2)
);

INSERT INTO #DatosMulticulturales VALUES
('15/01/2024', '1.500,50', 'ES'),
('01/15/2024', '1,500.50', 'US'),
('2024-01-15', '1500.50', 'MX'),
('15.01.2024', '1.500,50', 'DE');

SELECT 
    ID,
    FechaTexto,
    MontoTexto,
    PaisOrigen,
    CASE PaisOrigen
        WHEN 'ES' THEN TRY_PARSE(FechaTexto AS DATE USING 'es-ES')
        WHEN 'US' THEN TRY_PARSE(FechaTexto AS DATE USING 'en-US')
        WHEN 'DE' THEN TRY_PARSE(FechaTexto AS DATE USING 'de-DE')
        ELSE TRY_CONVERT(DATE, FechaTexto, 120)
    END AS FechaConvertida,
    CASE PaisOrigen
        WHEN 'ES' THEN TRY_PARSE(MontoTexto AS DECIMAL(10,2) USING 'es-ES')
        WHEN 'US' THEN TRY_PARSE(MontoTexto AS DECIMAL(10,2) USING 'en-US')
        WHEN 'DE' THEN TRY_PARSE(MontoTexto AS DECIMAL(10,2) USING 'de-DE')
        ELSE TRY_CONVERT(DECIMAL(10,2), MontoTexto)
    END AS MontoConvertido
FROM #DatosMulticulturales;

-- =====================================================================
-- PARTE 9: TRANSACCIONES Y CHECKPOINTS
-- =====================================================================
/*
   ESTRATEGIA DE TRANSACCIONES EN BATCHING:
   
   OPCIÓN 1: Sin transacción explícita (auto-commit)
   - Cada batch es independiente
   - Si falla uno, los anteriores se mantienen
   - Más seguro para procesos largos
   
   OPCIÓN 2: Transacción por batch
   - Control granular
   - Posibilidad de retry
   
   OPCIÓN 3: Checkpoint table
   - Guardar progreso
   - Resumir si falla
*/

-- Crear tabla de checkpoint
CREATE TABLE dbo.BatchCheckpoint (
    ProcesoID INT PRIMARY KEY,
    NombreProceso VARCHAR(100),
    UltimoIDProcesado BIGINT,
    RegistrosProcesados INT,
    FechaInicio DATETIME,
    FechaUltimoUpdate DATETIME,
    Estado VARCHAR(20),
    MensajeError VARCHAR(MAX)
);

-- SP con checkpoint y manejo de errores
CREATE OR ALTER PROCEDURE dbo.sp_PurgaTransaccionesAntiguas
    @FechaCorte DATE,
    @BatchSize INT = 10000,
    @MaxBatches INT = 1000,  -- Límite de seguridad
    @ProcesoID INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RowsAffected INT = 1;
    DECLARE @TotalDeleted INT = 0;
    DECLARE @BatchCount INT = 0;
    DECLARE @UltimoID BIGINT = 0;
    DECLARE @ErrorMessage VARCHAR(MAX);
    
    -- Generar ID de proceso si no existe
    IF @ProcesoID IS NULL
        SET @ProcesoID = ISNULL((SELECT MAX(ProcesoID) FROM dbo.BatchCheckpoint), 0) + 1;
    
    -- Verificar si hay un proceso previo para continuar
    SELECT @UltimoID = ISNULL(UltimoIDProcesado, 0),
           @TotalDeleted = ISNULL(RegistrosProcesados, 0)
    FROM dbo.BatchCheckpoint
    WHERE ProcesoID = @ProcesoID AND Estado = 'EN_PROGRESO';
    
    -- Registrar inicio
    IF NOT EXISTS (SELECT 1 FROM dbo.BatchCheckpoint WHERE ProcesoID = @ProcesoID)
    BEGIN
        INSERT INTO dbo.BatchCheckpoint 
        (ProcesoID, NombreProceso, UltimoIDProcesado, RegistrosProcesados, FechaInicio, FechaUltimoUpdate, Estado)
        VALUES 
        (@ProcesoID, 'PurgaTransacciones', 0, 0, GETDATE(), GETDATE(), 'EN_PROGRESO');
    END
    
    PRINT '========================================';
    PRINT 'Proceso ID: ' + CAST(@ProcesoID AS VARCHAR);
    PRINT 'Fecha corte: ' + CAST(@FechaCorte AS VARCHAR);
    PRINT 'Batch size: ' + CAST(@BatchSize AS VARCHAR);
    PRINT 'Continuando desde ID: ' + CAST(@UltimoID AS VARCHAR);
    PRINT '========================================';
    
    BEGIN TRY
        WHILE @RowsAffected > 0 AND @BatchCount < @MaxBatches
        BEGIN
            BEGIN TRANSACTION;
            
            -- DELETE con tracking de ID
            ;WITH Batch AS (
                SELECT TOP (@BatchSize) TransaccionID
                FROM TRANSACCIONES_BANCARIAS
                WHERE FechaTransaccion < @FechaCorte
                  AND TransaccionID > @UltimoID
                ORDER BY TransaccionID
            )
            DELETE FROM TRANSACCIONES_BANCARIAS
            OUTPUT DELETED.TransaccionID
            WHERE TransaccionID IN (SELECT TransaccionID FROM Batch);
            
            SET @RowsAffected = @@ROWCOUNT;
            
            IF @RowsAffected > 0
            BEGIN
                -- Actualizar último ID procesado
                SELECT @UltimoID = MAX(TransaccionID)
                FROM TRANSACCIONES_BANCARIAS
                WHERE TransaccionID <= @UltimoID + @BatchSize;
                
                SET @TotalDeleted = @TotalDeleted + @RowsAffected;
                SET @BatchCount = @BatchCount + 1;
                
                -- Checkpoint
                UPDATE dbo.BatchCheckpoint
                SET UltimoIDProcesado = @UltimoID,
                    RegistrosProcesados = @TotalDeleted,
                    FechaUltimoUpdate = GETDATE()
                WHERE ProcesoID = @ProcesoID;
                
                PRINT 'Batch ' + CAST(@BatchCount AS VARCHAR) + 
                      ': ' + CAST(@RowsAffected AS VARCHAR) + ' registros' +
                      ' | Total: ' + CAST(@TotalDeleted AS VARCHAR) +
                      ' | Último ID: ' + CAST(@UltimoID AS VARCHAR);
            END
            
            COMMIT TRANSACTION;
        END
        
        -- Marcar como completado
        UPDATE dbo.BatchCheckpoint
        SET Estado = 'COMPLETADO',
            FechaUltimoUpdate = GETDATE()
        WHERE ProcesoID = @ProcesoID;
        
        PRINT '========================================';
        PRINT 'PROCESO COMPLETADO';
        PRINT 'Total eliminado: ' + CAST(@TotalDeleted AS VARCHAR);
        PRINT '========================================';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE();
        
        UPDATE dbo.BatchCheckpoint
        SET Estado = 'ERROR',
            MensajeError = @ErrorMessage,
            FechaUltimoUpdate = GETDATE()
        WHERE ProcesoID = @ProcesoID;
        
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- PARTE 10: MONITOREO DE PROGRESO
-- =====================================================================

-- Vista para monitorear procesos batch
CREATE OR ALTER VIEW dbo.vw_MonitoreoBatch
AS
SELECT 
    ProcesoID,
    NombreProceso,
    Estado,
    RegistrosProcesados,
    DATEDIFF(MINUTE, FechaInicio, ISNULL(FechaUltimoUpdate, GETDATE())) AS MinutosTranscurridos,
    CASE 
        WHEN DATEDIFF(MINUTE, FechaInicio, ISNULL(FechaUltimoUpdate, GETDATE())) > 0
        THEN RegistrosProcesados / DATEDIFF(MINUTE, FechaInicio, ISNULL(FechaUltimoUpdate, GETDATE()))
        ELSE RegistrosProcesados
    END AS RegistrosPorMinuto,
    FechaInicio,
    FechaUltimoUpdate,
    MensajeError
FROM dbo.BatchCheckpoint;
GO

-- Consultar progreso
-- SELECT * FROM dbo.vw_MonitoreoBatch;

-- =====================================================================
-- PARTE 11: CASO PRÁCTICO - PURGA BANCODB
-- =====================================================================
/*
   ESCENARIO:
   - Retención de transacciones: 7 años
   - Millones de registros a purgar
   - Horario: Solo noches/fines de semana
   - Requisito: No afectar operaciones diurnas
*/

-- SP completo para purga con throttling
CREATE OR ALTER PROCEDURE dbo.sp_PurgaProgramada
    @AñosRetencion INT = 7,
    @BatchSize INT = 5000,
    @MaxMinutos INT = 120,         -- Tiempo máximo de ejecución
    @PausaSegundos INT = 1,        -- Pausa entre batches
    @HoraInicioPermitida TIME = '22:00:00',
    @HoraFinPermitida TIME = '06:00:00'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaCorte DATE = DATEADD(YEAR, -@AñosRetencion, GETDATE());
    DECLARE @FechaInicio DATETIME = GETDATE();
    DECLARE @RowsAffected INT = 1;
    DECLARE @TotalDeleted INT = 0;
    DECLARE @HoraActual TIME;
    
    -- Validar horario permitido
    SET @HoraActual = CAST(GETDATE() AS TIME);
    IF NOT (@HoraActual >= @HoraInicioPermitida OR @HoraActual <= @HoraFinPermitida)
    BEGIN
        RAISERROR('Ejecución solo permitida entre %s y %s', 16, 1, 
                  @HoraInicioPermitida, @HoraFinPermitida);
        RETURN;
    END
    
    PRINT 'Iniciando purga programada...';
    PRINT 'Fecha corte: ' + CAST(@FechaCorte AS VARCHAR);
    PRINT 'Tiempo máximo: ' + CAST(@MaxMinutos AS VARCHAR) + ' minutos';
    
    WHILE @RowsAffected > 0
    BEGIN
        -- Verificar tiempo transcurrido
        IF DATEDIFF(MINUTE, @FechaInicio, GETDATE()) >= @MaxMinutos
        BEGIN
            PRINT 'Tiempo máximo alcanzado. Pausando proceso.';
            BREAK;
        END
        
        -- Verificar si seguimos en horario permitido
        SET @HoraActual = CAST(GETDATE() AS TIME);
        IF NOT (@HoraActual >= @HoraInicioPermitida OR @HoraActual <= @HoraFinPermitida)
        BEGIN
            PRINT 'Fuera de horario permitido. Pausando proceso.';
            BREAK;
        END
        
        -- Ejecutar batch
        DELETE TOP (@BatchSize)
        FROM TRANSACCIONES_BANCARIAS
        WHERE FechaTransaccion < @FechaCorte;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalDeleted = @TotalDeleted + @RowsAffected;
        
        IF @RowsAffected > 0
        BEGIN
            PRINT CONVERT(VARCHAR, GETDATE(), 120) + ' - Eliminados: ' + 
                  CAST(@RowsAffected AS VARCHAR) + ' | Total: ' + CAST(@TotalDeleted AS VARCHAR);
            
            -- Pausa para no saturar
            WAITFOR DELAY '00:00:01';
        END
    END
    
    SELECT 
        @TotalDeleted AS TotalEliminados,
        DATEDIFF(MINUTE, @FechaInicio, GETDATE()) AS MinutosEjecutados,
        CASE WHEN @RowsAffected = 0 THEN 'COMPLETADO' ELSE 'PAUSADO' END AS Estado;
END;
GO

-- =====================================================================
-- RESUMEN DE LA SESIÓN
-- =====================================================================
/*
   CONCEPTOS CLAVE:
   
   1. BATCHING:
      - Siempre procesar grandes volúmenes en lotes
      - Tamaño típico: 1000-50000 registros
      - Evita bloqueos y desbordamiento de log
   
   2. TÉCNICAS:
      - DELETE/UPDATE TOP (@BatchSize) en WHILE
      - MERGE para operaciones combinadas
      - Checkpoint tables para procesos largos
   
   3. CONVERSIONES SEGURAS:
      - TRY_CONVERT: Para datos potencialmente inválidos
      - TRY_CAST: Alternativa sin estilo
      - TRY_PARSE: Para formatos culturales
   
   4. BUENAS PRÁCTICAS:
      - Logging de progreso
      - Manejo de errores con TRY/CATCH
      - Checkpoints para poder resumir
      - Throttling en producción
      - Horarios de ventana de mantenimiento
   
   PRÓXIMA SESIÓN:
   - Tablas Temporales y Variables de Tabla (#temp, @table, ##global)
*/

-- Limpieza de objetos de prueba
DROP TABLE IF EXISTS #DatosMasivos;
DROP TABLE IF EXISTS #DestinoMasivo;
DROP TABLE IF EXISTS #ProductosRef;
DROP TABLE IF EXISTS #ProductosStaging;
DROP TABLE IF EXISTS #DatosSucios;
DROP TABLE IF EXISTS #DatosMulticulturales;
