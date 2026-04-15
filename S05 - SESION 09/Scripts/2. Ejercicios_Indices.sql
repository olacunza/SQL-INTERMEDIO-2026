/*
=====================================================================
  EJERCICIOS PRÁCTICOS: OPTIMIZACIÓN DE ÍNDICES
  SQL Server Intermedio 2026 - Sesión 09
  
  Instrucciones:
  - Completar cada ejercicio según las indicaciones
  - Comparar con las soluciones al final
  - Usar BancoDB como base de datos
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- EJERCICIO 1: ANÁLISIS DE FRAGMENTACIÓN
-- =====================================================================
/*
   OBJETIVO: Crear un reporte de fragmentación para las tablas principales
   
   INSTRUCCIONES:
   1. Analizar fragmentación de TODAS las tablas de BancoDB
   2. Mostrar solo índices con más de 10 páginas
   3. Incluir: Tabla, Índice, Tipo, % Fragmentación, Páginas, Acción recomendada
   4. Ordenar por fragmentación descendente
   
   CRITERIOS:
   - <5%: "Sin acción"
   - 5-30%: "REORGANIZE"
   - >30%: "REBUILD"
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 2: SIMULAR Y MEDIR FRAGMENTACIÓN
-- =====================================================================
/*
   OBJETIVO: Crear una tabla, fragmentarla y medir el impacto
   
   INSTRUCCIONES:
   1. Crear tabla #TestFragmentacion con columnas:
      - ID INT IDENTITY PRIMARY KEY
      - Datos CHAR(200)
      - Valor INT
   2. Insertar 10,000 registros
   3. Medir fragmentación inicial
   4. Eliminar todos los registros donde ID sea múltiplo de 4
   5. Medir fragmentación después
   6. Aplicar REORGANIZE
   7. Medir fragmentación final
   8. Documentar resultados en comentarios
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 3: FILL FACTOR ÓPTIMO
-- =====================================================================
/*
   OBJETIVO: Analizar y recomendar Fill Factor para las tablas de BancoDB
   
   INSTRUCCIONES:
   Para cada tabla principal, analizar:
   1. Patrón de inserción (secuencial vs aleatorio)
   2. Frecuencia de updates
   3. Frecuencia de deletes
   
   Crear una tabla con tus recomendaciones:
   - Tabla
   - Índice
   - FillFactor actual
   - FillFactor recomendado
   - Justificación
   
   TABLAS A ANALIZAR:
   - CLIENTES
   - CUENTAS
   - TRANSACCIONES_BANCARIAS
   - EMPLEADOS (si existe)
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 4: DETECTAR ÍNDICES INEFICIENTES
-- =====================================================================
/*
   OBJETIVO: Encontrar índices con más escrituras que lecturas
   
   INSTRUCCIONES:
   1. Consultar sys.dm_db_index_usage_stats
   2. Mostrar índices donde user_updates > (user_seeks + user_scans) * 2
   3. Calcular "costo de mantenimiento" = updates / (seeks + scans + 1)
   4. Excluir índices únicos y primary keys
   5. Ordenar por costo descendente
   
   COLUMNAS REQUERIDAS:
   - Tabla, Índice, Seeks, Scans, Updates, CostoMantenimiento, Recomendación
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 5: MISSING INDEXES PRIORITIZADOS
-- =====================================================================
/*
   OBJETIVO: Crear un reporte priorizado de índices sugeridos
   
   INSTRUCCIONES:
   1. Consultar las DMVs de missing indexes
   2. Calcular score de prioridad: avg_user_impact * user_seeks
   3. Generar script CREATE INDEX automático
   4. Mostrar solo índices con score > 1000
   5. Considerar si ya existe un índice similar
   
   NOTA: Si no hay missing indexes, crear algunas queries que los generen
*/

-- Queries para generar missing indexes (ejecutar primero):
SELECT * FROM TRANSACCIONES_BANCARIAS WHERE Monto > 5000 AND FechaTransaccion > '2024-01-01';
SELECT * FROM CLIENTES WHERE Apellido LIKE 'García%' AND Estado = 'Activo';
SELECT c.*, cu.Saldo FROM CLIENTES c JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID WHERE c.Ciudad = 'México';
GO

-- TU CÓDIGO AQUÍ (reporte de missing indexes):




-- =====================================================================
-- EJERCICIO 6: ÍNDICES DUPLICADOS
-- =====================================================================
/*
   OBJETIVO: Detectar índices con las mismas columnas clave
   
   INSTRUCCIONES:
   1. Crear temporalmente algunos índices que se superpongan
   2. Escribir query para detectar duplicados
   3. Incluir análisis de columnas INCLUDE
   4. Generar script DROP para los redundantes
   5. Limpiar los índices de prueba
*/

-- Crear índices de prueba para simular duplicados
CREATE NONCLUSTERED INDEX IX_Test_Dup1 ON TRANSACCIONES_BANCARIAS(CuentaID);
CREATE NONCLUSTERED INDEX IX_Test_Dup2 ON TRANSACCIONES_BANCARIAS(CuentaID) INCLUDE (Monto);
GO

-- TU CÓDIGO AQUÍ:




-- Limpiar
DROP INDEX IF EXISTS IX_Test_Dup1 ON TRANSACCIONES_BANCARIAS;
DROP INDEX IF EXISTS IX_Test_Dup2 ON TRANSACCIONES_BANCARIAS;
GO

-- =====================================================================
-- EJERCICIO 7: PLAN DE MANTENIMIENTO SEMANAL
-- =====================================================================
/*
   OBJETIVO: Crear un SP de mantenimiento personalizado para BancoDB
   
   INSTRUCCIONES:
   1. El SP debe recibir parámetros:
      - @Modo: 'ANALISIS' o 'EJECUCION'
      - @UmbralBajo: Porcentaje mínimo para acción
      - @UmbralAlto: Porcentaje para REBUILD
      - @IncluirEstadisticas: BIT para actualizar stats
   
   2. Debe:
      - Analizar todos los índices
      - Aplicar REORGANIZE o REBUILD según umbrales
      - Opcionalmente actualizar estadísticas
      - Retornar resumen de acciones
   
   3. Registrar en tabla de log cada ejecución
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 8: CALCULAR ESPACIO DESPERDICIADO
-- =====================================================================
/*
   OBJETIVO: Cuantificar espacio perdido por fragmentación interna
   
   INSTRUCCIONES:
   1. Para cada índice, calcular:
      - Espacio actual usado
      - Espacio teórico si estuviera 100% lleno
      - Espacio desperdiciado (MB)
      - Porcentaje de desperdicio
   
   2. Mostrar totales por tabla y global
   3. Ordenar por espacio desperdiciado descendente
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 9: MONITOREO EN TIEMPO REAL
-- =====================================================================
/*
   OBJETIVO: Crear un dashboard de salud de índices
   
   INSTRUCCIONES:
   1. Crear una vista que muestre:
      - Estado de fragmentación (emoji o texto)
      - Estado de uso (lectura vs escritura)
      - Cuándo fue la última vez que se usó
      - Tamaño en MB
      - Recomendación de acción
   
   2. Agregar columna de "urgencia" basada en múltiples factores
*/

-- TU CÓDIGO AQUÍ:




-- =====================================================================
-- EJERCICIO 10: CASO DE ESTUDIO COMPLETO
-- =====================================================================
/*
   ESCENARIO:
   El banco ha reportado que las consultas de fin de mes están lentas.
   Las transacciones se insertan constantemente (24/7).
   Los reportes se ejecutan los primeros 5 días del mes.
   
   TAREAS:
   1. Analizar el estado actual de los índices
   2. Identificar problemas específicos
   3. Proponer un plan de acción con:
      - Acciones inmediatas
      - Plan de mantenimiento regular
      - Índices a crear/eliminar
      - Fill Factor recomendado
   4. Estimar mejora esperada
   
   ENTREGABLE: Documento con análisis y recomendaciones en comentarios
*/

-- TU ANÁLISIS AQUÍ:
/*
   ANÁLISIS ACTUAL:
   ================
   
   
   PROBLEMAS IDENTIFICADOS:
   ========================
   
   
   PLAN DE ACCIÓN:
   ===============
   
   ACCIONES INMEDIATAS:
   
   
   MANTENIMIENTO REGULAR:
   
   
   ÍNDICES A MODIFICAR:
   
   
   MEJORA ESPERADA:
   
*/



-- #####################################################################
-- #                        SOLUCIONES                                 #
-- #####################################################################

-- =====================================================================
-- SOLUCIÓN 1: ANÁLISIS DE FRAGMENTACIÓN
-- =====================================================================
SELECT 
    OBJECT_SCHEMA_NAME(ps.object_id) AS Esquema,
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    ROUND(ps.avg_fragmentation_in_percent, 2) AS PctFragmentacion,
    ps.page_count AS Paginas,
    ps.page_count * 8 / 1024 AS TamañoMB,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 5 THEN 'Sin acción'
        WHEN ps.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END AS AccionRecomendada,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 5 THEN ''
        WHEN ps.avg_fragmentation_in_percent < 30 THEN
            'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + 
            QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + 
            QUOTENAME(OBJECT_NAME(ps.object_id)) + ' REORGANIZE;'
        ELSE
            'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + 
            QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + 
            QUOTENAME(OBJECT_NAME(ps.object_id)) + ' REBUILD;'
    END AS Script
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
INNER JOIN sys.indexes i 
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.page_count > 10
  AND ps.index_id > 0
  AND OBJECT_SCHEMA_NAME(ps.object_id) = 'dbo'
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- =====================================================================
-- SOLUCIÓN 2: SIMULAR Y MEDIR FRAGMENTACIÓN
-- =====================================================================
-- Paso 1: Crear tabla
CREATE TABLE #TestFragmentacion (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Datos CHAR(200) DEFAULT REPLICATE('X', 200),
    Valor INT DEFAULT 100
);

-- Paso 2: Insertar datos
INSERT INTO #TestFragmentacion (Datos, Valor)
SELECT TOP 10000 REPLICATE('A', 200), ABS(CHECKSUM(NEWID())) % 1000
FROM sys.objects a, sys.objects b;

-- Paso 3: Medir fragmentación inicial
SELECT 'INICIAL' AS Estado,
    avg_fragmentation_in_percent AS FragPct,
    avg_page_space_used_in_percent AS UsoPct,
    page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    2, OBJECT_ID('tempdb..#TestFragmentacion'), 1, NULL, 'DETAILED'
)
WHERE index_level = 0;

-- Paso 4: Fragmentar (DELETE múltiplos de 4)
DELETE FROM #TestFragmentacion WHERE ID % 4 = 0;

-- Paso 5: Medir después de deletes
SELECT 'DESPUÉS DELETE' AS Estado,
    avg_fragmentation_in_percent AS FragPct,
    avg_page_space_used_in_percent AS UsoPct,
    page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    2, OBJECT_ID('tempdb..#TestFragmentacion'), 1, NULL, 'DETAILED'
)
WHERE index_level = 0;

-- Paso 6: REORGANIZE
ALTER INDEX ALL ON #TestFragmentacion REORGANIZE;

-- Paso 7: Medir después de reorganize
SELECT 'DESPUÉS REORGANIZE' AS Estado,
    avg_fragmentation_in_percent AS FragPct,
    avg_page_space_used_in_percent AS UsoPct,
    page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    2, OBJECT_ID('tempdb..#TestFragmentacion'), 1, NULL, 'DETAILED'
)
WHERE index_level = 0;

DROP TABLE #TestFragmentacion;

-- =====================================================================
-- SOLUCIÓN 3: FILL FACTOR ÓPTIMO
-- =====================================================================
SELECT 
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    CASE WHEN i.fill_factor = 0 THEN 100 ELSE i.fill_factor END AS FillFactorActual,
    CASE 
        -- CLIENTES: Pocos cambios, datos estables
        WHEN OBJECT_NAME(i.object_id) = 'CLIENTES' THEN 95
        -- CUENTAS: Updates frecuentes de saldo
        WHEN OBJECT_NAME(i.object_id) = 'CUENTAS' THEN 85
        -- TRANSACCIONES: Inserts secuenciales (por fecha)
        WHEN OBJECT_NAME(i.object_id) = 'TRANSACCIONES_BANCARIAS' 
             AND i.type_desc = 'CLUSTERED' THEN 95
        -- Índices NC en transacciones: más fragmentación potencial
        WHEN OBJECT_NAME(i.object_id) = 'TRANSACCIONES_BANCARIAS' 
             AND i.type_desc = 'NONCLUSTERED' THEN 80
        ELSE 90
    END AS FillFactorRecomendado,
    CASE 
        WHEN OBJECT_NAME(i.object_id) = 'CLIENTES' 
            THEN 'Datos maestros estables, pocas escrituras'
        WHEN OBJECT_NAME(i.object_id) = 'CUENTAS' 
            THEN 'Updates frecuentes de saldo requieren espacio extra'
        WHEN OBJECT_NAME(i.object_id) = 'TRANSACCIONES_BANCARIAS' 
             AND i.type_desc = 'CLUSTERED' 
            THEN 'Inserts secuenciales por fecha/ID'
        WHEN OBJECT_NAME(i.object_id) = 'TRANSACCIONES_BANCARIAS' 
            THEN 'Índice NC con potenciales page splits'
        ELSE 'Configuración balanceada por defecto'
    END AS Justificacion
FROM sys.indexes i
WHERE i.object_id IN (
    OBJECT_ID('CLIENTES'),
    OBJECT_ID('CUENTAS'),
    OBJECT_ID('TRANSACCIONES_BANCARIAS')
)
AND i.index_id > 0
ORDER BY OBJECT_NAME(i.object_id), i.index_id;

-- =====================================================================
-- SOLUCIÓN 4: DETECTAR ÍNDICES INEFICIENTES
-- =====================================================================
SELECT 
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    ISNULL(us.user_seeks, 0) AS Seeks,
    ISNULL(us.user_scans, 0) AS Scans,
    ISNULL(us.user_lookups, 0) AS Lookups,
    ISNULL(us.user_updates, 0) AS Updates,
    ROUND(
        CAST(ISNULL(us.user_updates, 0) AS FLOAT) / 
        NULLIF(ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + 1, 0), 
    2) AS CostoMantenimiento,
    CASE 
        WHEN ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) = 0 
            THEN 'ELIMINAR - Nunca usado para lecturas'
        WHEN ISNULL(us.user_updates, 0) > (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0)) * 5 
            THEN 'REVISAR - Alto costo de mantenimiento'
        WHEN ISNULL(us.user_updates, 0) > (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0)) * 2 
            THEN 'MONITOREAR - Posible candidato a eliminar'
        ELSE 'OK - Uso balanceado'
    END AS Recomendacion
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED'
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_unique = 0
  AND ISNULL(us.user_updates, 0) > 0
ORDER BY CostoMantenimiento DESC;

-- =====================================================================
-- SOLUCIÓN 5: MISSING INDEXES PRIORITIZADOS
-- =====================================================================
SELECT 
    OBJECT_NAME(mid.object_id) AS Tabla,
    mid.equality_columns AS ColumnasIgualdad,
    mid.inequality_columns AS ColumnasRango,
    mid.included_columns AS ColumnasIncluir,
    migs.unique_compiles AS Compilaciones,
    migs.user_seeks AS BusquedasEstimadas,
    ROUND(migs.avg_user_impact, 2) AS ImpactoPct,
    ROUND(migs.avg_user_impact * migs.user_seeks, 0) AS ScorePrioridad,
    'CREATE NONCLUSTERED INDEX [IX_' + 
        OBJECT_NAME(mid.object_id) + '_Sugerido_' + 
        CAST(mid.index_handle AS VARCHAR) + '] ON ' + 
        mid.statement + ' (' + 
        ISNULL(mid.equality_columns, '') +
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
             THEN ', ' ELSE '' END +
        ISNULL(mid.inequality_columns, '') + ')' +
        CASE WHEN mid.included_columns IS NOT NULL 
             THEN ' INCLUDE (' + mid.included_columns + ')' 
             ELSE '' END + ';' AS ScriptCreacion
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig 
    ON mid.index_handle = mig.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs 
    ON mig.index_group_handle = migs.group_handle
WHERE mid.database_id = DB_ID()
  AND migs.avg_user_impact * migs.user_seeks > 1000
ORDER BY ScorePrioridad DESC;

-- =====================================================================
-- SOLUCIÓN 6: ÍNDICES DUPLICADOS
-- =====================================================================
;WITH IndexColumnas AS (
    SELECT 
        OBJECT_NAME(i.object_id) AS Tabla,
        i.name AS NombreIndice,
        i.index_id,
        i.object_id,
        STRING_AGG(
            CASE WHEN ic.is_included_column = 0 THEN c.name END, ','
        ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS ColumnasClave,
        STRING_AGG(
            CASE WHEN ic.is_included_column = 1 THEN c.name END, ','
        ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS ColumnasIncluidas
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic 
        ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c 
        ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.type_desc = 'NONCLUSTERED'
    GROUP BY i.object_id, i.name, i.index_id
)
SELECT 
    a.Tabla,
    a.NombreIndice AS Indice1,
    b.NombreIndice AS Indice2,
    a.ColumnasClave,
    a.ColumnasIncluidas AS Include1,
    b.ColumnasIncluidas AS Include2,
    CASE 
        WHEN a.ColumnasIncluidas IS NULL AND b.ColumnasIncluidas IS NOT NULL 
            THEN 'Mantener ' + b.NombreIndice + ' (tiene INCLUDE)'
        WHEN b.ColumnasIncluidas IS NULL AND a.ColumnasIncluidas IS NOT NULL 
            THEN 'Mantener ' + a.NombreIndice + ' (tiene INCLUDE)'
        ELSE 'Evaluar cuál eliminar'
    END AS Recomendacion,
    'DROP INDEX ' + QUOTENAME(a.NombreIndice) + ' ON dbo.' + 
        QUOTENAME(a.Tabla) + ';' AS ScriptEliminacion
FROM IndexColumnas a
INNER JOIN IndexColumnas b 
    ON a.object_id = b.object_id 
    AND a.ColumnasClave = b.ColumnasClave
    AND a.index_id < b.index_id;

-- =====================================================================
-- SOLUCIÓN 7: PLAN DE MANTENIMIENTO SEMANAL
-- =====================================================================
-- Tabla de log
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LogMantenimientoIndices')
BEGIN
    CREATE TABLE dbo.LogMantenimientoIndices (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        FechaEjecucion DATETIME DEFAULT GETDATE(),
        Tabla NVARCHAR(256),
        Indice NVARCHAR(256),
        FragmentacionAntes FLOAT,
        Accion VARCHAR(20),
        Exitoso BIT,
        MensajeError NVARCHAR(MAX)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_MantenimientoSemanalBancoDB
    @Modo VARCHAR(10) = 'ANALISIS',          -- ANALISIS o EJECUCION
    @UmbralBajo FLOAT = 5.0,                  -- Mínimo para acción
    @UmbralAlto FLOAT = 30.0,                 -- Umbral para REBUILD
    @IncluirEstadisticas BIT = 1              -- Actualizar estadísticas
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Tabla NVARCHAR(256);
    DECLARE @Indice NVARCHAR(256);
    DECLARE @Frag FLOAT;
    DECLARE @Accion VARCHAR(20);
    
    -- Recopilar datos
    SELECT 
        QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + 
        QUOTENAME(OBJECT_NAME(ps.object_id)) AS Tabla,
        i.name AS Indice,
        ps.avg_fragmentation_in_percent AS Fragmentacion,
        CASE 
            WHEN ps.avg_fragmentation_in_percent < @UmbralBajo THEN 'NINGUNA'
            WHEN ps.avg_fragmentation_in_percent < @UmbralAlto THEN 'REORGANIZE'
            ELSE 'REBUILD'
        END AS Accion
    INTO #Acciones
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    INNER JOIN sys.indexes i 
        ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    WHERE ps.page_count > 50
      AND ps.index_id > 0
      AND ps.avg_fragmentation_in_percent >= @UmbralBajo;
    
    IF @Modo = 'ANALISIS'
    BEGIN
        SELECT *, 
            CASE Accion 
                WHEN 'REORGANIZE' THEN 'ALTER INDEX [' + Indice + '] ON ' + Tabla + ' REORGANIZE;'
                WHEN 'REBUILD' THEN 'ALTER INDEX [' + Indice + '] ON ' + Tabla + ' REBUILD WITH (ONLINE=ON);'
                ELSE ''
            END AS Script
        FROM #Acciones
        ORDER BY Fragmentacion DESC;
    END
    ELSE
    BEGIN
        DECLARE cur CURSOR FOR 
            SELECT Tabla, Indice, Fragmentacion, Accion 
            FROM #Acciones 
            WHERE Accion <> 'NINGUNA';
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @Tabla, @Indice, @Frag, @Accion;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@Indice) + ' ON ' + @Tabla + ' ' + @Accion;
            IF @Accion = 'REBUILD' SET @SQL = @SQL + ' WITH (ONLINE=ON)';
            
            BEGIN TRY
                EXEC sp_executesql @SQL;
                
                INSERT INTO dbo.LogMantenimientoIndices 
                    (Tabla, Indice, FragmentacionAntes, Accion, Exitoso)
                VALUES (@Tabla, @Indice, @Frag, @Accion, 1);
            END TRY
            BEGIN CATCH
                INSERT INTO dbo.LogMantenimientoIndices 
                    (Tabla, Indice, FragmentacionAntes, Accion, Exitoso, MensajeError)
                VALUES (@Tabla, @Indice, @Frag, @Accion, 0, ERROR_MESSAGE());
            END CATCH
            
            FETCH NEXT FROM cur INTO @Tabla, @Indice, @Frag, @Accion;
        END
        
        CLOSE cur;
        DEALLOCATE cur;
        
        -- Actualizar estadísticas si se solicitó
        IF @IncluirEstadisticas = 1
        BEGIN
            EXEC sp_updatestats;
        END
        
        -- Mostrar resumen
        SELECT 
            Accion,
            COUNT(*) AS Cantidad,
            SUM(CASE WHEN Exitoso = 1 THEN 1 ELSE 0 END) AS Exitosos,
            SUM(CASE WHEN Exitoso = 0 THEN 1 ELSE 0 END) AS Fallidos
        FROM dbo.LogMantenimientoIndices
        WHERE CAST(FechaEjecucion AS DATE) = CAST(GETDATE() AS DATE)
        GROUP BY Accion;
    END
    
    DROP TABLE #Acciones;
END
GO

-- Uso: EXEC dbo.sp_MantenimientoSemanalBancoDB @Modo = 'ANALISIS';

-- =====================================================================
-- SOLUCIÓN 8: CALCULAR ESPACIO DESPERDICIADO
-- =====================================================================
SELECT 
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    ps.page_count AS Paginas,
    ps.avg_page_space_used_in_percent AS PctUsoActual,
    ps.page_count * 8.0 / 1024 AS EspacioActualMB,
    ROUND(ps.page_count * (ps.avg_page_space_used_in_percent / 100.0) * 8.0 / 1024, 2) AS EspacioUsadoRealMB,
    ROUND(ps.page_count * ((100 - ps.avg_page_space_used_in_percent) / 100.0) * 8.0 / 1024, 2) AS EspacioDesperdiciadoMB,
    100 - ps.avg_page_space_used_in_percent AS PctDesperdicio
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ps
INNER JOIN sys.indexes i 
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.page_count > 10
  AND ps.index_level = 0
  AND ps.avg_page_space_used_in_percent < 90
ORDER BY EspacioDesperdiciadoMB DESC;

-- Total por base de datos
SELECT 
    SUM(ps.page_count * 8.0 / 1024) AS TotalMB,
    SUM(ps.page_count * ((100 - ps.avg_page_space_used_in_percent) / 100.0) * 8.0 / 1024) AS DesperdicioMB,
    ROUND(AVG(ps.avg_page_space_used_in_percent), 2) AS PromedioUso
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ps
WHERE ps.page_count > 10
  AND ps.index_level = 0;

-- =====================================================================
-- SOLUCIÓN 9: MONITOREO EN TIEMPO REAL
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_DashboardIndices
AS
SELECT 
    OBJECT_SCHEMA_NAME(ps.object_id) AS Esquema,
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    ps.page_count * 8 / 1024 AS TamañoMB,
    ps.avg_fragmentation_in_percent AS PctFragmentacion,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 5 THEN 'OK'
        WHEN ps.avg_fragmentation_in_percent < 30 THEN 'Advertencia'
        ELSE 'Crítico'
    END AS EstadoFragmentacion,
    ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) AS Lecturas,
    ISNULL(us.user_updates, 0) AS Escrituras,
    CASE 
        WHEN ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) = 0 
             AND ISNULL(us.user_updates, 0) > 100 THEN 'SinUso'
        WHEN ISNULL(us.user_updates, 0) > (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0)) * 3 
            THEN 'CostoAlto'
        ELSE 'Normal'
    END AS EstadoUso,
    us.last_user_seek AS UltimaLectura,
    CASE 
        WHEN ps.avg_fragmentation_in_percent > 30 THEN 3
        WHEN ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) = 0 
             AND ISNULL(us.user_updates, 0) > 100 THEN 2
        WHEN ps.avg_fragmentation_in_percent > 10 THEN 1
        ELSE 0
    END AS NivelUrgencia
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
INNER JOIN sys.indexes i 
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
WHERE ps.index_id > 0
  AND ps.page_count > 10;
GO

-- Uso
SELECT * FROM dbo.vw_DashboardIndices ORDER BY NivelUrgencia DESC, PctFragmentacion DESC;

-- =====================================================================
-- LIMPIEZA DE OBJETOS DE PRUEBA
-- =====================================================================
-- DROP PROCEDURE IF EXISTS dbo.sp_MantenimientoSemanalBancoDB;
-- DROP VIEW IF EXISTS dbo.vw_DashboardIndices;
-- DROP TABLE IF EXISTS dbo.LogMantenimientoIndices;
