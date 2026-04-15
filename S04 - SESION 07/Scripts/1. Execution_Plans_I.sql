/*
=====================================================================
  SESIÓN 07: EXECUTION PLANS I - ANÁLISIS DE PLANES DE EJECUCIÓN
  SQL Server Intermedio 2026
  
  Temas:
    1. ¿Qué es un Plan de Ejecución?
    2. Plan Estimado vs Plan Real
    3. Operadores Básicos (Scan, Seek, Lookup)
    4. Index Scan vs Index Seek
    5. Key Lookup y su impacto
    6. STATISTICS IO y STATISTICS TIME
    7. Identificación de cuellos de botella
    8. Interpretación de costos
    9. Warnings en planes de ejecución
   10. SET SHOWPLAN_XML y planes en texto
   11. Caso práctico: Optimizando consultas bancarias
   
  Base de datos: BancoDB
=====================================================================
*/

USE BancoDB;
GO

-- =====================================================================
-- PARTE 1: ¿QUÉ ES UN PLAN DE EJECUCIÓN?
-- =====================================================================
/*
   Un Plan de Ejecución es el "mapa" que SQL Server genera para
   ejecutar una consulta. Muestra:
   
   - QUÉ operadores se usarán (Scan, Seek, Join, Sort, etc.)
   - EN QUÉ ORDEN se ejecutarán
   - CUÁNTO COSTARÁ cada operador (estimado)
   - CUÁNTAS FILAS se procesarán
   
   El Query Optimizer evalúa múltiples planes posibles y elige
   el de menor "costo" estimado.
   
   IMPORTANTE:
   - El costo es una ESTIMACIÓN basada en estadísticas
   - El plan "óptimo" puede no serlo si las estadísticas están desactualizadas
*/

-- Habilitar el plan de ejecución gráfico:
-- En SSMS: Ctrl + M (antes de ejecutar) o Ctrl + L (solo estimado)

-- =====================================================================
-- PARTE 2: PLAN ESTIMADO VS PLAN REAL
-- =====================================================================

/*
   PLAN ESTIMADO (Ctrl + L):
   - Se genera SIN ejecutar la consulta
   - Muestra filas ESTIMADAS basadas en estadísticas
   - Útil para análisis rápido sin impacto en producción
   
   PLAN REAL (Ctrl + M + F5):
   - Se genera EJECUTANDO la consulta
   - Muestra filas REALES procesadas
   - Incluye tiempos, memory grants, warnings reales
   - Esencial para debugging
   
   REGLA DE ORO:
   Si "Estimated Rows" difiere mucho de "Actual Rows" = Estadísticas desactualizadas
*/

-- Comparación: Plan estimado vs real
-- Primero veamos las estadísticas de la tabla
SELECT 
    t.name AS Tabla,
    s.name AS Estadistica,
    STATS_DATE(s.object_id, s.stats_id) AS UltimaActualizacion,
    s.auto_created,
    s.user_created
FROM sys.stats s
INNER JOIN sys.tables t ON s.object_id = t.object_id
WHERE t.name IN ('CLIENTES', 'CUENTAS', 'TRANSACCIONES_BANCARIAS')
ORDER BY t.name, s.name;

-- =====================================================================
-- PARTE 3: OPERADORES BÁSICOS - LA FAMILIA SCAN/SEEK
-- =====================================================================

/*
   OPERADORES DE ACCESO A DATOS:
   
   ┌─────────────────────┬──────────────────────────────────────────┐
   │ OPERADOR            │ DESCRIPCIÓN                              │
   ├─────────────────────┼──────────────────────────────────────────┤
   │ TABLE SCAN          │ Lee TODA la tabla (heap, sin clustered)  │
   │ CLUSTERED INDEX SCAN│ Lee TODO el índice clustered             │
   │ INDEX SCAN          │ Lee TODO un índice non-clustered         │
   │ CLUSTERED INDEX SEEK│ Búsqueda directa en índice clustered     │
   │ INDEX SEEK          │ Búsqueda directa en índice non-clustered │
   │ KEY LOOKUP          │ Volver al clustered para obtener columnas│
   │ RID LOOKUP          │ Igual que Key Lookup pero en heaps       │
   └─────────────────────┴──────────────────────────────────────────┘
*/

-- Ejemplo de cada operador:

-- 3.1 TABLE SCAN (evitar en producción)
-- Primero creamos una tabla HEAP (sin índice clustered) para demo
CREATE TABLE #ClientesHeap (
    ClienteID INT,
    Nombre NVARCHAR(100),
    Email NVARCHAR(100)
);

INSERT INTO #ClientesHeap
SELECT ClienteID, Nombre, Email FROM CLIENTES;

-- Esta consulta hará TABLE SCAN (no hay índices)
SELECT * FROM #ClientesHeap WHERE Nombre = 'Juan';

DROP TABLE #ClientesHeap;

-- 3.2 CLUSTERED INDEX SCAN
-- Lee TODO el índice clustered (como leer todo un libro)
SELECT * FROM CLIENTES;

-- 3.3 CLUSTERED INDEX SEEK
-- Búsqueda directa por la clave del clustered (como ir al índice de un libro)
SELECT * FROM CLIENTES WHERE ClienteID = 100;

-- 3.4 INDEX SCAN (Non-Clustered)
-- Vamos a crear un índice para demostrar
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CLIENTES_Email')
    CREATE NONCLUSTERED INDEX IX_CLIENTES_Email ON CLIENTES(Email);

-- Esta consulta probablemente hará INDEX SCAN si buscamos con LIKE
SELECT Email FROM CLIENTES WHERE Email LIKE '%@gmail.com';

-- 3.5 INDEX SEEK (Non-Clustered)
-- Búsqueda exacta usando el índice
SELECT Email FROM CLIENTES WHERE Email = 'cliente1@email.com';

-- =====================================================================
-- PARTE 4: INDEX SCAN VS INDEX SEEK - LA DIFERENCIA CLAVE
-- =====================================================================

/*
   INDEX SEEK (🟢 BUENO):
   - Navega directamente al dato usando el B-Tree
   - Complejidad: O(log n)
   - Lectura de pocas páginas
   - IDEAL para consultas selectivas (pocas filas)
   
   INDEX SCAN (🟡 CUIDADO):
   - Lee TODAS las páginas del índice
   - Complejidad: O(n)
   - Necesario cuando no hay índice adecuado
   - O cuando se retorna gran porcentaje de la tabla
   
   REGLA: No todo Scan es malo, no todo Seek es bueno
   - Seek + Key Lookup en millones de filas = MUY MALO
   - Scan retornando 80% de la tabla = PUEDE SER ÓPTIMO
*/

-- Demostración: Seek vs Scan

-- Asegurar índice en TipoCuenta
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CUENTAS_TipoCuenta')
    CREATE NONCLUSTERED INDEX IX_CUENTAS_TipoCuenta ON CUENTAS(TipoCuenta);

-- Habilitar estadísticas de IO
SET STATISTICS IO ON;

-- CASO 1: Seek (pocas filas)
-- Buscar un tipo específico poco frecuente
SELECT CuentaID, NumeroCuenta, TipoCuenta
FROM CUENTAS
WHERE TipoCuenta = 'Inversión';  -- Probablemente pocos registros
-- Ver en plan: INDEX SEEK

-- CASO 2: Scan (muchas filas)
-- Buscar tipo muy frecuente
SELECT CuentaID, NumeroCuenta, TipoCuenta
FROM CUENTAS
WHERE TipoCuenta = 'Ahorro';  -- Probablemente muchos registros
-- Puede cambiar a SCAN si el % es alto

SET STATISTICS IO OFF;

-- =====================================================================
-- PARTE 5: KEY LOOKUP - EL ENEMIGO SILENCIOSO
-- =====================================================================

/*
   KEY LOOKUP ocurre cuando:
   1. SQL Server usa un índice non-clustered para filtrar (Seek/Scan)
   2. Pero necesita columnas que NO están en ese índice
   3. Debe "volver" al clustered index para obtenerlas
   
   IMPACTO:
   - Por cada fila del non-clustered → 1 operación adicional al clustered
   - En consultas de 10,000 filas = 10,000 Key Lookups adicionales
   - MUY COSTOSO en términos de I/O
   
   SOLUCIÓN:
   - INCLUDE columns en el índice (índice cubriente/covering index)
   - O cambiar la consulta para no necesitar esas columnas
*/

-- Demostración de Key Lookup

-- Índice solo en TipoTransaccion
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_TipoTransaccion')
    CREATE NONCLUSTERED INDEX IX_TX_TipoTransaccion 
    ON TRANSACCIONES_BANCARIAS(TipoTransaccion);

SET STATISTICS IO ON;

-- Esta consulta CAUSARÁ Key Lookup
-- El índice tiene TipoTransaccion, pero necesitamos Monto y Fecha
SELECT 
    TransaccionID,
    TipoTransaccion,
    Monto,           -- No está en el índice!
    FechaTransaccion -- No está en el índice!
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Transferencia';

-- Ver en el plan: INDEX SEEK + KEY LOOKUP
-- Notar el número de lecturas lógicas

SET STATISTICS IO OFF;

-- SOLUCIÓN: Crear índice cubriente (covering index)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_TipoTransaccion')
    DROP INDEX IX_TX_TipoTransaccion ON TRANSACCIONES_BANCARIAS;

CREATE NONCLUSTERED INDEX IX_TX_TipoTransaccion_Covering
ON TRANSACCIONES_BANCARIAS(TipoTransaccion)
INCLUDE (Monto, FechaTransaccion);

SET STATISTICS IO ON;

-- Ahora NO hay Key Lookup
SELECT 
    TransaccionID,
    TipoTransaccion,
    Monto,           -- Ahora está en INCLUDE
    FechaTransaccion -- Ahora está en INCLUDE
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Transferencia';

-- Ver en el plan: Solo INDEX SEEK (sin Key Lookup)
-- Lecturas lógicas dramáticamente reducidas

SET STATISTICS IO OFF;

-- =====================================================================
-- PARTE 6: STATISTICS IO Y STATISTICS TIME
-- =====================================================================

/*
   SET STATISTICS IO ON:
   Muestra el I/O real de cada tabla:
   
   - Scan count: Número de veces que se accedió al índice/tabla
   - Logical reads: Páginas leídas desde buffer cache (memoria)
   - Physical reads: Páginas leídas desde disco (malo si es alto)
   - Read-ahead reads: Lecturas anticipadas (prefetch)
   - Lob logical reads: Lecturas de datos LOB (varchar(max), etc.)
   
   SET STATISTICS TIME ON:
   Muestra tiempos de CPU y elapsed:
   
   - CPU time: Tiempo de procesamiento
   - Elapsed time: Tiempo total (incluye esperas)
   
   Si Elapsed >> CPU = Hay esperas (bloqueos, I/O, etc.)
*/

-- Ejemplo completo con STATISTICS
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT 
    c.Nombre AS Cliente,
    cu.NumeroCuenta,
    cu.Saldo,
    COUNT(t.TransaccionID) AS NumTransacciones,
    SUM(CASE WHEN t.TipoTransaccion = 'Depósito' THEN t.Monto ELSE 0 END) AS TotalDepositos,
    SUM(CASE WHEN t.TipoTransaccion = 'Retiro' THEN t.Monto ELSE 0 END) AS TotalRetiros
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE c.FechaRegistro >= '2024-01-01'
GROUP BY c.Nombre, cu.NumeroCuenta, cu.Saldo
ORDER BY TotalDepositos DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   INTERPRETACIÓN DE RESULTADOS:
   
   Table 'CLIENTES'. Scan count 1, logical reads 25...
   Table 'CUENTAS'. Scan count 1, logical reads 150...
   Table 'TRANSACCIONES_BANCARIAS'. Scan count 1, logical reads 8500...
   
   CPU time = 234 ms, elapsed time = 1250 ms.
   
   ANÁLISIS:
   - TRANSACCIONES tiene muchas lecturas → Candidato a optimización
   - Elapsed (1250) >> CPU (234) → Posibles esperas de I/O
*/

-- =====================================================================
-- PARTE 7: IDENTIFICACIÓN DE CUELLOS DE BOTELLA
-- =====================================================================

/*
   PATRÓN PARA IDENTIFICAR PROBLEMAS EN EL PLAN:
   
   1. Buscar el operador con MAYOR % de costo
   2. Verificar si es Scan cuando debería ser Seek
   3. Buscar Key Lookups con muchas filas
   4. Verificar "thick arrows" (flechas gruesas = muchas filas)
   5. Buscar operadores con warnings (triángulo amarillo)
   
   OPERADORES COSTOSOS COMUNES:
   - Sort (sin índice que lo soporte)
   - Hash Match (falta índice para Merge Join)
   - Table Spool (subqueries correlacionados)
   - Key Lookup (índice no cubriente)
*/

-- Consulta problemática para análisis
-- (Habilitar Ctrl+M antes de ejecutar)

SELECT 
    c.Nombre,
    c.Email,
    cu.NumeroCuenta,
    t.TipoTransaccion,
    t.Monto,
    t.FechaTransaccion
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE t.FechaTransaccion >= DATEADD(MONTH, -6, GETDATE())
  AND t.Monto > 5000
ORDER BY t.Monto DESC;

/*
   ¿QUÉ BUSCAR EN EL PLAN?
   
   1. ¿Hay SORT? → El ORDER BY está causando un Sort
      Solución: Índice en (FechaTransaccion, Monto DESC)
      
   2. ¿Hay HASH MATCH en el JOIN? → Falta índice para Nested Loops/Merge
      
   3. ¿Flechas gruesas? → Muchos datos fluyendo
      Revisar filtros, ¿se pueden hacer más selectivos?
*/

-- =====================================================================
-- PARTE 8: INTERPRETACIÓN DE COSTOS
-- =====================================================================

/*
   COSTO EN PLANES DE EJECUCIÓN:
   
   - El "costo" es una UNIDAD ABSTRACTA (no segundos ni MB)
   - Basado en: CPU, I/O, memoria estimados
   - Sirve para COMPARAR operadores, no para medir tiempo real
   
   COSTO DE SUBÁRBOL (Subtree Cost):
   - Costo acumulado de un operador + todos sus hijos
   - El operador raíz (SELECT) muestra el costo total de la consulta
   
   IMPORTANTE:
   - Costo bajo ≠ consulta rápida (estadísticas pueden mentir)
   - Siempre validar con STATISTICS IO/TIME
*/

-- Ver costo de diferentes enfoques

-- Opción 1: Sin índice específico
SELECT COUNT(*) 
FROM TRANSACCIONES_BANCARIAS 
WHERE Monto BETWEEN 1000 AND 5000;

-- Opción 2: Con índice (si existe)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_Monto')
    CREATE NONCLUSTERED INDEX IX_TX_Monto ON TRANSACCIONES_BANCARIAS(Monto);

SELECT COUNT(*) 
FROM TRANSACCIONES_BANCARIAS 
WHERE Monto BETWEEN 1000 AND 5000;

-- Comparar el "Estimated Subtree Cost" de ambas opciones

-- =====================================================================
-- PARTE 9: WARNINGS EN PLANES DE EJECUCIÓN
-- =====================================================================

/*
   WARNINGS (Triángulo amarillo ⚠️):
   
   ┌────────────────────────┬─────────────────────────────────────────┐
   │ WARNING                │ SIGNIFICADO                             │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ Missing Index          │ SQL Server sugiere un índice            │
   │ Implicit Conversion    │ Conversión de tipo evita uso de índice  │
   │ No Join Predicate      │ Cartesian product (¡muy malo!)          │
   │ Table/Index Spill      │ Sort/Hash desbordó a tempdb             │
   │ Residual Predicate     │ Filtro adicional después del Seek       │
   │ Memory Grant Warning   │ Memoria pedida vs usada muy diferente   │
   └────────────────────────┴─────────────────────────────────────────┘
*/

-- Ejemplo: IMPLICIT CONVERSION (muy común)
-- Supongamos que NumeroCuenta es VARCHAR pero buscamos con NVARCHAR

-- Crear índice en NumeroCuenta si no existe
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CUENTAS_NumeroCuenta')
    CREATE NONCLUSTERED INDEX IX_CUENTAS_NumeroCuenta ON CUENTAS(NumeroCuenta);

-- Esta consulta puede causar Implicit Conversion si los tipos no coinciden
DECLARE @NumCuenta NVARCHAR(20) = N'CTA-0001';

SELECT CuentaID, NumeroCuenta, Saldo
FROM CUENTAS
WHERE NumeroCuenta = @NumCuenta;

-- Ver el plan: Si hay warning de Implicit Conversion, el índice no se usa óptimamente
-- SOLUCIÓN: Usar el tipo de dato correcto en la variable/parámetro

-- Ejemplo: MISSING INDEX WARNING
-- SQL Server sugiere índices cuando detecta oportunidades

SELECT c.Nombre, cu.Saldo, cu.FechaApertura
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE cu.FechaApertura BETWEEN '2024-01-01' AND '2024-06-30'
  AND cu.Saldo > 10000;

-- Si aparece "Missing Index" en el plan, SQL Server sugiere:
-- CREATE INDEX IX_... ON CUENTAS(FechaApertura, Saldo) INCLUDE (ClienteID)

-- =====================================================================
-- PARTE 10: SET SHOWPLAN EN DIFERENTES FORMATOS
-- =====================================================================

/*
   FORMATOS DE PLAN:
   
   1. SHOWPLAN_TEXT - Texto plano (básico)
   2. SHOWPLAN_ALL - Texto con costos
   3. SHOWPLAN_XML - XML completo (el más detallado)
   4. STATISTICS XML - Plan real en XML
   5. STATISTICS PROFILE - Filas procesadas por operador
*/

-- SHOWPLAN_TEXT (solo muestra, no ejecuta)
SET SHOWPLAN_TEXT ON;
GO
SELECT * FROM CLIENTES WHERE ClienteID = 1;
GO
SET SHOWPLAN_TEXT OFF;
GO

-- SHOWPLAN_XML (más detallado, no ejecuta)
SET SHOWPLAN_XML ON;
GO
SELECT * FROM CLIENTES WHERE ClienteID = 1;
GO
SET SHOWPLAN_XML OFF;
GO

-- STATISTICS XML (ejecuta y muestra plan real)
SET STATISTICS XML ON;
GO
SELECT * FROM CLIENTES WHERE ClienteID = 1;
GO
SET STATISTICS XML OFF;
GO

-- =====================================================================
-- PARTE 11: CASO PRÁCTICO - OPTIMIZANDO CONSULTAS BANCARIAS
-- =====================================================================

/*
   ESCENARIO: El reporte de "Estado de Cuenta" está lento
   
   - Se ejecuta miles de veces al día
   - Promedio actual: 850ms
   - Objetivo: < 100ms
*/

-- Consulta original problemática
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT 
    c.ClienteID,
    c.Nombre,
    c.Email,
    cu.NumeroCuenta,
    cu.TipoCuenta,
    cu.Saldo,
    t.TransaccionID,
    t.TipoTransaccion,
    t.Monto,
    t.FechaTransaccion,
    t.Descripcion
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE c.ClienteID = 100
  AND (t.FechaTransaccion >= DATEADD(MONTH, -3, GETDATE()) OR t.TransaccionID IS NULL)
ORDER BY t.FechaTransaccion DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   ANÁLISIS DEL PLAN:
   
   1. ¿Hay Clustered Index Seek en CLIENTES por ClienteID? ✓
   2. ¿Hay índice en CUENTAS.ClienteID para el JOIN?
   3. ¿Hay índice en TRANSACCIONES.CuentaID + FechaTransaccion?
   4. ¿Hay Key Lookups costosos?
   5. ¿El ORDER BY causa SORT adicional?
*/

-- SOLUCIÓN: Crear índices optimizados

-- Índice para JOIN con CUENTAS
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CUENTAS_ClienteID_Inc')
    CREATE NONCLUSTERED INDEX IX_CUENTAS_ClienteID_Inc
    ON CUENTAS(ClienteID)
    INCLUDE (NumeroCuenta, TipoCuenta, Saldo);

-- Índice para TRANSACCIONES (covering)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TX_CuentaID_Fecha_Inc')
    CREATE NONCLUSTERED INDEX IX_TX_CuentaID_Fecha_Inc
    ON TRANSACCIONES_BANCARIAS(CuentaID, FechaTransaccion DESC)
    INCLUDE (TipoTransaccion, Monto, Descripcion);

-- Ejecutar de nuevo y comparar
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT 
    c.ClienteID,
    c.Nombre,
    c.Email,
    cu.NumeroCuenta,
    cu.TipoCuenta,
    cu.Saldo,
    t.TransaccionID,
    t.TipoTransaccion,
    t.Monto,
    t.FechaTransaccion,
    t.Descripcion
FROM CLIENTES c
INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE c.ClienteID = 100
  AND (t.FechaTransaccion >= DATEADD(MONTH, -3, GETDATE()) OR t.TransaccionID IS NULL)
ORDER BY t.FechaTransaccion DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

/*
   RESULTADO ESPERADO:
   
   ANTES:
   - Logical reads CLIENTES: 3
   - Logical reads CUENTAS: 150 (scan)    → Reducido
   - Logical reads TX: 8500 (key lookups) → Reducido
   - CPU time: 350ms
   
   DESPUÉS:
   - Logical reads CLIENTES: 3
   - Logical reads CUENTAS: 6 (seek)
   - Logical reads TX: 45 (seek, no key lookup)
   - CPU time: 15ms
   
   ¡Mejora de 20x+ en lecturas!
*/

-- =====================================================================
-- LIMPIEZA DE ÍNDICES DE DEMO (ejecutar al final si deseas)
-- =====================================================================
/*
DROP INDEX IF EXISTS IX_CLIENTES_Email ON CLIENTES;
DROP INDEX IF EXISTS IX_CUENTAS_TipoCuenta ON CUENTAS;
DROP INDEX IF EXISTS IX_TX_TipoTransaccion_Covering ON TRANSACCIONES_BANCARIAS;
DROP INDEX IF EXISTS IX_TX_Monto ON TRANSACCIONES_BANCARIAS;
DROP INDEX IF EXISTS IX_CUENTAS_NumeroCuenta ON CUENTAS;
DROP INDEX IF EXISTS IX_CUENTAS_ClienteID_Inc ON CUENTAS;
DROP INDEX IF EXISTS IX_TX_CuentaID_Fecha_Inc ON TRANSACCIONES_BANCARIAS;
*/

-- =====================================================================
-- RESUMEN DE LA SESIÓN
-- =====================================================================
/*
   CONCEPTOS CLAVE:
   
   1. Plan Estimado (Ctrl+L) vs Real (Ctrl+M)
   
   2. Operadores principales:
      - Clustered Index Seek/Scan
      - Index Seek/Scan  
      - Key Lookup (costoso!)
   
   3. STATISTICS IO: Mide lecturas reales
      - Logical reads = páginas en memoria
      - Physical reads = páginas de disco
   
   4. Key Lookup:
      - Problema: índice no tiene todas las columnas
      - Solución: INCLUDE columnas en el índice
   
   5. Warnings a buscar:
      - Missing Index
      - Implicit Conversion
      - Spill to tempdb
   
   6. El costo es ESTIMADO, siempre validar con STATISTICS
   
   PRÓXIMA SESIÓN:
   - Execution Plans II: Query hints, OPTION, planes forzados
*/
