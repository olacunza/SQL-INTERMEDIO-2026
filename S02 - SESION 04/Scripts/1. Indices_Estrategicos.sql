-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 4
-- ÍNDICES ESTRATÉGICOS
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- PARTE 0: PREPARAR DATOS DE PRUEBA
-- ============================================================

-- Asegurar que tenemos la tabla de volumen de la sesión anterior
IF OBJECT_ID('TRANSACCIONES_VOLUMEN') IS NULL
BEGIN
    PRINT 'Creando tabla TRANSACCIONES_VOLUMEN...';
    
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
            DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE()),
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
    END
    SET NOCOUNT OFF;
    PRINT 'Tabla TRANSACCIONES_VOLUMEN creada con 100,000 filas.';
END
GO

-- ============================================================
-- DEMO 1: ANATOMÍA DE UN ÍNDICE
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 1: ANATOMÍA DE UN ÍNDICE';
PRINT '============================================';

-- Un índice es como el índice de un libro:
-- En lugar de leer todo el libro, buscas en el índice alfabético

-- La PRIMARY KEY crea automáticamente un índice CLUSTERED
SELECT 
    i.name AS NombreIndice,
    i.type_desc AS TipoIndice,
    i.is_primary_key AS EsPrimaryKey,
    i.is_unique AS EsUnico
FROM sys.indexes i
WHERE object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN');

-- Ver las columnas de cada índice
SELECT 
    i.name AS NombreIndice,
    c.name AS Columna,
    ic.key_ordinal AS OrdenEnIndice,
    ic.is_descending_key AS Descendente,
    ic.is_included_column AS EsIncluida
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN')
ORDER BY i.name, ic.key_ordinal;

GO

-- ============================================================
-- DEMO 2: CLUSTERED vs NONCLUSTERED
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 2: CLUSTERED vs NONCLUSTERED';
PRINT '============================================';

/*
CLUSTERED INDEX:
- Los datos de la tabla SE ORDENAN físicamente según el índice
- Solo puede haber UNO por tabla
- El índice ES la tabla
- Las hojas del B-tree contienen las FILAS COMPLETAS

NONCLUSTERED INDEX:
- Estructura SEPARADA de los datos
- Puede haber hasta 999 por tabla
- Las hojas contienen: KEYS + Puntero a la fila real
- El puntero es: RID (si no hay clustered) o Clustered Key
*/

-- Crear tabla SIN clustered index (HEAP)
IF OBJECT_ID('TRANSACCIONES_HEAP') IS NOT NULL DROP TABLE TRANSACCIONES_HEAP;

CREATE TABLE TRANSACCIONES_HEAP (
    TransaccionID INT NOT NULL,  -- Sin PRIMARY KEY
    FechaTransaccion DATETIME,
    Monto DECIMAL(15,2)
);

-- Insertar datos
INSERT INTO TRANSACCIONES_HEAP (TransaccionID, FechaTransaccion, Monto)
SELECT TOP 10000 
    TransaccionID, 
    FechaTransaccion, 
    Monto
FROM TRANSACCIONES_VOLUMEN;

-- Verificar: Es un HEAP (sin clustered index)
SELECT 
    i.name AS NombreIndice,
    i.type_desc AS Tipo
FROM sys.indexes i
WHERE object_id = OBJECT_ID('TRANSACCIONES_HEAP');
-- Resultado: type_desc = 'HEAP'

-- Crear índice NONCLUSTERED en tabla HEAP
CREATE NONCLUSTERED INDEX IX_Heap_Fecha 
ON TRANSACCIONES_HEAP(FechaTransaccion);

-- Ahora tenemos: HEAP + 1 NC Index
SELECT 
    i.name AS NombreIndice,
    i.type_desc AS Tipo
FROM sys.indexes i
WHERE object_id = OBJECT_ID('TRANSACCIONES_HEAP');

GO

-- Comparar tamaño: la tabla con clustered vs HEAP
EXEC sp_spaceused 'TRANSACCIONES_VOLUMEN';
EXEC sp_spaceused 'TRANSACCIONES_HEAP';

GO

-- ============================================================
-- DEMO 3: EL PROBLEMA DEL KEY LOOKUP
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 3: KEY LOOKUP (Bookmark Lookup)';
PRINT '============================================';

-- Eliminar índices previos para demo limpia
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Trans_Fecha_NoInc' AND object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN'))
    DROP INDEX IX_Trans_Fecha_NoInc ON TRANSACCIONES_VOLUMEN;

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Trans_Fecha_Inc' AND object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN'))
    DROP INDEX IX_Trans_Fecha_Inc ON TRANSACCIONES_VOLUMEN;

GO

-- Crear índice SIN columnas incluidas
CREATE NONCLUSTERED INDEX IX_Trans_Fecha_NoInc
ON TRANSACCIONES_VOLUMEN(FechaTransaccion);

GO

SET STATISTICS IO ON;

PRINT '';
PRINT '--- CONSULTA 1: Solo la columna del índice ---';
-- Esta consulta puede resolverse completamente con el índice
SELECT FechaTransaccion
FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';
-- Plan: Index Seek (eficiente)

GO

PRINT '';
PRINT '--- CONSULTA 2: Columnas adicionales (KEY LOOKUP) ---';
-- Esta consulta necesita columnas que NO están en el índice
SELECT FechaTransaccion, Monto, Estado, Descripcion
FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';
-- Plan: Index Seek + Key Lookup + Nested Loops
-- ¡MUCHO MÁS COSTOSO!

GO

SET STATISTICS IO OFF;

/*
OBSERVA en el plan de ejecución (Ctrl+M):
1. Index Seek en IX_Trans_Fecha_NoInc
2. Key Lookup en PK (clustered)
3. Nested Loops para unirlos

¿Por qué es malo?
- Por CADA fila encontrada en el NC index
- SQL debe ir al CLUSTERED index a buscar el resto de columnas
- Si la query devuelve muchas filas = MUCHOS lookups = LENTO
*/

GO

-- ============================================================
-- DEMO 4: INCLUDE - LA SOLUCIÓN AL KEY LOOKUP
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 4: COVERING INDEX con INCLUDE';
PRINT '============================================';

-- Crear índice que INCLUYE las columnas necesarias
CREATE NONCLUSTERED INDEX IX_Trans_Fecha_Inc
ON TRANSACCIONES_VOLUMEN(FechaTransaccion)
INCLUDE (Monto, Estado, Descripcion);

GO

SET STATISTICS IO ON;

PRINT '';
PRINT '--- MISMA CONSULTA con COVERING INDEX ---';
SELECT FechaTransaccion, Monto, Estado, Descripcion
FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';
-- Plan: Solo Index Seek - ¡SIN KEY LOOKUP!

SET STATISTICS IO OFF;

GO

-- Comparar espacio de ambos índices
SELECT 
    i.name AS NombreIndice,
    SUM(s.used_page_count) * 8 / 1024.0 AS TamanioMB
FROM sys.indexes i
JOIN sys.dm_db_partition_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN')
  AND i.name LIKE 'IX_Trans_Fecha%'
GROUP BY i.name;

/*
NOTA: El índice con INCLUDE es más grande porque almacena las columnas extra
      PERO evita el costoso Key Lookup

REGLA:
- Las columnas en KEY (dentro del paréntesis) se usan para BUSCAR y ORDENAR
- Las columnas en INCLUDE solo se almacenan en las hojas para EVITAR LOOKUPS
*/

GO

-- ============================================================
-- DEMO 5: ORDEN DE COLUMNAS EN ÍNDICE COMPUESTO
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 5: ORDEN DE COLUMNAS EN ÍNDICE';
PRINT '============================================';

-- El orden de las columnas es CRÍTICO
-- Piensa en una guía telefónica: Apellido, Nombre
-- ¿Puedes buscar por Nombre sin saber Apellido? ¡NO!

-- Crear índice compuesto
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Trans_Estado_Tipo_Fecha')
    DROP INDEX IX_Trans_Estado_Tipo_Fecha ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Trans_Estado_Tipo_Fecha
ON TRANSACCIONES_VOLUMEN(Estado, TipoTransaccion, FechaTransaccion);

GO

SET STATISTICS IO ON;

PRINT '';
PRINT '--- Caso A: WHERE usa columna 1 (SEEK) ---';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'COMPLETADA';
-- ✅ SEEK - La primera columna es usada

PRINT '';
PRINT '--- Caso B: WHERE usa columnas 1 y 2 (SEEK) ---';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'COMPLETADA' AND TipoTransaccion = 'TRANSFERENCIA';
-- ✅ SEEK - Columnas 1 y 2 en orden

PRINT '';
PRINT '--- Caso C: WHERE usa columna 2 SIN columna 1 (SCAN) ---';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE TipoTransaccion = 'TRANSFERENCIA';
-- ❌ SCAN - No puede "saltar" la primera columna

PRINT '';
PRINT '--- Caso D: WHERE usa columnas 1 y 3, saltando 2 ---';
SELECT COUNT(*) FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'COMPLETADA' AND FechaTransaccion >= '2025-01-01';
-- Parcialmente eficiente: SEEK por Estado, pero no por Fecha completa

SET STATISTICS IO OFF;

GO

/*
REGLA PARA ORDENAR COLUMNAS:
1. Columnas con = primero (máxima selectividad)
2. Columnas con > < BETWEEN después  
3. Columnas de ORDER BY al final
4. La columna MÁS selectiva (más valores únicos) primero

EJEMPLO:
WHERE Estado = 'ACTIVO' AND FechaCreacion > '2025-01-01' ORDER BY Nombre
→ INDEX (Estado, FechaCreacion, Nombre)
*/

GO

-- ============================================================
-- DEMO 6: ÍNDICES FILTRADOS
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 6: FILTERED INDEXES';
PRINT '============================================';

-- Los índices filtrados solo incluyen un subconjunto de filas
-- Útiles cuando la mayoría de consultas buscan un valor específico

-- Ver distribución de estados
SELECT Estado, COUNT(*) AS Cantidad
FROM TRANSACCIONES_VOLUMEN
GROUP BY Estado;

GO

-- Crear índice filtrado solo para transacciones pendientes
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Trans_Pendientes')
    DROP INDEX IX_Trans_Pendientes ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Trans_Pendientes
ON TRANSACCIONES_VOLUMEN(FechaTransaccion, CuentaOrigenID)
WHERE Estado = 'PENDIENTE';

GO

-- Ver tamaño del índice filtrado vs uno completo
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Trans_Todos')
    DROP INDEX IX_Trans_Todos ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Trans_Todos
ON TRANSACCIONES_VOLUMEN(FechaTransaccion, CuentaOrigenID);

GO

SELECT 
    i.name AS NombreIndice,
    i.has_filter AS TieneFiltro,
    i.filter_definition AS Filtro,
    SUM(s.used_page_count) * 8 / 1024.0 AS TamanioMB,
    SUM(s.row_count) AS Filas
FROM sys.indexes i
JOIN sys.dm_db_partition_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN')
  AND i.name IN ('IX_Trans_Pendientes', 'IX_Trans_Todos')
GROUP BY i.name, i.has_filter, i.filter_definition;

GO

SET STATISTICS IO ON;

PRINT '';
PRINT '--- Consulta que usa el índice filtrado ---';
SELECT CuentaOrigenID, FechaTransaccion
FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'PENDIENTE' 
  AND FechaTransaccion >= '2025-01-01';
-- SQL usa IX_Trans_Pendientes (más pequeño y eficiente)

SET STATISTICS IO OFF;

GO

/*
VENTAJAS DE ÍNDICES FILTRADOS:
1. Ocupan menos espacio
2. Se mantienen más rápido (menos filas que actualizar)
3. Más eficientes para su subconjunto de datos

CASOS DE USO:
- WHERE Estado = 'ACTIVO' (ignorar eliminados)
- WHERE FechaCreacion > 'fecha reciente' (datos históricos)
- WHERE TipoCliente = 'PREMIUM' (clientes especiales)
- WHERE Columna IS NOT NULL (sparse data)

LIMITACIÓN:
- La query DEBE incluir la condición del filtro
- O SQL no usará el índice
*/

GO

-- ============================================================
-- DEMO 7: ANALIZAR ÍNDICES EXISTENTES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 7: ANÁLISIS DE ÍNDICES';
PRINT '============================================';

-- Ver uso de índices
SELECT 
    OBJECT_NAME(s.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    s.user_seeks AS Seeks,
    s.user_scans AS Scans,
    s.user_lookups AS Lookups,
    s.user_updates AS Updates,
    CASE 
        WHEN s.user_seeks + s.user_scans + s.user_lookups = 0 THEN 'NO USADO'
        WHEN s.user_updates > (s.user_seeks + s.user_scans) * 10 THEN 'MÁS WRITES'
        ELSE 'OK'
    END AS Diagnostico
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE OBJECT_NAME(s.object_id) = 'TRANSACCIONES_VOLUMEN'
  AND i.name IS NOT NULL
ORDER BY s.user_seeks + s.user_scans DESC;

GO

-- Ver fragmentación
SELECT 
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    ps.index_type_desc AS Tipo,
    ps.avg_fragmentation_in_percent AS Fragmentacion,
    ps.page_count AS Paginas,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 10 THEN 'OK'
        WHEN ps.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END AS Accion
FROM sys.dm_db_index_physical_stats(
    DB_ID(), 
    OBJECT_ID('TRANSACCIONES_VOLUMEN'), 
    NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.page_count > 10  -- Solo índices con al menos 10 páginas
ORDER BY ps.avg_fragmentation_in_percent DESC;

GO

-- ============================================================
-- DEMO 8: MISSING INDEX DMVs
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 8: ÍNDICES SUGERIDOS POR SQL SERVER';
PRINT '============================================';

-- Ver qué índices sugiere SQL Server basado en las queries ejecutadas
SELECT TOP 10
    OBJECT_NAME(mid.object_id) AS Tabla,
    mid.equality_columns AS ColumnasIgualdad,
    mid.inequality_columns AS ColumnasDesigualdad,
    mid.included_columns AS ColumnasIncluidas,
    migs.avg_user_impact AS ImpactoPromedio,
    migs.user_seeks AS VecesNecesitado,
    -- Script sugerido para crear el índice
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_Sugerido ON ' +
    OBJECT_NAME(mid.object_id) + ' (' +
    ISNULL(mid.equality_columns, '') +
    CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
         THEN ', ' ELSE '' END +
    ISNULL(mid.inequality_columns, '') + ')' +
    CASE WHEN mid.included_columns IS NOT NULL 
         THEN ' INCLUDE (' + mid.included_columns + ')' 
         ELSE '' END AS ScriptSugerido
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
WHERE database_id = DB_ID()
ORDER BY migs.avg_user_impact * migs.user_seeks DESC;

/*
NOTA: Las sugerencias de missing index son solo SUGERENCIAS
Debes evaluar:
1. ¿Cuántos índices ya tiene la tabla?
2. ¿Hay índices similares que podrían ampliarse?
3. ¿El índice beneficia vs el costo de mantenerlo?
4. ¿La query realmente se ejecuta con frecuencia?
*/

GO

-- ============================================================
-- DEMO 9: MANTENIMIENTO DE ÍNDICES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 9: MANTENIMIENTO';
PRINT '============================================';

-- Fragmentar un índice artificialmente
-- (En producción esto pasa naturalmente con INSERTs/UPDATEs/DELETEs)

DECLARE @j INT = 1;
WHILE @j <= 5000
BEGIN
    UPDATE TRANSACCIONES_VOLUMEN 
    SET Monto = Monto + 0.01
    WHERE TransaccionID = @j;
    SET @j = @j + 1;
END

-- Ver fragmentación después de updates
SELECT 
    i.name AS Indice,
    ps.avg_fragmentation_in_percent AS Fragmentacion,
    ps.page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    DB_ID(), 
    OBJECT_ID('TRANSACCIONES_VOLUMEN'), 
    NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.page_count > 10
ORDER BY ps.avg_fragmentation_in_percent DESC;

GO

-- REORGANIZE: Ordena las páginas existentes (online, menos recursos)
ALTER INDEX IX_Trans_Fecha_Inc ON TRANSACCIONES_VOLUMEN REORGANIZE;
PRINT 'REORGANIZE completado';

-- REBUILD: Recrea el índice completamente (más efectivo pero más recursos)
ALTER INDEX IX_Trans_Fecha_NoInc ON TRANSACCIONES_VOLUMEN REBUILD;
PRINT 'REBUILD completado';

-- Verificar después del mantenimiento
SELECT 
    i.name AS Indice,
    ps.avg_fragmentation_in_percent AS Fragmentacion
FROM sys.dm_db_index_physical_stats(
    DB_ID(), 
    OBJECT_ID('TRANSACCIONES_VOLUMEN'), 
    NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.name IN ('IX_Trans_Fecha_Inc', 'IX_Trans_Fecha_NoInc');

GO

-- ============================================================
-- DEMO 10: SP DE DIAGNÓSTICO DE ÍNDICES
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT 'DEMO 10: SP DE DIAGNÓSTICO';
PRINT '============================================';

CREATE OR ALTER PROCEDURE SP_DiagnosticoIndices
    @NombreTabla NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ObjectId INT = OBJECT_ID(@NombreTabla);
    
    IF @ObjectId IS NULL
    BEGIN
        RAISERROR('Tabla no encontrada: %s', 16, 1, @NombreTabla);
        RETURN;
    END
    
    -- 1. Resumen de índices
    PRINT '';
    PRINT '=== ÍNDICES DE ' + @NombreTabla + ' ===';
    
    SELECT 
        i.name AS NombreIndice,
        i.type_desc AS Tipo,
        i.is_unique AS Unico,
        i.is_primary_key AS PK,
        i.has_filter AS Filtrado,
        (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0) AS ColsKey,
        (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1) AS ColsInclude
    FROM sys.indexes i
    WHERE i.object_id = @ObjectId
    ORDER BY i.index_id;
    
    -- 2. Fragmentación
    PRINT '';
    PRINT '=== FRAGMENTACIÓN ===';
    
    SELECT 
        i.name AS Indice,
        ps.avg_fragmentation_in_percent AS Fragmentacion,
        ps.page_count AS Paginas,
        CASE 
            WHEN ps.avg_fragmentation_in_percent < 10 THEN '✓ OK'
            WHEN ps.avg_fragmentation_in_percent < 30 THEN '⚠ REORGANIZE'
            ELSE '✗ REBUILD'
        END AS Recomendacion
    FROM sys.dm_db_index_physical_stats(DB_ID(), @ObjectId, NULL, NULL, 'LIMITED') ps
    JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    WHERE ps.page_count > 10
    ORDER BY ps.avg_fragmentation_in_percent DESC;
    
    -- 3. Uso de índices
    PRINT '';
    PRINT '=== USO DE ÍNDICES ===';
    
    SELECT 
        i.name AS Indice,
        ISNULL(s.user_seeks, 0) AS Seeks,
        ISNULL(s.user_scans, 0) AS Scans,
        ISNULL(s.user_lookups, 0) AS Lookups,
        ISNULL(s.user_updates, 0) AS Updates,
        CASE 
            WHEN ISNULL(s.user_seeks, 0) + ISNULL(s.user_scans, 0) = 0 AND ISNULL(s.user_updates, 0) > 0 
                THEN '⚠ CANDIDATO A ELIMINAR'
            WHEN ISNULL(s.user_updates, 0) > (ISNULL(s.user_seeks, 0) + ISNULL(s.user_scans, 0)) * 10 
                THEN '⚠ MÁS WRITES QUE READS'
            ELSE '✓ OK'
        END AS Estado
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats s 
        ON i.object_id = s.object_id AND i.index_id = s.index_id AND s.database_id = DB_ID()
    WHERE i.object_id = @ObjectId
      AND i.type > 0  -- No heap
    ORDER BY ISNULL(s.user_seeks, 0) + ISNULL(s.user_scans, 0) DESC;
    
    PRINT '';
    PRINT 'Diagnóstico completado.';
END
GO

-- Ejecutar diagnóstico
EXEC SP_DiagnosticoIndices 'TRANSACCIONES_VOLUMEN';

GO

-- ============================================================
-- LIMPIEZA OPCIONAL
-- ============================================================

/*
-- Para limpiar los índices de demo:
DROP INDEX IF EXISTS IX_Trans_Fecha_Inc ON TRANSACCIONES_VOLUMEN;
DROP INDEX IF EXISTS IX_Trans_Fecha_NoInc ON TRANSACCIONES_VOLUMEN;
DROP INDEX IF EXISTS IX_Trans_Estado_Tipo_Fecha ON TRANSACCIONES_VOLUMEN;
DROP INDEX IF EXISTS IX_Trans_Pendientes ON TRANSACCIONES_VOLUMEN;
DROP INDEX IF EXISTS IX_Trans_Todos ON TRANSACCIONES_VOLUMEN;
DROP TABLE IF EXISTS TRANSACCIONES_HEAP;
*/

PRINT '';
PRINT '============================================';
PRINT 'FIN DE DEMO - ÍNDICES ESTRATÉGICOS';
PRINT '============================================';
