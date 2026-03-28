-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 3
-- DISEÑO PARA PERFORMANCE
-- Enfoque: Minimizar CPU y RAM
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- PARTE 0: PREPARAR DATOS DE PRUEBA CON VOLUMEN
-- ============================================================

-- Crear tabla de transacciones con volumen para demos
IF OBJECT_ID('TRANSACCIONES_VOLUMEN') IS NOT NULL 
    DROP TABLE TRANSACCIONES_VOLUMEN;

CREATE TABLE TRANSACCIONES_VOLUMEN (
    TransaccionID INT IDENTITY(1,1) PRIMARY KEY,
    CuentaOrigenID INT,
    CuentaDestinoID INT,
    Monto DECIMAL(15,2),
    FechaTransaccion DATETIME,
    TipoTransaccion VARCHAR(20),
    Estado VARCHAR(15),
    CodigoReferencia VARCHAR(20),
    Descripcion NVARCHAR(200)
);

-- Insertar 100,000 registros de prueba
PRINT 'Insertando 100,000 registros de prueba...';
SET NOCOUNT ON;

DECLARE @i INT = 1;
WHILE @i <= 100000
BEGIN
    INSERT INTO TRANSACCIONES_VOLUMEN 
        (CuentaOrigenID, CuentaDestinoID, Monto, FechaTransaccion, 
         TipoTransaccion, Estado, CodigoReferencia, Descripcion)
    VALUES (
        ABS(CHECKSUM(NEWID())) % 1000 + 1,
        ABS(CHECKSUM(NEWID())) % 1000 + 1,
        CAST(ABS(CHECKSUM(NEWID())) % 100000 AS DECIMAL(15,2)) / 100,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE()),  -- Últimos 2 años
        CASE ABS(CHECKSUM(NEWID())) % 3 
            WHEN 0 THEN 'TRANSFERENCIA'
            WHEN 1 THEN 'DEPOSITO'
            ELSE 'RETIRO'
        END,
        CASE ABS(CHECKSUM(NEWID())) % 3
            WHEN 0 THEN 'COMPLETADA'
            WHEN 1 THEN 'PENDIENTE'
            ELSE 'REVERTIDA'
        END,
        CONCAT('REF', RIGHT('000000' + CAST(@i AS VARCHAR), 6)),
        'Transaccion de prueba numero ' + CAST(@i AS VARCHAR)
    );
    
    SET @i = @i + 1;
    
    -- Mostrar progreso cada 10,000
    IF @i % 10000 = 0
        PRINT CONCAT('Insertados: ', @i, ' registros');
END

PRINT 'Inserción completada.';
GO

-- Crear índice en FechaTransaccion para demos
CREATE NONCLUSTERED INDEX IX_TransVol_Fecha 
ON TRANSACCIONES_VOLUMEN(FechaTransaccion);

CREATE NONCLUSTERED INDEX IX_TransVol_Codigo 
ON TRANSACCIONES_VOLUMEN(CodigoReferencia);

PRINT '✅ Índices creados';
GO

-- ============================================================
-- DEMO 1: IMPACTO DE TIPOS DE DATOS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 1: COMPARACIÓN DE TIPOS DE DATOS';
PRINT '============================================';

-- Crear tablas con diferentes tipos para comparar
IF OBJECT_ID('TIPOS_MALO') IS NOT NULL DROP TABLE TIPOS_MALO;
IF OBJECT_ID('TIPOS_BUENO') IS NOT NULL DROP TABLE TIPOS_BUENO;

-- Tabla con tipos "malos" (sobredimensionados)
CREATE TABLE TIPOS_MALO (
    ID BIGINT IDENTITY PRIMARY KEY,           -- 8 bytes (vs 4 de INT)
    Edad BIGINT,                               -- 8 bytes (vs 1 de TINYINT)
    Cantidad BIGINT,                           -- 8 bytes (vs 2 de SMALLINT)
    Monto FLOAT,                               -- 8 bytes + imprecisión
    CodigoPais NVARCHAR(50),                   -- hasta 102 bytes (vs 2)
    Nombre NVARCHAR(MAX),                      -- LOB storage
    FechaRegistro DATETIME,                    -- 8 bytes (vs 3 de DATE)
    Activo VARCHAR(10)                         -- hasta 12 bytes (vs 1 de BIT)
);

-- Tabla con tipos "buenos" (optimizados)
CREATE TABLE TIPOS_BUENO (
    ID INT IDENTITY PRIMARY KEY,              -- 4 bytes
    Edad TINYINT,                             -- 1 byte
    Cantidad SMALLINT,                        -- 2 bytes
    Monto DECIMAL(12,2),                      -- 5-9 bytes, preciso
    CodigoPais CHAR(2),                       -- 2 bytes
    Nombre NVARCHAR(100),                     -- hasta 202 bytes, in-row
    FechaRegistro DATE,                       -- 3 bytes
    Activo BIT                                -- 1 bit
);

-- Insertar mismos datos en ambas
DECLARE @j INT = 1;
WHILE @j <= 10000
BEGIN
    INSERT INTO TIPOS_MALO (Edad, Cantidad, Monto, CodigoPais, Nombre, FechaRegistro, Activo)
    VALUES (30, 100, 1500.50, 'PE', 'Cliente de Prueba', GETDATE(), 'SI');
    
    INSERT INTO TIPOS_BUENO (Edad, Cantidad, Monto, CodigoPais, Nombre, FechaRegistro, Activo)
    VALUES (30, 100, 1500.50, 'PE', 'Cliente de Prueba', GETDATE(), 1);
    
    SET @j = @j + 1;
END

-- Comparar espacio usado
EXEC sp_spaceused 'TIPOS_MALO';
EXEC sp_spaceused 'TIPOS_BUENO';

-- Detalle de columnas
SELECT 
    'TIPOS_MALO' AS Tabla,
    SUM(CASE c.name
        WHEN 'ID' THEN 8
        WHEN 'Edad' THEN 8
        WHEN 'Cantidad' THEN 8
        WHEN 'Monto' THEN 8
        WHEN 'CodigoPais' THEN 102
        WHEN 'Nombre' THEN 16 -- Puntero LOB
        WHEN 'FechaRegistro' THEN 8
        WHEN 'Activo' THEN 12
        ELSE 0
    END) AS BytesPorFila_Aprox
FROM sys.columns c WHERE object_id = OBJECT_ID('TIPOS_MALO')
UNION ALL
SELECT 
    'TIPOS_BUENO',
    SUM(CASE c.name
        WHEN 'ID' THEN 4
        WHEN 'Edad' THEN 1
        WHEN 'Cantidad' THEN 2
        WHEN 'Monto' THEN 5
        WHEN 'CodigoPais' THEN 2
        WHEN 'Nombre' THEN 202
        WHEN 'FechaRegistro' THEN 3
        WHEN 'Activo' THEN 1
        ELSE 0
    END)
FROM sys.columns c WHERE object_id = OBJECT_ID('TIPOS_BUENO');

GO

-- ============================================================
-- DEMO 2: SARGABILITY - SEEK vs SCAN
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 2: SARGABILITY (SEEK vs SCAN)';
PRINT '============================================';

-- Activar estadísticas de IO y tiempo
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT '';
PRINT '--- CONSULTA NO-SARGABLE (Función en columna) ---';
-- ❌ MAL: Usando YEAR() 
SELECT COUNT(*) AS Total
FROM TRANSACCIONES_VOLUMEN
WHERE YEAR(FechaTransaccion) = 2025;
-- Observar: "Scan count 1, logical reads XXXX"

PRINT '';
PRINT '--- CONSULTA SARGABLE (Rango de fechas) ---';
-- ✅ BIEN: Usando rango
SELECT COUNT(*) AS Total
FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-01-01' 
  AND FechaTransaccion < '2026-01-01';
-- Observar: "Scan count 1, logical reads XX" (mucho menor)

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

GO

-- Ver planes de ejecución
-- Presiona Ctrl+M para ver plan real, luego ejecuta:
/*
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE YEAR(FechaTransaccion) = 2025;
-- Plan: INDEX SCAN

SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-01-01' 
  AND FechaTransaccion < '2026-01-01';
-- Plan: INDEX SEEK
*/

GO

-- ============================================================
-- DEMO 3: DIFERENTES FUNCIONES PROBLEMÁTICAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 3: FUNCIONES PROBLEMÁTICAS EN WHERE';
PRINT '============================================';

SET STATISTICS IO ON;

-- 3A: LEFT() vs LIKE
PRINT '';
PRINT '--- 3A: LEFT() vs LIKE ---';

PRINT 'LEFT() - NO SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE LEFT(CodigoReferencia, 3) = 'REF';

PRINT 'LIKE - SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia LIKE 'REF%';

GO

-- 3B: DATEPART() vs Rango
PRINT '';
PRINT '--- 3B: MONTH() vs Rango ---';

PRINT 'MONTH() - NO SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE MONTH(FechaTransaccion) = 3;

PRINT 'Rango - SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';

GO

-- 3C: CONVERT(DATE) vs Rango
PRINT '';
PRINT '--- 3C: CONVERT() vs Rango ---';

PRINT 'CONVERT() - NO SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE CONVERT(DATE, FechaTransaccion) = '2025-03-15';

PRINT 'Rango - SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-15' 
  AND FechaTransaccion < '2025-03-16';

GO

-- 3D: ISNULL() vs IS NULL OR
PRINT '';
PRINT '--- 3D: ISNULL() problemático ---';

-- Primero insertar algunos NULLs
UPDATE TOP (1000) TRANSACCIONES_VOLUMEN 
SET CuentaDestinoID = NULL 
WHERE Estado = 'REVERTIDA';

PRINT 'ISNULL() - NO SARGABLE:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE ISNULL(CuentaDestinoID, 0) = 0;

PRINT 'IS NULL OR - SARGABLE (si hay índice):';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE CuentaDestinoID IS NULL OR CuentaDestinoID = 0;

SET STATISTICS IO OFF;
GO

-- ============================================================
-- DEMO 4: CONVERSIONES IMPLÍCITAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 4: CONVERSIONES IMPLÍCITAS';
PRINT '============================================';

SET STATISTICS IO ON;

-- El CodigoReferencia es VARCHAR
PRINT '';
PRINT '--- Conversión Implícita VARCHAR vs INT ---';

-- ❌ MAL: Comparar con número (SQL convierte TODA la columna)
PRINT 'Comparando VARCHAR con INT (convierte TODA la columna):';
-- Este ejemplo no aplica directamente porque CodigoReferencia tiene letras
-- Pero el concepto es: si la columna es VARCHAR y comparas con INT, hay conversión

-- Crear columna numérica almacenada como VARCHAR para demo
ALTER TABLE TRANSACCIONES_VOLUMEN ADD CodigoNumerico VARCHAR(10);
GO
UPDATE TRANSACCIONES_VOLUMEN SET CodigoNumerico = CAST(TransaccionID AS VARCHAR(10));
CREATE INDEX IX_CodigoNum ON TRANSACCIONES_VOLUMEN(CodigoNumerico);
GO

PRINT '❌ MAL - Comparar VARCHAR con INT:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE CodigoNumerico = 50000;  -- SQL convierte TODA la columna a INT = SCAN

PRINT '✅ BIEN - Comparar VARCHAR con VARCHAR:';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE CodigoNumerico = '50000';  -- Sin conversión = SEEK

SET STATISTICS IO OFF;
GO

-- ============================================================
-- DEMO 5: COLUMNAS CALCULADAS PERSISTIDAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 5: COLUMNAS CALCULADAS PERSISTIDAS';
PRINT '============================================';

-- Agregar columna calculada para el año
ALTER TABLE TRANSACCIONES_VOLUMEN
ADD TransaccionAnio AS YEAR(FechaTransaccion) PERSISTED;
GO

-- Crear índice en la columna calculada
CREATE INDEX IX_TransVol_Anio ON TRANSACCIONES_VOLUMEN(TransaccionAnio);
GO

SET STATISTICS IO ON;

PRINT '';
PRINT '--- Ahora YEAR() SÍ puede usar índice ---';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE TransaccionAnio = 2025;
-- ¡Ahora es SEEK!

PRINT '';
PRINT '--- Agregar también mes para consultas frecuentes ---';
ALTER TABLE TRANSACCIONES_VOLUMEN
ADD TransaccionMes AS MONTH(FechaTransaccion) PERSISTED;
GO

CREATE INDEX IX_TransVol_AnioMes ON TRANSACCIONES_VOLUMEN(TransaccionAnio, TransaccionMes);
GO

SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE TransaccionAnio = 2025 AND TransaccionMes = 3;
-- SEEK con ambas columnas

SET STATISTICS IO OFF;
GO

-- ============================================================
-- DEMO 6: TABLA DE DIMENSIÓN DE FECHAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 6: TABLA DE DIMENSIÓN DE FECHAS';
PRINT '============================================';

IF OBJECT_ID('DIM_FECHAS') IS NOT NULL DROP TABLE DIM_FECHAS;

CREATE TABLE DIM_FECHAS (
    Fecha DATE PRIMARY KEY,
    Anio SMALLINT NOT NULL,
    Mes TINYINT NOT NULL,
    Dia TINYINT NOT NULL,
    DiaSemana TINYINT NOT NULL,  -- 1=Domingo, 7=Sábado
    NombreDia VARCHAR(10) NOT NULL,
    NombreMes VARCHAR(10) NOT NULL,
    Trimestre TINYINT NOT NULL,
    Semana TINYINT NOT NULL,
    EsFinDeSemana BIT NOT NULL,
    EsFeriado BIT DEFAULT 0,
    DescripcionFeriado VARCHAR(50) NULL
);

-- Poblar con fechas de 2020 a 2030
DECLARE @FechaInicio DATE = '2020-01-01';
DECLARE @FechaFin DATE = '2030-12-31';
DECLARE @Fecha DATE = @FechaInicio;

WHILE @Fecha <= @FechaFin
BEGIN
    INSERT INTO DIM_FECHAS (Fecha, Anio, Mes, Dia, DiaSemana, NombreDia, NombreMes, 
                            Trimestre, Semana, EsFinDeSemana)
    VALUES (
        @Fecha,
        YEAR(@Fecha),
        MONTH(@Fecha),
        DAY(@Fecha),
        DATEPART(WEEKDAY, @Fecha),
        DATENAME(WEEKDAY, @Fecha),
        DATENAME(MONTH, @Fecha),
        DATEPART(QUARTER, @Fecha),
        DATEPART(WEEK, @Fecha),
        CASE WHEN DATEPART(WEEKDAY, @Fecha) IN (1, 7) THEN 1 ELSE 0 END
    );
    
    SET @Fecha = DATEADD(DAY, 1, @Fecha);
END

PRINT 'Tabla DIM_FECHAS creada con ' + CAST(@@ROWCOUNT AS VARCHAR) + ' filas';

-- Crear índices útiles
CREATE INDEX IX_DimFecha_Anio ON DIM_FECHAS(Anio);
CREATE INDEX IX_DimFecha_AnioMes ON DIM_FECHAS(Anio, Mes);
CREATE INDEX IX_DimFecha_DiaSemana ON DIM_FECHAS(DiaSemana);

GO

-- Ejemplo de uso: Transacciones de días hábiles de Marzo 2026
SET STATISTICS IO ON;

PRINT '';
PRINT '--- Consulta con DIM_FECHAS (días hábiles marzo 2026) ---';
SELECT COUNT(*) AS TransaccionesDiasHabiles
FROM TRANSACCIONES_VOLUMEN T
JOIN DIM_FECHAS F ON CAST(T.FechaTransaccion AS DATE) = F.Fecha
WHERE F.Anio = 2026 
  AND F.Mes = 3 
  AND F.EsFinDeSemana = 0;

SET STATISTICS IO OFF;
GO

-- ============================================================
-- DEMO 7: RESUMEN DE STATISTICS IO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 7: CÓMO LEER STATISTICS IO';
PRINT '============================================';

/*
Cuando ejecutas SET STATISTICS IO ON, ves algo como:

Table 'TRANSACCIONES_VOLUMEN'. Scan count 1, logical reads 458, 
physical reads 0, page server reads 0, read-ahead reads 0, 
page server read-ahead reads 0, lob logical reads 0, 
lob physical reads 0, lob page server reads 0, 
lob read-ahead reads 0, lob page server read-ahead reads 0.

TÉRMINOS CLAVE:
===============

Scan count: Número de veces que se accedió a la tabla/índice
  - 1 = Acceso único (normal)
  - >1 = Múltiples accesos (posible con joins o parallelism)

Logical reads: Páginas leídas del Buffer Pool (memoria)
  - ESTE ES EL NÚMERO MÁS IMPORTANTE
  - Menos = Mejor (menos trabajo = más rápido)
  - Cada página = 8KB

Physical reads: Páginas leídas del disco
  - 0 es ideal (todo en memoria)
  - >0 en primera ejecución es normal

LOB reads: Páginas de Large Objects (TEXT, IMAGE, VARCHAR(MAX))
  - Idealmente 0 si no usas LOB

REGLA:
Si dos consultas devuelven lo mismo, la que tiene menos LOGICAL READS es mejor.
*/

GO

-- ============================================================
-- EJERCICIO GUIADO: IDENTIFICAR PROBLEMAS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'EJERCICIO: IDENTIFICAR Y CORREGIR';
PRINT '============================================';

/*
EJERCICIO: Las siguientes consultas tienen problemas de SARGability.
Identifica el problema y escribe la versión corregida.

PROBLEMA 1:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE DATEADD(DAY, 30, FechaTransaccion) > GETDATE();

PROBLEMA 2:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE UPPER(TipoTransaccion) = 'TRANSFERENCIA';

PROBLEMA 3:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia + '-2025' = 'REF000100-2025';

PROBLEMA 4:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE DATEDIFF(DAY, FechaTransaccion, GETDATE()) < 7;

PROBLEMA 5:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE SUBSTRING(CodigoReferencia, 4, 3) = '001';

-- Las soluciones están en el archivo de Ejercicios
*/

GO

-- Limpieza de estadísticas
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- ============================================================
-- CONSULTAS DE DIAGNÓSTICO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'CONSULTAS DE DIAGNÓSTICO';
PRINT '============================================';

-- Ver índices y su uso
SELECT 
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    us.user_seeks AS Seeks,
    us.user_scans AS Scans,
    us.user_lookups AS Lookups,
    us.user_updates AS Updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id AND i.index_id = us.index_id
WHERE OBJECT_NAME(i.object_id) = 'TRANSACCIONES_VOLUMEN'
ORDER BY i.index_id;

-- Ver tamaño de tablas
SELECT 
    t.name AS Tabla,
    p.rows AS Filas,
    CAST(SUM(a.total_pages) * 8 / 1024.0 AS DECIMAL(10,2)) AS TamanioMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.name IN ('TRANSACCIONES_VOLUMEN', 'TIPOS_MALO', 'TIPOS_BUENO', 'DIM_FECHAS')
GROUP BY t.name, p.rows
ORDER BY TamanioMB DESC;

GO

PRINT '';
PRINT '============================================';
PRINT 'FIN DE LA SESIÓN 3';
PRINT '============================================';
