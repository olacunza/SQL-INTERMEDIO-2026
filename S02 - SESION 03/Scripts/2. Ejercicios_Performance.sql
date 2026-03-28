-- ============================================================
-- SQL SERVER INTERMEDIO - SESIÓN 3
-- EJERCICIOS PRÁCTICOS: DISEÑO PARA PERFORMANCE
-- ============================================================

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: SOLUCIONES A LOS PROBLEMAS DE SARGABILITY
-- ============================================================

/*
PROBLEMA 1:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE DATEADD(DAY, 30, FechaTransaccion) > GETDATE();

ANÁLISIS: DATEADD() aplicado a la columna = NO SARGABLE
SIGNIFICADO: "Transacciones donde la fecha + 30 días > hoy"
           = "Transacciones de los últimos 30 días hacia el futuro"
           = "Transacciones a más de 30 días desde hoy" (si son futuras)
*/

-- ✅ SOLUCIÓN 1:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion > DATEADD(DAY, -30, GETDATE());
-- Mover la función al lado del valor, no de la columna

GO

/*
PROBLEMA 2:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE UPPER(TipoTransaccion) = 'TRANSFERENCIA';

ANÁLISIS: UPPER() aplicado a columna = NO SARGABLE
NOTA: SQL Server con collation CI (Case Insensitive) ya ignora mayúsculas
*/

-- ✅ SOLUCIÓN 2A (si collation es CI):
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE TipoTransaccion = 'TRANSFERENCIA';
-- La mayoría de collations son Case Insensitive por defecto

-- ✅ SOLUCIÓN 2B (si necesitas case-insensitive explícito):
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE TipoTransaccion = 'transferencia' COLLATE Latin1_General_CI_AS;
-- CI = Case Insensitive, pero esto también puede afectar SARGability

-- ✅ SOLUCIÓN 2C (si los datos pueden tener variaciones):
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE TipoTransaccion IN ('TRANSFERENCIA', 'transferencia', 'Transferencia');
-- Pero mejor: normalizar los datos al insertar

GO

/*
PROBLEMA 3:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia + '-2025' = 'REF000100-2025';

ANÁLISIS: Concatenación con columna = NO SARGABLE
*/

-- ✅ SOLUCIÓN 3:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia = 'REF000100';
-- Quitar la concatenación innecesaria

-- O si realmente necesitas el patrón:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia = REPLACE('REF000100-2025', '-2025', '');

GO

/*
PROBLEMA 4:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE DATEDIFF(DAY, FechaTransaccion, GETDATE()) < 7;

ANÁLISIS: DATEDIFF() con columna como parámetro = NO SARGABLE
SIGNIFICADO: "Transacciones de los últimos 7 días"
*/

-- ✅ SOLUCIÓN 4:
DECLARE @HaceSieteDias DATE = DATEADD(DAY, -7, GETDATE());
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= @HaceSieteDias;

-- O inline:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= DATEADD(DAY, -7, GETDATE());

GO

/*
PROBLEMA 5:
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE SUBSTRING(CodigoReferencia, 4, 3) = '001';

ANÁLISIS: SUBSTRING() en columna = NO SARGABLE
PATRÓN: CodigoReferencia = 'REF001xxx'
*/

-- ✅ SOLUCIÓN 5A (si el patrón es 'REF' + número):
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoReferencia LIKE 'REF001%';
-- LIKE con comodín al final SÍ es SARGable

-- ✅ SOLUCIÓN 5B (columna calculada si es consulta frecuente):
ALTER TABLE TRANSACCIONES_VOLUMEN
ADD CodigoSecuencia AS SUBSTRING(CodigoReferencia, 4, 3) PERSISTED;

CREATE INDEX IX_CodigoSecuencia ON TRANSACCIONES_VOLUMEN(CodigoSecuencia);

SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE CodigoSecuencia = '001';

GO

-- ============================================================
-- EJERCICIO 2: OPTIMIZAR TIPOS DE DATOS
-- ============================================================

-- Analizar una tabla existente y proponer mejoras
-- Tabla original con tipos subóptimos
IF OBJECT_ID('CLIENTES_SUBOPTIMO') IS NOT NULL DROP TABLE CLIENTES_SUBOPTIMO;

CREATE TABLE CLIENTES_SUBOPTIMO (
    ClienteID BIGINT IDENTITY PRIMARY KEY,     -- Sobredimensionado
    Nombre NVARCHAR(MAX),                       -- LOB innecesario
    Apellido NVARCHAR(MAX),                     -- LOB innecesario
    Edad BIGINT,                                -- 8 bytes para max 150
    Genero NVARCHAR(20),                        -- Debería ser CHAR(1) o BIT
    Email VARCHAR(1000),                        -- Exagerado
    Telefono VARCHAR(100),                      -- Exagerado
    FechaRegistro DATETIME,                     -- 8 bytes, solo necesita DATE
    Activo VARCHAR(10),                         -- Debería ser BIT
    SaldoPromedio FLOAT,                        -- Impreciso para dinero
    NumeroTransacciones BIGINT,                 -- Sobredimensionado
    PaisResidencia NVARCHAR(100),               -- Solo necesita código
    FechaUltimoAcceso DATETIME2(7)              -- Precisión excesiva
);

GO

-- ✅ SOLUCIÓN: Tabla optimizada
IF OBJECT_ID('CLIENTES_OPTIMIZADO') IS NOT NULL DROP TABLE CLIENTES_OPTIMIZADO;

CREATE TABLE CLIENTES_OPTIMIZADO (
    ClienteID INT IDENTITY PRIMARY KEY,         -- 4 bytes (suficiente para 2 mil millones)
    Nombre NVARCHAR(50) NOT NULL,               -- Límite razonable
    Apellido NVARCHAR(50) NOT NULL,             -- Límite razonable
    Edad TINYINT,                               -- 1 byte (0-255)
    Genero CHAR(1),                             -- 'M', 'F', 'O' = 1 byte
    Email VARCHAR(100),                         -- 100 chars suficiente
    Telefono VARCHAR(20),                       -- Formato: +51 999 999 999
    FechaRegistro DATE NOT NULL,                -- 3 bytes, solo fecha
    Activo BIT DEFAULT 1,                       -- 1 bit
    SaldoPromedio DECIMAL(15,2),                -- Preciso para dinero
    NumeroTransacciones INT DEFAULT 0,          -- 4 bytes
    CodigoPais CHAR(2),                         -- ISO 3166: PE, US, etc.
    FechaUltimoAcceso DATETIME2(0)              -- Sin milisegundos = 6 bytes
);

-- Comparar definiciones
PRINT 'Comparación de tipo de datos:';

SELECT 
    c.name AS Columna,
    t.name AS Tipo,
    c.max_length AS MaxBytes,
    c.precision AS Precision,
    c.scale AS Scale
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('CLIENTES_SUBOPTIMO')
ORDER BY c.column_id;

SELECT 
    c.name AS Columna,
    t.name AS Tipo,
    c.max_length AS MaxBytes,
    c.precision AS Precision,
    c.scale AS Scale
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('CLIENTES_OPTIMIZADO')
ORDER BY c.column_id;

GO

-- ============================================================
-- EJERCICIO 3: CREAR SP CON CONSULTAS SARGABLES
-- ============================================================

CREATE OR ALTER PROCEDURE SP_BuscarTransacciones
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @TipoTransaccion VARCHAR(20) = NULL,
    @MontoMinimo DECIMAL(15,2) = NULL,
    @MontoMaximo DECIMAL(15,2) = NULL,
    @CuentaID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Establecer defaults si no se especifican fechas
    IF @FechaInicio IS NULL
        SET @FechaInicio = DATEADD(MONTH, -1, GETDATE());
    
    IF @FechaFin IS NULL
        SET @FechaFin = GETDATE();
    
    -- Ajustar fecha fin para incluir todo el día
    SET @FechaFin = DATEADD(DAY, 1, @FechaFin);
    
    -- Consulta SARGable con parámetros opcionales
    SELECT 
        TransaccionID,
        CuentaOrigenID,
        CuentaDestinoID,
        Monto,
        FechaTransaccion,
        TipoTransaccion,
        Estado
    FROM TRANSACCIONES_VOLUMEN
    WHERE FechaTransaccion >= @FechaInicio          -- SARGable
      AND FechaTransaccion < @FechaFin              -- SARGable (< en lugar de <=)
      AND (@TipoTransaccion IS NULL OR TipoTransaccion = @TipoTransaccion)
      AND (@MontoMinimo IS NULL OR Monto >= @MontoMinimo)
      AND (@MontoMaximo IS NULL OR Monto <= @MontoMaximo)
      AND (@CuentaID IS NULL OR CuentaOrigenID = @CuentaID OR CuentaDestinoID = @CuentaID)
    ORDER BY FechaTransaccion DESC;
END
GO

-- Probar
SET STATISTICS IO ON;
EXEC SP_BuscarTransacciones @FechaInicio = '2025-03-01', @FechaFin = '2025-03-31';
EXEC SP_BuscarTransacciones @TipoTransaccion = 'TRANSFERENCIA', @MontoMinimo = 1000;
SET STATISTICS IO OFF;

GO

-- ============================================================
-- EJERCICIO 4: IDENTIFICAR CONVERSIONES IMPLÍCITAS
-- ============================================================

-- Crear tabla de ejemplo
IF OBJECT_ID('CODIGOS_CLIENTE') IS NOT NULL DROP TABLE CODIGOS_CLIENTE;

CREATE TABLE CODIGOS_CLIENTE (
    ID INT IDENTITY PRIMARY KEY,
    CodigoCliente VARCHAR(10) NOT NULL,  -- VARCHAR, no INT
    NombreCliente VARCHAR(100)
);

CREATE INDEX IX_CodigoCliente ON CODIGOS_CLIENTE(CodigoCliente);

-- Insertar datos
INSERT INTO CODIGOS_CLIENTE (CodigoCliente, NombreCliente)
SELECT 
    RIGHT('0000000000' + CAST(n AS VARCHAR), 10),
    'Cliente ' + CAST(n AS VARCHAR)
FROM (SELECT TOP 10000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n 
      FROM sys.objects a CROSS JOIN sys.objects b) x;

GO

-- ❌ MAL: Conversión implícita
SET STATISTICS IO ON;

PRINT '❌ Búsqueda con INT (conversión implícita):';
SELECT * FROM CODIGOS_CLIENTE WHERE CodigoCliente = 5000;
-- SQL convierte TODA la columna a INT

PRINT '✅ Búsqueda con VARCHAR (sin conversión):';
SELECT * FROM CODIGOS_CLIENTE WHERE CodigoCliente = '0000005000';
-- Sin conversión, usa índice

SET STATISTICS IO OFF;

GO

-- ============================================================
-- EJERCICIO 5: ANÁLISIS DE PLAN DE EJECUCIÓN
-- ============================================================

/*
Instrucciones para este ejercicio:
1. Presiona Ctrl+M para activar "Include Actual Execution Plan"
2. Ejecuta las siguientes consultas
3. Observa en el plan:
   - Index Seek (bueno) vs Index Scan (malo)
   - Costo relativo de cada operación
   - Warnings (triángulo amarillo)
*/

-- Consulta A: Operación costosa
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE YEAR(FechaTransaccion) = 2025
  AND MONTH(FechaTransaccion) = 3;
-- Esperado: Index Scan con alto costo

-- Consulta B: Operación eficiente
SELECT * FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';
-- Esperado: Index Seek con bajo costo

-- Consulta C: Key Lookup (problema común)
SELECT TransaccionID, FechaTransaccion, Descripcion
FROM TRANSACCIONES_VOLUMEN
WHERE FechaTransaccion >= '2025-03-01' 
  AND FechaTransaccion < '2025-04-01';
-- El índice IX_TransVol_Fecha no incluye Descripcion
-- SQL debe hacer Key Lookup al clustered index

-- Solución: Índice que cubre las columnas
CREATE INDEX IX_TransVol_Fecha_Inc 
ON TRANSACCIONES_VOLUMEN(FechaTransaccion) 
INCLUDE (Descripcion);

-- Repetir consulta C - ahora no debería haber Key Lookup

GO

-- ============================================================
-- EJERCICIO 6: QUIZ DE AUTOEVALUACIÓN
-- ============================================================

/*
PREGUNTA 1: ¿Cuál es la consulta SARGable?
a) WHERE CONVERT(DATE, FechaVenta) = '2025-01-15'
b) WHERE FechaVenta >= '2025-01-15' AND FechaVenta < '2025-01-16'
c) WHERE CAST(FechaVenta AS DATE) = '2025-01-15'
d) WHERE DATEDIFF(DAY, FechaVenta, '2025-01-15') = 0

PREGUNTA 2: Si tienes una columna de edad (valores 0-120), ¿qué tipo usarías?
a) INT
b) BIGINT
c) TINYINT
d) SMALLINT

PREGUNTA 3: Para almacenar montos de dinero, ¿qué tipo es correcto?
a) FLOAT
b) REAL
c) DECIMAL(15,2)
d) MONEY

PREGUNTA 4: ¿Qué indica un Index Scan en el plan de ejecución?
a) La consulta es muy rápida
b) El índice está siendo usado eficientemente
c) SQL está recorriendo todo el índice
d) La consulta es SARGable

PREGUNTA 5: La consulta WHERE Email LIKE '%@gmail.com' es:
a) SARGable porque usa LIKE
b) No SARGable porque el comodín está al inicio
c) SARGable si hay índice en Email
d) Depende del collation

RESPUESTAS:
1. b) Rango de fechas es SARGable
2. c) TINYINT (1 byte, valores 0-255)
3. c) DECIMAL para precisión exacta (MONEY también es válido pero menos portable)
4. c) SQL recorre todo el índice (ineficiente)
5. b) No SARGable - comodín al inicio = scan obligatorio
*/

GO

-- ============================================================
-- EJERCICIO 7: CASO PRÁCTICO BANCARIO
-- ============================================================

/*
ESCENARIO:
El equipo de reporting se queja de que el reporte de fin de mes tarda 45 minutos.
La consulta actual es:

SELECT 
    YEAR(T.FechaTransaccion) AS Anio,
    MONTH(T.FechaTransaccion) AS Mes,
    CONVERT(VARCHAR, T.CuentaOrigenID) AS CuentaOrigen,
    COUNT(*) AS NumTransacciones,
    SUM(T.Monto) AS MontoTotal
FROM TRANSACCIONES_VOLUMEN T
WHERE YEAR(T.FechaTransaccion) = YEAR(GETDATE())
  AND LEFT(CONVERT(VARCHAR, T.CuentaOrigenID), 2) = '10'
  AND ISNULL(T.Estado, 'PENDIENTE') = 'COMPLETADA'
GROUP BY 
    YEAR(T.FechaTransaccion),
    MONTH(T.FechaTransaccion),
    CONVERT(VARCHAR, T.CuentaOrigenID)
ORDER BY Mes, CuentaOrigen;

IDENTIFICA:
1. ¿Cuántos problemas de SARGability hay?
2. ¿Qué conversiones implícitas existen?
3. Escribe la versión optimizada
*/

-- ✅ SOLUCIÓN:
-- Problemas identificados:
-- 1. YEAR(FechaTransaccion) - No SARGable
-- 2. LEFT(CONVERT(VARCHAR, CuentaOrigenID), 2) - No SARGable + conversión
-- 3. ISNULL(Estado, 'PENDIENTE') - No SARGable
-- 4. CONVERT en GROUP BY - Cálculo repetido

DECLARE @AnioActual INT = YEAR(GETDATE());
DECLARE @InicioAnio DATE = DATEFROMPARTS(@AnioActual, 1, 1);
DECLARE @FinAnio DATE = DATEFROMPARTS(@AnioActual + 1, 1, 1);

SELECT 
    @AnioActual AS Anio,
    MONTH(T.FechaTransaccion) AS Mes,
    T.CuentaOrigenID AS CuentaOrigen,  -- Sin conversión
    COUNT(*) AS NumTransacciones,
    SUM(T.Monto) AS MontoTotal
FROM TRANSACCIONES_VOLUMEN T
WHERE T.FechaTransaccion >= @InicioAnio        -- ✅ SARGable
  AND T.FechaTransaccion < @FinAnio            -- ✅ SARGable
  AND T.CuentaOrigenID >= 100                   -- ✅ SARGable (asumiendo que "10X" = 100-109)
  AND T.CuentaOrigenID < 110
  AND T.Estado = 'COMPLETADA'                   -- ✅ SARGable, sin ISNULL
GROUP BY 
    MONTH(T.FechaTransaccion),
    T.CuentaOrigenID
ORDER BY Mes, CuentaOrigen;

GO

PRINT 'Fin de los ejercicios prácticos - Sesión 3';
