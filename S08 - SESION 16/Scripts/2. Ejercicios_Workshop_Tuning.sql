/*
================================================================================
        SQL INTERMEDIO 2026 - SESIÓN 16: EJERCICIOS
        WORKSHOP FINAL DE TUNING - CASOS PRÁCTICOS
        🎓 SESIÓN FINAL DEL CURSO
================================================================================
Base de datos: BancoDB
Nivel: Avanzado

INSTRUCCIONES:
    • Estos ejercicios integran TODOS los conceptos del curso
    • Cada ejercicio presenta un problema de rendimiento real
    • Debes diagnosticar, proponer y aplicar la solución
    • Se espera que uses el plan de ejecución para validar mejoras
================================================================================
*/

USE BancoDB;
GO

-- ============================================================================
-- EJERCICIO 1: ANÁLISIS DE PLAN DE EJECUCIÓN
-- Identificar problemas en una query existente
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
La siguiente consulta tarda demasiado. Analiza el plan de ejecución y:
1. Identifica qué operadores consumen más recursos
2. Detecta si hay Table Scans que deberían ser Index Seeks
3. Propón índices para mejorar el rendimiento
4. Implementa la solución y compara tiempos
*/

-- Query a analizar
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Incluir Plan de Ejecución Real (Ctrl+M en SSMS)
SELECT 
    c.NumeroCliente,
    c.Nombre,
    c.Apellido,
    COUNT(t.TransaccionID) AS TotalTransacciones,
    SUM(CASE WHEN t.TipoTransaccion = 'DEPOSITO' THEN t.Monto ELSE 0 END) AS TotalDepositos,
    SUM(CASE WHEN t.TipoTransaccion = 'RETIRO' THEN t.Monto ELSE 0 END) AS TotalRetiros
FROM dbo.CLIENTES_WS c
LEFT JOIN dbo.CUENTAS_WS cu ON c.ClienteID = cu.ClienteID
LEFT JOIN dbo.TRANSACCIONES_WS t ON cu.CuentaID = t.CuentaOrigenID
WHERE c.TipoCliente = 'VIP'
  AND t.FechaTransaccion >= '2025-01-01'
GROUP BY c.NumeroCliente, c.Nombre, c.Apellido
HAVING COUNT(t.TransaccionID) > 10
ORDER BY TotalTransacciones DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- SOLUCIÓN EJERCICIO 1:

/*
DIAGNÓSTICO ESPERADO:
1. Table Scan en CLIENTES_WS (sin índice en TipoCliente)
2. Table Scan en TRANSACCIONES_WS (sin índice en FechaTransaccion + CuentaOrigenID)
3. Hash Match costoso por falta de índices

SOLUCIÓN:
*/

-- Índice para filtro de TipoCliente
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CLIENTES_WS_TipoCliente')
CREATE NONCLUSTERED INDEX IX_CLIENTES_WS_TipoCliente
ON dbo.CLIENTES_WS (TipoCliente)
INCLUDE (NumeroCliente, Nombre, Apellido);
GO

-- Índice para filtro de fecha y JOIN en transacciones
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TRANS_WS_CuentaOrigen_Fecha')
CREATE NONCLUSTERED INDEX IX_TRANS_WS_CuentaOrigen_Fecha
ON dbo.TRANSACCIONES_WS (CuentaOrigenID, FechaTransaccion)
INCLUDE (TipoTransaccion, Monto);
GO

-- Verificar mejora ejecutando la query nuevamente
-- El plan debería mostrar Index Seeks en lugar de Table Scans

PRINT 'Ejercicio 1: Índices creados. Ejecutar query nuevamente para comparar.';
GO

-- ============================================================================
-- EJERCICIO 2: ELIMINAR CURSOR Y USAR SET-BASED
-- Refactorizar proceso que usa cursor
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
El siguiente procedimiento usa un cursor para calcular comisiones.
Actualmente tarda ~30 segundos para 10,000 transacciones.
Refactorízalo para usar operaciones SET-BASED y reducir a <2 segundos.
*/

-- Versión con CURSOR (PROBLEMÁTICA)
CREATE OR ALTER PROCEDURE dbo.SP_CalcularComisiones_CURSOR
    @FechaProceso DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TransaccionID BIGINT;
    DECLARE @Monto FLOAT;
    DECLARE @TipoTrans VARCHAR(50);
    DECLARE @Comision FLOAT;
    DECLARE @Total INT = 0;
    
    -- Tabla para resultados
    IF OBJECT_ID('tempdb..#Comisiones') IS NOT NULL DROP TABLE #Comisiones;
    CREATE TABLE #Comisiones (
        TransaccionID BIGINT,
        MontoOriginal FLOAT,
        Comision FLOAT
    );
    
    -- CURSOR - LENTO!
    DECLARE cur CURSOR FOR
        SELECT TransaccionID, Monto, TipoTransaccion
        FROM dbo.TRANSACCIONES_WS
        WHERE CAST(FechaTransaccion AS DATE) = @FechaProceso
          AND Estado = 'COMPLETADA';
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @TransaccionID, @Monto, @TipoTrans;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calcular comisión según tipo
        SET @Comision = CASE @TipoTrans
            WHEN 'TRANSFERENCIA' THEN @Monto * 0.01
            WHEN 'RETIRO' THEN 
                CASE WHEN @Monto > 10000 THEN 50 ELSE 25 END
            WHEN 'PAGO_SERVICIO' THEN @Monto * 0.005
            ELSE 0
        END;
        
        INSERT INTO #Comisiones VALUES (@TransaccionID, @Monto, @Comision);
        SET @Total += 1;
        
        FETCH NEXT FROM cur INTO @TransaccionID, @Monto, @TipoTrans;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
    
    SELECT * FROM #Comisiones WHERE Comision > 0;
    PRINT 'Procesadas: ' + CAST(@Total AS VARCHAR);
END;
GO

-- SOLUCIÓN EJERCICIO 2: Versión SET-BASED

CREATE OR ALTER PROCEDURE dbo.SP_CalcularComisiones_SETBASED
    @FechaProceso DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Una sola operación SET-BASED
    SELECT 
        TransaccionID,
        Monto AS MontoOriginal,
        CASE TipoTransaccion
            WHEN 'TRANSFERENCIA' THEN Monto * 0.01
            WHEN 'RETIRO' THEN 
                CASE WHEN Monto > 10000 THEN 50.0 ELSE 25.0 END
            WHEN 'PAGO_SERVICIO' THEN Monto * 0.005
            ELSE 0
        END AS Comision
    FROM dbo.TRANSACCIONES_WS
    WHERE CAST(FechaTransaccion AS DATE) = @FechaProceso
      AND Estado = 'COMPLETADA'
      AND TipoTransaccion IN ('TRANSFERENCIA', 'RETIRO', 'PAGO_SERVICIO');
    
    PRINT 'Procesadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
END;
GO

-- Comparar rendimiento
DECLARE @Fecha DATE = CAST(GETDATE() AS DATE);

PRINT '=== Con CURSOR ===';
SET STATISTICS TIME ON;
EXEC dbo.SP_CalcularComisiones_CURSOR @Fecha;
SET STATISTICS TIME OFF;

PRINT '';
PRINT '=== SET-BASED ===';
SET STATISTICS TIME ON;
EXEC dbo.SP_CalcularComisiones_SETBASED @Fecha;
SET STATISTICS TIME OFF;
GO

-- ============================================================================
-- EJERCICIO 3: OPTIMIZAR PROCESO DE BATCHING
-- Implementar proceso masivo con control de transacciones
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Se necesita actualizar el estado de 100,000 cuentas inactivas
(sin movimientos en 1 año). Un UPDATE directo bloquea la tabla por minutos.

REQUISITOS:
1. Usar batching de 5,000 registros
2. COMMIT después de cada batch
3. Mostrar progreso
4. Registrar tiempo total
*/

-- SOLUCIÓN EJERCICIO 3:

CREATE OR ALTER PROCEDURE dbo.SP_MarcarCuentasInactivas
    @DiasInactividad INT = 365,
    @TamañoBatch INT = 5000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalActualizadas BIGINT = 0;
    DECLARE @BatchActualizadas INT = 1;
    DECLARE @FechaCorte DATE = DATEADD(DAY, -@DiasInactividad, GETDATE());
    DECLARE @InicioProc DATETIME2 = SYSDATETIME();
    
    -- Contar total a procesar
    DECLARE @TotalAProcesar INT;
    SELECT @TotalAProcesar = COUNT(*)
    FROM dbo.CUENTAS_WS
    WHERE Estado = 'ACTIVA'
      AND (FechaUltimoMov IS NULL OR FechaUltimoMov < @FechaCorte);
    
    PRINT '=====================================================';
    PRINT '  MARCAR CUENTAS INACTIVAS';
    PRINT '=====================================================';
    PRINT 'Cuentas a procesar: ' + CAST(@TotalAProcesar AS VARCHAR);
    PRINT 'Tamaño de batch: ' + CAST(@TamañoBatch AS VARCHAR);
    PRINT '-----------------------------------------------------';
    
    IF @TotalAProcesar = 0
    BEGIN
        PRINT 'No hay cuentas para procesar.';
        RETURN;
    END
    
    -- Procesar en batches
    WHILE @BatchActualizadas > 0
    BEGIN
        -- Cada batch es una transacción independiente
        BEGIN TRANSACTION;
        
        UPDATE TOP (@TamañoBatch) dbo.CUENTAS_WS
        SET Estado = 'INACTIVA'
        WHERE Estado = 'ACTIVA'
          AND (FechaUltimoMov IS NULL OR FechaUltimoMov < @FechaCorte);
        
        SET @BatchActualizadas = @@ROWCOUNT;
        SET @TotalActualizadas += @BatchActualizadas;
        
        COMMIT TRANSACTION;
        
        -- Mostrar progreso
        IF @BatchActualizadas > 0
        BEGIN
            PRINT 'Batch completado: ' + CAST(@TotalActualizadas AS VARCHAR) + 
                  ' / ' + CAST(@TotalAProcesar AS VARCHAR) +
                  ' (' + CAST(CAST(@TotalActualizadas * 100.0 / @TotalAProcesar AS INT) AS VARCHAR) + '%)';
        END
    END
    
    PRINT '-----------------------------------------------------';
    PRINT 'COMPLETADO';
    PRINT 'Total actualizadas: ' + CAST(@TotalActualizadas AS VARCHAR);
    PRINT 'Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioProc, SYSDATETIME()) AS VARCHAR) + ' ms';
END;
GO

-- Probar (modo de solo lectura, sin ejecutar updates reales)
-- EXEC dbo.SP_MarcarCuentasInactivas @DiasInactividad = 365, @TamañoBatch = 5000;

PRINT 'Ejercicio 3: Procedimiento de batching creado.';
GO

-- ============================================================================
-- EJERCICIO 4: CREAR ÍNDICE FILTRADO
-- Optimizar consultas que filtran por estado específico
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
El 95% de las consultas de transacciones filtran por Estado = 'PENDIENTE',
pero este estado representa solo el 5% de los datos.
Un índice normal incluiría todos los registros innecesariamente.

TAREA:
Crear un índice filtrado que solo incluya transacciones pendientes.
*/

-- SOLUCIÓN EJERCICIO 4:

-- Índice filtrado para transacciones pendientes
CREATE NONCLUSTERED INDEX IX_TRANS_WS_Pendientes_Filtered
ON dbo.TRANSACCIONES_WS (FechaTransaccion, CuentaOrigenID)
INCLUDE (Monto, TipoTransaccion, Referencia)
WHERE Estado = 'PENDIENTE';
GO

-- Query que aprovecha el índice filtrado
SELECT 
    FechaTransaccion,
    CuentaOrigenID,
    TipoTransaccion,
    Monto
FROM dbo.TRANSACCIONES_WS
WHERE Estado = 'PENDIENTE'
  AND FechaTransaccion >= DATEADD(HOUR, -24, GETDATE())
ORDER BY FechaTransaccion DESC;
GO

PRINT 'Ejercicio 4: Índice filtrado creado.';
GO

-- ============================================================================
-- EJERCICIO 5: IMPLEMENTAR PAGINACIÓN EFICIENTE
-- Usar OFFSET-FETCH correctamente
-- Nivel: Intermedio
-- ============================================================================

/*
PROBLEMA:
La aplicación web necesita mostrar transacciones paginadas.
La implementación actual usa ROW_NUMBER() subconsulta que es lenta para páginas altas.

REQUISITOS:
1. Implementar con OFFSET-FETCH
2. Retornar metadatos de paginación
3. Incluir conteo total optimizado
*/

-- SOLUCIÓN EJERCICIO 5:

CREATE OR ALTER PROCEDURE dbo.SP_TransaccionesPaginadas
    @CuentaID INT,
    @Pagina INT = 1,
    @TamañoPagina INT = 20,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Valores por defecto
    SET @FechaDesde = ISNULL(@FechaDesde, DATEADD(MONTH, -1, GETDATE()));
    SET @FechaHasta = ISNULL(@FechaHasta, GETDATE());
    
    -- Calcular OFFSET
    DECLARE @Offset INT = (@Pagina - 1) * @TamañoPagina;
    
    -- Conteo total (optimizado con COUNT_BIG)
    DECLARE @TotalRegistros BIGINT;
    
    SELECT @TotalRegistros = COUNT_BIG(*)
    FROM dbo.TRANSACCIONES_WS
    WHERE CuentaOrigenID = @CuentaID
      AND FechaTransaccion BETWEEN @FechaDesde AND @FechaHasta;
    
    -- Calcular metadatos de paginación
    DECLARE @TotalPaginas INT = CEILING(@TotalRegistros * 1.0 / @TamañoPagina);
    
    -- Resultados paginados con OFFSET-FETCH
    SELECT 
        TransaccionID,
        TipoTransaccion,
        CAST(Monto AS DECIMAL(18,2)) AS Monto,
        Estado,
        FORMAT(FechaTransaccion, 'dd/MM/yyyy HH:mm') AS Fecha,
        Referencia,
        -- Metadatos de paginación en cada fila
        @Pagina AS PaginaActual,
        @TotalPaginas AS TotalPaginas,
        @TotalRegistros AS TotalRegistros
    FROM dbo.TRANSACCIONES_WS
    WHERE CuentaOrigenID = @CuentaID
      AND FechaTransaccion BETWEEN @FechaDesde AND @FechaHasta
    ORDER BY FechaTransaccion DESC
    OFFSET @Offset ROWS
    FETCH NEXT @TamañoPagina ROWS ONLY;
END;
GO

-- Probar paginación
EXEC dbo.SP_TransaccionesPaginadas @CuentaID = 1, @Pagina = 1, @TamañoPagina = 10;
GO

PRINT 'Ejercicio 5: Procedimiento de paginación creado.';
GO

-- ============================================================================
-- EJERCICIO 6: QUERY CON CTE Y WINDOW FUNCTIONS
-- Calcular ranking y acumulados en una sola pasada
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
El negocio necesita un reporte de "Top Clientes" que muestre:
1. Ranking por monto total movido
2. Porcentaje del total que representa cada cliente
3. Monto acumulado (running total)
4. Comparación con cliente anterior

Implementar de forma eficiente usando CTE y Window Functions.
*/

-- SOLUCIÓN EJERCICIO 6:

CREATE OR ALTER PROCEDURE dbo.SP_ReporteTopClientes
    @TopN INT = 100,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @FechaDesde = ISNULL(@FechaDesde, DATEADD(MONTH, -1, GETDATE()));
    SET @FechaHasta = ISNULL(@FechaHasta, GETDATE());
    
    ;WITH MovimientosCliente AS (
        -- Primer nivel: agregar por cliente
        SELECT 
            c.ClienteID,
            c.NumeroCliente,
            c.Nombre + ' ' + c.Apellido AS NombreCompleto,
            c.TipoCliente,
            COUNT(t.TransaccionID) AS NumTransacciones,
            SUM(t.Monto) AS MontoTotal
        FROM dbo.CLIENTES_WS c
        INNER JOIN dbo.CUENTAS_WS cu ON c.ClienteID = cu.ClienteID
        INNER JOIN dbo.TRANSACCIONES_WS t ON cu.CuentaID = t.CuentaOrigenID
        WHERE t.FechaTransaccion BETWEEN @FechaDesde AND @FechaHasta
          AND t.Estado = 'COMPLETADA'
        GROUP BY c.ClienteID, c.NumeroCliente, c.Nombre, c.Apellido, c.TipoCliente
    ),
    ClientesRankeados AS (
        -- Segundo nivel: calcular métricas con Window Functions
        SELECT 
            NumeroCliente,
            NombreCompleto,
            TipoCliente,
            NumTransacciones,
            MontoTotal,
            
            -- Ranking
            ROW_NUMBER() OVER (ORDER BY MontoTotal DESC) AS Ranking,
            DENSE_RANK() OVER (ORDER BY MontoTotal DESC) AS DenseRanking,
            
            -- Percentil
            PERCENT_RANK() OVER (ORDER BY MontoTotal) AS Percentil,
            
            -- Porcentaje del total
            MontoTotal * 100.0 / SUM(MontoTotal) OVER () AS PorcentajeTotal,
            
            -- Acumulado (running total)
            SUM(MontoTotal) OVER (ORDER BY MontoTotal DESC 
                                  ROWS UNBOUNDED PRECEDING) AS MontoAcumulado,
            
            -- Comparación con anterior
            MontoTotal - LAG(MontoTotal, 1, MontoTotal) OVER (ORDER BY MontoTotal DESC) AS DiferenciaAnterior,
            
            -- Total general para referencia
            SUM(MontoTotal) OVER () AS TotalGeneral
        FROM MovimientosCliente
    )
    SELECT TOP (@TopN)
        Ranking,
        NumeroCliente,
        NombreCompleto,
        TipoCliente,
        NumTransacciones,
        FORMAT(MontoTotal, 'C', 'es-MX') AS MontoTotal,
        FORMAT(PorcentajeTotal, 'N2') + '%' AS PorcentajeDelTotal,
        FORMAT(MontoAcumulado, 'C', 'es-MX') AS MontoAcumulado,
        FORMAT(MontoAcumulado * 100.0 / TotalGeneral, 'N2') + '%' AS PorcentajeAcumulado,
        FORMAT(DiferenciaAnterior, 'C', 'es-MX') AS DiferenciaVsAnterior,
        CASE 
            WHEN Percentil >= 0.95 THEN 'Top 5%'
            WHEN Percentil >= 0.90 THEN 'Top 10%'
            WHEN Percentil >= 0.75 THEN 'Top 25%'
            ELSE 'Regular'
        END AS Categoria
    FROM ClientesRankeados
    ORDER BY Ranking;
END;
GO

-- Ejecutar reporte
EXEC dbo.SP_ReporteTopClientes @TopN = 20;
GO

PRINT 'Ejercicio 6: Reporte con CTE y Window Functions creado.';
GO

-- ============================================================================
-- EJERCICIO 7: SQL DINÁMICO SEGURO PARA BÚSQUEDA FLEXIBLE
-- Implementar búsqueda con múltiples filtros opcionales
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Se necesita un procedimiento de búsqueda de transacciones donde todos
los parámetros son opcionales. Debe ser seguro contra SQL Injection.

PARÁMETROS:
- @CuentaID (opcional)
- @TipoTransaccion (opcional, puede ser múltiple separado por comas)
- @MontoMinimo (opcional)
- @MontoMaximo (opcional)
- @FechaDesde (opcional)
- @FechaHasta (opcional)
- @Estado (opcional)
- @CanalOrigen (opcional)
*/

-- SOLUCIÓN EJERCICIO 7:

CREATE OR ALTER PROCEDURE dbo.SP_BusquedaTransacciones
    @CuentaID INT = NULL,
    @TiposTransaccion VARCHAR(200) = NULL,  -- Ej: 'DEPOSITO,RETIRO,TRANSFERENCIA'
    @MontoMinimo DECIMAL(18,2) = NULL,
    @MontoMaximo DECIMAL(18,2) = NULL,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL,
    @Estado VARCHAR(20) = NULL,
    @CanalOrigen VARCHAR(50) = NULL,
    @TopN INT = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @Where NVARCHAR(MAX) = N' WHERE 1=1 ';
    
    -- Construir query base
    SET @SQL = N'
        SELECT TOP (@TopN)
            t.TransaccionID,
            t.CuentaOrigenID,
            t.CuentaDestinoID,
            t.TipoTransaccion,
            CAST(t.Monto AS DECIMAL(18,2)) AS Monto,
            t.Estado,
            t.FechaTransaccion,
            t.CanalOrigen,
            t.Referencia
        FROM dbo.TRANSACCIONES_WS t
    ';
    
    -- Agregar filtros dinámicamente (de forma segura)
    IF @CuentaID IS NOT NULL
        SET @Where += N' AND t.CuentaOrigenID = @pCuentaID ';
    
    IF @TiposTransaccion IS NOT NULL
    BEGIN
        -- Usar tabla temporal para filtro de múltiples tipos
        SET @Where += N' AND t.TipoTransaccion IN (SELECT value FROM STRING_SPLIT(@pTiposTransaccion, '','')) ';
    END
    
    IF @MontoMinimo IS NOT NULL
        SET @Where += N' AND t.Monto >= @pMontoMinimo ';
    
    IF @MontoMaximo IS NOT NULL
        SET @Where += N' AND t.Monto <= @pMontoMaximo ';
    
    IF @FechaDesde IS NOT NULL
        SET @Where += N' AND t.FechaTransaccion >= @pFechaDesde ';
    
    IF @FechaHasta IS NOT NULL
        SET @Where += N' AND t.FechaTransaccion <= @pFechaHasta ';
    
    IF @Estado IS NOT NULL
        SET @Where += N' AND t.Estado = @pEstado ';
    
    IF @CanalOrigen IS NOT NULL
        SET @Where += N' AND t.CanalOrigen = @pCanalOrigen ';
    
    -- Agregar ORDER BY
    SET @SQL = @SQL + @Where + N' ORDER BY t.FechaTransaccion DESC ';
    
    -- Definir parámetros (previene SQL Injection)
    SET @Parametros = N'
        @TopN INT,
        @pCuentaID INT,
        @pTiposTransaccion VARCHAR(200),
        @pMontoMinimo DECIMAL(18,2),
        @pMontoMaximo DECIMAL(18,2),
        @pFechaDesde DATE,
        @pFechaHasta DATE,
        @pEstado VARCHAR(20),
        @pCanalOrigen VARCHAR(50)
    ';
    
    -- Ejecutar con sp_executesql (seguro)
    EXEC sp_executesql @SQL, @Parametros,
        @TopN = @TopN,
        @pCuentaID = @CuentaID,
        @pTiposTransaccion = @TiposTransaccion,
        @pMontoMinimo = @MontoMinimo,
        @pMontoMaximo = @MontoMaximo,
        @pFechaDesde = @FechaDesde,
        @pFechaHasta = @FechaHasta,
        @pEstado = @Estado,
        @pCanalOrigen = @CanalOrigen;
END;
GO

-- Ejemplos de uso
PRINT '--- Búsqueda por tipo ---';
EXEC dbo.SP_BusquedaTransacciones @TiposTransaccion = 'DEPOSITO,RETIRO', @TopN = 5;

PRINT '--- Búsqueda por rango de monto ---';
EXEC dbo.SP_BusquedaTransacciones @MontoMinimo = 1000, @MontoMaximo = 5000, @TopN = 5;

PRINT '--- Búsqueda combinada ---';
EXEC dbo.SP_BusquedaTransacciones 
    @TiposTransaccion = 'TRANSFERENCIA',
    @MontoMinimo = 100,
    @Estado = 'COMPLETADA',
    @CanalOrigen = 'WEB',
    @TopN = 5;
GO

PRINT 'Ejercicio 7: Búsqueda dinámica segura creada.';
GO

-- ============================================================================
-- EJERCICIO 8: DETECCIÓN DE ANOMALÍAS CON ANÁLISIS ESTADÍSTICO
-- Identificar transacciones sospechosas usando desviaciones
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
Detectar transacciones anómalas que se desvían significativamente
del patrón normal del cliente (más de 3 desviaciones estándar).
*/

-- SOLUCIÓN EJERCICIO 8:

CREATE OR ALTER PROCEDURE dbo.SP_DetectarAnomalias
    @DesviacionesUmbral DECIMAL(5,2) = 3.0,
    @DiasAnalisis INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    ;WITH EstadisticasCliente AS (
        -- Calcular estadísticas por cliente
        SELECT 
            cu.ClienteID,
            AVG(t.Monto) AS MontoPromedio,
            STDEV(t.Monto) AS DesviacionEstandar,
            COUNT(*) AS TotalTransacciones
        FROM dbo.TRANSACCIONES_WS t
        INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
        WHERE t.FechaTransaccion >= DATEADD(DAY, -@DiasAnalisis, GETDATE())
          AND t.Estado = 'COMPLETADA'
        GROUP BY cu.ClienteID
        HAVING COUNT(*) >= 10  -- Mínimo de transacciones para estadística confiable
    ),
    TransaccionesRecientes AS (
        -- Transacciones de últimas 24 horas
        SELECT 
            t.TransaccionID,
            cu.ClienteID,
            c.NumeroCliente,
            c.Nombre + ' ' + c.Apellido AS NombreCliente,
            t.TipoTransaccion,
            t.Monto,
            t.FechaTransaccion,
            t.CanalOrigen
        FROM dbo.TRANSACCIONES_WS t
        INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
        INNER JOIN dbo.CLIENTES_WS c ON cu.ClienteID = c.ClienteID
        WHERE t.FechaTransaccion >= DATEADD(HOUR, -24, GETDATE())
    )
    SELECT 
        tr.TransaccionID,
        tr.NumeroCliente,
        tr.NombreCliente,
        tr.TipoTransaccion,
        FORMAT(tr.Monto, 'C') AS MontoTransaccion,
        FORMAT(ec.MontoPromedio, 'C') AS MontoPromedioCliente,
        FORMAT(ec.DesviacionEstandar, 'N2') AS DesviacionEstandar,
        FORMAT((tr.Monto - ec.MontoPromedio) / NULLIF(ec.DesviacionEstandar, 0), 'N2') AS NumDesviaciones,
        tr.FechaTransaccion,
        tr.CanalOrigen,
        CASE 
            WHEN (tr.Monto - ec.MontoPromedio) / NULLIF(ec.DesviacionEstandar, 0) > @DesviacionesUmbral 
            THEN 'MONTO ALTO ANÓMALO'
            WHEN (tr.Monto - ec.MontoPromedio) / NULLIF(ec.DesviacionEstandar, 0) < -@DesviacionesUmbral 
            THEN 'MONTO BAJO ANÓMALO'
            ELSE 'NORMAL'
        END AS TipoAnomalia
    FROM TransaccionesRecientes tr
    INNER JOIN EstadisticasCliente ec ON tr.ClienteID = ec.ClienteID
    WHERE ABS((tr.Monto - ec.MontoPromedio) / NULLIF(ec.DesviacionEstandar, 0)) > @DesviacionesUmbral
    ORDER BY ABS((tr.Monto - ec.MontoPromedio) / NULLIF(ec.DesviacionEstandar, 0)) DESC;
END;
GO

-- Ejecutar detección
EXEC dbo.SP_DetectarAnomalias @DesviacionesUmbral = 2.5;
GO

PRINT 'Ejercicio 8: Detección de anomalías creada.';
GO

-- ============================================================================
-- EJERCICIO 9: MONITOREO DE RENDIMIENTO DE QUERIES
-- Crear vista para identificar queries lentas
-- Nivel: Avanzado
-- ============================================================================

/*
PROBLEMA:
El DBA necesita identificar rápidamente las queries más costosas
para priorizarlas en el proceso de tuning.
*/

-- SOLUCIÓN EJERCICIO 9:

CREATE OR ALTER VIEW dbo.VW_QueryMasCostosas
AS
SELECT TOP 50
    qs.total_elapsed_time / qs.execution_count / 1000.0 AS AvgDuracionMs,
    qs.total_worker_time / qs.execution_count / 1000.0 AS AvgCPUMs,
    qs.total_logical_reads / qs.execution_count AS AvgLecturasLogicas,
    qs.execution_count AS Ejecuciones,
    qs.total_elapsed_time / 1000.0 AS TiempoTotalMs,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1) AS TextoQuery,
    qp.query_plan AS PlanEjecucion,
    qs.creation_time AS FechaCompilacion,
    qs.last_execution_time AS UltimaEjecucion
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE st.dbid = DB_ID()
ORDER BY qs.total_elapsed_time DESC;
GO

-- Consultar queries más costosas
SELECT 
    AvgDuracionMs,
    AvgCPUMs,
    AvgLecturasLogicas,
    Ejecuciones,
    LEFT(TextoQuery, 200) AS Query_Truncada,
    UltimaEjecucion
FROM dbo.VW_QueryMasCostosas;
GO

PRINT 'Ejercicio 9: Vista de monitoreo creada.';
GO

-- ============================================================================
-- EJERCICIO 10: CASO INTEGRAL - OPTIMIZACIÓN COMPLETA
-- Aplicar todas las técnicas aprendidas
-- Nivel: Experto
-- ============================================================================

/*
DESAFÍO FINAL:
Crear un procedimiento "SP_ReporteMensualOptimizado" que:

1. Use CTEs para organizar la lógica
2. Aplique Window Functions para rankings y acumulados
3. Incluya manejo de errores con TRY-CATCH
4. Use hints de índice apropiados
5. Retorne resultados paginados
6. Registre auditoría de ejecución
7. Funcione eficientemente para >1M de transacciones

El reporte debe incluir:
- Top clientes por volumen
- Desglose por tipo de transacción
- Comparativo vs mes anterior
- Métricas de tendencia
*/

-- SOLUCIÓN EJERCICIO 10:

CREATE OR ALTER PROCEDURE dbo.SP_ReporteMensualOptimizado
    @MesReporte INT = NULL,        -- NULL = mes actual
    @AñoReporte INT = NULL,        -- NULL = año actual
    @TopClientes INT = 100,
    @Pagina INT = 1,
    @TamañoPagina INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @InicioProc DATETIME2 = SYSDATETIME();
    DECLARE @ErrorMsg NVARCHAR(500);
    
    BEGIN TRY
        -- Valores por defecto
        SET @MesReporte = ISNULL(@MesReporte, MONTH(GETDATE()));
        SET @AñoReporte = ISNULL(@AñoReporte, YEAR(GETDATE()));
        
        -- Calcular fechas
        DECLARE @FechaInicio DATE = DATEFROMPARTS(@AñoReporte, @MesReporte, 1);
        DECLARE @FechaFin DATE = EOMONTH(@FechaInicio);
        DECLARE @FechaInicioAnterior DATE = DATEADD(MONTH, -1, @FechaInicio);
        DECLARE @FechaFinAnterior DATE = EOMONTH(@FechaInicioAnterior);
        
        -- CTE Principal: Datos del mes actual
        ;WITH DatosMesActual AS (
            SELECT 
                c.ClienteID,
                c.NumeroCliente,
                c.Nombre + ' ' + c.Apellido AS NombreCompleto,
                c.TipoCliente,
                t.TipoTransaccion,
                COUNT(*) AS Cantidad,
                SUM(t.Monto) AS MontoTotal
            FROM dbo.TRANSACCIONES_WS t WITH (INDEX(IX_TRANS_WS_Fecha_Estado))
            INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
            INNER JOIN dbo.CLIENTES_WS c ON cu.ClienteID = c.ClienteID
            WHERE t.FechaTransaccion BETWEEN @FechaInicio AND @FechaFin
              AND t.Estado = 'COMPLETADA'
            GROUP BY c.ClienteID, c.NumeroCliente, c.Nombre, c.Apellido, 
                     c.TipoCliente, t.TipoTransaccion
        ),
        -- Datos del mes anterior para comparación
        DatosMesAnterior AS (
            SELECT 
                cu.ClienteID,
                SUM(t.Monto) AS MontoTotalAnterior
            FROM dbo.TRANSACCIONES_WS t
            INNER JOIN dbo.CUENTAS_WS cu ON t.CuentaOrigenID = cu.CuentaID
            WHERE t.FechaTransaccion BETWEEN @FechaInicioAnterior AND @FechaFinAnterior
              AND t.Estado = 'COMPLETADA'
            GROUP BY cu.ClienteID
        ),
        -- Agregar por cliente con Window Functions
        ResumenCliente AS (
            SELECT 
                ma.ClienteID,
                ma.NumeroCliente,
                ma.NombreCompleto,
                ma.TipoCliente,
                SUM(ma.Cantidad) AS TotalTransacciones,
                SUM(ma.MontoTotal) AS MontoTotalMes,
                
                -- Ranking y percentiles
                ROW_NUMBER() OVER (ORDER BY SUM(ma.MontoTotal) DESC) AS Ranking,
                PERCENT_RANK() OVER (ORDER BY SUM(ma.MontoTotal)) AS Percentil,
                
                -- Comparativo vs mes anterior
                ISNULL(ant.MontoTotalAnterior, 0) AS MontoMesAnterior,
                SUM(ma.MontoTotal) - ISNULL(ant.MontoTotalAnterior, 0) AS VariacionMonto,
                CASE 
                    WHEN ISNULL(ant.MontoTotalAnterior, 0) > 0 
                    THEN (SUM(ma.MontoTotal) - ant.MontoTotalAnterior) * 100.0 / ant.MontoTotalAnterior
                    ELSE 100.0 
                END AS VariacionPorcentaje,
                
                -- Acumulados
                SUM(SUM(ma.MontoTotal)) OVER (ORDER BY SUM(ma.MontoTotal) DESC 
                                              ROWS UNBOUNDED PRECEDING) AS MontoAcumulado,
                SUM(SUM(ma.MontoTotal)) OVER () AS TotalGeneral
            FROM DatosMesActual ma
            LEFT JOIN DatosMesAnterior ant ON ma.ClienteID = ant.ClienteID
            GROUP BY ma.ClienteID, ma.NumeroCliente, ma.NombreCompleto, 
                     ma.TipoCliente, ant.MontoTotalAnterior
        )
        -- Resultado final paginado
        SELECT 
            Ranking,
            NumeroCliente,
            NombreCompleto,
            TipoCliente,
            TotalTransacciones,
            FORMAT(MontoTotalMes, 'C', 'es-MX') AS MontoMesActual,
            FORMAT(MontoMesAnterior, 'C', 'es-MX') AS MontoMesAnterior,
            FORMAT(VariacionMonto, 'C', 'es-MX') AS VariacionMonto,
            FORMAT(VariacionPorcentaje, 'N2') + '%' AS VariacionPorcentaje,
            CASE 
                WHEN VariacionMonto > 0 THEN '📈 Crecimiento'
                WHEN VariacionMonto < 0 THEN '📉 Decremento'
                ELSE '➖ Sin cambio'
            END AS Tendencia,
            FORMAT(MontoTotalMes * 100.0 / TotalGeneral, 'N2') + '%' AS PorcentajeTotal,
            FORMAT(MontoAcumulado * 100.0 / TotalGeneral, 'N2') + '%' AS PorcentajeAcumulado,
            CASE 
                WHEN Percentil >= 0.95 THEN '⭐ Top 5%'
                WHEN Percentil >= 0.90 THEN '🔹 Top 10%'
                WHEN Percentil >= 0.75 THEN '🔸 Top 25%'
                ELSE '○ Regular'
            END AS Categoria,
            -- Metadatos de paginación
            COUNT(*) OVER () AS TotalRegistros,
            @Pagina AS PaginaActual,
            CEILING(COUNT(*) OVER () * 1.0 / @TamañoPagina) AS TotalPaginas
        FROM ResumenCliente
        WHERE Ranking <= @TopClientes
        ORDER BY Ranking
        OFFSET ((@Pagina - 1) * @TamañoPagina) ROWS
        FETCH NEXT @TamañoPagina ROWS ONLY;
        
        -- Registrar ejecución exitosa
        INSERT INTO dbo.LOG_AUDITORIA_WS (TablaAfectada, Operacion, DatosNuevos)
        VALUES ('REPORTE_MENSUAL', 'EJECUTADO', 
                'Mes: ' + CAST(@MesReporte AS VARCHAR) + '/' + CAST(@AñoReporte AS VARCHAR) +
                ', Duración: ' + CAST(DATEDIFF(MILLISECOND, @InicioProc, SYSDATETIME()) AS VARCHAR) + 'ms');
        
    END TRY
    BEGIN CATCH
        SET @ErrorMsg = ERROR_MESSAGE();
        
        -- Registrar error
        INSERT INTO dbo.LOG_AUDITORIA_WS (TablaAfectada, Operacion, DatosNuevos)
        VALUES ('REPORTE_MENSUAL', 'ERROR', @ErrorMsg);
        
        THROW;
    END CATCH
END;
GO

-- Ejecutar reporte optimizado
EXEC dbo.SP_ReporteMensualOptimizado 
    @TopClientes = 50, 
    @Pagina = 1, 
    @TamañoPagina = 10;
GO

PRINT '=====================================================';
PRINT '  🎓 WORKSHOP FINAL COMPLETADO';
PRINT '  ¡FELICITACIONES POR COMPLETAR EL CURSO!';
PRINT '=====================================================';
GO

-- ============================================================================
-- LIMPIEZA (OPCIONAL)
-- ============================================================================

/*
-- Descomentar para eliminar objetos de los ejercicios

DROP PROCEDURE IF EXISTS dbo.SP_ReporteMensualOptimizado;
DROP PROCEDURE IF EXISTS dbo.SP_DetectarAnomalias;
DROP PROCEDURE IF EXISTS dbo.SP_BusquedaTransacciones;
DROP PROCEDURE IF EXISTS dbo.SP_ReporteTopClientes;
DROP PROCEDURE IF EXISTS dbo.SP_TransaccionesPaginadas;
DROP PROCEDURE IF EXISTS dbo.SP_MarcarCuentasInactivas;
DROP PROCEDURE IF EXISTS dbo.SP_CalcularComisiones_SETBASED;
DROP PROCEDURE IF EXISTS dbo.SP_CalcularComisiones_CURSOR;
DROP VIEW IF EXISTS dbo.VW_QueryMasCostosas;
DROP INDEX IF EXISTS IX_CLIENTES_WS_TipoCliente ON dbo.CLIENTES_WS;
DROP INDEX IF EXISTS IX_TRANS_WS_CuentaOrigen_Fecha ON dbo.TRANSACCIONES_WS;
DROP INDEX IF EXISTS IX_TRANS_WS_Pendientes_Filtered ON dbo.TRANSACCIONES_WS;
*/
