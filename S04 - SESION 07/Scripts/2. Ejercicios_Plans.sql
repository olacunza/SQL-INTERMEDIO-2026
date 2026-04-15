/*
=====================================================================
  SESIÓN 07: EJERCICIOS - EXECUTION PLANS I
  SQL Server Intermedio 2026
  
  Ejercicios prácticos para análisis de planes de ejecución
  Base de datos: BancoDB
  
  INSTRUCCIONES:
  - Habilitar Ctrl+M (Include Actual Execution Plan) antes de ejecutar
  - Usar SET STATISTICS IO ON para medir lecturas
  - Analizar cada plan y responder las preguntas
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- EJERCICIO 1: IDENTIFICAR SCAN VS SEEK (Básico)
-- =====================================================================
/*
   OBJETIVO: Entender cuándo SQL Server elige Scan vs Seek
   
   INSTRUCCIONES:
   1. Ejecutar cada consulta con Ctrl+M habilitado
   2. Identificar el operador usado (Scan o Seek)
   3. Explicar POR QUÉ se eligió ese operador
*/

-- 1A: ¿Qué operador se usa? ¿Por qué?
SELECT * FROM CLIENTES WHERE ClienteID = 50;

-- 1B: ¿Qué operador se usa? ¿Por qué?
SELECT * FROM CLIENTES WHERE Nombre LIKE '%García%';

-- 1C: ¿Qué cambia si creamos un índice en Nombre?
-- CREATE NONCLUSTERED INDEX IX_CLIENTES_Nombre ON CLIENTES(Nombre);
-- SELECT * FROM CLIENTES WHERE Nombre LIKE '%García%';
-- ¿El índice ayuda con LIKE '%...%'? ¿Por qué sí o no?

/*
   TU RESPUESTA:
   
   1A: _______________________________________________
   
   1B: _______________________________________________
   
   1C: _______________________________________________
*/

-- =====================================================================
-- EJERCICIO 2: DETECTAR KEY LOOKUP (Intermedio)
-- =====================================================================
/*
   OBJETIVO: Identificar Key Lookups y su impacto
   
   INSTRUCCIONES:
   1. Ejecutar la consulta con STATISTICS IO ON
   2. Identificar si hay Key Lookup en el plan
   3. Calcular el overhead (lecturas extra)
   4. Proponer una solución
*/

-- Primero crear un índice parcial
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_Fecha_Basic')
    CREATE NONCLUSTERED INDEX IX_TX_Fecha_Basic 
    ON TRANSACCIONES_BANCARIAS(FechaTransaccion);

SET STATISTICS IO ON;

-- 2A: Ejecutar y analizar
SELECT 
    TransaccionID,
    FechaTransaccion,
    TipoTransaccion,    -- No está en el índice
    Monto,              -- No está en el índice
    Descripcion         -- No está en el índice
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= '2024-01-01'
  AND FechaTransaccion < '2024-02-01';

SET STATISTICS IO OFF;

/*
   PREGUNTAS:
   
   1. ¿Cuántas logical reads se reportan?
      ________________
   
   2. ¿Hay Key Lookup en el plan? (Sí/No)
      ________________
   
   3. ¿Qué porcentaje del costo total es el Key Lookup?
      ________________
   
   4. Escribe el CREATE INDEX para eliminar el Key Lookup:
   
      CREATE NONCLUSTERED INDEX IX_TX_Fecha_Covering
      ON TRANSACCIONES_BANCARIAS(________________)
      INCLUDE (________________);
*/

-- SOLUCIÓN: Crea el índice y vuelve a ejecutar para comparar
-- (Escribe tu índice aquí)



-- =====================================================================
-- EJERCICIO 3: COMPARAR ESTRATEGIAS DE JOIN (Intermedio)
-- =====================================================================
/*
   OBJETIVO: Ver cómo los índices afectan el tipo de JOIN
   
   Tipos de JOIN físicos:
   - NESTED LOOPS: Bueno con índices, pocas filas outer
   - HASH MATCH: Bueno sin índices, muchas filas
   - MERGE JOIN: Requiere ambos lados ordenados
*/

-- 3A: Ver el plan de esta consulta y anotar el tipo de JOIN usado
SELECT 
    c.Nombre,
    cu.NumeroCuenta,
    cu.Saldo
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.ClienteID BETWEEN 1 AND 10;

-- 3B: Ahora con más datos
SELECT 
    c.Nombre,
    cu.NumeroCuenta,
    cu.Saldo
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID;

/*
   PREGUNTAS:
   
   3A. Tipo de JOIN usado: _______________
       ¿Por qué crees que eligió este tipo?
       ________________________________________________
   
   3B. Tipo de JOIN usado: _______________
       ¿Cambió el tipo? ¿Por qué?
       ________________________________________________
*/

-- =====================================================================
-- EJERCICIO 4: STATISTICS IO ANALYSIS (Intermedio)
-- =====================================================================
/*
   OBJETIVO: Usar STATISTICS IO para medir impacto real
   
   INSTRUCCIONES:
   1. Ejecutar ambas versiones de la consulta
   2. Comparar las lecturas lógicas
   3. Determinar cuál es más eficiente
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- VERSIÓN A: EXISTS
SELECT c.Nombre, c.Email
FROM CLIENTES c
WHERE EXISTS (
    SELECT 1 
    FROM TRANSACCIONES_BANCARIAS t
    INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
    WHERE cu.ClienteID = c.ClienteID
      AND t.TipoTransaccion = 'Transferencia'
      AND t.Monto > 10000
);

-- VERSIÓN B: JOIN con DISTINCT
SELECT DISTINCT c.Nombre, c.Email
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE t.TipoTransaccion = 'Transferencia'
  AND t.Monto > 10000;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   ANÁLISIS:
   
   VERSIÓN A (EXISTS):
   - Logical reads CLIENTES: ________
   - Logical reads CUENTAS: ________
   - Logical reads TX: ________
   - CPU time: ________ ms
   
   VERSIÓN B (JOIN DISTINCT):
   - Logical reads CLIENTES: ________
   - Logical reads CUENTAS: ________
   - Logical reads TX: ________
   - CPU time: ________ ms
   
   ¿Cuál es más eficiente y por qué?
   ________________________________________________
   ________________________________________________
*/

-- =====================================================================
-- EJERCICIO 5: OPTIMIZAR CONSULTA PROBLEMÁTICA (Avanzado)
-- =====================================================================
/*
   ESCENARIO: 
   Esta consulta tarda 5+ segundos y es crítica para el dashboard.
   Analiza el plan, identifica los problemas y optimízala.
*/

-- CONSULTA PROBLEMÁTICA
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT 
    MONTH(t.FechaTransaccion) AS Mes,
    c.Nombre AS Cliente,
    SUM(t.Monto) AS TotalMovimientos,
    COUNT(*) AS NumTransacciones,
    AVG(t.Monto) AS PromedioMonto
FROM TRANSACCIONES_BANCARIAS t
INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2024-01-01'
  AND t.FechaTransaccion < '2025-01-01'
  AND t.Monto > 0
GROUP BY MONTH(t.FechaTransaccion), c.Nombre
HAVING SUM(t.Monto) > 50000
ORDER BY TotalMovimientos DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   ANÁLISIS DEL PLAN:
   
   1. ¿Qué operador tiene el mayor costo?
      ________________________________________________
   
   2. ¿Hay Key Lookups? ¿En qué tabla?
      ________________________________________________
   
   3. ¿Hay Sort? ¿Es necesario?
      ________________________________________________
   
   4. ¿Qué índices crearías para optimizar?
   
      Índice 1:
      CREATE INDEX ________________________________
      ON ______________ (______________)
      INCLUDE (______________);
      
      Índice 2:
      CREATE INDEX ________________________________
      ON ______________ (______________)
      INCLUDE (______________);
   
   5. Después de crear los índices, ejecuta de nuevo y compara:
      
      ANTES: ________ logical reads, ________ ms
      DESPUÉS: ________ logical reads, ________ ms
*/

-- =====================================================================
-- EJERCICIO 6: DETECTAR IMPLICIT CONVERSION (Avanzado)
-- =====================================================================
/*
   OBJETIVO: Identificar conversiones implícitas que evitan uso de índices
   
   La conversión implícita es un "asesino silencioso" del rendimiento
*/

-- Crear índice para la demostración
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CUENTAS_NumeroCuenta_Test')
    CREATE NONCLUSTERED INDEX IX_CUENTAS_NumeroCuenta_Test ON CUENTAS(NumeroCuenta);

-- 6A: Ver el tipo de dato de NumeroCuenta
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CUENTAS' 
  AND COLUMN_NAME = 'NumeroCuenta';

-- 6B: Ejecutar con tipo correcto
DECLARE @NumCuenta1 VARCHAR(20) = 'CTA-0001';  -- Mismo tipo que la columna

SELECT CuentaID, NumeroCuenta, Saldo
FROM CUENTAS
WHERE NumeroCuenta = @NumCuenta1;
-- Ver plan: ¿Index Seek?

-- 6C: Ejecutar con tipo diferente
DECLARE @NumCuenta2 NVARCHAR(20) = N'CTA-0001';  -- Tipo diferente!

SELECT CuentaID, NumeroCuenta, Saldo
FROM CUENTAS
WHERE NumeroCuenta = @NumCuenta2;
-- Ver plan: ¿Index Seek o Scan? ¿Hay warning de Implicit Conversion?

/*
   PREGUNTAS:
   
   1. ¿Qué tipo de dato tiene NumeroCuenta en la tabla?
      ________________
   
   2. ¿Qué plan se genera en 6B?
      ________________
   
   3. ¿Qué plan se genera en 6C? ¿Por qué cambió?
      ________________________________________________
   
   4. ¿Cómo arreglarías este problema en código de aplicación?
      ________________________________________________
*/

-- =====================================================================
-- CASO INTEGRADOR: "El Reporte de Cierre Lento"
-- =====================================================================
/*
   ESCENARIO:
   El equipo de contabilidad reporta que el informe de cierre mensual
   tarda más de 2 minutos en generarse. El SLA es de 30 segundos.
   
   TU MISIÓN:
   1. Ejecutar la consulta y capturar STATISTICS
   2. Analizar el plan de ejecución
   3. Identificar TODOS los problemas
   4. Crear los índices necesarios
   5. Demostrar la mejora
*/

-- REPORTE DE CIERRE (versión actual)
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @FechaInicio DATE = '2024-01-01';
DECLARE @FechaFin DATE = '2024-01-31';

SELECT 
    cu.TipoCuenta,
    COUNT(DISTINCT cu.CuentaID) AS TotalCuentas,
    SUM(CASE WHEN t.TipoTransaccion = 'Depósito' THEN t.Monto ELSE 0 END) AS TotalDepositos,
    SUM(CASE WHEN t.TipoTransaccion = 'Retiro' THEN t.Monto ELSE 0 END) AS TotalRetiros,
    SUM(CASE WHEN t.TipoTransaccion = 'Transferencia' THEN t.Monto ELSE 0 END) AS TotalTransferencias,
    COUNT(*) AS TotalOperaciones,
    AVG(t.Monto) AS MontoPromedio,
    MAX(t.Monto) AS MontoMaximo,
    MIN(CASE WHEN t.Monto > 0 THEN t.Monto END) AS MontoMinimo
FROM CUENTAS cu
LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    AND t.FechaTransaccion >= @FechaInicio
    AND t.FechaTransaccion <= @FechaFin
GROUP BY cu.TipoCuenta
ORDER BY TotalDepositos DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   DOCUMENTACIÓN DE TU ANÁLISIS:
   
   ═══════════════════════════════════════════════════════════════
   MÉTRICAS INICIALES:
   ═══════════════════════════════════════════════════════════════
   
   Tabla CUENTAS:
   - Logical reads: ________
   - Operador: ________
   
   Tabla TRANSACCIONES:
   - Logical reads: ________
   - Operador: ________
   
   Tiempos:
   - CPU time: ________ ms
   - Elapsed time: ________ ms
   
   ═══════════════════════════════════════════════════════════════
   PROBLEMAS IDENTIFICADOS:
   ═══════════════════════════════════════════════════════════════
   
   1. ________________________________________________
   
   2. ________________________________________________
   
   3. ________________________________________________
   
   ═══════════════════════════════════════════════════════════════
   SOLUCIÓN - ÍNDICES A CREAR:
   ═══════════════════════════════════════════════════════════════
   
   -- Índice 1:
   
   
   -- Índice 2:
   
   
   ═══════════════════════════════════════════════════════════════
   MÉTRICAS DESPUÉS DE OPTIMIZACIÓN:
   ═══════════════════════════════════════════════════════════════
   
   Tabla CUENTAS:
   - Logical reads: ________ (mejora: ___%)
   
   Tabla TRANSACCIONES:
   - Logical reads: ________ (mejora: ___%)
   
   Tiempos:
   - CPU time: ________ ms (mejora: ___%)
   - Elapsed time: ________ ms (mejora: ___%)
   
   ¿Se cumple el SLA de 30 segundos? ________
   
*/

-- =====================================================================
-- EJERCICIO BONUS: CREAR SP DE ANÁLISIS DE PLANES
-- =====================================================================
/*
   Crea un SP que analice los planes en cache y muestre consultas
   con alto costo de Key Lookup
*/

CREATE OR ALTER PROCEDURE dbo.sp_AnalyzarKeyLookups
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    ;WITH XMLNAMESPACES (
        DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
    SELECT TOP (@TopN)
        DB_NAME(st.dbid) AS BaseDatos,
        qs.execution_count AS Ejecuciones,
        qs.total_logical_reads AS LecturasLogicasTotales,
        qs.total_logical_reads / qs.execution_count AS LecturasPromedio,
        SUBSTRING(st.text, 
            (qs.statement_start_offset/2) + 1,
            ((CASE qs.statement_end_offset 
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset 
             END - qs.statement_start_offset)/2) + 1
        ) AS ConsultaSQL,
        qp.query_plan.exist('//IndexScan[@Lookup="1"]') AS TieneKeyLookup
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
    WHERE st.dbid = DB_ID()
      AND qp.query_plan.exist('//IndexScan[@Lookup="1"]') = 1
    ORDER BY qs.total_logical_reads DESC;
END;
GO

-- Ejecutar el SP
-- EXEC dbo.sp_AnalyzarKeyLookups @TopN = 10;

-- =====================================================================
-- LIMPIEZA (ejecutar al final del ejercicio)
-- =====================================================================
/*
DROP INDEX IF EXISTS IX_TX_Fecha_Basic ON TRANSACCIONES_BANCARIAS;
DROP INDEX IF EXISTS IX_CUENTAS_NumeroCuenta_Test ON CUENTAS;
DROP PROCEDURE IF EXISTS dbo.sp_AnalyzarKeyLookups;
*/

PRINT '¡Ejercicios de Execution Plans I completados!';
GO
