-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 5
-- EJERCICIOS PRÁCTICOS: SQL PROFILER & TRACES
-- Enfoque: Identificar el SP que "cuelga" la DB
-- ============================================================

USE BancoDB;
GO

/*
╔══════════════════════════════════════════════════════════════╗
║              INSTRUCCIONES GENERALES                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Estos ejercicios simulan escenarios reales donde debes:     ║
║  1. Crear traces para capturar eventos específicos           ║
║  2. Filtrar para reducir el ruido                            ║
║  3. Analizar resultados e identificar problemas              ║
║  4. Documentar hallazgos para el equipo                      ║
║                                                              ║
║  ⚠️ REQUISITOS:                                               ║
║  • Ejecutar con permisos de sysadmin                         ║
║  • Crear carpeta C:\Temp si no existe                        ║
║  • Tener la DB BancoDB con las tablas de la sesión 1         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- ============================================================
-- PREPARACIÓN: Crear más data y SPs problemáticos
-- ============================================================

-- Insertar más transacciones para tener data suficiente
INSERT INTO TRANSACCIONES_BANCARIAS (CUENTA_ORIGEN, CUENTA_DESTINO, TIPO, MONTO, EMPLEADOID, ESTADO, FECHA)
SELECT 
    ABS(CHECKSUM(NEWID())) % 10 + 1 AS CUENTA_ORIGEN,
    ABS(CHECKSUM(NEWID())) % 10 + 2 AS CUENTA_DESTINO,
    CASE ABS(CHECKSUM(NEWID())) % 3
        WHEN 0 THEN 'DEPOSITO'
        WHEN 1 THEN 'RETIRO'
        ELSE 'TRANSFERENCIA'
    END AS TIPO,
    CAST(ABS(CHECKSUM(NEWID())) % 10000 + 100 AS DECIMAL(15,2)) AS MONTO,
    ABS(CHECKSUM(NEWID())) % 5 + 1 AS EMPLEADOID,
    'COMPLETADA' AS ESTADO,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()) AS FECHA
FROM sys.all_objects a
CROSS JOIN sys.all_objects b
WHERE a.object_id < 10 AND b.object_id < 50;

PRINT '✅ Data adicional insertada: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transacciones';
GO

-- SP con problemas de performance (para detectar)
CREATE OR ALTER PROCEDURE SP_ReporteAnualIneficiente
AS
BEGIN
    SET NOCOUNT ON;
    
    -- PROBLEMA 1: Cursor innecesario
    DECLARE @ClienteID INT;
    DECLARE @TotalSaldo DECIMAL(15,2);
    
    CREATE TABLE #ResultadoTemp (
        ClienteID INT,
        NombreCliente NVARCHAR(100),
        TotalSaldo DECIMAL(15,2),
        CantidadCuentas INT
    );
    
    DECLARE curClientes CURSOR FOR
        SELECT CLIENTEID FROM CLIENTES;
    
    OPEN curClientes;
    FETCH NEXT FROM curClientes INTO @ClienteID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- PROBLEMA 2: Consulta dentro del cursor
        INSERT INTO #ResultadoTemp
        SELECT 
            c.CLIENTEID,
            c.NOMBRE + ' ' + c.APELLIDO,
            ISNULL(SUM(cu.SALDO), 0),
            COUNT(cu.CUENTAID)
        FROM CLIENTES c
        LEFT JOIN CUENTAS cu ON c.CLIENTEID = cu.CLIENTEID
        WHERE c.CLIENTEID = @ClienteID
        GROUP BY c.CLIENTEID, c.NOMBRE, c.APELLIDO;
        
        -- PROBLEMA 3: Delay artificial por fila
        WAITFOR DELAY '00:00:00.050';  -- 50ms por cliente
        
        FETCH NEXT FROM curClientes INTO @ClienteID;
    END
    
    CLOSE curClientes;
    DEALLOCATE curClientes;
    
    SELECT * FROM #ResultadoTemp ORDER BY TotalSaldo DESC;
    DROP TABLE #ResultadoTemp;
END
GO

-- SP optimizado (para comparar)
CREATE OR ALTER PROCEDURE SP_ReporteAnualOptimizado
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Versión Set-Based (sin cursor)
    SELECT 
        c.CLIENTEID,
        c.NOMBRE + ' ' + c.APELLIDO AS NombreCliente,
        ISNULL(SUM(cu.SALDO), 0) AS TotalSaldo,
        COUNT(cu.CUENTAID) AS CantidadCuentas
    FROM CLIENTES c
    LEFT JOIN CUENTAS cu ON c.CLIENTEID = cu.CLIENTEID
    GROUP BY c.CLIENTEID, c.NOMBRE, c.APELLIDO
    ORDER BY TotalSaldo DESC;
END
GO

-- SP con problema de Table Scan
CREATE OR ALTER PROCEDURE SP_BuscarTransaccionesPorMonto
    @MontoMinimo DECIMAL(15,2),
    @MontoMaximo DECIMAL(15,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- PROBLEMA: Función en columna (no SARGable)
    SELECT 
        tb.TRANSACCIONID,
        tb.TIPO,
        tb.MONTO,
        DATEDIFF(DAY, tb.FECHA, GETDATE()) AS DiasAntiguedad,  -- OK
        c.NOMBRE + ' ' + c.APELLIDO AS Cliente
    FROM TRANSACCIONES_BANCARIAS tb
    INNER JOIN CUENTAS cu ON tb.CUENTA_ORIGEN = cu.CUENTAID
    INNER JOIN CLIENTES c ON cu.CLIENTEID = c.CLIENTEID
    WHERE CAST(tb.MONTO AS INT) BETWEEN @MontoMinimo AND @MontoMaximo  -- PROBLEMA!
    ORDER BY tb.FECHA DESC;
END
GO

PRINT '✅ SPs de prueba creados para ejercicios';
GO

-- ============================================================
-- EJERCICIO 1: CREAR TRACE BÁSICO
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 1: Mi Primer Trace con T-SQL                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  OBJETIVO:                                                   ║
║  Crear un trace que capture todas las consultas que          ║
║  duren más de 500 milisegundos en la base de datos BancoDB.  ║
║                                                              ║
║  REQUERIMIENTOS:                                             ║
║  • Capturar eventos: SQL:BatchCompleted, SP:Completed        ║
║  • Columnas: TextData, Duration, Reads, CPU, StartTime       ║
║  • Filtro: Duration > 500ms (500,000 microsegundos)          ║
║  • Filtro: Solo base de datos BancoDB                        ║
║  • Guardar en: C:\Temp\Ejercicio1_MiTrace.trc                ║
║                                                              ║
║  TIPS:                                                       ║
║  • EventClass 12 = SQL:BatchCompleted                        ║
║  • EventClass 43 = SP:Completed                              ║
║  • Column 13 = Duration (en microsegundos)                   ║
║  • Column 16 = Reads                                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TU CÓDIGO AQUÍ:
-- ================

-- Paso 1: Crear el trace
DECLARE @TraceID INT;
DECLARE @FilePath NVARCHAR(256) = N'C:\Temp\Ejercicio1_MiTrace';

-- Tu código para crear el trace...


-- Paso 2: Agregar eventos y columnas
-- Evento SQL:BatchCompleted (12)
-- ...

-- Evento SP:Completed (43)
-- ...


-- Paso 3: Agregar filtros
-- Filtro de duración > 500ms
-- ...

-- Filtro de base de datos
-- ...


-- Paso 4: Iniciar el trace
-- ...

GO

-- SOLUCIÓN EJERCICIO 1:
-- =====================
/*
DECLARE @TraceID INT;
DECLARE @FilePath NVARCHAR(256) = N'C:\Temp\Ejercicio1_MiTrace';
DECLARE @DatabaseID INT;
SELECT @DatabaseID = database_id FROM sys.databases WHERE name = 'BancoDB';

-- Crear trace
EXEC sp_trace_create @traceid = @TraceID OUTPUT, @options = 2, 
     @tracefile = @FilePath, @maxfilesize = 50;

-- Eventos SQL:BatchCompleted (12)
EXEC sp_trace_setevent @TraceID, 12, 1, 1;   -- TextData
EXEC sp_trace_setevent @TraceID, 12, 13, 1;  -- Duration
EXEC sp_trace_setevent @TraceID, 12, 14, 1;  -- StartTime
EXEC sp_trace_setevent @TraceID, 12, 16, 1;  -- Reads
EXEC sp_trace_setevent @TraceID, 12, 18, 1;  -- CPU

-- Eventos SP:Completed (43)
EXEC sp_trace_setevent @TraceID, 43, 1, 1;   -- TextData
EXEC sp_trace_setevent @TraceID, 43, 13, 1;  -- Duration
EXEC sp_trace_setevent @TraceID, 43, 14, 1;  -- StartTime
EXEC sp_trace_setevent @TraceID, 43, 16, 1;  -- Reads
EXEC sp_trace_setevent @TraceID, 43, 18, 1;  -- CPU
EXEC sp_trace_setevent @TraceID, 43, 34, 1;  -- ObjectName

-- Filtros
EXEC sp_trace_setfilter @TraceID, 13, 0, 4, 500000;  -- Duration >= 500000 μs
EXEC sp_trace_setfilter @TraceID, 3, 0, 0, @DatabaseID;  -- DatabaseID

-- Iniciar
EXEC sp_trace_setstatus @TraceID, 1;
SELECT @TraceID AS TraceID, 'Trace iniciado' AS Estado;
*/


-- ============================================================
-- EJERCICIO 2: DETECTAR EL SP PROBLEMÁTICO
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 2: Caso Práctico - El SP que cuelga la DB         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  El equipo de Operaciones reporta que la DB se pone lenta    ║
║  durante la generación de reportes mensuales.                ║
║  Sospechamos de uno de estos SPs:                            ║
║  • SP_ReporteAnualIneficiente                                ║
║  • SP_ReporteAnualOptimizado                                 ║
║  • SP_ReporteMensual                                         ║
║                                                              ║
║  TAREAS:                                                     ║
║  1. Iniciar un trace que capture SP:Completed                ║
║  2. Ejecutar los 3 SPs                                       ║
║  3. Detener el trace                                         ║
║  4. Analizar los resultados                                  ║
║  5. Identificar cuál es el SP problemático                   ║
║  6. Documentar las métricas (Duration, Reads, CPU)           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- PARTE A: Crear y iniciar trace
-- ===============================
-- Tu código aquí...


-- PARTE B: Ejecutar los SPs (después de iniciar el trace)
-- ========================================================
PRINT 'Ejecutando SP_ReporteAnualIneficiente...';
EXEC SP_ReporteAnualIneficiente;

PRINT 'Ejecutando SP_ReporteAnualOptimizado...';
EXEC SP_ReporteAnualOptimizado;

PRINT 'Ejecutando SP_ReporteMensual...';
EXEC SP_ReporteMensual @MesNumero = 1;

GO

-- PARTE C: Detener trace y analizar
-- ==================================
-- Tu código para detener y leer el trace...


-- PARTE D: Documentar hallazgos
-- =============================
/*
    Completa la siguiente tabla con tus resultados:
    
    ╔════════════════════════════════════════════════════════════════╗
    ║  STORED PROCEDURE              │ Duration(ms) │ Reads │ CPU   ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  SP_ReporteAnualIneficiente    │ _________    │ _____ │ _____ ║
    ║  SP_ReporteAnualOptimizado     │ _________    │ _____ │ _____ ║
    ║  SP_ReporteMensual             │ _________    │ _____ │ _____ ║
    ╚════════════════════════════════════════════════════════════════╝
    
    CONCLUSIÓN:
    El SP problemático es: _____________________________________
    Razón: _____________________________________________________
    
*/


-- ============================================================
-- EJERCICIO 3: MONITOREO EN TIEMPO REAL CON DMVs
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 3: Alternativa a Traces - Usar DMVs               ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  A veces no tenemos acceso para crear traces pero sí para    ║
║  consultar DMVs. Practica usar sys.dm_exec_query_stats       ║
║  para encontrar consultas problemáticas.                     ║
║                                                              ║
║  TAREAS:                                                     ║
║  1. Encontrar el TOP 5 consultas con más lecturas lógicas    ║
║  2. Encontrar el TOP 5 SPs más lentos (duración promedio)    ║
║  3. Encontrar consultas ejecutadas más de 100 veces          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- TAREA 1: TOP 5 consultas con más lecturas lógicas
-- Tu código aquí:



-- TAREA 2: TOP 5 SPs más lentos por duración promedio
-- Tu código aquí:



-- TAREA 3: Consultas ejecutadas más de 100 veces
-- Tu código aquí:



-- SOLUCIÓN TAREA 1:
/*
SELECT TOP 5
    SUBSTRING(st.text, 1, 200) AS ConsultaSQL,
    qs.execution_count AS Ejecuciones,
    qs.total_logical_reads AS TotalLecturas,
    qs.total_logical_reads / qs.execution_count AS LecturasPorEjecucion,
    qs.total_elapsed_time / 1000 AS TotalMS
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_reads DESC;
*/


-- ============================================================
-- EJERCICIO 4: TRACE PARA DEADLOCKS (AVANZADO)
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 4: Configurar Captura de Deadlocks                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  El sistema de core bancario reporta errores 1205 (deadlock) ║
║  de forma esporádica. Necesitas capturar el próximo          ║
║  deadlock para analizar qué lo está causando.                ║
║                                                              ║
║  TAREAS:                                                     ║
║  1. Crear un trace que capture SOLO eventos de deadlock      ║
║  2. El trace debe incluir el Deadlock Graph (XML)            ║
║  3. Mantenerlo activo por 24 horas mínimo                    ║
║  4. Crear un script para detener y analizar                  ║
║                                                              ║
║  EVENTOS NECESARIOS:                                         ║
║  • Lock:Deadlock (EventClass 25)                             ║
║  • Deadlock Graph (EventClass 148)                           ║
║  • Lock:Deadlock Chain (EventClass 59) - Opcional            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- Tu código aquí:



-- BONUS: Script para simular un Deadlock (para probar tu trace)
/*
    Abre DOS ventanas de SSMS y ejecuta:
    
    -- SESIÓN 1:
    BEGIN TRANSACTION;
    UPDATE CUENTAS SET SALDO = SALDO + 100 WHERE CUENTAID = 1;
    WAITFOR DELAY '00:00:05';
    UPDATE CUENTAS SET SALDO = SALDO - 100 WHERE CUENTAID = 2;
    COMMIT;
    
    -- SESIÓN 2 (ejecutar inmediatamente después):
    BEGIN TRANSACTION;
    UPDATE CUENTAS SET SALDO = SALDO + 100 WHERE CUENTAID = 2;
    WAITFOR DELAY '00:00:05';
    UPDATE CUENTAS SET SALDO = SALDO - 100 WHERE CUENTAID = 1;
    COMMIT;
    
    Una de las sesiones será elegida como "víctima" del deadlock.
*/


-- ============================================================
-- EJERCICIO 5: ANÁLISIS DE TRACE FILE
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 5: Análisis Post-Mortem de un Trace               ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO:                                                  ║
║  Te entregan un archivo .trc de producción y debes extraer   ║
║  métricas importantes para un reporte de incidentes.         ║
║                                                              ║
║  (Simularemos creando y leyendo un trace)                    ║
║                                                              ║
║  TAREAS:                                                     ║
║  1. Crear consulta que muestre TOP 10 consultas más lentas   ║
║  2. Agrupar por ApplicationName y mostrar totales            ║
║  3. Identificar horarios con más actividad (por hora)        ║
║  4. Calcular percentil 95 de duración                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- Si tienes un archivo .trc, usa esta plantilla:
/*
DECLARE @TraceFile NVARCHAR(256) = N'C:\Temp\MiArchivo.trc';

-- TAREA 1: TOP 10 más lentas
SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY Duration DESC) AS Ranking,
    Duration / 1000 AS DuracionMS,
    Reads AS LecturasLogicas,
    CPU,
    LEFT(CAST(TextData AS NVARCHAR(200)), 100) AS Consulta,
    StartTime
FROM fn_trace_gettable(@TraceFile, DEFAULT)
WHERE Duration IS NOT NULL
ORDER BY Duration DESC;

-- TAREA 2: Agrupar por aplicación
SELECT 
    ISNULL(ApplicationName, 'Desconocido') AS Aplicacion,
    COUNT(*) AS TotalConsultas,
    SUM(Duration) / 1000000 AS TotalSegundos,
    AVG(Duration) / 1000 AS PromedioMS,
    MAX(Duration) / 1000 AS MaximoMS,
    SUM(Reads) AS TotalLecturas
FROM fn_trace_gettable(@TraceFile, DEFAULT)
WHERE Duration IS NOT NULL
GROUP BY ApplicationName
ORDER BY SUM(Duration) DESC;

-- TAREA 3: Actividad por hora
SELECT 
    DATEPART(HOUR, StartTime) AS Hora,
    COUNT(*) AS CantidadConsultas,
    AVG(Duration) / 1000 AS PromedioDuracionMS
FROM fn_trace_gettable(@TraceFile, DEFAULT)
WHERE Duration IS NOT NULL
GROUP BY DATEPART(HOUR, StartTime)
ORDER BY Hora;

-- TAREA 4: Percentil 95
SELECT DISTINCT
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Duration / 1000) 
        OVER () AS P95_DuracionMS,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY Duration / 1000) 
        OVER () AS P99_DuracionMS
FROM fn_trace_gettable(@TraceFile, DEFAULT)
WHERE Duration IS NOT NULL;
*/


-- ============================================================
-- EJERCICIO 6: CREAR SP DE DIAGNÓSTICO REUTILIZABLE
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO 6: SP de Diagnóstico Integral                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  OBJETIVO:                                                   ║
║  Crear un SP que un DBA pueda ejecutar para obtener          ║
║  rápidamente información de diagnóstico sin usar Profiler.   ║
║                                                              ║
║  EL SP DEBE MOSTRAR:                                         ║
║  1. TOP 5 consultas más lentas (últimas 24 horas)            ║
║  2. TOP 5 SPs más ejecutados                                 ║
║  3. Consultas con muchas lecturas lógicas (>10000)           ║
║  4. Sesiones activas con transacciones abiertas              ║
║  5. Bloqueos actuales (si hay)                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE SP_DiagnosticoRapido
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '═══════════════════════════════════════════════════════════════';
    PRINT '              DIAGNÓSTICO RÁPIDO DE BASE DE DATOS';
    PRINT '═══════════════════════════════════════════════════════════════';
    PRINT '';
    
    -- SECCIÓN 1: TOP 5 consultas más lentas
    PRINT '▶ TOP 5 CONSULTAS MÁS LENTAS:';
    -- Tu código aquí...
    
    
    -- SECCIÓN 2: TOP 5 SPs más ejecutados
    PRINT '';
    PRINT '▶ TOP 5 STORED PROCEDURES MÁS EJECUTADOS:';
    -- Tu código aquí...
    
    
    -- SECCIÓN 3: Consultas con muchas lecturas
    PRINT '';
    PRINT '▶ CONSULTAS CON MÁS DE 10,000 LECTURAS LÓGICAS:';
    -- Tu código aquí...
    
    
    -- SECCIÓN 4: Sesiones con transacciones abiertas
    PRINT '';
    PRINT '▶ SESIONES CON TRANSACCIONES ABIERTAS:';
    -- Tu código aquí...
    
    
    -- SECCIÓN 5: Bloqueos actuales
    PRINT '';
    PRINT '▶ BLOQUEOS ACTUALES:';
    -- Tu código aquí...
    
END
GO


-- ============================================================
-- EJERCICIO FINAL: CASO INTEGRADOR
-- ============================================================
/*
╔══════════════════════════════════════════════════════════════╗
║  EJERCICIO FINAL: El Caso del Cierre Mensual Lento           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ESCENARIO COMPLETO:                                         ║
║                                                              ║
║  El proceso de cierre mensual del banco tarda 4 horas        ║
║  cuando debería tardar máximo 30 minutos. Los usuarios       ║
║  reportan que el sistema está "congelado" durante este       ║
║  tiempo.                                                     ║
║                                                              ║
║  INFORMACIÓN DISPONIBLE:                                     ║
║  • El cierre ejecuta estos SPs en orden:                     ║
║    1. SP_ReporteMensual                                      ║
║    2. SP_ReporteAnualIneficiente                             ║
║    3. SP_TransferenciaMasiva                                 ║
║    4. SP_BuscarTransaccionesPorMonto                         ║
║                                                              ║
║  MISIÓN:                                                     ║
║  1. Crear trace para capturar la ejecución de estos SPs      ║
║  2. Ejecutar cada SP y capturar métricas                     ║
║  3. Analizar el trace e identificar los cuellos de botella   ║
║  4. Crear reporte con recomendaciones                        ║
║  5. Proponer versiones optimizadas (si es posible)           ║
║                                                              ║
║  ENTREGABLE:                                                 ║
║  Script con el análisis y reporte final                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
*/

-- ===============================
-- PASO 1: Crear Trace
-- ===============================



-- ===============================
-- PASO 2: Ejecutar los SPs
-- ===============================
PRINT 'Ejecutando proceso de cierre mensual simulado...';
PRINT '';

-- SP 1
PRINT '1. Ejecutando SP_ReporteMensual...';
DECLARE @InicioSP1 DATETIME2 = SYSDATETIME();
EXEC SP_ReporteMensual @MesNumero = 3;
PRINT '   Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioSP1, SYSDATETIME()) AS VARCHAR) + ' ms';
PRINT '';

-- SP 2
PRINT '2. Ejecutando SP_ReporteAnualIneficiente...';
DECLARE @InicioSP2 DATETIME2 = SYSDATETIME();
EXEC SP_ReporteAnualIneficiente;
PRINT '   Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioSP2, SYSDATETIME()) AS VARCHAR) + ' ms';
PRINT '';

-- SP 3
PRINT '3. Ejecutando SP_TransferenciaMasiva...';
DECLARE @InicioSP3 DATETIME2 = SYSDATETIME();
EXEC SP_TransferenciaMasiva @CuentaOrigen = 1, @MontoTotal = 1000.00;
PRINT '   Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioSP3, SYSDATETIME()) AS VARCHAR) + ' ms';
PRINT '';

-- SP 4
PRINT '4. Ejecutando SP_BuscarTransaccionesPorMonto...';
DECLARE @InicioSP4 DATETIME2 = SYSDATETIME();
EXEC SP_BuscarTransaccionesPorMonto @MontoMinimo = 100, @MontoMaximo = 5000;
PRINT '   Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioSP4, SYSDATETIME()) AS VARCHAR) + ' ms';
PRINT '';

GO

-- ===============================
-- PASO 3: Detener Trace y Analizar
-- ===============================



-- ===============================
-- PASO 4: Tu Reporte Final
-- ===============================
/*
═══════════════════════════════════════════════════════════════════════════════
                    REPORTE DE ANÁLISIS DE PERFORMANCE
                    Proceso: Cierre Mensual BancoDB
                    Analista: ______________________
                    Fecha: _________________________
═══════════════════════════════════════════════════════════════════════════════

RESUMEN EJECUTIVO:
──────────────────
[Tu resumen aquí]


HALLAZGOS POR STORED PROCEDURE:
───────────────────────────────

1. SP_ReporteMensual
   - Duración: _____ ms
   - Lecturas: _____
   - Diagnóstico: _______________
   - Recomendación: _____________

2. SP_ReporteAnualIneficiente
   - Duración: _____ ms
   - Lecturas: _____
   - Diagnóstico: _______________
   - Recomendación: _____________

3. SP_TransferenciaMasiva
   - Duración: _____ ms
   - Lecturas: _____
   - Diagnóstico: _______________
   - Recomendación: _____________

4. SP_BuscarTransaccionesPorMonto
   - Duración: _____ ms
   - Lecturas: _____
   - Diagnóstico: _______________
   - Recomendación: _____________


PLAN DE ACCIÓN PROPUESTO:
─────────────────────────
Prioridad Alta:
1. _________________________________
2. _________________________________

Prioridad Media:
1. _________________________________
2. _________________________________


MEJORA ESPERADA:
────────────────
Tiempo actual: ~4 horas
Tiempo estimado después de optimización: ____ minutos
Porcentaje de mejora: ____%

═══════════════════════════════════════════════════════════════════════════════
*/


-- ============================================================
-- LIMPIEZA FINAL
-- ============================================================

-- Script para limpiar todos los traces que puedan haber quedado abiertos
DECLARE @TraceID INT;
DECLARE curTraces CURSOR FOR
    SELECT id FROM sys.traces WHERE id > 1;  -- El trace 1 es el default

OPEN curTraces;
FETCH NEXT FROM curTraces INTO @TraceID;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_trace_setstatus @TraceID, 0;  -- Detener
    EXEC sp_trace_setstatus @TraceID, 2;  -- Cerrar
    PRINT 'Trace ' + CAST(@TraceID AS VARCHAR) + ' cerrado.';
    FETCH NEXT FROM curTraces INTO @TraceID;
END

CLOSE curTraces;
DEALLOCATE curTraces;

PRINT '';
PRINT '✅ Limpieza completada. Todos los traces cerrados.';
GO


-- ============================================================
PRINT '';
PRINT '╔══════════════════════════════════════════════════════════════╗';
PRINT '║           EJERCICIOS COMPLETADOS - SESIÓN 5                  ║';
PRINT '╠══════════════════════════════════════════════════════════════╣';
PRINT '║                                                              ║';
PRINT '║  APRENDISTE:                                                 ║';
PRINT '║  ✓ Crear Server-Side Traces con T-SQL                        ║';
PRINT '║  ✓ Filtrar eventos para reducir ruido                        ║';
PRINT '║  ✓ Identificar SPs problemáticos                             ║';
PRINT '║  ✓ Usar DMVs como alternativa a Traces                       ║';
PRINT '║  ✓ Analizar archivos .trc                                    ║';
PRINT '║  ✓ Crear herramientas de diagnóstico reutilizables           ║';
PRINT '║                                                              ║';
PRINT '║  PRÓXIMA SESIÓN:                                             ║';
PRINT '║  Extended Events (XEvents) - El reemplazo moderno            ║';
PRINT '║                                                              ║';
PRINT '╚══════════════════════════════════════════════════════════════╝';
GO
