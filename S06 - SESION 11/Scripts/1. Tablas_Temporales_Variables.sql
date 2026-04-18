/***************************************************************
 * SESIÓN 11: TABLAS TEMPORALES Y VARIABLES DE TABLA
 * SQL Server Intermedio - 2026
 * 
 * Contenido:
 *   1. Introducción a almacenamiento temporal
 *   2. Tablas temporales locales (#temp)
 *   3. Tablas temporales globales (##temp)
 *   4. Variables de tabla (@table)
 *   5. Scope y ciclo de vida
 *   6. Performance: #temp vs @table
 *   7. Estadísticas y recompilaciones
 *   8. Table-Valued Parameters (TVP)
 *   9. Mejores prácticas
 *   10. Casos prácticos con BancoDB
 * 
 * Base de datos: BancoDB
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- PARTE 1: INTRODUCCIÓN A ALMACENAMIENTO TEMPORAL
-- ============================================================
/*
   ¿Por qué necesitamos almacenamiento temporal?
   
   1. Almacenar resultados intermedios en procesos complejos
   2. Dividir queries grandes en pasos manejables
   3. Mejorar rendimiento evitando cálculos repetidos
   4. Pasar conjuntos de datos entre procedimientos
   5. Staging para transformaciones ETL
   
   Opciones principales:
   ┌─────────────────┬────────────────┬─────────────────┐
   │ Tipo            │ Scope          │ Almacenamiento  │
   ├─────────────────┼────────────────┼─────────────────┤
   │ #temp           │ Sesión/SP      │ tempdb          │
   │ ##temp          │ Global         │ tempdb          │
   │ @variable       │ Batch/SP       │ Memoria/tempdb  │
   │ CTE             │ Sentencia      │ No persiste     │
   └─────────────────┴────────────────┴─────────────────┘
*/

-- ============================================================
-- PARTE 2: TABLAS TEMPORALES LOCALES (#temp)
-- ============================================================
/*
   Características de tablas temporales locales:
   
   ✓ Se crean en tempdb con nombre único interno
   ✓ Visibles solo en la sesión que las creó
   ✓ Los SPs hijos pueden acceder a ellas
   ✓ Se eliminan al cerrar la sesión o explícitamente
   ✓ Soportan índices, constraints, estadísticas
   ✓ Pueden tener millones de filas eficientemente
*/

-- Sintaxis básica de creación
-- -------------------------

-- Método 1: CREATE TABLE explícito
IF OBJECT_ID('tempdb..#ClientesActivos') IS NOT NULL
    DROP TABLE #ClientesActivos;

CREATE TABLE #ClientesActivos (
    ClienteID INT PRIMARY KEY,
    NombreCompleto NVARCHAR(200),
    SaldoTotal DECIMAL(18,2),
    NumCuentas INT,
    UltimaTransaccion DATE
);

-- Método 2: SELECT INTO (crea estructura automáticamente)
IF OBJECT_ID('tempdb..#TransaccionesRecientes') IS NOT NULL
    DROP TABLE #TransaccionesRecientes;

SELECT 
    TransaccionID,
    CuentaID,
    TipoTransaccion,
    Monto,
    FechaTransaccion
INTO #TransaccionesRecientes
FROM TRANSACCIONES_BANCARIAS
WHERE FechaTransaccion >= DATEADD(MONTH, -1, GETDATE());

PRINT 'Transacciones recientes cargadas: ' + CAST(@@ROWCOUNT AS VARCHAR(20));


-- Ejemplo práctico: Resumen de clientes con cálculos intermedios
-- ---------------------------------------------------------------
IF OBJECT_ID('tempdb..#ResumenClientes') IS NOT NULL
    DROP TABLE #ResumenClientes;

-- Paso 1: Calcular métricas base por cliente
SELECT 
    c.ClienteID,
    c.Nombre + ' ' + c.Apellido AS NombreCompleto,
    c.Segmento,
    COUNT(DISTINCT cu.CuentaID) AS NumCuentas,
    SUM(cu.Saldo) AS SaldoTotal,
    MAX(t.FechaTransaccion) AS UltimaActividad,
    COUNT(t.TransaccionID) AS TotalTransacciones
INTO #ResumenClientes
FROM CLIENTES c
LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
LEFT JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
WHERE c.Estado = 'Activo'
GROUP BY c.ClienteID, c.Nombre, c.Apellido, c.Segmento;

-- Paso 2: Agregar índice para mejorar consultas posteriores
CREATE INDEX IX_ResumenClientes_Segmento ON #ResumenClientes(Segmento);
CREATE INDEX IX_ResumenClientes_SaldoTotal ON #ResumenClientes(SaldoTotal);

-- Paso 3: Usar la tabla temporal en múltiples consultas
SELECT 
    Segmento,
    COUNT(*) AS Clientes,
    SUM(SaldoTotal) AS SaldoSegmento,
    AVG(NumCuentas) AS PromedioCuentas
FROM #ResumenClientes
GROUP BY Segmento
ORDER BY SaldoSegmento DESC;

-- Los clientes top por segmento
SELECT * FROM #ResumenClientes
WHERE SaldoTotal > 100000
ORDER BY SaldoTotal DESC;

-- Verificar existencia en tempdb
SELECT 
    name AS NombreInterno,
    create_date AS FechaCreacion,
    OBJECT_ID('tempdb..#ResumenClientes') AS ObjectID
FROM tempdb.sys.tables 
WHERE name LIKE '#ResumenClientes%';


-- Agregar columnas e índices después de creación
-- -----------------------------------------------
ALTER TABLE #ResumenClientes
ADD Clasificacion VARCHAR(20) NULL;

-- Actualizar clasificación basada en saldo
UPDATE #ResumenClientes
SET Clasificacion = CASE 
    WHEN SaldoTotal >= 500000 THEN 'VIP'
    WHEN SaldoTotal >= 100000 THEN 'Premium'
    WHEN SaldoTotal >= 10000 THEN 'Estándar'
    ELSE 'Básico'
END;

SELECT Clasificacion, COUNT(*) AS Cantidad
FROM #ResumenClientes
GROUP BY Clasificacion;


-- ============================================================
-- PARTE 3: TABLAS TEMPORALES GLOBALES (##temp)
-- ============================================================
/*
   Características de tablas temporales globales:
   
   ✓ Visibles por TODAS las sesiones
   ✓ Se eliminan cuando la sesión creadora termina
     Y no hay otras sesiones usándola
   ✓ Útiles para compartir datos entre procesos
   ✓ Usar con precaución (posibles conflictos)
   
   Casos de uso:
   - Compartir datos entre múltiples procesos
   - Staging temporal para ETL cross-session
   - Testing y debugging
*/

-- Crear tabla temporal global
IF OBJECT_ID('tempdb..##ParametrosGlobales') IS NOT NULL
    DROP TABLE ##ParametrosGlobales;

CREATE TABLE ##ParametrosGlobales (
    ParametroID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Valor VARCHAR(500),
    FechaActualizacion DATETIME DEFAULT GETDATE()
);

-- Esta tabla es visible desde OTRA sesión
INSERT INTO ##ParametrosGlobales (Nombre, Valor)
VALUES 
    ('FechaCortePurga', '2024-01-01'),
    ('BatchSizeDefault', '10000'),
    ('EmailNotificacion', 'dba@banco.com');

-- Cualquier sesión puede consultar
SELECT * FROM ##ParametrosGlobales;

-- ADVERTENCIA: Conflictos potenciales si dos sesiones intentan crear
-- la misma tabla global simultáneamente


-- Ejemplo: Tabla global para proceso ETL distribuido
-- ---------------------------------------------------
IF OBJECT_ID('tempdb..##ETL_Log') IS NOT NULL
    DROP TABLE ##ETL_Log;

CREATE TABLE ##ETL_Log (
    LogID INT IDENTITY(1,1),
    SessionID INT DEFAULT @@SPID,
    Proceso VARCHAR(100),
    Mensaje VARCHAR(500),
    FechaHora DATETIME DEFAULT GETDATE()
);

-- Múltiples sesiones pueden registrar en el mismo log
INSERT INTO ##ETL_Log (Proceso, Mensaje)
VALUES ('Carga_Clientes', 'Inicio del proceso');


-- ============================================================
-- PARTE 4: VARIABLES DE TABLA (@table)
-- ============================================================
/*
   Características de variables de tabla:
   
   ✓ Scope limitado al batch/SP donde se declaran
   ✓ No visible fuera de su scope
   ✓ No participa en transacciones (¡importante!)
   ✓ Para SQL Server < 2019: sin estadísticas
   ✓ Estimación de cardinalidad = 1 fila
   ✓ Ideal para conjuntos pequeños (<100 filas)
*/

-- Declaración básica
DECLARE @ClientesVIP TABLE (
    ClienteID INT PRIMARY KEY,
    Nombre NVARCHAR(100),
    SaldoTotal DECIMAL(18,2)
);

-- Insertar datos
INSERT INTO @ClientesVIP (ClienteID, Nombre, SaldoTotal)
SELECT 
    c.ClienteID,
    c.Nombre + ' ' + c.Apellido,
    ISNULL(SUM(cu.Saldo), 0)
FROM CLIENTES c
LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
WHERE c.Segmento = 'VIP'
GROUP BY c.ClienteID, c.Nombre, c.Apellido;

-- Usar la variable
SELECT * FROM @ClientesVIP ORDER BY SaldoTotal DESC;


-- Variables de tabla con restricciones
-- ------------------------------------
DECLARE @Transacciones TABLE (
    ID INT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,
    CuentaID INT NOT NULL,
    Monto DECIMAL(18,2) NOT NULL CHECK (Monto > 0),
    Tipo VARCHAR(20) NOT NULL,
    INDEX IX_CuentaID NONCLUSTERED (CuentaID)  -- Índice no clustered
);

INSERT INTO @Transacciones (CuentaID, Monto, Tipo)
SELECT TOP 100
    CuentaID,
    ABS(Monto),
    TipoTransaccion
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Depósito';


-- IMPORTANTE: Variables de tabla NO hacen rollback
-- ------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    
    DECLARE @LogOperaciones TABLE (
        Operacion VARCHAR(100),
        Fecha DATETIME DEFAULT GETDATE()
    );
    
    -- Insertar en variable de tabla
    INSERT INTO @LogOperaciones (Operacion) VALUES ('Inicio proceso');
    
    -- Simular error
    RAISERROR('Error simulado', 16, 1);
    
    COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;  -- El ROLLBACK NO afecta a @LogOperaciones
    
    -- La variable de tabla MANTIENE sus datos
    SELECT * FROM @LogOperaciones;  -- Muestra 'Inicio proceso'
    
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;


-- ============================================================
-- PARTE 5: SCOPE Y CICLO DE VIDA
-- ============================================================

-- Demostración de scope de #temp vs @table
-- ----------------------------------------

-- La tabla #temp es visible en SPs anidados
IF OBJECT_ID('tempdb..#DatosCompartidos') IS NOT NULL
    DROP TABLE #DatosCompartidos;

CREATE TABLE #DatosCompartidos (
    ID INT,
    Valor VARCHAR(100)
);

INSERT INTO #DatosCompartidos VALUES (1, 'Dato desde sesión principal');

-- Crear SP que accede a la tabla temporal del caller
CREATE OR ALTER PROCEDURE dbo.sp_AccederTempExterna
AS
BEGIN
    -- Este SP puede ver #DatosCompartidos creada por el caller
    INSERT INTO #DatosCompartidos VALUES (2, 'Dato desde SP hijo');
    
    SELECT * FROM #DatosCompartidos;
END;
GO

-- Ejecutar
EXEC dbo.sp_AccederTempExterna;
-- Resultado: muestra ambas filas


-- PERO: @table NO es visible en SPs hijos
CREATE OR ALTER PROCEDURE dbo.sp_IntentarAccederVariable
AS
BEGIN
    -- Esto fallaría si intentamos acceder a @MiVariable 
    -- declarada en el caller
    PRINT 'Las variables de tabla no son visibles aquí';
END;
GO


-- Scope de tablas temporales en SPs
-- ----------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CreaTempLocal
AS
BEGIN
    -- Esta #temp solo existe dentro de este SP
    CREATE TABLE #TempDelSP (ID INT);
    INSERT INTO #TempDelSP VALUES (1);
    
    SELECT * FROM #TempDelSP;
    
    -- Al terminar el SP, #TempDelSP se destruye automáticamente
END;
GO

EXEC dbo.sp_CreaTempLocal;

-- Esto fallaría: #TempDelSP ya no existe
-- SELECT * FROM #TempDelSP;


-- ============================================================
-- PARTE 6: PERFORMANCE - #temp vs @table
-- ============================================================
/*
   Guía de selección:
   
   ┌─────────────────────┬─────────────────┬─────────────────┐
   │ Escenario           │ Recomendación   │ Razón           │
   ├─────────────────────┼─────────────────┼─────────────────┤
   │ < 100 filas         │ @variable       │ Menos overhead  │
   │ 100 - 10,000 filas  │ Depende         │ Ver estadísticas│
   │ > 10,000 filas      │ #temp           │ Estadísticas    │
   │ Necesita índices    │ #temp           │ Más flexible    │
   │ Múltiples queries   │ #temp           │ Plan reúso      │
   │ Paso a SP hijo      │ #temp o TVP     │ Visibilidad     │
   │ No rollback         │ @variable       │ Comportamiento  │
   └─────────────────────┴─────────────────┴─────────────────┘
*/

-- Comparación práctica: mismo query con #temp vs @table
-- -----------------------------------------------------

-- Escenario: Procesar transacciones de alto valor
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Opción 1: Tabla temporal
IF OBJECT_ID('tempdb..#TransAltoValor') IS NOT NULL
    DROP TABLE #TransAltoValor;

SELECT TransaccionID, CuentaID, Monto, FechaTransaccion
INTO #TransAltoValor
FROM TRANSACCIONES_BANCARIAS
WHERE Monto > 50000;

CREATE INDEX IX_Trans_Cuenta ON #TransAltoValor(CuentaID);

-- Consulta con JOIN
SELECT 
    c.Nombre,
    COUNT(*) AS TransaccionesAltas,
    SUM(t.Monto) AS MontoTotal
FROM #TransAltoValor t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
GROUP BY c.Nombre
HAVING COUNT(*) > 5;

-- Opción 2: Variable de tabla (comparar rendimiento)
DECLARE @TransAltoValor TABLE (
    TransaccionID INT,
    CuentaID INT,
    Monto DECIMAL(18,2),
    FechaTransaccion DATE,
    INDEX IX_Cuenta NONCLUSTERED (CuentaID)
);

INSERT INTO @TransAltoValor
SELECT TransaccionID, CuentaID, Monto, FechaTransaccion
FROM TRANSACCIONES_BANCARIAS
WHERE Monto > 50000;

-- Misma consulta
SELECT 
    c.Nombre,
    COUNT(*) AS TransaccionesAltas,
    SUM(t.Monto) AS MontoTotal
FROM @TransAltoValor t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
GROUP BY c.Nombre
HAVING COUNT(*) > 5;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;


-- ============================================================
-- PARTE 7: ESTADÍSTICAS Y RECOMPILACIONES
-- ============================================================
/*
   Problema clave: Estimación de cardinalidad
   
   - #temp: SQL Server mantiene estadísticas automáticas
   - @variable (pre-2019): Estimación fija de 1 fila
   - @variable (2019+): Table Variable Deferred Compilation
   
   Esto afecta DIRECTAMENTE la elección del plan de ejecución
*/

-- Ver estimaciones vs realidad
-- -----------------------------

-- Con tabla temporal (estadísticas correctas)
IF OBJECT_ID('tempdb..#TestEstadisticas') IS NOT NULL
    DROP TABLE #TestEstadisticas;

SELECT *
INTO #TestEstadisticas
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Depósito';

-- Forzar actualización de estadísticas
UPDATE STATISTICS #TestEstadisticas;

-- Ver plan: la estimación será cercana a la realidad
SELECT t.*, c.Nombre
FROM #TestEstadisticas t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
WHERE t.Monto > 10000;
-- Activar "Include Actual Execution Plan" para comparar


-- OPTION (RECOMPILE) para variables de tabla
-- ------------------------------------------
DECLARE @TestVar TABLE (
    TransaccionID INT,
    CuentaID INT,
    Monto DECIMAL(18,2)
);

INSERT INTO @TestVar
SELECT TransaccionID, CuentaID, Monto
FROM TRANSACCIONES_BANCARIAS
WHERE TipoTransaccion = 'Retiro';

-- Sin RECOMPILE: estimación = 1 fila
SELECT t.*, c.Nombre
FROM @TestVar t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID;

-- Con RECOMPILE: estimación más precisa (costo: recompila cada vez)
SELECT t.*, c.Nombre
FROM @TestVar t
JOIN CUENTAS cu ON t.CuentaID = cu.CuentaID
JOIN CLIENTES c ON cu.ClienteID = c.ClienteID
OPTION (RECOMPILE);


-- SQL Server 2019+: Table Variable Deferred Compilation
-- -----------------------------------------------------
/*
   En SQL Server 2019+ (compatibility level 150+):
   - La compilación del plan se difiere hasta la ejecución
   - El optimizador conoce el conteo real de filas
   - Ya no necesitas OPTION (RECOMPILE) en muchos casos
   
   Verificar nivel de compatibilidad:
*/
SELECT 
    name, 
    compatibility_level,
    CASE WHEN compatibility_level >= 150 
         THEN 'Table Variable Deferred Compilation ACTIVO'
         ELSE 'Estimación fija = 1 fila'
    END AS Comportamiento
FROM sys.databases
WHERE name = 'BancoDB';


-- ============================================================
-- PARTE 8: TABLE-VALUED PARAMETERS (TVP)
-- ============================================================
/*
   Los TVP permiten pasar conjuntos de datos a stored procedures.
   
   Ventajas:
   ✓ Tipado fuerte
   ✓ Reutilizable
   ✓ Mejor que concatenar strings
   ✓ Mejor que múltiples parámetros
*/

-- Paso 1: Crear el tipo de tabla
IF TYPE_ID('dbo.TipoListaIDs') IS NOT NULL
    DROP TYPE dbo.TipoListaIDs;

CREATE TYPE dbo.TipoListaIDs AS TABLE (
    ID INT NOT NULL PRIMARY KEY
);
GO

-- Paso 2: Crear SP que usa el TVP
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerClientesPorLista
    @ListaClienteIDs dbo.TipoListaIDs READONLY  -- READONLY es obligatorio
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClienteID,
        c.Nombre,
        c.Apellido,
        c.Email,
        c.Segmento,
        ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal
    FROM CLIENTES c
    INNER JOIN @ListaClienteIDs ids ON c.ClienteID = ids.ID
    LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    GROUP BY c.ClienteID, c.Nombre, c.Apellido, c.Email, c.Segmento;
END;
GO

-- Paso 3: Usar el TVP
DECLARE @MisClientes dbo.TipoListaIDs;

INSERT INTO @MisClientes (ID)
VALUES (1), (2), (3), (5), (10);

EXEC dbo.sp_ObtenerClientesPorLista @ListaClienteIDs = @MisClientes;


-- TVP más complejo: Inserción masiva validada
-- -------------------------------------------
IF TYPE_ID('dbo.TipoNuevasTransacciones') IS NOT NULL
    DROP TYPE dbo.TipoNuevasTransacciones;

CREATE TYPE dbo.TipoNuevasTransacciones AS TABLE (
    CuentaID INT NOT NULL,
    TipoTransaccion VARCHAR(50) NOT NULL,
    Monto DECIMAL(18,2) NOT NULL,
    Descripcion VARCHAR(255) NULL,
    INDEX IX_CuentaID (CuentaID)
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_InsertarTransaccionesMasivo
    @Transacciones dbo.TipoNuevasTransacciones READONLY,
    @TransaccionesInsertadas INT OUTPUT,
    @TransaccionesRechazadas INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRecibidas INT = (SELECT COUNT(*) FROM @Transacciones);
    
    -- Validar que las cuentas existan y estén activas
    DECLARE @TransValidadas TABLE (
        CuentaID INT,
        TipoTransaccion VARCHAR(50),
        Monto DECIMAL(18,2),
        Descripcion VARCHAR(255)
    );
    
    INSERT INTO @TransValidadas
    SELECT t.CuentaID, t.TipoTransaccion, t.Monto, t.Descripcion
    FROM @Transacciones t
    INNER JOIN CUENTAS c ON t.CuentaID = c.CuentaID
    WHERE c.Estado = 'Activa'
      AND t.Monto > 0;
    
    SET @TransaccionesInsertadas = @@ROWCOUNT;
    SET @TransaccionesRechazadas = @TotalRecibidas - @TransaccionesInsertadas;
    
    -- Insertar las válidas
    INSERT INTO TRANSACCIONES_BANCARIAS (CuentaID, TipoTransaccion, Monto, Descripcion, FechaTransaccion)
    SELECT CuentaID, TipoTransaccion, Monto, Descripcion, GETDATE()
    FROM @TransValidadas;
    
    -- Log de resultado
    PRINT 'Recibidas: ' + CAST(@TotalRecibidas AS VARCHAR(10));
    PRINT 'Insertadas: ' + CAST(@TransaccionesInsertadas AS VARCHAR(10));
    PRINT 'Rechazadas: ' + CAST(@TransaccionesRechazadas AS VARCHAR(10));
END;
GO


-- ============================================================
-- PARTE 9: MEJORES PRÁCTICAS
-- ============================================================

/*
   1. LIMPIEZA EXPLÍCITA
   ---------------------
   Siempre verificar y limpiar tablas temporales antes de crear
*/
IF OBJECT_ID('tempdb..#MiTabla') IS NOT NULL
    DROP TABLE #MiTabla;
-- O en SQL Server 2016+:
DROP TABLE IF EXISTS #MiTabla;


/*
   2. ÍNDICES EN TABLAS TEMPORALES
   -------------------------------
   Crear índices DESPUÉS de cargar los datos es más eficiente
*/
-- MAL: Crear índice antes de insertar
CREATE TABLE #MalEjemplo (
    ID INT PRIMARY KEY,
    Valor VARCHAR(100),
    INDEX IX_Valor (Valor)
);
INSERT INTO #MalEjemplo ... -- Cada INSERT mantiene los índices

-- BIEN: Índices después de carga masiva
CREATE TABLE #BuenEjemplo (
    ID INT,
    Valor VARCHAR(100)
);
INSERT INTO #BuenEjemplo ... -- Inserts rápidos
CREATE INDEX IX_ID ON #BuenEjemplo(ID);
CREATE INDEX IX_Valor ON #BuenEjemplo(Valor);


/*
   3. USAR TRUNCATE EN VEZ DE DELETE
   ---------------------------------
   TRUNCATE es más rápido y no genera log masivo
*/
-- En lugar de:
DELETE FROM #MiTemporal;

-- Usar:
TRUNCATE TABLE #MiTemporal;


/*
   4. CONSIDERAR MEMORY-OPTIMIZED TABLE TYPES
   ------------------------------------------
   En SQL Server 2016+ para alto rendimiento
*/
/*
CREATE TYPE dbo.TipoMemoriaOptimizada AS TABLE (
    ID INT NOT NULL PRIMARY KEY NONCLUSTERED,
    Valor VARCHAR(100)
) WITH (MEMORY_OPTIMIZED = ON);
*/


/*
   5. NO USAR TABLAS TEMPORALES CUANDO NO ES NECESARIO
   ---------------------------------------------------
   CTEs o subqueries pueden ser más eficientes para uso único
*/
-- En lugar de:
SELECT * INTO #Temp FROM Tabla WHERE Condicion;
SELECT * FROM #Temp WHERE OtraCondicion;

-- Considerar:
;WITH CTE AS (
    SELECT * FROM Tabla WHERE Condicion
)
SELECT * FROM CTE WHERE OtraCondicion;


-- ============================================================
-- PARTE 10: CASOS PRÁCTICOS CON BancoDB
-- ============================================================

-- CASO 1: Reporte complejo con múltiples pasos
-- --------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ReporteConcentracionRiesgo
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Paso 1: Calcular movimientos por cliente
    IF OBJECT_ID('tempdb..#MovimientosCliente') IS NOT NULL
        DROP TABLE #MovimientosCliente;
    
    SELECT 
        c.ClienteID,
        c.Nombre + ' ' + c.Apellido AS Cliente,
        c.Segmento,
        SUM(CASE WHEN t.TipoTransaccion = 'Depósito' THEN t.Monto ELSE 0 END) AS TotalDepositos,
        SUM(CASE WHEN t.TipoTransaccion = 'Retiro' THEN t.Monto ELSE 0 END) AS TotalRetiros,
        COUNT(DISTINCT t.TransaccionID) AS NumTransacciones,
        MAX(t.FechaTransaccion) AS UltimaTransaccion
    INTO #MovimientosCliente
    FROM CLIENTES c
    INNER JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    INNER JOIN TRANSACCIONES_BANCARIAS t ON cu.CuentaID = t.CuentaID
    WHERE t.FechaTransaccion BETWEEN @FechaInicio AND @FechaFin
    GROUP BY c.ClienteID, c.Nombre, c.Apellido, c.Segmento;
    
    CREATE INDEX IX_Mov_Segmento ON #MovimientosCliente(Segmento);
    
    -- Paso 2: Calcular métricas de concentración
    IF OBJECT_ID('tempdb..#MetricasConcentracion') IS NOT NULL
        DROP TABLE #MetricasConcentracion;
    
    SELECT
        Segmento,
        COUNT(*) AS Clientes,
        SUM(TotalDepositos) AS DepositosSegmento,
        SUM(TotalRetiros) AS RetirosSegmento,
        SUM(TotalDepositos + TotalRetiros) AS VolumenTotal,
        AVG(NumTransacciones) AS PromedioTransacciones
    INTO #MetricasConcentracion
    FROM #MovimientosCliente
    GROUP BY Segmento;
    
    -- Paso 3: Calcular porcentajes sobre el total
    DECLARE @VolumenGlobal DECIMAL(18,2);
    SELECT @VolumenGlobal = SUM(VolumenTotal) FROM #MetricasConcentracion;
    
    -- Resultado final con análisis de riesgo
    SELECT 
        mc.Segmento,
        mc.Clientes,
        mc.DepositosSegmento,
        mc.RetirosSegmento,
        mc.VolumenTotal,
        CAST(mc.VolumenTotal * 100.0 / NULLIF(@VolumenGlobal, 0) AS DECIMAL(5,2)) AS PorcentajeConcentracion,
        mc.PromedioTransacciones,
        CASE 
            WHEN mc.VolumenTotal * 100.0 / NULLIF(@VolumenGlobal, 0) > 40 THEN 'ALTO'
            WHEN mc.VolumenTotal * 100.0 / NULLIF(@VolumenGlobal, 0) > 20 THEN 'MEDIO'
            ELSE 'BAJO'
        END AS NivelRiesgoConcentracion
    FROM #MetricasConcentracion mc
    ORDER BY mc.VolumenTotal DESC;
    
    -- Detalle de clientes con alta actividad
    SELECT TOP 20
        Cliente,
        Segmento,
        TotalDepositos,
        TotalRetiros,
        NumTransacciones,
        UltimaTransaccion
    FROM #MovimientosCliente
    ORDER BY (TotalDepositos + TotalRetiros) DESC;
    
END;
GO

-- Probar
EXEC dbo.sp_ReporteConcentracionRiesgo 
    @FechaInicio = '2024-01-01',
    @FechaFin = '2024-12-31';


-- CASO 2: Proceso ETL con staging temporal
-- ----------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ETL_ActualizarSaldosConsolidados
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FilasActualizadas INT = 0;
    DECLARE @FilasInsertadas INT = 0;
    
    -- Staging: Calcular saldos actuales
    IF OBJECT_ID('tempdb..#SaldosNuevos') IS NOT NULL
        DROP TABLE #SaldosNuevos;
    
    SELECT 
        c.ClienteID,
        SUM(cu.Saldo) AS SaldoConsolidado,
        COUNT(cu.CuentaID) AS NumeroCuentas,
        MAX(cu.FechaApertura) AS UltimaCuentaAbierta,
        GETDATE() AS FechaCalculo
    INTO #SaldosNuevos
    FROM CLIENTES c
    LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
    GROUP BY c.ClienteID;
    
    CREATE INDEX IX_SaldosNuevos_Cliente ON #SaldosNuevos(ClienteID);
    
    -- Log de proceso
    DECLARE @TotalCalculados INT = (SELECT COUNT(*) FROM #SaldosNuevos);
    PRINT 'Saldos calculados para ' + CAST(@TotalCalculados AS VARCHAR(10)) + ' clientes';
    
    -- Si existiera una tabla de consolidados, aquí haríamos MERGE
    -- Este es un ejemplo ilustrativo
    /*
    MERGE dbo.SALDOS_CONSOLIDADOS AS target
    USING #SaldosNuevos AS source
    ON target.ClienteID = source.ClienteID
    WHEN MATCHED THEN
        UPDATE SET 
            SaldoConsolidado = source.SaldoConsolidado,
            NumeroCuentas = source.NumeroCuentas,
            FechaCalculo = source.FechaCalculo
    WHEN NOT MATCHED THEN
        INSERT (ClienteID, SaldoConsolidado, NumeroCuentas, FechaCalculo)
        VALUES (source.ClienteID, source.SaldoConsolidado, source.NumeroCuentas, source.FechaCalculo);
    */
    
    -- Mostrar resultado del staging
    SELECT TOP 10 * FROM #SaldosNuevos ORDER BY SaldoConsolidado DESC;
    
END;
GO


-- CASO 3: Variables de tabla para logging sin rollback
-- ----------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_TransferenciaConLog
    @CuentaOrigen INT,
    @CuentaDestino INT,
    @Monto DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variable de tabla para log (NO se pierde en rollback)
    DECLARE @LogProceso TABLE (
        Paso INT IDENTITY(1,1),
        Descripcion VARCHAR(200),
        Fecha DATETIME DEFAULT GETDATE()
    );
    
    INSERT INTO @LogProceso (Descripcion) VALUES ('Inicio transferencia');
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO @LogProceso (Descripcion) 
        VALUES ('Validando cuenta origen: ' + CAST(@CuentaOrigen AS VARCHAR(10)));
        
        -- Verificar saldo
        DECLARE @SaldoOrigen DECIMAL(18,2);
        SELECT @SaldoOrigen = Saldo 
        FROM CUENTAS WHERE CuentaID = @CuentaOrigen;
        
        IF @SaldoOrigen < @Monto
        BEGIN
            INSERT INTO @LogProceso (Descripcion) VALUES ('ERROR: Saldo insuficiente');
            RAISERROR('Saldo insuficiente para la transferencia', 16, 1);
        END
        
        INSERT INTO @LogProceso (Descripcion) VALUES ('Saldo validado: OK');
        
        -- Simular transferencia (no ejecutamos realmente)
        INSERT INTO @LogProceso (Descripcion) 
        VALUES ('Transferencia completada: $' + CAST(@Monto AS VARCHAR(20)));
        
        COMMIT;
        
        INSERT INTO @LogProceso (Descripcion) VALUES ('Commit exitoso');
        
    END TRY
    BEGIN CATCH
        ROLLBACK;
        
        INSERT INTO @LogProceso (Descripcion) 
        VALUES ('ROLLBACK ejecutado - Error: ' + ERROR_MESSAGE());
    END CATCH;
    
    -- El log SIEMPRE está disponible
    SELECT * FROM @LogProceso ORDER BY Paso;
    
END;
GO

-- Probar con cuenta que no existe o saldo insuficiente
EXEC dbo.sp_TransferenciaConLog 
    @CuentaOrigen = 1, 
    @CuentaDestino = 2, 
    @Monto = 999999999.00;


-- ============================================================
-- RESUMEN COMPARATIVO FINAL
-- ============================================================
/*
   ╔═══════════════════════╦═══════════════════════════════════════════════════╗
   ║ Característica        ║ #temp          ║ ##temp         ║ @variable      ║
   ╠═══════════════════════╬═══════════════════════════════════════════════════╣
   ║ Ubicación             ║ tempdb         ║ tempdb         ║ memoria/tempdb ║
   ║ Scope                 ║ sesión/SP      ║ global         ║ batch/SP       ║
   ║ Visible en SP hijo    ║ Sí             ║ Sí             ║ No             ║
   ║ Estadísticas          ║ Sí             ║ Sí             ║ 2019+          ║
   ║ Rollback afecta       ║ Sí             ║ Sí             ║ NO             ║
   ║ Índices               ║ Cualquiera     ║ Cualquiera     ║ Limitados      ║
   ║ Ideal para            ║ > 100 filas    ║ Cross-session  ║ < 100 filas    ║
   ║ ALTER después         ║ Sí             ║ Sí             ║ No             ║
   ╚═══════════════════════╩═══════════════════════════════════════════════════╝
*/

-- Limpieza
DROP TABLE IF EXISTS #ClientesActivos;
DROP TABLE IF EXISTS #TransaccionesRecientes;
DROP TABLE IF EXISTS #ResumenClientes;
DROP TABLE IF EXISTS #TestEstadisticas;
DROP TABLE IF EXISTS #TransAltoValor;
DROP TABLE IF EXISTS #DatosCompartidos;
DROP TABLE IF EXISTS ##ParametrosGlobales;
DROP TABLE IF EXISTS ##ETL_Log;

PRINT '============================================================';
PRINT 'Sesión 11 completada: Tablas Temporales y Variables de Tabla';
PRINT '============================================================';
