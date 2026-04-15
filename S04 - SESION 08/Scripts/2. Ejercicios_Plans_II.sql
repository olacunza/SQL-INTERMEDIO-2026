/*
=====================================================================
  SESIÓN 08: EJERCICIOS - EXECUTION PLANS II
  SQL Server Intermedio 2026
  
  Ejercicios prácticos sobre Query Hints, OPTION y Plan Forcing
  Base de datos: BancoDB
  
  INSTRUCCIONES:
  - Habilitar Ctrl+M (Include Actual Execution Plan)
  - Usar SET STATISTICS IO ON para comparar
  - Documentar resultados en cada ejercicio
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- EJERCICIO 1: COMPARAR JOIN HINTS (Básico)
-- =====================================================================
/*
   OBJETIVO: Ver el impacto de forzar diferentes tipos de JOIN
   
   INSTRUCCIONES:
   1. Ejecutar las 4 versiones de la consulta
   2. Comparar planes de ejecución
   3. Comparar STATISTICS IO
   4. Determinar cuál es más eficiente y por qué
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- VERSION 1: Sin hint (optimizer decide)
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.FechaRegistro >= '2024-01-01';

-- VERSION 2: Forzar NESTED LOOPS
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER LOOP JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.FechaRegistro >= '2024-01-01';

-- VERSION 3: Forzar HASH JOIN
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER HASH JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.FechaRegistro >= '2024-01-01';

-- VERSION 4: Forzar MERGE JOIN
SELECT c.Nombre, cu.NumeroCuenta, cu.Saldo
FROM CLIENTES c
INNER MERGE JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.FechaRegistro >= '2024-01-01';

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   RESULTADOS:
   
   VERSION 1 (Sin hint):
   - Tipo JOIN elegido: ________________
   - Logical reads CLIENTES: ________________
   - Logical reads CUENTAS: ________________
   - Tiempo CPU: ________________
   
   VERSION 2 (LOOP):
   - Logical reads CLIENTES: ________________
   - Logical reads CUENTAS: ________________
   - Tiempo CPU: ________________
   
   VERSION 3 (HASH):
   - Logical reads CLIENTES: ________________
   - Logical reads CUENTAS: ________________
   - Tiempo CPU: ________________
   
   VERSION 4 (MERGE):
   - Logical reads CLIENTES: ________________
   - Logical reads CUENTAS: ________________
   - Tiempo CPU: ________________
   
   ANÁLISIS:
   ¿Cuál es más eficiente? ________________
   ¿Por qué? ________________________________________________
   ¿El optimizer eligió la mejor opción? ________________
*/

-- =====================================================================
-- EJERCICIO 2: TABLE HINTS - NOLOCK Y SUS RIESGOS (Intermedio)
-- =====================================================================
/*
   OBJETIVO: Entender cuándo usar NOLOCK y sus riesgos
   
   NOLOCK permite lecturas "sucias" (uncommitted data)
   Puede causar: datos parciales, duplicados, filas fantasma
*/

-- 2A: Crear escenario de prueba
-- Abrir DOS ventanas de SSMS

-- VENTANA 1: Iniciar transacción sin commit
/*
BEGIN TRANSACTION;
UPDATE CUENTAS 
SET Saldo = Saldo + 999999
WHERE CuentaID = 1;
-- NO HACER COMMIT AÚN
*/

-- VENTANA 2: Intentar leer

-- Sin NOLOCK (se bloquea esperando)
SELECT CuentaID, Saldo FROM CUENTAS WHERE CuentaID = 1;

-- Con NOLOCK (lee el valor no committed)
SELECT CuentaID, Saldo FROM CUENTAS WITH (NOLOCK) WHERE CuentaID = 1;

-- VENTANA 1: Hacer ROLLBACK
/*
ROLLBACK;
*/

/*
   PREGUNTAS:
   
   1. ¿Qué valor mostró la consulta con NOLOCK?
      ________________
   
   2. ¿Ese valor era correcto (después del ROLLBACK)?
      ________________
   
   3. ¿En qué escenarios bancarios sería PELIGROSO usar NOLOCK?
      ________________________________________________
      ________________________________________________
   
   4. ¿En qué escenarios podría ser aceptable usar NOLOCK?
      ________________________________________________
      ________________________________________________
*/

-- =====================================================================
-- EJERCICIO 3: OPTION RECOMPILE VS OPTIMIZE FOR (Intermedio)
-- =====================================================================
/*
   OBJETIVO: Comparar soluciones para parameter sniffing
*/

-- Crear SP de prueba
CREATE OR ALTER PROCEDURE dbo.sp_BuscarTransacciones_Test
    @TipoTransaccion VARCHAR(20),
    @MontoMinimo DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion,
        c.Nombre AS Cliente
    FROM TRANSACCIONES_BANCARIAS t
    INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
    INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
    WHERE t.TipoTransaccion = @TipoTransaccion
      AND t.Monto >= @MontoMinimo;
END;
GO

-- 3A: Probar sin hints
DBCC FREEPROCCACHE;  -- Limpiar cache (solo para pruebas!)
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXEC dbo.sp_BuscarTransacciones_Test 
    @TipoTransaccion = 'Depósito', 
    @MontoMinimo = 100000;  -- Pocos resultados

EXEC dbo.sp_BuscarTransacciones_Test 
    @TipoTransaccion = 'Retiro', 
    @MontoMinimo = 1;  -- Muchos resultados

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- 3B: Agregar OPTION (RECOMPILE)
CREATE OR ALTER PROCEDURE dbo.sp_BuscarTransacciones_Recompile
    @TipoTransaccion VARCHAR(20),
    @MontoMinimo DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.TransaccionID,
        t.TipoTransaccion,
        t.Monto,
        t.FechaTransaccion,
        c.Nombre AS Cliente
    FROM TRANSACCIONES_BANCARIAS t
    INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
    INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
    WHERE t.TipoTransaccion = @TipoTransaccion
      AND t.Monto >= @MontoMinimo
    OPTION (RECOMPILE);
END;
GO

-- Probar
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXEC dbo.sp_BuscarTransacciones_Recompile 
    @TipoTransaccion = 'Depósito', 
    @MontoMinimo = 100000;

EXEC dbo.sp_BuscarTransacciones_Recompile 
    @TipoTransaccion = 'Retiro', 
    @MontoMinimo = 1;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   COMPARACIÓN:
   
   SIN RECOMPILE:
   - Primera ejecución (Depósito, 100000): ________ ms
   - Segunda ejecución (Retiro, 1): ________ ms
   - ¿Usó plan óptimo en la segunda? ________
   
   CON RECOMPILE:
   - Primera ejecución (Depósito, 100000): ________ ms
   - Segunda ejecución (Retiro, 1): ________ ms
   - ¿Cada ejecución tiene plan óptimo? ________
   
   ¿Cuál es el trade-off de RECOMPILE?
   ________________________________________________
*/

-- =====================================================================
-- EJERCICIO 4: FORCESEEK VS FORCESCAN (Avanzado)
-- =====================================================================
/*
   OBJETIVO: Entender cuándo forzar Seek o Scan
*/

-- Crear índice para pruebas
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_TipoTX_Test')
    CREATE NONCLUSTERED INDEX IX_TX_TipoTX_Test 
    ON TRANSACCIONES_BANCARIAS(TipoTransaccion)
    INCLUDE (Monto, FechaTransaccion);

SET STATISTICS IO ON;

-- 4A: Buscar tipo poco frecuente (pocos resultados)
-- Sin hint
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Comisión';  -- Asumiendo que hay pocos

-- Con FORCESEEK
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS WITH (FORCESEEK)
WHERE TipoTransaccion = 'Comisión';

-- 4B: Buscar tipo muy frecuente (muchos resultados)
-- Sin hint
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Retiro';  -- Asumiendo que hay muchos

-- Con FORCESCAN
SELECT TransaccionID, TipoTransaccion, Monto
FROM TRANSACCIONES_BANCARIAS WITH (FORCESCAN)
WHERE TipoTransaccion = 'Retiro';

SET STATISTICS IO OFF;

/*
   ANÁLISIS:
   
   4A (pocos resultados):
   - Sin hint: Operador = ________, Reads = ________
   - Con FORCESEEK: Operador = ________, Reads = ________
   - ¿Cuál es mejor? ________
   
   4B (muchos resultados):
   - Sin hint: Operador = ________, Reads = ________
   - Con FORCESCAN: Operador = ________, Reads = ________
   - ¿El optimizer eligió bien? ________
   
   CONCLUSIÓN: ¿Cuándo usar cada hint?
   FORCESEEK: ________________________________________________
   FORCESCAN: ________________________________________________
*/

-- =====================================================================
-- EJERCICIO 5: QUERY STORE - ANÁLISIS Y FORCING (Avanzado)
-- =====================================================================
/*
   OBJETIVO: Usar Query Store para identificar y estabilizar planes
*/

-- 5A: Verificar que Query Store está habilitado
SELECT 
    name,
    is_query_store_on
FROM sys.databases
WHERE name = 'BancoDB';

-- Si no está habilitado:
-- ALTER DATABASE BancoDB SET QUERY_STORE = ON;

-- 5B: Crear consulta para monitorear
CREATE OR ALTER PROCEDURE dbo.sp_ReporteMensual_Monitor
    @Anio INT,
    @Mes INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FechaInicio DATE = DATEFROMPARTS(@Anio, @Mes, 1);
    DECLARE @FechaFin DATE = EOMONTH(@FechaInicio);
    
    SELECT 
        cu.TipoCuenta,
        COUNT(DISTINCT c.ClienteID) AS TotalClientes,
        COUNT(t.TransaccionID) AS TotalTransacciones,
        SUM(CASE WHEN t.TipoTransaccion = 'Depósito' THEN t.Monto ELSE 0 END) AS Depositos,
        SUM(CASE WHEN t.TipoTransaccion = 'Retiro' THEN t.Monto ELSE 0 END) AS Retiros
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
        AND t.FechaTransaccion BETWEEN @FechaInicio AND @FechaFin
    GROUP BY cu.TipoCuenta
    ORDER BY TotalTransacciones DESC;
END;
GO

-- 5C: Ejecutar múltiples veces para generar estadísticas
EXEC dbo.sp_ReporteMensual_Monitor @Anio = 2024, @Mes = 1;
EXEC dbo.sp_ReporteMensual_Monitor @Anio = 2024, @Mes = 6;
EXEC dbo.sp_ReporteMensual_Monitor @Anio = 2024, @Mes = 12;
EXEC dbo.sp_ReporteMensual_Monitor @Anio = 2023, @Mes = 1;
EXEC dbo.sp_ReporteMensual_Monitor @Anio = 2023, @Mes = 6;
GO 5  -- Ejecutar 5 veces más

-- 5D: Consultar Query Store
SELECT 
    q.query_id,
    p.plan_id,
    p.is_forced_plan,
    rs.count_executions,
    rs.avg_duration / 1000.0 AS avg_ms,
    rs.min_duration / 1000.0 AS min_ms,
    rs.max_duration / 1000.0 AS max_ms,
    rs.avg_logical_io_reads,
    rs.last_execution_time
FROM sys.query_store_query q
INNER JOIN sys.query_store_query_text t ON q.query_text_id = t.query_text_id
INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE t.query_sql_text LIKE '%ReporteMensual%'
ORDER BY q.query_id, p.plan_id;

/*
   ANÁLISIS DE QUERY STORE:
   
   1. ¿Cuántos planes diferentes se generaron?
      ________
   
   2. ¿Hay variación significativa en tiempos (min vs max)?
      ________
   
   3. ¿Cuál plan tiene mejor avg_duration?
      Plan ID: ________, avg_ms: ________
   
   4. Si quisieras forzar ese plan, el comando sería:
      EXEC sp_query_store_force_plan @query_id = ____, @plan_id = ____;
*/

-- =====================================================================
-- EJERCICIO 6: MAXDOP - CONTROL DE PARALELISMO (Avanzado)
-- =====================================================================
/*
   OBJETIVO: Entender el impacto del paralelismo
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- 6A: Consulta pesada SIN límite de MAXDOP
SELECT 
    YEAR(t.FechaTransaccion) AS Anio,
    MONTH(t.FechaTransaccion) AS Mes,
    c.Nombre,
    SUM(t.Monto) AS TotalMovido,
    COUNT(*) AS NumTX,
    AVG(t.Monto) AS PromedioTX
FROM TRANSACCIONES_BANCARIAS t
INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2023-01-01'
GROUP BY YEAR(t.FechaTransaccion), MONTH(t.FechaTransaccion), c.Nombre
HAVING COUNT(*) > 5
ORDER BY Anio, Mes, TotalMovido DESC;

-- 6B: Misma consulta con MAXDOP 1 (serial)
SELECT 
    YEAR(t.FechaTransaccion) AS Anio,
    MONTH(t.FechaTransaccion) AS Mes,
    c.Nombre,
    SUM(t.Monto) AS TotalMovido,
    COUNT(*) AS NumTX,
    AVG(t.Monto) AS PromedioTX
FROM TRANSACCIONES_BANCARIAS t
INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2023-01-01'
GROUP BY YEAR(t.FechaTransaccion), MONTH(t.FechaTransaccion), c.Nombre
HAVING COUNT(*) > 5
ORDER BY Anio, Mes, TotalMovido DESC
OPTION (MAXDOP 1);

-- 6C: Con MAXDOP 2
SELECT 
    YEAR(t.FechaTransaccion) AS Anio,
    MONTH(t.FechaTransaccion) AS Mes,
    c.Nombre,
    SUM(t.Monto) AS TotalMovido,
    COUNT(*) AS NumTX,
    AVG(t.Monto) AS PromedioTX
FROM TRANSACCIONES_BANCARIAS t
INNER JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
INNER JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.FechaTransaccion >= '2023-01-01'
GROUP BY YEAR(t.FechaTransaccion), MONTH(t.FechaTransaccion), c.Nombre
HAVING COUNT(*) > 5
ORDER BY Anio, Mes, TotalMovido DESC
OPTION (MAXDOP 2);

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   RESULTADOS:
   
   SIN MAXDOP (paralelo completo):
   - CPU time: ________ ms
   - Elapsed time: ________ ms
   - ¿Hay operadores Parallelism en el plan? ________
   
   MAXDOP 1 (serial):
   - CPU time: ________ ms
   - Elapsed time: ________ ms
   
   MAXDOP 2:
   - CPU time: ________ ms
   - Elapsed time: ________ ms
   
   ANÁLISIS:
   1. ¿Qué MAXDOP dio mejor elapsed time?
      ________
   
   2. ¿Por qué CPU time puede ser MAYOR con paralelismo?
      ________________________________________________
   
   3. ¿Cuándo preferirías MAXDOP 1?
      ________________________________________________
*/

-- =====================================================================
-- CASO INTEGRADOR: "El SP Inestable"
-- =====================================================================
/*
   ESCENARIO:
   El SP de consulta de saldos tiene comportamiento errático.
   A veces tarda 100ms, otras veces 30 segundos.
   El equipo de desarrollo no puede modificar el código fácilmente.
   
   TU MISIÓN:
   1. Diagnosticar el problema
   2. Implementar solución SIN modificar el SP
   3. Documentar la solución
*/

-- El SP problemático (no lo modifiques)
CREATE OR ALTER PROCEDURE dbo.sp_ConsultaSaldos_Problematico
    @TipoCuenta VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClienteID,
        c.Nombre,
        c.Email,
        cu.NumeroCuenta,
        cu.TipoCuenta,
        cu.Saldo,
        cu.FechaApertura,
        (
            SELECT COUNT(*) 
            FROM TRANSACCIONES_BANCARIAS t 
            WHERE t.CuentaID = cu.CuentaID
        ) AS NumTransacciones
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    WHERE cu.TipoCuenta = ISNULL(@TipoCuenta, cu.TipoCuenta)
    ORDER BY cu.Saldo DESC;
END;
GO

-- Prueba 1: Sin parámetro (todos los tipos)
EXEC dbo.sp_ConsultaSaldos_Problematico;

-- Prueba 2: Con parámetro específico
EXEC dbo.sp_ConsultaSaldos_Problematico @TipoCuenta = 'Ahorro';

/*
   ═══════════════════════════════════════════════════════════════
   TU DIAGNÓSTICO:
   ═══════════════════════════════════════════════════════════════
   
   1. ¿Qué problema de performance identificaste?
      ________________________________________________
   
   2. ¿Por qué el SP es inestable (a veces rápido, a veces lento)?
      ________________________________________________
   
   ═══════════════════════════════════════════════════════════════
   TU SOLUCIÓN (sin modificar el SP):
   ═══════════════════════════════════════════════════════════════
   
   Opción A: Plan Guide
   Escribe el comando para crear un Plan Guide que agregue
   OPTION (RECOMPILE) al SP:
   
   -- Tu código aquí:
   
   
   Opción B: Query Store Force
   1. Ejecutar el SP varias veces
   2. Identificar el mejor plan en Query Store
   3. Forzar ese plan
   
   -- Consulta para identificar planes:
   
   
   ═══════════════════════════════════════════════════════════════
   VALIDACIÓN:
   ═══════════════════════════════════════════════════════════════
   
   Después de aplicar la solución:
   
   - Tiempo sin parámetro: ________ ms
   - Tiempo con 'Ahorro': ________ ms
   - ¿El comportamiento es estable ahora? ________
   
*/

-- =====================================================================
-- LIMPIEZA
-- =====================================================================
/*
DROP PROCEDURE IF EXISTS dbo.sp_BuscarTransacciones_Test;
DROP PROCEDURE IF EXISTS dbo.sp_BuscarTransacciones_Recompile;
DROP PROCEDURE IF EXISTS dbo.sp_ReporteMensual_Monitor;
DROP PROCEDURE IF EXISTS dbo.sp_ConsultaSaldos_Problematico;
DROP INDEX IF EXISTS IX_TX_TipoTX_Test ON TRANSACCIONES_BANCARIAS;
*/

PRINT '¡Ejercicios de Execution Plans II completados!';
GO
