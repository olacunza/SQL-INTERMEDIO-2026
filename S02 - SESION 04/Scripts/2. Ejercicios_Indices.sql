-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 4
-- EJERCICIOS PRÁCTICOS: ÍNDICES ESTRATÉGICOS
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: DISEÑAR ÍNDICES PARA CONSULTAS ESPECÍFICAS
-- ============================================================

/*
Dadas las siguientes consultas frecuentes, diseña los índices óptimos.
Considera: Key columns vs Include columns, orden de columnas, filtros.
*/

-- CONSULTA A: Reporte de transacciones por estado y fecha
/*
SELECT Estado, FechaTransaccion, CuentaOrigenID, Monto
FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'COMPLETADA'
  AND FechaTransaccion >= '2025-01-01'
  AND FechaTransaccion < '2025-04-01'
ORDER BY FechaTransaccion DESC;
*/

-- ✅ SOLUCIÓN A:
-- Estado = igualdad, FechaTransaccion = rango + ORDER BY
-- CuentaOrigenID y Monto solo se leen → INCLUDE
CREATE NONCLUSTERED INDEX IX_Ej1A_ReporteEstado
ON TRANSACCIONES_VOLUMEN(Estado, FechaTransaccion DESC)
INCLUDE (CuentaOrigenID, Monto);

GO

-- CONSULTA B: Búsqueda por cuenta con detalles
/*
SELECT TransaccionID, FechaTransaccion, Monto, TipoTransaccion, Estado
FROM TRANSACCIONES_VOLUMEN
WHERE CuentaOrigenID = @CuentaID
ORDER BY FechaTransaccion DESC;
*/

-- ✅ SOLUCIÓN B:
CREATE NONCLUSTERED INDEX IX_Ej1B_BusquedaCuenta
ON TRANSACCIONES_VOLUMEN(CuentaOrigenID, FechaTransaccion DESC)
INCLUDE (Monto, TipoTransaccion, Estado);
-- TransaccionID está en clustered key, no necesita INCLUDE

GO

-- CONSULTA C: Transacciones grandes de transferencia
/*
SELECT TOP 100 *
FROM TRANSACCIONES_VOLUMEN
WHERE TipoTransaccion = 'TRANSFERENCIA'
  AND Monto > 10000
ORDER BY Monto DESC;
*/

-- ✅ SOLUCIÓN C:
-- Índice filtrado porque solo nos interesan transferencias grandes
CREATE NONCLUSTERED INDEX IX_Ej1C_TransferenciasGrandes
ON TRANSACCIONES_VOLUMEN(Monto DESC)
INCLUDE (CuentaOrigenID, CuentaDestinoID, FechaTransaccion, Estado, CodigoReferencia, Descripcion)
WHERE TipoTransaccion = 'TRANSFERENCIA' AND Monto > 10000;

GO

-- Verificar que los índices se crearon
SELECT 
    i.name AS Indice,
    i.type_desc AS Tipo,
    i.has_filter AS Filtrado,
    i.filter_definition AS Filtro
FROM sys.indexes i
WHERE object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN')
  AND i.name LIKE 'IX_Ej1%'
ORDER BY i.name;

GO

-- ============================================================
-- EJERCICIO 2: ELIMINAR KEY LOOKUP
-- ============================================================

-- Crear índice deliberadamente incompleto
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ej2_Incompleto')
    DROP INDEX IX_Ej2_Incompleto ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Ej2_Incompleto
ON TRANSACCIONES_VOLUMEN(Estado);

GO

SET STATISTICS IO ON;

-- Esta consulta genera KEY LOOKUP
PRINT '--- Consulta con KEY LOOKUP ---';
SELECT Estado, FechaTransaccion, Monto, Descripcion
FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'PENDIENTE';

-- Ver logical reads (alto por los lookups)

SET STATISTICS IO OFF;

GO

-- ✅ SOLUCIÓN: Modificar índice para cubrir todas las columnas
-- Opción 1: DROP y CREATE con INCLUDE
DROP INDEX IX_Ej2_Incompleto ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Ej2_Completo
ON TRANSACCIONES_VOLUMEN(Estado)
INCLUDE (FechaTransaccion, Monto, Descripcion);

GO

SET STATISTICS IO ON;

PRINT '--- Misma consulta SIN KEY LOOKUP ---';
SELECT Estado, FechaTransaccion, Monto, Descripcion
FROM TRANSACCIONES_VOLUMEN
WHERE Estado = 'PENDIENTE';

-- Ver logical reads (mucho menor)

SET STATISTICS IO OFF;

GO

-- ============================================================
-- EJERCICIO 3: ÍNDICE COMPUESTO - ORDEN CORRECTO
-- ============================================================

-- Escenario: Sistema de alertas que busca transacciones por múltiples criterios

-- Crear tabla de ejercicio
IF OBJECT_ID('ALERTAS_TRANSACCION') IS NOT NULL DROP TABLE ALERTAS_TRANSACCION;

CREATE TABLE ALERTAS_TRANSACCION (
    AlertaID INT IDENTITY PRIMARY KEY,
    TransaccionID INT,
    TipoAlerta VARCHAR(20),     -- 'FRAUDE', 'MONTO_ALTO', 'DUPLICADA'
    Severidad TINYINT,          -- 1=Baja, 2=Media, 3=Alta
    FechaAlerta DATETIME,
    Estado VARCHAR(15),         -- 'NUEVA', 'EN_REVISION', 'RESUELTA', 'DESCARTADA'
    AsignadoA VARCHAR(50),
    Descripcion NVARCHAR(500)
);

-- Insertar datos de prueba
INSERT INTO ALERTAS_TRANSACCION (TransaccionID, TipoAlerta, Severidad, FechaAlerta, Estado, AsignadoA, Descripcion)
SELECT 
    ABS(CHECKSUM(NEWID())) % 100000 + 1,
    CASE ABS(CHECKSUM(NEWID())) % 3
        WHEN 0 THEN 'FRAUDE'
        WHEN 1 THEN 'MONTO_ALTO'
        ELSE 'DUPLICADA'
    END,
    (ABS(CHECKSUM(NEWID())) % 3) + 1,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN 'NUEVA'
        WHEN 1 THEN 'EN_REVISION'
        WHEN 2 THEN 'RESUELTA'
        ELSE 'DESCARTADA'
    END,
    'Analista_' + CAST((ABS(CHECKSUM(NEWID())) % 10) + 1 AS VARCHAR),
    'Descripción de alerta de prueba'
FROM TRANSACCIONES_VOLUMEN
WHERE TransaccionID <= 50000;

GO

-- CONSULTAS TÍPICAS:
-- 1. Ver alertas nuevas de alta severidad
-- 2. Ver alertas asignadas a un analista por tipo
-- 3. Ver alertas de fraude en un rango de fechas

-- Pregunta: ¿Qué índices crearías?

-- ✅ SOLUCIÓN:

-- Índice 1: Para dashboard de alertas prioritarias
CREATE NONCLUSTERED INDEX IX_Alertas_EstadoSeveridad
ON ALERTAS_TRANSACCION(Estado, Severidad DESC, FechaAlerta DESC)
INCLUDE (TipoAlerta, TransaccionID);

-- Índice 2: Para vista de analista
CREATE NONCLUSTERED INDEX IX_Alertas_Analista
ON ALERTAS_TRANSACCION(AsignadoA, TipoAlerta, Estado)
INCLUDE (FechaAlerta, Severidad, TransaccionID);

-- Índice 3: Para investigación de fraude (filtrado)
CREATE NONCLUSTERED INDEX IX_Alertas_Fraude
ON ALERTAS_TRANSACCION(FechaAlerta)
INCLUDE (TransaccionID, Severidad, Estado, AsignadoA)
WHERE TipoAlerta = 'FRAUDE';

GO

-- Probar las consultas
SET STATISTICS IO ON;

PRINT '--- Dashboard: Alertas nuevas de alta severidad ---';
SELECT TOP 20 TipoAlerta, FechaAlerta, TransaccionID
FROM ALERTAS_TRANSACCION
WHERE Estado = 'NUEVA' AND Severidad = 3
ORDER BY FechaAlerta DESC;

PRINT '--- Vista analista: Alertas de Analista_5 ---';
SELECT TipoAlerta, Estado, COUNT(*) AS Cantidad
FROM ALERTAS_TRANSACCION
WHERE AsignadoA = 'Analista_5'
GROUP BY TipoAlerta, Estado;

PRINT '--- Investigación: Fraudes de último mes ---';
SELECT FechaAlerta, TransaccionID, Severidad, Estado
FROM ALERTAS_TRANSACCION
WHERE TipoAlerta = 'FRAUDE'
  AND FechaAlerta >= DATEADD(MONTH, -1, GETDATE())
ORDER BY FechaAlerta DESC;

SET STATISTICS IO OFF;

GO

-- ============================================================
-- EJERCICIO 4: ANÁLISIS DE ÍNDICES DUPLICADOS
-- ============================================================

-- Crear índices que se solapan (mala práctica)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dup1' AND object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN'))
    DROP INDEX IX_Dup1 ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dup2' AND object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN'))
    DROP INDEX IX_Dup2 ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dup3' AND object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN'))
    DROP INDEX IX_Dup3 ON TRANSACCIONES_VOLUMEN;

CREATE NONCLUSTERED INDEX IX_Dup1 ON TRANSACCIONES_VOLUMEN(CuentaOrigenID);
CREATE NONCLUSTERED INDEX IX_Dup2 ON TRANSACCIONES_VOLUMEN(CuentaOrigenID, Estado);
CREATE NONCLUSTERED INDEX IX_Dup3 ON TRANSACCIONES_VOLUMEN(CuentaOrigenID, Estado, TipoTransaccion);

GO

-- Pregunta: ¿Cuáles de estos índices son redundantes?

-- ✅ SOLUCIÓN:
-- IX_Dup1 (CuentaOrigenID) es REDUNDANTE porque IX_Dup2 y IX_Dup3 lo cubren
-- IX_Dup2 podría ser redundante si IX_Dup3 cubre todos sus casos

-- Query para encontrar índices potencialmente duplicados
WITH IndicesConColumnas AS (
    SELECT 
        i.object_id,
        i.index_id,
        i.name AS NombreIndice,
        (
            SELECT STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal)
            FROM sys.index_columns ic
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ) AS ColumnasKey
    FROM sys.indexes i
    WHERE i.object_id = OBJECT_ID('TRANSACCIONES_VOLUMEN')
      AND i.type > 0
)
SELECT 
    A.NombreIndice AS IndiceA,
    A.ColumnasKey AS ColumnasA,
    B.NombreIndice AS IndiceB,
    B.ColumnasKey AS ColumnasB,
    'Revisar si A es redundante con B' AS Nota
FROM IndicesConColumnas A
JOIN IndicesConColumnas B ON A.object_id = B.object_id
    AND A.index_id < B.index_id
    AND B.ColumnasKey LIKE A.ColumnasKey + '%'  -- B comienza con todas las columnas de A
ORDER BY A.NombreIndice;

-- Eliminar el índice redundante
PRINT 'Eliminando índice redundante IX_Dup1...';
DROP INDEX IX_Dup1 ON TRANSACCIONES_VOLUMEN;

GO

-- ============================================================
-- EJERCICIO 5: CASO PRÁCTICO - SISTEMA BANCARIO
-- ============================================================

/*
ESCENARIO:
El sistema bancario tiene una tabla de MOVIMIENTOS que recibe:
- 10,000 INSERTs por hora (24/7)
- 500 consultas de saldo por hora
- 50 reportes mensuales
- 20 auditorías diarias

Las consultas más críticas son:
1. Obtener últimos 10 movimientos de una cuenta
2. Calcular saldo actual de una cuenta
3. Buscar movimiento por referencia
4. Reporte mensual: Total por tipo de movimiento

Diseña los índices considerando el balance entre lecturas y escrituras.
*/

IF OBJECT_ID('MOVIMIENTOS_BANCO') IS NOT NULL DROP TABLE MOVIMIENTOS_BANCO;

CREATE TABLE MOVIMIENTOS_BANCO (
    MovimientoID BIGINT IDENTITY PRIMARY KEY,
    CuentaID INT NOT NULL,
    TipoMovimiento VARCHAR(15) NOT NULL,  -- 'CREDITO', 'DEBITO'
    Monto DECIMAL(18,2) NOT NULL,
    Saldo DECIMAL(18,2) NOT NULL,         -- Saldo después del movimiento
    FechaMovimiento DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    Referencia VARCHAR(30) NOT NULL,
    Descripcion NVARCHAR(200),
    CanalOrigen VARCHAR(20) NOT NULL,     -- 'ATM', 'WEB', 'SUCURSAL', 'APP'
    CONSTRAINT UQ_Referencia UNIQUE (Referencia)
);

-- Insertar datos de prueba
INSERT INTO MOVIMIENTOS_BANCO (CuentaID, TipoMovimiento, Monto, Saldo, FechaMovimiento, Referencia, Descripcion, CanalOrigen)
SELECT 
    (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 5000) + 1 AS CuentaID,
    CASE WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 3 = 0 THEN 'DEBITO' ELSE 'CREDITO' END,
    CAST(ABS(CHECKSUM(NEWID())) % 50000 AS DECIMAL(18,2)) / 100,
    CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS DECIMAL(18,2)) / 100,
    DATEADD(MINUTE, -ABS(CHECKSUM(NEWID())) % 525600, GETDATE()),
    'MOV' + FORMAT(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '0000000000'),
    'Movimiento de prueba',
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN 'ATM'
        WHEN 1 THEN 'WEB'
        WHEN 2 THEN 'SUCURSAL'
        ELSE 'APP'
    END
FROM TRANSACCIONES_VOLUMEN;

GO

-- ✅ SOLUCIONES DE ÍNDICES:

-- Índice 1: Últimos movimientos por cuenta (CONSULTA CRÍTICA)
-- CuentaID = igualdad, FechaMovimiento para ORDER BY
CREATE NONCLUSTERED INDEX IX_Mov_Cuenta_Fecha
ON MOVIMIENTOS_BANCO(CuentaID, FechaMovimiento DESC)
INCLUDE (TipoMovimiento, Monto, Saldo, Descripcion);

-- Índice 2: Saldo actual = último movimiento
-- Ya cubierto por IX_Mov_Cuenta_Fecha

-- Índice 3: Búsqueda por referencia
-- Ya existe el UNIQUE constraint que crea un índice

-- Índice 4: Reporte mensual (baja frecuencia, no amerita índice dedicado)
-- Puede usar Table Scan o crear índice temporal

GO

-- Verificar que cubre las consultas
SET STATISTICS IO ON;

PRINT '--- Consulta 1: Últimos 10 movimientos cuenta 1234 ---';
SELECT TOP 10 TipoMovimiento, Monto, Saldo, FechaMovimiento, Descripcion
FROM MOVIMIENTOS_BANCO
WHERE CuentaID = 1234
ORDER BY FechaMovimiento DESC;

PRINT '--- Consulta 2: Saldo actual cuenta 1234 ---';
SELECT TOP 1 Saldo
FROM MOVIMIENTOS_BANCO
WHERE CuentaID = 1234
ORDER BY FechaMovimiento DESC;

PRINT '--- Consulta 3: Buscar por referencia ---';
SELECT *
FROM MOVIMIENTOS_BANCO
WHERE Referencia = 'MOV0000050000';

SET STATISTICS IO OFF;

GO

-- ============================================================
-- EJERCICIO 6: QUIZ DE AUTOEVALUACIÓN
-- ============================================================

/*
PREGUNTA 1: ¿Cuántos clustered indexes puede tener una tabla?
a) Ninguno
b) Uno
c) Hasta 999
d) Ilimitados

PREGUNTA 2: ¿Qué almacenan las hojas de un nonclustered index?
a) Las filas completas de la tabla
b) Solo los valores de las columnas key
c) Key values + puntero (RID o Clustering Key)
d) Solo punteros

PREGUNTA 3: ¿Cuándo usar INCLUDE en un índice?
a) Para columnas del WHERE
b) Para eliminar Key Lookups
c) Para ordenar resultados
d) Para columnas con muchos valores únicos

PREGUNTA 4: Si el índice es IX(A, B, C), ¿cuál consulta NO puede hacer SEEK?
a) WHERE A = 1
b) WHERE A = 1 AND B = 2
c) WHERE B = 2
d) WHERE A = 1 AND C = 3

PREGUNTA 5: ¿Fragmentación de 25% en un índice requiere?
a) No hacer nada
b) REORGANIZE
c) REBUILD
d) DROP y CREATE

PREGUNTA 6: ¿Ventaja de un índice filtrado?
a) Ocupa más espacio
b) Se puede usar para cualquier consulta
c) Es más pequeño y eficiente para su subconjunto
d) Puede ser clustered

RESPUESTAS:
1. b) Uno - solo puede haber un clustered index por tabla
2. c) Key values + puntero - necesita poder ir a buscar la fila completa
3. b) Eliminar Key Lookups - incluir columnas que solo se leen
4. c) WHERE B = 2 - no puede "saltar" la primera columna A
5. b) REORGANIZE - entre 10-30% es REORGANIZE
6. c) Más pequeño y eficiente - solo incluye filas que cumplen el filtro
*/

GO

-- ============================================================
-- LIMPIEZA
-- ============================================================

-- Eliminar índices de ejercicio
PRINT 'Limpiando índices de ejercicio...';

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ej1A_ReporteEstado') DROP INDEX IX_Ej1A_ReporteEstado ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ej1B_BusquedaCuenta') DROP INDEX IX_Ej1B_BusquedaCuenta ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ej1C_TransferenciasGrandes') DROP INDEX IX_Ej1C_TransferenciasGrandes ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ej2_Completo') DROP INDEX IX_Ej2_Completo ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dup2') DROP INDEX IX_Dup2 ON TRANSACCIONES_VOLUMEN;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dup3') DROP INDEX IX_Dup3 ON TRANSACCIONES_VOLUMEN;

PRINT 'Limpieza completada.';

GO

PRINT '';
PRINT 'Fin de los ejercicios - Sesión 4: Índices Estratégicos';
