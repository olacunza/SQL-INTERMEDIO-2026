/*
=====================================================================
  SESIÓN 09: OPTIMIZACIÓN DE ÍNDICES
  SQL Server Intermedio 2026
  
  Temas:
    1. Anatomía de un índice B-Tree
    2. ¿Qué es la fragmentación?
    3. Tipos de fragmentación (interna vs externa)
    4. Midiendo fragmentación: sys.dm_db_index_physical_stats
    5. REBUILD vs REORGANIZE
    6. Fill Factor y PAD_INDEX
    7. Índices unused y duplicados
    8. Estadísticas de uso de índices
    9. Missing Indexes: DMVs y análisis
   10. Mantenimiento automatizado
   11. Caso práctico: Plan de mantenimiento para BancoDB
   
  Base de datos: BancoDB
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- PARTE 1: ANATOMÍA DE UN ÍNDICE B-TREE
-- =====================================================================
/*
   ESTRUCTURA B-TREE EN SQL SERVER:
   
   ┌─────────────────────────────────────────────────────────────────┐
   │                         ROOT PAGE                               │
   │                    (Página Raíz - Nivel 2)                      │
   │              [1-1000] [1001-2000] [2001-3000]                   │
   └───────────┬──────────────┬──────────────┬───────────────────────┘
               │              │              │
   ┌───────────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
   │ INTERMEDIATE     │ │INTERMEDIATE│ │INTERMEDIATE│  Nivel 1
   │ [1-500][501-1000]│ │  [...]     │ │   [...]    │
   └──────┬───────────┘ └────────────┘ └────────────┘
          │
   ┌──────▼──────┐ ┌────────────┐
   │  LEAF PAGE  │ │ LEAF PAGE  │  Nivel 0 (Hojas)
   │ Datos reales│ │Datos reales│
   └─────────────┘ └────────────┘

   CONCEPTOS CLAVE:
   - Root Page: Punto de entrada (siempre 1 página)
   - Intermediate: Páginas de navegación
   - Leaf Pages: Datos reales (clustered) o punteros (non-clustered)
   - Page Size: 8KB fijo
   - Extent: 8 páginas contiguas (64KB)
*/

-- Ver estructura de índices de una tabla
SELECT 
    i.name AS NombreIndice,
    i.type_desc AS TipoIndice,
    i.is_unique AS EsUnico,
    i.fill_factor AS FillFactor,
    ps.index_depth AS Profundidad,
    ps.page_count AS TotalPaginas,
    ps.record_count AS TotalRegistros,
    ps.avg_page_space_used_in_percent AS PorcentajeUsoPromedio
FROM sys.indexes i
INNER JOIN sys.dm_db_index_physical_stats(
    DB_ID(), OBJECT_ID('TRANSACCIONES_BANCARIAS'), NULL, NULL, 'DETAILED'
) ps ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_BANCARIAS')
  AND ps.index_level = 0  -- Solo hojas
ORDER BY i.index_id;

-- =====================================================================
-- PARTE 2: ¿QUÉ ES LA FRAGMENTACIÓN?
-- =====================================================================
/*
   FRAGMENTACIÓN: Desorden en las páginas del índice que causa:
   - Lecturas adicionales de disco
   - Uso ineficiente del buffer pool
   - Degradación gradual del rendimiento
   
   CAUSAS PRINCIPALES:
   1. INSERTs aleatorios (no secuenciales)
   2. UPDATEs que cambian tamaño del registro
   3. DELETEs que dejan huecos
   4. Page Splits (página llena → dividir en dos)
   
   PAGE SPLIT:
   Cuando una página está llena y llega un nuevo registro:
   
   ANTES:                    DESPUÉS:
   ┌──────────┐             ┌──────────┐ ┌──────────┐
   │[1][2][3] │  INSERT 2.5 │[1][2]    │ │[2.5][3]  │
   │[LLENA]   │  ───────►   │[50%]     │ │[50%]     │
   └──────────┘             └──────────┘ └──────────┘
   
   RESULTADO: 2 páginas medio vacías + posible desorden físico
*/

-- =====================================================================
-- PARTE 3: TIPOS DE FRAGMENTACIÓN
-- =====================================================================
/*
   FRAGMENTACIÓN EXTERNA (Lógica):
   - Páginas fuera de orden lógico en disco
   - avg_fragmentation_in_percent > 0
   - Afecta lecturas secuenciales (scans)
   - Solución: REBUILD o REORGANIZE
   
   FRAGMENTACIÓN INTERNA:
   - Espacio desperdiciado dentro de páginas
   - avg_page_space_used_in_percent < 100
   - Más páginas de las necesarias
   - Solución: REBUILD con Fill Factor apropiado
*/

-- Demostración: Causar fragmentación
-- Crear tabla de prueba
CREATE TABLE #FragmentDemo (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Datos CHAR(500),  -- 500 bytes fijos
    FechaCreacion DATETIME DEFAULT GETDATE()
);

-- Insertar 5000 registros
INSERT INTO #FragmentDemo (Datos)
SELECT TOP 5000 REPLICATE('X', 500)
FROM sys.objects a, sys.objects b;

-- Ver estado inicial
SELECT 
    'Inicial' AS Estado,
    index_type_desc,
    avg_fragmentation_in_percent AS FragExternal,
    avg_page_space_used_in_percent AS UsoInterno,
    page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    DB_ID('tempdb'), OBJECT_ID('tempdb..#FragmentDemo'), NULL, NULL, 'DETAILED'
)
WHERE index_level = 0;

-- Causar fragmentación con DELETEs aleatorios
DELETE FROM #FragmentDemo WHERE ID % 3 = 0;

-- Ver fragmentación resultante
SELECT 
    'Después DELETEs' AS Estado,
    index_type_desc,
    avg_fragmentation_in_percent AS FragExternal,
    avg_page_space_used_in_percent AS UsoInterno,
    page_count AS Paginas
FROM sys.dm_db_index_physical_stats(
    DB_ID('tempdb'), OBJECT_ID('tempdb..#FragmentDemo'), NULL, NULL, 'DETAILED'
)
WHERE index_level = 0;

DROP TABLE #FragmentDemo;

-- =====================================================================
-- PARTE 4: MIDIENDO FRAGMENTACIÓN
-- =====================================================================
/*
   sys.dm_db_index_physical_stats():
   
   Modos de análisis:
   - LIMITED: Rápido, escanea solo páginas no-hoja
   - SAMPLED: Muestreo 1% de páginas
   - DETAILED: Completo, todas las páginas (lento)
   
   Columnas importantes:
   - avg_fragmentation_in_percent: Fragmentación lógica
   - avg_page_space_used_in_percent: Uso de espacio
   - page_count: Total páginas
   - record_count: Total registros
   - fragment_count: Número de fragmentos
*/

-- Query para analizar fragmentación de toda la base de datos
SELECT 
    OBJECT_SCHEMA_NAME(ps.object_id) AS Esquema,
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    ps.index_type_desc AS TipoFisico,
    ps.avg_fragmentation_in_percent AS PctFragmentacion,
    ps.avg_page_space_used_in_percent AS PctUsoEspacio,
    ps.page_count AS Paginas,
    ps.record_count AS Registros,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 5 THEN 'OK - No acción'
        WHEN ps.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END AS AccionRecomendada
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED'
) ps
INNER JOIN sys.indexes i 
    ON ps.object_id = i.object_id 
    AND ps.index_id = i.index_id
WHERE ps.page_count > 100  -- Solo índices con >100 páginas
  AND ps.index_id > 0      -- Excluir heaps
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- =====================================================================
-- PARTE 5: REBUILD VS REORGANIZE
-- =====================================================================
/*
   ┌─────────────────────┬──────────────────────┬──────────────────────┐
   │ CARACTERÍSTICA      │ REORGANIZE           │ REBUILD              │
   ├─────────────────────┼──────────────────────┼──────────────────────┤
   │ Qué hace            │ Ordena páginas hoja  │ Reconstruye completo │
   │ Bloqueo             │ Mínimo (online)      │ Puede ser exclusivo  │
   │ Transaccional       │ Sí (interrumpible)   │ No (todo o nada)     │
   │ Actualiza stats     │ NO                   │ SÍ                   │
   │ Compacta            │ Parcial              │ Completo             │
   │ Fill Factor         │ No puede cambiar     │ Puede especificar    │
   │ Uso de tempdb       │ Mínimo               │ Puede ser alto       │
   │ Cuándo usar         │ Frag 5-30%           │ Frag >30%            │
   └─────────────────────┴──────────────────────┴──────────────────────┘
*/

-- REORGANIZE: Para fragmentación moderada (5-30%)
ALTER INDEX IX_MiIndice ON MiTabla REORGANIZE;

-- REORGANIZE todos los índices de una tabla
ALTER INDEX ALL ON TRANSACCIONES_BANCARIAS REORGANIZE;

-- REBUILD: Para fragmentación severa (>30%)
ALTER INDEX IX_MiIndice ON MiTabla REBUILD;

-- REBUILD con opciones
ALTER INDEX IX_MiIndice ON MiTabla REBUILD 
WITH (
    FILLFACTOR = 80,           -- 80% lleno
    ONLINE = ON,               -- No bloquear tabla (Enterprise)
    SORT_IN_TEMPDB = ON,       -- Usar tempdb para ordenar
    DATA_COMPRESSION = PAGE    -- Comprimir páginas
);

-- REBUILD todos los índices de una tabla
ALTER INDEX ALL ON TRANSACCIONES_BANCARIAS REBUILD 
WITH (FILLFACTOR = 90, ONLINE = ON);

-- =====================================================================
-- PARTE 6: FILL FACTOR Y PAD_INDEX
-- =====================================================================
/*
   FILL FACTOR:
   - Porcentaje de espacio a usar en páginas HOJA al crear/rebuild
   - 100 (o 0): Páginas llenas (máxima densidad)
   - 70-90: Más común, deja espacio para inserts futuros
   
   Fórmula mental:
   Fill Factor bajo = Más espacio libre = Menos page splits = Más páginas
   Fill Factor alto = Menos espacio libre = Más page splits = Menos páginas
   
   PAD_INDEX:
   - Aplica el Fill Factor también a páginas INTERMEDIAS
   - Útil en índices muy profundos o con muchas actualizaciones
   
   RECOMENDACIONES:
   ┌───────────────────────────┬──────────────────────────────────────┐
   │ ESCENARIO                 │ FILL FACTOR RECOMENDADO              │
   ├───────────────────────────┼──────────────────────────────────────┤
   │ Tabla solo lectura        │ 100 (máxima densidad)                │
   │ Inserts secuenciales      │ 95-100 (poca fragmentación natural)  │
   │ Inserts aleatorios        │ 70-80 (espacio para nuevos)          │
   │ Muchos updates de tamaño  │ 60-70 (espacio para crecimiento)     │
   │ Mix OLTP normal           │ 80-90 (buen balance)                 │
   └───────────────────────────┴──────────────────────────────────────┘
*/

-- Ver Fill Factor actual de índices
SELECT 
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    i.fill_factor AS FillFactor,  -- 0 = 100%
    CASE i.fill_factor
        WHEN 0 THEN 'Máxima densidad (100%)'
        WHEN 100 THEN 'Máxima densidad (100%)'
        ELSE CONCAT(i.fill_factor, '% - Deja ', 100 - i.fill_factor, '% libre')
    END AS Interpretacion
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_BANCARIAS')
  AND i.index_id > 0
ORDER BY i.index_id;

-- Crear índice con Fill Factor específico
CREATE NONCLUSTERED INDEX IX_TX_Demo_FF70
ON TRANSACCIONES_BANCARIAS(FechaTransaccion)
WITH (FILLFACTOR = 70, PAD_INDEX = ON);

-- Modificar Fill Factor con REBUILD
ALTER INDEX IX_TX_Demo_FF70 ON TRANSACCIONES_BANCARIAS REBUILD
WITH (FILLFACTOR = 85);

-- Limpieza
DROP INDEX IF EXISTS IX_TX_Demo_FF70 ON TRANSACCIONES_BANCARIAS;

-- =====================================================================
-- PARTE 7: ÍNDICES UNUSED Y DUPLICADOS
-- =====================================================================
/*
   ÍNDICES NO USADOS:
   - Ocupan espacio en disco
   - Consumen I/O en INSERTs/UPDATEs/DELETEs
   - Aumentan tiempo de backup/restore
   
   ÍNDICES DUPLICADOS:
   - Mismo conjunto de columnas clave
   - Desperdicio total de recursos
*/

-- Índices nunca usados (seeks, scans, lookups = 0)
SELECT 
    OBJECT_SCHEMA_NAME(i.object_id) AS Esquema,
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    us.user_seeks + us.user_scans + us.user_lookups AS TotalLecturas,
    us.user_updates AS TotalEscrituras,
    ps.page_count * 8 / 1024 AS TamañoMB,
    'Candidato a eliminar' AS Recomendacion
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
INNER JOIN sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.type_desc = 'NONCLUSTERED'
  AND (us.user_seeks IS NULL OR (us.user_seeks = 0 AND us.user_scans = 0 AND us.user_lookups = 0))
  AND ps.page_count > 100
ORDER BY ps.page_count DESC;

-- Detectar índices duplicados (mismas columnas clave)
;WITH IndexColumns AS (
    SELECT 
        OBJECT_SCHEMA_NAME(i.object_id) AS Esquema,
        OBJECT_NAME(i.object_id) AS Tabla,
        i.name AS Indice,
        i.index_id,
        i.object_id,
        STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS ColumnasOrdenadas
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.type_desc = 'NONCLUSTERED'
      AND ic.is_included_column = 0  -- Solo columnas clave
    GROUP BY i.object_id, i.name, i.index_id, OBJECT_SCHEMA_NAME(i.object_id), OBJECT_NAME(i.object_id)
)
SELECT 
    ic1.Esquema,
    ic1.Tabla,
    ic1.Indice AS Indice1,
    ic2.Indice AS Indice2,
    ic1.ColumnasOrdenadas,
    'Posibles duplicados - verificar INCLUDE' AS Nota
FROM IndexColumns ic1
INNER JOIN IndexColumns ic2 
    ON ic1.object_id = ic2.object_id 
    AND ic1.ColumnasOrdenadas = ic2.ColumnasOrdenadas
    AND ic1.index_id < ic2.index_id
ORDER BY ic1.Tabla, ic1.Indice;

-- =====================================================================
-- PARTE 8: ESTADÍSTICAS DE USO DE ÍNDICES
-- =====================================================================
/*
   sys.dm_db_index_usage_stats:
   Acumula uso desde último reinicio del servicio
   
   - user_seeks: Búsquedas usando el índice
   - user_scans: Escaneos del índice
   - user_lookups: Key Lookups (solo clustered)
   - user_updates: Modificaciones (INSERT/UPDATE/DELETE)
   
   ÍNDICE SALUDABLE:
   - Seeks + Scans + Lookups >> Updates
   
   ÍNDICE PROBLEMÁTICO:
   - Updates >> Seeks + Scans + Lookups
*/

-- Análisis de uso de índices
SELECT 
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    us.user_seeks AS Seeks,
    us.user_scans AS Scans,
    us.user_lookups AS Lookups,
    us.user_seeks + us.user_scans + us.user_lookups AS TotalLecturas,
    us.user_updates AS Escrituras,
    CASE 
        WHEN us.user_updates = 0 THEN 'N/A'
        ELSE CAST(
            CAST(us.user_seeks + us.user_scans + us.user_lookups AS FLOAT) / 
            NULLIF(us.user_updates, 0) AS VARCHAR(10)
        )
    END AS RatioLecturaEscritura,
    us.last_user_seek AS UltimoSeek,
    us.last_user_scan AS UltimoScan,
    us.last_user_update AS UltimaEscritura
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('TRANSACCIONES_BANCARIAS')
ORDER BY TotalLecturas DESC;

-- Índices más escritos vs leídos (candidatos a eliminar)
SELECT TOP 20
    OBJECT_NAME(i.object_id) AS Tabla,
    i.name AS Indice,
    us.user_updates AS Escrituras,
    us.user_seeks + us.user_scans + us.user_lookups AS Lecturas,
    CASE 
        WHEN us.user_seeks + us.user_scans + us.user_lookups = 0 THEN 'Solo escrituras!'
        ELSE CONCAT('1:', CAST(us.user_updates / NULLIF(us.user_seeks + us.user_scans + us.user_lookups, 0) AS VARCHAR))
    END AS RatioEscrituraLectura
FROM sys.indexes i
INNER JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED'
  AND us.user_updates > us.user_seeks + us.user_scans + us.user_lookups
ORDER BY us.user_updates DESC;

-- =====================================================================
-- PARTE 9: MISSING INDEXES - DMVs
-- =====================================================================
/*
   SQL Server sugiere índices automáticamente cuando detecta
   que podrían mejorar las consultas ejecutadas.
   
   DMVs para Missing Indexes:
   - sys.dm_db_missing_index_details: Detalle (columnas)
   - sys.dm_db_missing_index_groups: Agrupación
   - sys.dm_db_missing_index_group_stats: Estadísticas de impacto
   
   CUIDADO:
   - Son SUGERENCIAS, no mandatos
   - No consideran el impacto en escrituras
   - Pueden sugerir índices redundantes
   - Se resetean al reiniciar SQL Server
*/

-- Ver índices sugeridos con impacto estimado
SELECT 
    OBJECT_NAME(mid.object_id) AS Tabla,
    mid.equality_columns AS ColumnaIgualdad,
    mid.inequality_columns AS ColumnaDesigualdad,
    mid.included_columns AS ColumnasIncluir,
    migs.unique_compiles AS Compilaciones,
    migs.user_seeks AS SeeksEsperados,
    migs.user_scans AS ScansEsperados,
    migs.avg_total_user_cost AS CostoPromedio,
    migs.avg_user_impact AS ImpactoPromedio,
    -- Fórmula de prioridad
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 2) AS Prioridad,
    -- Script para crear el índice
    'CREATE NONCLUSTERED INDEX IX_' + 
    OBJECT_NAME(mid.object_id) + '_' + 
    REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '[', '') +
    ' ON ' + mid.statement + 
    ' (' + ISNULL(mid.equality_columns, '') + 
    CASE WHEN mid.inequality_columns IS NOT NULL 
         THEN ', ' + mid.inequality_columns ELSE '' END + ')' +
    CASE WHEN mid.included_columns IS NOT NULL 
         THEN ' INCLUDE (' + mid.included_columns + ')' ELSE '' END AS ScriptCreacion
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig 
    ON mid.index_handle = mig.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs 
    ON mig.index_group_handle = migs.group_handle
WHERE mid.database_id = DB_ID()
ORDER BY Prioridad DESC;

-- =====================================================================
-- PARTE 10: MANTENIMIENTO AUTOMATIZADO
-- =====================================================================
/*
   ESTRATEGIA DE MANTENIMIENTO:
   
   1. DIARIO (fuera de horario pico):
      - Actualizar estadísticas de tablas críticas
      - Reorganize índices con 5-10% fragmentación
   
   2. SEMANAL:
      - Analizar fragmentación completa
      - Rebuild índices con >30% fragmentación
      - Reorganize índices con 10-30%
   
   3. MENSUAL:
      - Revisar índices no usados
      - Evaluar missing indexes
      - Ajustar Fill Factor según patrones
*/

-- SP para mantenimiento inteligente de índices
CREATE OR ALTER PROCEDURE dbo.sp_MantenimientoIndices
    @ModoEjecucion VARCHAR(10) = 'REPORT',  -- REPORT, EXECUTE
    @UmbralReorganize FLOAT = 5.0,
    @UmbralRebuild FLOAT = 30.0,
    @MinPaginas INT = 100,
    @Online BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Tabla NVARCHAR(256);
    DECLARE @Indice NVARCHAR(256);
    DECLARE @Fragmentacion FLOAT;
    DECLARE @Accion VARCHAR(20);
    
    -- Tabla para resultados
    CREATE TABLE #ResultadoMantenimiento (
        Tabla NVARCHAR(256),
        Indice NVARCHAR(256),
        Fragmentacion FLOAT,
        Paginas INT,
        Accion VARCHAR(20),
        Script NVARCHAR(MAX),
        Ejecutado BIT DEFAULT 0,
        FechaEjecucion DATETIME
    );
    
    -- Analizar fragmentación
    INSERT INTO #ResultadoMantenimiento (Tabla, Indice, Fragmentacion, Paginas, Accion, Script)
    SELECT 
        QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + QUOTENAME(OBJECT_NAME(ps.object_id)),
        i.name,
        ps.avg_fragmentation_in_percent,
        ps.page_count,
        CASE 
            WHEN ps.avg_fragmentation_in_percent < @UmbralReorganize THEN 'NINGUNA'
            WHEN ps.avg_fragmentation_in_percent < @UmbralRebuild THEN 'REORGANIZE'
            ELSE 'REBUILD'
        END,
        CASE 
            WHEN ps.avg_fragmentation_in_percent < @UmbralReorganize THEN NULL
            WHEN ps.avg_fragmentation_in_percent < @UmbralRebuild THEN
                'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + 
                QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + 
                QUOTENAME(OBJECT_NAME(ps.object_id)) + ' REORGANIZE;'
            ELSE
                'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + 
                QUOTENAME(OBJECT_SCHEMA_NAME(ps.object_id)) + '.' + 
                QUOTENAME(OBJECT_NAME(ps.object_id)) + 
                ' REBUILD WITH (ONLINE = ' + CASE WHEN @Online = 1 THEN 'ON' ELSE 'OFF' END + ');'
        END
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
    INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
    WHERE ps.page_count >= @MinPaginas
      AND ps.index_id > 0
      AND ps.avg_fragmentation_in_percent >= @UmbralReorganize
    ORDER BY ps.avg_fragmentation_in_percent DESC;
    
    -- Si es modo EXECUTE, ejecutar scripts
    IF @ModoEjecucion = 'EXECUTE'
    BEGIN
        DECLARE cur CURSOR FOR 
            SELECT Script FROM #ResultadoMantenimiento WHERE Script IS NOT NULL;
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @SQL;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                EXEC sp_executesql @SQL;
                
                UPDATE #ResultadoMantenimiento 
                SET Ejecutado = 1, FechaEjecucion = GETDATE()
                WHERE Script = @SQL;
            END TRY
            BEGIN CATCH
                PRINT 'Error en: ' + @SQL;
                PRINT ERROR_MESSAGE();
            END CATCH
            
            FETCH NEXT FROM cur INTO @SQL;
        END
        
        CLOSE cur;
        DEALLOCATE cur;
    END
    
    -- Retornar resultados
    SELECT 
        Tabla,
        Indice,
        ROUND(Fragmentacion, 2) AS PctFragmentacion,
        Paginas,
        Accion,
        Script,
        Ejecutado,
        FechaEjecucion
    FROM #ResultadoMantenimiento
    ORDER BY Fragmentacion DESC;
    
    DROP TABLE #ResultadoMantenimiento;
END;
GO

-- Uso del SP
-- Solo reporte
EXEC dbo.sp_MantenimientoIndices @ModoEjecucion = 'REPORT';

-- Ejecutar mantenimiento
-- EXEC dbo.sp_MantenimientoIndices @ModoEjecucion = 'EXECUTE', @Online = 1;

-- =====================================================================
-- PARTE 11: CASO PRÁCTICO - PLAN DE MANTENIMIENTO BANCODB
-- =====================================================================
/*
   ESCENARIO BANCODB:
   
   Características:
   - TRANSACCIONES_BANCARIAS: Alta actividad INSERT, consultas por rango de fechas
   - CUENTAS: Moderada actividad UPDATE (saldos), consultas frecuentes
   - CLIENTES: Baja actividad de escritura, muchas lecturas
   
   PLAN DE MANTENIMIENTO:
*/

-- 1. Establecer Fill Factor según patrón de uso
-- TRANSACCIONES: Inserts al final (secuencial) → Fill Factor alto
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'PK_TRANSACCIONES' AND object_id = OBJECT_ID('TRANSACCIONES_BANCARIAS'))
    ALTER INDEX PK_TRANSACCIONES ON TRANSACCIONES_BANCARIAS REBUILD WITH (FILLFACTOR = 95);

-- CUENTAS: Updates frecuentes de saldo → Fill Factor moderado
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'PK_CUENTAS' AND object_id = OBJECT_ID('CUENTAS'))
    ALTER INDEX PK_CUENTAS ON CUENTAS REBUILD WITH (FILLFACTOR = 85);

-- CLIENTES: Rara vez cambia → Fill Factor máximo
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'PK_CLIENTES' AND object_id = OBJECT_ID('CLIENTES'))
    ALTER INDEX PK_CLIENTES ON CLIENTES REBUILD WITH (FILLFACTOR = 100);

-- 2. Crear job SQL Agent para mantenimiento semanal
/*
-- Crear en SQL Agent:

Step 1: Mantenimiento de Índices
EXEC dbo.sp_MantenimientoIndices 
    @ModoEjecucion = 'EXECUTE',
    @UmbralReorganize = 5.0,
    @UmbralRebuild = 30.0,
    @Online = 1;

Step 2: Actualizar Estadísticas
EXEC sp_updatestats;

Schedule: Domingos 2:00 AM
*/

-- 3. Query para dashboard de salud de índices
CREATE OR ALTER VIEW dbo.vw_SaludIndices
AS
SELECT 
    OBJECT_SCHEMA_NAME(ps.object_id) AS Esquema,
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    ps.avg_fragmentation_in_percent AS PctFragmentacion,
    ps.page_count AS Paginas,
    ps.page_count * 8 / 1024 AS TamañoMB,
    ISNULL(us.user_seeks, 0) AS Seeks,
    ISNULL(us.user_scans, 0) AS Scans,
    ISNULL(us.user_updates, 0) AS Updates,
    CASE 
        WHEN ps.avg_fragmentation_in_percent < 5 THEN '🟢 OK'
        WHEN ps.avg_fragmentation_in_percent < 30 THEN '🟡 Reorganize'
        ELSE '🔴 Rebuild'
    END AS EstadoFragmentacion,
    CASE 
        WHEN ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) = 0 
             AND ISNULL(us.user_updates, 0) > 1000 THEN '🔴 Sin lecturas'
        WHEN ISNULL(us.user_updates, 0) > (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0)) * 10 
             THEN '🟡 Más escrituras que lecturas'
        ELSE '🟢 Balanceado'
    END AS EstadoUso
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats us 
    ON i.object_id = us.object_id 
    AND i.index_id = us.index_id 
    AND us.database_id = DB_ID()
WHERE ps.index_id > 0
  AND ps.page_count > 10;
GO

-- Usar la vista
SELECT * FROM dbo.vw_SaludIndices ORDER BY PctFragmentacion DESC;

-- =====================================================================
-- RESUMEN DE LA SESIÓN
-- =====================================================================
/*
   CONCEPTOS CLAVE:
   
   1. FRAGMENTACIÓN:
      - Externa: Páginas desordenadas → REBUILD/REORGANIZE
      - Interna: Espacio desperdiciado → Ajustar Fill Factor
   
   2. ACCIONES:
      - <5% fragmentación: No hacer nada
      - 5-30%: REORGANIZE (online, incremental)
      - >30%: REBUILD (más completo)
   
   3. FILL FACTOR:
      - 100: Solo lectura
      - 90-95: Inserts secuenciales
      - 70-85: Inserts aleatorios / muchos updates
   
   4. ÍNDICES PROBLEMÁTICOS:
      - Sin uso (seeks=0, scans=0): Candidatos a eliminar
      - Más updates que reads: Evaluar necesidad
      - Duplicados: Eliminar redundantes
   
   5. MISSING INDEXES:
      - Son sugerencias, no mandatos
      - Evaluar antes de crear
      - No consideran impacto en escrituras
   
   PRÓXIMA SESIÓN:
   - Procesamiento por Lotes (Batching, Chunking, TRY_CONVERT)
*/
