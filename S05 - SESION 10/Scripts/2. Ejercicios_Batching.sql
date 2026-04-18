/*
=====================================================================
  EJERCICIOS PRÁCTICOS: BATCHING Y OPERACIONES MASIVAS
  SQL Server Intermedio 2026 - Sesión 10
  
  Instrucciones:
  - Completar cada ejercicio según las indicaciones
  - Comparar con las soluciones al final
  - Usar BancoDB como base de datos
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- EJERCICIO 1: DELETE BÁSICO CON CHUNKING
-- =====================================================================
/*
   OBJETIVO: Eliminar registros antiguos de forma segura
   
   INSTRUCCIONES:
   1. Crear una tabla temporal #LogActividad con 50,000 registros
   2. Incluir columnas: ID, FechaEvento, TipoEvento, Descripcion
   3. Eliminar registros con FechaEvento > 1 año usando batches de 2,500
   4. Mostrar progreso en cada iteración
   5. Al final, mostrar total eliminado y tiempo total
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 2: UPDATE MASIVO CON CONTROL
-- =====================================================================
/*
   OBJETIVO: Actualizar masivamente el estado de cuentas inactivas
   
   INSTRUCCIONES:
   1. Crear tabla #CuentasDemo con 30,000 registros
   2. Columnas: CuentaID, UltimaActividad DATE, Estado VARCHAR(20)
   3. Actualizar Estado a 'INACTIVA' donde UltimaActividad > 6 meses
   4. Usar batches de 5,000 registros
   5. Agregar una columna FechaActualizacion con la fecha de update
   6. Mostrar estadísticas al finalizar
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 3: MERGE BÁSICO
-- =====================================================================
/*
   OBJETIVO: Sincronizar tabla de empleados con datos nuevos
   
   INSTRUCCIONES:
   1. Crear tabla #EmpleadosTarget con 10 empleados
   2. Crear tabla #EmpleadosSource con:
      - 5 empleados existentes (algunos con cambios)
      - 3 empleados nuevos
   3. Usar MERGE para:
      - UPDATE: Si existe y tiene cambios
      - INSERT: Si es nuevo
      - OUTPUT: Mostrar todas las acciones realizadas
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 4: TRY_CONVERT PARA LIMPIEZA DE DATOS
-- =====================================================================
/*
   OBJETIVO: Limpiar e importar datos de un archivo CSV simulado
   
   INSTRUCCIONES:
   1. Crear tabla #ImportCSV con datos "sucios" (todos VARCHAR)
   2. Incluir: FechaStr, MontoStr, CantidadStr, EmailStr
   3. Insertar 10 registros mezclados (válidos e inválidos)
   4. Crear query que:
      - Convierta datos usando TRY_CONVERT
      - Identifique registros con errores
      - Clasifique errores por tipo
   5. Insertar solo datos válidos en tabla destino
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 5: TRY_PARSE MULTICULTURAL
-- =====================================================================
/*
   OBJETIVO: Procesar transacciones de diferentes países
   
   INSTRUCCIONES:
   1. Crear tabla #TransaccionesGlobales con datos de:
      - España (formato fecha: dd/mm/yyyy, número: 1.234,56)
      - USA (formato fecha: mm/dd/yyyy, número: 1,234.56)
      - México (formato fecha: yyyy-mm-dd, número: 1234.56)
   2. Usar TRY_PARSE con la cultura correcta según país
   3. Mostrar conversiones exitosas y fallidas
   4. Crear resumen por país de errores de conversión
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 6: BATCHING CON CHECKPOINT
-- =====================================================================
/*
   OBJETIVO: Crear proceso que pueda resumirse si falla
   
   INSTRUCCIONES:
   1. Crear tabla de checkpoint dbo.ProcesoCheckpoint
   2. Crear tabla de datos #DatosAProcesar (100,000 registros)
   3. Crear SP que:
      - Procese en batches de 10,000
      - Guarde checkpoint después de cada batch
      - Pueda resumir desde el último checkpoint
      - Tenga parámetro para simular error en batch N
   4. Probar el resume después de un error simulado
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 7: MERGE CON HISTORIAL (SCD TYPE 2)
-- =====================================================================
/*
   OBJETIVO: Implementar Slowly Changing Dimension Type 2
   
   INSTRUCCIONES:
   1. Crear tabla #ClientesDim con:
      - ClienteID, Nombre, Direccion, FechaInicio, FechaFin, EsActual
   2. Crear tabla #ClientesSource con cambios
   3. Usar MERGE para:
      - Si cambia: Cerrar registro anterior, insertar nuevo
      - Si es nuevo: Insertar con EsActual = 1
   4. Mantener historial completo de cambios
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 8: INSERT MASIVO CON VALIDACIÓN
-- =====================================================================
/*
   OBJETIVO: Importar datos validando antes de insertar
   
   INSTRUCCIONES:
   1. Crear staging table con datos de transacciones
   2. Crear tabla de errores para rechazos
   3. Validar:
      - Monto debe ser > 0
      - Fecha no puede ser futura
      - CuentaID debe existir en tabla CUENTAS (si existe)
   4. Insertar válidos en destino, inválidos en errores
   5. Usar batching para ambas operaciones
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 9: PROCESO DE ARCHIVO CON THROTTLING
-- =====================================================================
/*
   OBJETIVO: Archivar transacciones antiguas con control de recursos
   
   INSTRUCCIONES:
   1. Crear tabla #TransaccionesArchivo para histórico
   2. Mover transacciones > 2 años a la tabla archivo
   3. Implementar:
      - Batches de 5,000 registros
      - Pausa de 500ms entre batches
      - Límite máximo de tiempo (5 minutos)
      - Log de progreso cada 10 batches
   4. Al final, mostrar resumen de registros archivados
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 10: CASO COMPLETO - MIGRACIÓN DE SISTEMA
-- =====================================================================
/*
   ESCENARIO:
   El banco está migrando de un sistema legacy. Debes:
   
   1. Importar clientes desde tabla legacy con:
      - Datos en formatos antiguos (fechas DD-MON-YYYY)
      - Algunos campos numéricos como texto
      - Campos NULL que ahora son requeridos
   
   2. Importar transacciones con:
      - Volumen: 500,000 registros
      - Validar integridad referencial
      - Mapear códigos antiguos a nuevos
   
   3. Implementar:
      - Proceso por etapas (Clientes primero, luego transacciones)
      - Checkpoint entre etapas
      - Rollback si hay más de 5% de errores
      - Reporte final de migración
*/

-- TU CÓDIGO AQUÍ:
/*
   PLAN DE MIGRACIÓN:
   ==================
   
   ETAPA 1: Preparación
   
   
   ETAPA 2: Migración Clientes
   
   
   ETAPA 3: Migración Transacciones
   
   
   ETAPA 4: Validación
   
   
   ETAPA 5: Reporte
   
*/



-- #####################################################################
-- #                        SOLUCIONES                                 #
-- #####################################################################

-- =====================================================================
-- SOLUCIÓN 1: DELETE BÁSICO CON CHUNKING
-- =====================================================================
-- Crear y poblar tabla
CREATE TABLE #LogActividad (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    FechaEvento DATETIME,
    TipoEvento VARCHAR(20),
    Descripcion VARCHAR(200)
);

INSERT INTO #LogActividad (FechaEvento, TipoEvento, Descripcion)
SELECT TOP 50000
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE()),
    CASE ABS(CHECKSUM(NEWID())) % 4 
        WHEN 0 THEN 'LOGIN'
        WHEN 1 THEN 'LOGOUT'
        WHEN 2 THEN 'ERROR'
        ELSE 'INFO'
    END,
    'Evento de actividad ' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS VARCHAR)
FROM sys.objects a, sys.objects b;

-- Delete con chunking
DECLARE @BatchSize INT = 2500;
DECLARE @RowsAffected INT = 1;
DECLARE @TotalDeleted INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @FechaCorte DATETIME = DATEADD(YEAR, -1, GETDATE());

PRINT 'Inicio: ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT 'Eliminando registros anteriores a: ' + CONVERT(VARCHAR, @FechaCorte, 120);

WHILE @RowsAffected > 0
BEGIN
    DELETE TOP (@BatchSize) FROM #LogActividad
    WHERE FechaEvento < @FechaCorte;
    
    SET @RowsAffected = @@ROWCOUNT;
    SET @TotalDeleted = @TotalDeleted + @RowsAffected;
    
    IF @RowsAffected > 0
        PRINT 'Batch: ' + CAST(@RowsAffected AS VARCHAR) + ' | Acumulado: ' + CAST(@TotalDeleted AS VARCHAR);
END

PRINT '========================================';
PRINT 'Total eliminado: ' + CAST(@TotalDeleted AS VARCHAR);
PRINT 'Tiempo total: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + ' segundos';

DROP TABLE #LogActividad;

-- =====================================================================
-- SOLUCIÓN 2: UPDATE MASIVO CON CONTROL
-- =====================================================================
CREATE TABLE #CuentasDemo (
    CuentaID INT IDENTITY(1,1) PRIMARY KEY,
    UltimaActividad DATE,
    Estado VARCHAR(20) DEFAULT 'ACTIVA',
    FechaActualizacion DATETIME
);

INSERT INTO #CuentasDemo (UltimaActividad)
SELECT TOP 30000
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM sys.objects a, sys.objects b;

DECLARE @BatchSize INT = 5000;
DECLARE @RowsAffected INT = 1;
DECLARE @TotalUpdated INT = 0;
DECLARE @FechaLimite DATE = DATEADD(MONTH, -6, GETDATE());

WHILE @RowsAffected > 0
BEGIN
    UPDATE TOP (@BatchSize) #CuentasDemo
    SET Estado = 'INACTIVA',
        FechaActualizacion = GETDATE()
    WHERE UltimaActividad < @FechaLimite
      AND Estado = 'ACTIVA';
    
    SET @RowsAffected = @@ROWCOUNT;
    SET @TotalUpdated = @TotalUpdated + @RowsAffected;
    
    IF @RowsAffected > 0
        PRINT 'Actualizadas: ' + CAST(@RowsAffected AS VARCHAR);
END

SELECT Estado, COUNT(*) AS Total FROM #CuentasDemo GROUP BY Estado;

DROP TABLE #CuentasDemo;

-- =====================================================================
-- SOLUCIÓN 3: MERGE BÁSICO
-- =====================================================================
CREATE TABLE #EmpleadosTarget (
    EmpleadoID INT PRIMARY KEY,
    Nombre VARCHAR(100),
    Departamento VARCHAR(50),
    Salario DECIMAL(10,2)
);

INSERT INTO #EmpleadosTarget VALUES
(1, 'Ana García', 'IT', 50000),
(2, 'Carlos López', 'Ventas', 45000),
(3, 'María Rodríguez', 'IT', 55000),
(4, 'Juan Martínez', 'RRHH', 42000),
(5, 'Laura Sánchez', 'Finanzas', 60000);

CREATE TABLE #EmpleadosSource (
    EmpleadoID INT,
    Nombre VARCHAR(100),
    Departamento VARCHAR(50),
    Salario DECIMAL(10,2)
);

INSERT INTO #EmpleadosSource VALUES
(1, 'Ana García', 'IT', 52000),          -- UPDATE salario
(2, 'Carlos López', 'Marketing', 48000), -- UPDATE depto y salario
(3, 'María Rodríguez', 'IT', 55000),     -- Sin cambios
(6, 'Pedro Ruiz', 'IT', 47000),          -- NUEVO
(7, 'Sofia Torres', 'Ventas', 44000),    -- NUEVO
(8, 'Diego Flores', 'RRHH', 41000);      -- NUEVO

MERGE INTO #EmpleadosTarget AS T
USING #EmpleadosSource AS S
ON T.EmpleadoID = S.EmpleadoID

WHEN MATCHED AND (T.Nombre <> S.Nombre OR T.Departamento <> S.Departamento OR T.Salario <> S.Salario)
THEN UPDATE SET 
    T.Nombre = S.Nombre,
    T.Departamento = S.Departamento,
    T.Salario = S.Salario

WHEN NOT MATCHED BY TARGET
THEN INSERT (EmpleadoID, Nombre, Departamento, Salario)
     VALUES (S.EmpleadoID, S.Nombre, S.Departamento, S.Salario)

OUTPUT 
    $action AS Accion,
    ISNULL(INSERTED.EmpleadoID, DELETED.EmpleadoID) AS EmpleadoID,
    DELETED.Nombre AS NombreAnterior,
    INSERTED.Nombre AS NombreNuevo,
    DELETED.Salario AS SalarioAnterior,
    INSERTED.Salario AS SalarioNuevo;

SELECT * FROM #EmpleadosTarget;

DROP TABLE #EmpleadosTarget;
DROP TABLE #EmpleadosSource;

-- =====================================================================
-- SOLUCIÓN 4: TRY_CONVERT PARA LIMPIEZA DE DATOS
-- =====================================================================
CREATE TABLE #ImportCSV (
    ID INT IDENTITY,
    FechaStr VARCHAR(50),
    MontoStr VARCHAR(50),
    CantidadStr VARCHAR(50),
    EmailStr VARCHAR(100)
);

INSERT INTO #ImportCSV VALUES
('2024-01-15', '1500.50', '10', 'ana@email.com'),
('15/01/2024', '2500.00', '20', 'carlos@test.com'),
('fecha_invalida', 'mil', 'abc', 'email_invalido'),
('2024-06-30', '-500.00', '5', 'maria@banco.com'),
(NULL, NULL, NULL, NULL),
('2024-13-45', '1000', '0', 'sin_arroba.com'),
('2024-03-20', '750.25', '15', 'juan@email.com'),
('', '', '', ''),
('2024-12-31', '9999.99', '100', 'test@test.com'),
('01-01-2024', '500abc', '10x', 'pedro@mail.com');

-- Análisis de datos
SELECT 
    ID,
    FechaStr,
    TRY_CONVERT(DATE, FechaStr, 120) AS FechaConvertida,
    MontoStr,
    TRY_CONVERT(DECIMAL(10,2), MontoStr) AS MontoConvertido,
    CantidadStr,
    TRY_CONVERT(INT, CantidadStr) AS CantidadConvertida,
    EmailStr,
    CASE WHEN EmailStr LIKE '%@%.%' THEN 1 ELSE 0 END AS EmailValido,
    -- Clasificación de errores
    CASE 
        WHEN TRY_CONVERT(DATE, FechaStr, 120) IS NULL AND FechaStr IS NOT NULL AND FechaStr <> '' THEN 'ERROR_FECHA'
        WHEN TRY_CONVERT(DECIMAL(10,2), MontoStr) IS NULL AND MontoStr IS NOT NULL AND MontoStr <> '' THEN 'ERROR_MONTO'
        WHEN TRY_CONVERT(INT, CantidadStr) IS NULL AND CantidadStr IS NOT NULL AND CantidadStr <> '' THEN 'ERROR_CANTIDAD'
        WHEN EmailStr NOT LIKE '%@%.%' AND EmailStr IS NOT NULL AND EmailStr <> '' THEN 'ERROR_EMAIL'
        WHEN FechaStr IS NULL OR MontoStr IS NULL THEN 'DATOS_NULOS'
        ELSE 'OK'
    END AS Estado
FROM #ImportCSV;

-- Resumen de errores
SELECT 
    CASE 
        WHEN TRY_CONVERT(DATE, FechaStr, 120) IS NULL AND FechaStr IS NOT NULL AND FechaStr <> '' THEN 'Fecha inválida'
        WHEN TRY_CONVERT(DECIMAL(10,2), MontoStr) IS NULL AND MontoStr IS NOT NULL AND MontoStr <> '' THEN 'Monto inválido'
        WHEN TRY_CONVERT(INT, CantidadStr) IS NULL AND CantidadStr IS NOT NULL AND CantidadStr <> '' THEN 'Cantidad inválida'
        WHEN EmailStr NOT LIKE '%@%.%' AND EmailStr IS NOT NULL AND EmailStr <> '' THEN 'Email inválido'
        WHEN FechaStr IS NULL OR MontoStr IS NULL THEN 'Datos nulos'
        ELSE 'Válido'
    END AS TipoError,
    COUNT(*) AS Cantidad
FROM #ImportCSV
GROUP BY 
    CASE 
        WHEN TRY_CONVERT(DATE, FechaStr, 120) IS NULL AND FechaStr IS NOT NULL AND FechaStr <> '' THEN 'Fecha inválida'
        WHEN TRY_CONVERT(DECIMAL(10,2), MontoStr) IS NULL AND MontoStr IS NOT NULL AND MontoStr <> '' THEN 'Monto inválido'
        WHEN TRY_CONVERT(INT, CantidadStr) IS NULL AND CantidadStr IS NOT NULL AND CantidadStr <> '' THEN 'Cantidad inválida'
        WHEN EmailStr NOT LIKE '%@%.%' AND EmailStr IS NOT NULL AND EmailStr <> '' THEN 'Email inválido'
        WHEN FechaStr IS NULL OR MontoStr IS NULL THEN 'Datos nulos'
        ELSE 'Válido'
    END;

DROP TABLE #ImportCSV;

-- =====================================================================
-- SOLUCIÓN 5: TRY_PARSE MULTICULTURAL
-- =====================================================================
CREATE TABLE #TransaccionesGlobales (
    ID INT IDENTITY,
    FechaStr VARCHAR(50),
    MontoStr VARCHAR(50),
    Pais CHAR(2)
);

INSERT INTO #TransaccionesGlobales VALUES
('15/01/2024', '1.234,56', 'ES'),
('01/15/2024', '1,234.56', 'US'),
('2024-01-15', '1234.56', 'MX'),
('20/03/2024', '5.000,00', 'ES'),
('03/20/2024', '5,000.00', 'US'),
('error', 'error', 'ES'),
('31/12/2024', '999,99', 'ES');

SELECT 
    ID,
    FechaStr,
    MontoStr,
    Pais,
    CASE Pais
        WHEN 'ES' THEN TRY_PARSE(FechaStr AS DATE USING 'es-ES')
        WHEN 'US' THEN TRY_PARSE(FechaStr AS DATE USING 'en-US')
        WHEN 'MX' THEN TRY_CONVERT(DATE, FechaStr, 120)
    END AS FechaConvertida,
    CASE Pais
        WHEN 'ES' THEN TRY_PARSE(MontoStr AS DECIMAL(10,2) USING 'es-ES')
        WHEN 'US' THEN TRY_PARSE(MontoStr AS DECIMAL(10,2) USING 'en-US')
        WHEN 'MX' THEN TRY_CONVERT(DECIMAL(10,2), MontoStr)
    END AS MontoConvertido,
    CASE 
        WHEN CASE Pais
            WHEN 'ES' THEN TRY_PARSE(FechaStr AS DATE USING 'es-ES')
            WHEN 'US' THEN TRY_PARSE(FechaStr AS DATE USING 'en-US')
            WHEN 'MX' THEN TRY_CONVERT(DATE, FechaStr, 120)
        END IS NULL THEN 'Error'
        ELSE 'OK'
    END AS EstadoConversion
FROM #TransaccionesGlobales;

-- Resumen por país
SELECT 
    Pais,
    COUNT(*) AS Total,
    SUM(CASE 
        WHEN CASE Pais
            WHEN 'ES' THEN TRY_PARSE(FechaStr AS DATE USING 'es-ES')
            WHEN 'US' THEN TRY_PARSE(FechaStr AS DATE USING 'en-US')
            WHEN 'MX' THEN TRY_CONVERT(DATE, FechaStr, 120)
        END IS NOT NULL THEN 1 ELSE 0 
    END) AS Exitosos,
    SUM(CASE 
        WHEN CASE Pais
            WHEN 'ES' THEN TRY_PARSE(FechaStr AS DATE USING 'es-ES')
            WHEN 'US' THEN TRY_PARSE(FechaStr AS DATE USING 'en-US')
            WHEN 'MX' THEN TRY_CONVERT(DATE, FechaStr, 120)
        END IS NULL THEN 1 ELSE 0 
    END) AS Fallidos
FROM #TransaccionesGlobales
GROUP BY Pais;

DROP TABLE #TransaccionesGlobales;

-- =====================================================================
-- SOLUCIÓN 6: BATCHING CON CHECKPOINT
-- =====================================================================
-- Tabla de checkpoint
IF OBJECT_ID('dbo.ProcesoCheckpoint', 'U') IS NOT NULL
    DROP TABLE dbo.ProcesoCheckpoint;

CREATE TABLE dbo.ProcesoCheckpoint (
    ProcesoID INT PRIMARY KEY,
    UltimoLoteProcesado INT,
    RegistrosProcesados INT,
    Estado VARCHAR(20),
    FechaInicio DATETIME,
    FechaUpdate DATETIME
);

-- Tabla de datos
CREATE TABLE #DatosAProcesar (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Valor INT,
    Procesado BIT DEFAULT 0
);

INSERT INTO #DatosAProcesar (Valor)
SELECT TOP 100000 ABS(CHECKSUM(NEWID())) % 1000
FROM sys.objects a, sys.objects b, sys.objects c;

-- SP con checkpoint
CREATE OR ALTER PROCEDURE dbo.sp_ProcesarConCheckpoint
    @BatchSize INT = 10000,
    @SimularErrorEnBatch INT = 0  -- 0 = sin error
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcesoID INT = 1;
    DECLARE @UltimoBatch INT = 0;
    DECLARE @TotalProcesados INT = 0;
    DECLARE @RowsAffected INT = 1;
    DECLARE @BatchNum INT = 0;
    
    -- Recuperar checkpoint si existe
    SELECT @UltimoBatch = UltimoLoteProcesado,
           @TotalProcesados = RegistrosProcesados
    FROM dbo.ProcesoCheckpoint
    WHERE ProcesoID = @ProcesoID AND Estado = 'EN_PROGRESO';
    
    IF @UltimoBatch > 0
        PRINT 'Resumiendo desde batch ' + CAST(@UltimoBatch AS VARCHAR);
    ELSE
    BEGIN
        INSERT INTO dbo.ProcesoCheckpoint VALUES (@ProcesoID, 0, 0, 'EN_PROGRESO', GETDATE(), GETDATE());
    END
    
    SET @BatchNum = @UltimoBatch;
    
    WHILE @RowsAffected > 0
    BEGIN
        SET @BatchNum = @BatchNum + 1;
        
        -- Simular error si se solicita
        IF @BatchNum = @SimularErrorEnBatch
        BEGIN
            RAISERROR('Error simulado en batch %d', 16, 1, @BatchNum);
            RETURN;
        END
        
        UPDATE TOP (@BatchSize) #DatosAProcesar
        SET Procesado = 1
        WHERE Procesado = 0;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalProcesados = @TotalProcesados + @RowsAffected;
        
        IF @RowsAffected > 0
        BEGIN
            UPDATE dbo.ProcesoCheckpoint
            SET UltimoLoteProcesado = @BatchNum,
                RegistrosProcesados = @TotalProcesados,
                FechaUpdate = GETDATE()
            WHERE ProcesoID = @ProcesoID;
            
            PRINT 'Batch ' + CAST(@BatchNum AS VARCHAR) + ': ' + CAST(@RowsAffected AS VARCHAR);
        END
    END
    
    UPDATE dbo.ProcesoCheckpoint
    SET Estado = 'COMPLETADO', FechaUpdate = GETDATE()
    WHERE ProcesoID = @ProcesoID;
    
    PRINT 'Completado. Total: ' + CAST(@TotalProcesados AS VARCHAR);
END;
GO

-- Probar con error
-- EXEC dbo.sp_ProcesarConCheckpoint @SimularErrorEnBatch = 3;
-- SELECT * FROM dbo.ProcesoCheckpoint;
-- EXEC dbo.sp_ProcesarConCheckpoint;  -- Resume

-- Limpieza
DROP TABLE IF EXISTS #DatosAProcesar;

-- =====================================================================
-- SOLUCIÓN 7: MERGE CON HISTORIAL (SCD TYPE 2)
-- =====================================================================
CREATE TABLE #ClientesDim (
    SK INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate Key
    ClienteID INT,                      -- Business Key
    Nombre VARCHAR(100),
    Direccion VARCHAR(200),
    FechaInicio DATE,
    FechaFin DATE,
    EsActual BIT
);

-- Datos iniciales
INSERT INTO #ClientesDim (ClienteID, Nombre, Direccion, FechaInicio, FechaFin, EsActual)
VALUES 
(1, 'Ana García', 'Calle Mayor 1', '2020-01-01', NULL, 1),
(2, 'Carlos López', 'Av. Principal 50', '2021-06-15', NULL, 1),
(3, 'María Rodríguez', 'Plaza Central 10', '2022-03-20', NULL, 1);

-- Datos source con cambios
CREATE TABLE #ClientesSource (
    ClienteID INT,
    Nombre VARCHAR(100),
    Direccion VARCHAR(200)
);

INSERT INTO #ClientesSource VALUES
(1, 'Ana García', 'Calle Nueva 100'),  -- Cambio de dirección
(2, 'Carlos López', 'Av. Principal 50'),  -- Sin cambios
(4, 'Pedro Ruiz', 'Av. Norte 25');  -- Nuevo

-- SCD Type 2 con MERGE
-- Paso 1: Cerrar registros que cambian
UPDATE d
SET FechaFin = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
    EsActual = 0
FROM #ClientesDim d
INNER JOIN #ClientesSource s ON d.ClienteID = s.ClienteID
WHERE d.EsActual = 1
  AND d.Direccion <> s.Direccion;

-- Paso 2: MERGE para nuevos y cambios
MERGE INTO #ClientesDim AS T
USING (
    SELECT s.*, 
           CASE WHEN d.ClienteID IS NULL THEN 'NUEVO'
                WHEN d.Direccion <> s.Direccion THEN 'CAMBIO'
                ELSE 'SIN_CAMBIO' END AS TipoAccion
    FROM #ClientesSource s
    LEFT JOIN #ClientesDim d ON s.ClienteID = d.ClienteID AND d.EsActual = 1
    WHERE d.ClienteID IS NULL OR d.Direccion <> s.Direccion
) AS S
ON 1 = 0  -- Forzar siempre INSERT

WHEN NOT MATCHED THEN INSERT (ClienteID, Nombre, Direccion, FechaInicio, FechaFin, EsActual)
VALUES (S.ClienteID, S.Nombre, S.Direccion, CAST(GETDATE() AS DATE), NULL, 1)

OUTPUT $action, INSERTED.*, S.TipoAccion;

-- Ver historial completo
SELECT * FROM #ClientesDim ORDER BY ClienteID, FechaInicio;

DROP TABLE #ClientesDim;
DROP TABLE #ClientesSource;

-- =====================================================================
-- SOLUCIÓN 8: INSERT MASIVO CON VALIDACIÓN
-- =====================================================================
CREATE TABLE #TransaccionesStaging (
    ID INT IDENTITY,
    CuentaID INT,
    Monto DECIMAL(15,2),
    Fecha DATE,
    Descripcion VARCHAR(200)
);

CREATE TABLE #TransaccionesDestino (
    ID INT IDENTITY PRIMARY KEY,
    CuentaID INT,
    Monto DECIMAL(15,2),
    Fecha DATE,
    Descripcion VARCHAR(200)
);

CREATE TABLE #TransaccionesErrores (
    ID INT,
    CuentaID INT,
    Monto DECIMAL(15,2),
    Fecha DATE,
    MotivoRechazo VARCHAR(200)
);

-- Datos de prueba (algunos inválidos)
INSERT INTO #TransaccionesStaging VALUES
(1, 1500.00, '2024-01-15', 'Depósito válido'),
(1, -500.00, '2024-01-16', 'Monto negativo'),
(999, 1000.00, '2024-01-17', 'Cuenta inexistente'),
(2, 2000.00, DATEADD(DAY, 30, GETDATE()), 'Fecha futura'),
(2, 750.00, '2024-01-18', 'Otra válida'),
(3, 0, '2024-01-19', 'Monto cero');

-- Validar e insertar
;WITH Validacion AS (
    SELECT 
        s.*,
        CASE 
            WHEN s.Monto <= 0 THEN 'Monto debe ser mayor a 0'
            WHEN s.Fecha > GETDATE() THEN 'Fecha no puede ser futura'
            ELSE 'OK'
        END AS Estado
    FROM #TransaccionesStaging s
)
INSERT INTO #TransaccionesErrores (ID, CuentaID, Monto, Fecha, MotivoRechazo)
SELECT ID, CuentaID, Monto, Fecha, Estado
FROM Validacion
WHERE Estado <> 'OK';

INSERT INTO #TransaccionesDestino (CuentaID, Monto, Fecha, Descripcion)
SELECT CuentaID, Monto, Fecha, Descripcion
FROM #TransaccionesStaging s
WHERE Monto > 0 AND Fecha <= GETDATE();

SELECT 'Válidos' AS Tipo, COUNT(*) AS Total FROM #TransaccionesDestino
UNION ALL
SELECT 'Rechazados', COUNT(*) FROM #TransaccionesErrores;

DROP TABLE #TransaccionesStaging;
DROP TABLE #TransaccionesDestino;
DROP TABLE #TransaccionesErrores;

-- =====================================================================
-- LIMPIEZA FINAL
-- =====================================================================
DROP PROCEDURE IF EXISTS dbo.sp_ProcesarConCheckpoint;
DROP TABLE IF EXISTS dbo.ProcesoCheckpoint;
