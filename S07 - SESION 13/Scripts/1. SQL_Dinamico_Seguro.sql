/***************************************************************
 * SESIÓN 13: SQL DINÁMICO SEGURO
 * Curso: SQL Server Intermedio 2026
 * Semana 7 - EXEC vs sp_executesql, Prevención SQL Injection
 * 
 * Base de datos: BancoDB
 * 
 * CONTENIDO:
 *   1. ¿Qué es SQL Dinámico y cuándo usarlo?
 *   2. EXEC (@sql) - El método básico (y peligroso)
 *   3. sp_executesql - El método seguro parametrizado
 *   4. SQL Injection: Ataques y Prevención
 *   5. QUOTENAME para identificadores
 *   6. Búsquedas dinámicas seguras
 *   7. Validación de nombres de tabla/columna
 *   8. Generación de DDL dinámico
 *   9. Debugging de SQL Dinámico
 *  10. Mejores Prácticas y Patrones
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- PARTE 1: ¿QUÉ ES SQL DINÁMICO Y CUÁNDO USARLO?
-- ============================================================
/*
   SQL Dinámico = SQL construido como string en tiempo de ejecución
   
   CASOS LEGÍTIMOS:
   ✓ Nombres de tabla/columna variables
   ✓ Búsquedas con filtros opcionales
   ✓ Pivot dinámico
   ✓ Generación de DDL (CREATE/ALTER)
   ✓ Mantenimiento/DBA tasks
   
   CASOS DONDE EVITAR:
   ✗ Valores parametrizables (usar parámetros normales)
   ✗ Lógica que puede resolverse con CASE
   ✗ Cuando static SQL es suficiente
*/

-- Ejemplo: ¿Por qué necesitamos SQL dinámico?
-- Esto NO funciona (nombres de tabla no pueden ser parámetros)
/*
CREATE PROCEDURE ObtenerDatos @Tabla NVARCHAR(128)
AS
    SELECT * FROM @Tabla;  -- ERROR!
*/

-- ============================================================
-- PARTE 2: EXEC (@sql) - EL MÉTODO BÁSICO
-- ============================================================
/*
   EXEC ejecuta una cadena SQL
   
   PROBLEMAS:
   - No soporta parámetros de salida directamente
   - No cachea planes de ejecución eficientemente
   - VULNERABLE a SQL Injection si concatena datos de usuario
*/

-- Ejemplo básico con EXEC
DECLARE @sql NVARCHAR(MAX);
DECLARE @NombreTabla NVARCHAR(128) = 'CLIENTES';

SET @sql = N'SELECT TOP 5 * FROM ' + @NombreTabla;
PRINT @sql;  -- Siempre debug
EXEC (@sql);
GO

-- PELIGRO: Concatenación de datos de usuario
-- ¡NUNCA HACER ESTO EN PRODUCCIÓN!
CREATE OR ALTER PROCEDURE BuscarClienteInseguro
    @Nombre NVARCHAR(100)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    
    -- ⚠️ VULNERABLE A SQL INJECTION
    SET @sql = N'SELECT * FROM CLIENTES WHERE Nombre LIKE ''%' + @Nombre + '%''';
    
    PRINT 'SQL Ejecutado: ' + @sql;
    EXEC (@sql);
END;
GO

-- Uso normal (funciona)
EXEC BuscarClienteInseguro @Nombre = 'García';

-- ⚠️ ATAQUE SQL INJECTION
-- El atacante puede inyectar código malicioso
EXEC BuscarClienteInseguro @Nombre = '''; DROP TABLE CLIENTES; --';
-- El SQL resultante sería:
-- SELECT * FROM CLIENTES WHERE Nombre LIKE '%'; DROP TABLE CLIENTES; --%'

GO

-- ============================================================
-- PARTE 3: sp_executesql - EL MÉTODO SEGURO
-- ============================================================
/*
   sp_executesql:
   ✓ Soporta parámetros (entrada y salida)
   ✓ Mejor reutilización de planes de ejecución
   ✓ PREVIENE SQL Injection cuando se usa correctamente
   
   Sintaxis:
   EXEC sp_executesql 
       @stmt = N'SQL con @parametros',
       @params = N'@param1 tipo, @param2 tipo',
       @param1 = valor1,
       @param2 = valor2;
*/

-- Ejemplo básico con sp_executesql
DECLARE @sql NVARCHAR(MAX);
DECLARE @ClienteID INT = 1;

SET @sql = N'SELECT * FROM CLIENTES WHERE ClienteID = @ID';

EXEC sp_executesql 
    @stmt = @sql,
    @params = N'@ID INT',
    @ID = @ClienteID;
GO

-- Versión SEGURA del procedimiento de búsqueda
CREATE OR ALTER PROCEDURE BuscarClienteSeguro
    @Nombre NVARCHAR(100)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(500);
    
    -- ✓ SEGURO: El valor se pasa como parámetro
    SET @sql = N'SELECT * FROM CLIENTES WHERE Nombre LIKE ''%'' + @NombreBuscar + ''%''';
    SET @params = N'@NombreBuscar NVARCHAR(100)';
    
    EXEC sp_executesql 
        @stmt = @sql,
        @params = @params,
        @NombreBuscar = @Nombre;
END;
GO

-- Ahora el ataque NO funciona
EXEC BuscarClienteSeguro @Nombre = '''; DROP TABLE CLIENTES; --';
-- El valor se trata como literal, no como código SQL
GO

-- Parámetros de SALIDA con sp_executesql
DECLARE @sql NVARCHAR(MAX);
DECLARE @params NVARCHAR(500);
DECLARE @TotalClientes INT;

SET @sql = N'SELECT @Total = COUNT(*) FROM CLIENTES WHERE Estado = @Est';
SET @params = N'@Est NVARCHAR(20), @Total INT OUTPUT';

EXEC sp_executesql 
    @stmt = @sql,
    @params = @params,
    @Est = 'Activo',
    @Total = @TotalClientes OUTPUT;

SELECT @TotalClientes AS TotalClientesActivos;
GO

-- ============================================================
-- PARTE 4: SQL INJECTION - ATAQUES Y PREVENCIÓN
-- ============================================================
/*
   SQL Injection: Cuando datos del usuario se interpretan como código SQL
   
   TIPOS DE ATAQUES:
   1. Terminación de string: ' OR '1'='1
   2. Comentarios: --  o  /* */
   3. UNION injection: ' UNION SELECT ...
   4. Stacked queries: '; DROP TABLE ...
   5. Blind injection: ' AND 1=1 -- (inferir datos por respuestas)
*/

-- TABLA DE DEMO (para ejemplos seguros)
CREATE TABLE #LoginDemo (
    Usuario NVARCHAR(50),
    Password NVARCHAR(50),
    Rol NVARCHAR(20)
);

INSERT INTO #LoginDemo VALUES 
('admin', 'secreto123', 'Admin'),
('usuario1', 'pass1', 'Usuario');
GO

-- ⚠️ PROCEDIMIENTO VULNERABLE
CREATE OR ALTER PROCEDURE LoginInseguro
    @Usuario NVARCHAR(50),
    @Password NVARCHAR(50)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    
    SET @sql = N'SELECT * FROM #LoginDemo 
                 WHERE Usuario = ''' + @Usuario + ''' 
                 AND Password = ''' + @Password + '''';
    
    PRINT 'SQL: ' + @sql;
    EXEC (@sql);
END;
GO

-- Login normal
EXEC LoginInseguro 'admin', 'secreto123';

-- ⚠️ ATAQUE: Bypass de autenticación
EXEC LoginInseguro 'admin', 'x'' OR ''1''=''1';
-- SQL resultante: WHERE Usuario = 'admin' AND Password = 'x' OR '1'='1'
-- ¡Devuelve TODOS los usuarios!

GO

-- ✓ PROCEDIMIENTO SEGURO
CREATE OR ALTER PROCEDURE LoginSeguro
    @Usuario NVARCHAR(50),
    @Password NVARCHAR(50)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    
    SET @sql = N'SELECT * FROM #LoginDemo 
                 WHERE Usuario = @User AND Password = @Pass';
    SET @params = N'@User NVARCHAR(50), @Pass NVARCHAR(50)';
    
    EXEC sp_executesql @sql, @params,
        @User = @Usuario, 
        @Pass = @Password;
END;
GO

-- El ataque ya no funciona
EXEC LoginSeguro 'admin', 'x'' OR ''1''=''1';
-- Se busca literalmente el password "x' OR '1'='1"

DROP TABLE #LoginDemo;
GO

-- ============================================================
-- PARTE 5: QUOTENAME PARA IDENTIFICADORES
-- ============================================================
/*
   QUOTENAME: Escapa nombres de objetos (tablas, columnas, schemas)
   
   ¿Por qué es necesario?
   - Nombres con espacios: [Mi Tabla]
   - Nombres reservados: [SELECT], [FROM]
   - Previene injection en identificadores
   
   Sintaxis: QUOTENAME('nombre') o QUOTENAME('nombre', '"')
*/

-- Ejemplo básico
SELECT 
    QUOTENAME('CLIENTES') AS ConCorchetes,
    QUOTENAME('Mi Tabla') AS ConEspacios,
    QUOTENAME('nombre', '''') AS ConComillasSimples;
GO

-- Procedimiento seguro para consultar cualquier tabla
CREATE OR ALTER PROCEDURE ConsultarTablaDinamica
    @Schema NVARCHAR(128) = 'dbo',
    @Tabla NVARCHAR(128),
    @TopN INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    
    -- Validar que la tabla existe
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = @Schema AND TABLE_NAME = @Tabla
    )
    BEGIN
        RAISERROR('La tabla %s.%s no existe.', 16, 1, @Schema, @Tabla);
        RETURN;
    END;
    
    -- Construir SQL con QUOTENAME
    SET @sql = N'SELECT TOP (@TopN) * FROM ' 
             + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Tabla);
    
    PRINT 'SQL: ' + @sql;
    
    EXEC sp_executesql @sql, N'@TopN INT', @TopN = @TopN;
END;
GO

-- Uso seguro
EXEC ConsultarTablaDinamica @Tabla = 'CLIENTES', @TopN = 5;
EXEC ConsultarTablaDinamica @Schema = 'dbo', @Tabla = 'CUENTAS';

-- Intento de injection (falla porque la tabla no existe)
EXEC ConsultarTablaDinamica @Tabla = 'CLIENTES; DROP TABLE CLIENTES';
GO

-- ============================================================
-- PARTE 6: BÚSQUEDAS DINÁMICAS SEGURAS
-- ============================================================
/*
   Patrón para búsquedas con filtros opcionales
   Cada filtro se aplica solo si tiene valor
*/

CREATE OR ALTER PROCEDURE BuscarClientesAvanzado
    @ClienteID INT = NULL,
    @Nombre NVARCHAR(100) = NULL,
    @Email NVARCHAR(150) = NULL,
    @Estado NVARCHAR(20) = NULL,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL,
    @SaldoMinimo DECIMAL(18,2) = NULL,
    @OrderBy NVARCHAR(50) = 'ClienteID',
    @Ascendente BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(1000);
    DECLARE @where NVARCHAR(MAX) = N'';
    
    -- Base de la consulta
    SET @sql = N'
        SELECT 
            c.ClienteID,
            c.Nombre,
            c.Email,
            c.Estado,
            c.FechaRegistro,
            (SELECT SUM(Saldo) FROM CUENTAS WHERE ClienteID = c.ClienteID) AS SaldoTotal
        FROM CLIENTES c
        WHERE 1=1 ';
    
    -- Construir filtros dinámicamente
    IF @ClienteID IS NOT NULL
        SET @where = @where + N' AND c.ClienteID = @pClienteID';
    
    IF @Nombre IS NOT NULL
        SET @where = @where + N' AND c.Nombre LIKE ''%'' + @pNombre + ''%''';
    
    IF @Email IS NOT NULL
        SET @where = @where + N' AND c.Email LIKE ''%'' + @pEmail + ''%''';
    
    IF @Estado IS NOT NULL
        SET @where = @where + N' AND c.Estado = @pEstado';
    
    IF @FechaDesde IS NOT NULL
        SET @where = @where + N' AND c.FechaRegistro >= @pFechaDesde';
    
    IF @FechaHasta IS NOT NULL
        SET @where = @where + N' AND c.FechaRegistro <= @pFechaHasta';
    
    IF @SaldoMinimo IS NOT NULL
        SET @where = @where + N' AND (SELECT SUM(Saldo) FROM CUENTAS WHERE ClienteID = c.ClienteID) >= @pSaldoMinimo';
    
    SET @sql = @sql + @where;
    
    -- ORDER BY dinámico (validado contra lista blanca)
    SET @sql = @sql + N' ORDER BY ' + 
        CASE @OrderBy
            WHEN 'ClienteID' THEN 'c.ClienteID'
            WHEN 'Nombre' THEN 'c.Nombre'
            WHEN 'Email' THEN 'c.Email'
            WHEN 'FechaRegistro' THEN 'c.FechaRegistro'
            ELSE 'c.ClienteID'  -- Default seguro
        END +
        CASE WHEN @Ascendente = 1 THEN ' ASC' ELSE ' DESC' END;
    
    -- Definir parámetros
    SET @params = N'
        @pClienteID INT,
        @pNombre NVARCHAR(100),
        @pEmail NVARCHAR(150),
        @pEstado NVARCHAR(20),
        @pFechaDesde DATE,
        @pFechaHasta DATE,
        @pSaldoMinimo DECIMAL(18,2)';
    
    -- Debug
    PRINT '-- SQL Generado:';
    PRINT @sql;
    
    -- Ejecutar
    EXEC sp_executesql @sql, @params,
        @pClienteID = @ClienteID,
        @pNombre = @Nombre,
        @pEmail = @Email,
        @pEstado = @Estado,
        @pFechaDesde = @FechaDesde,
        @pFechaHasta = @FechaHasta,
        @pSaldoMinimo = @SaldoMinimo;
END;
GO

-- Ejemplos de uso
EXEC BuscarClientesAvanzado @Estado = 'Activo';
EXEC BuscarClientesAvanzado @Nombre = 'García', @SaldoMinimo = 1000;
EXEC BuscarClientesAvanzado @FechaDesde = '2024-01-01', @OrderBy = 'Nombre';
GO

-- ============================================================
-- PARTE 7: VALIDACIÓN DE NOMBRES DE TABLA/COLUMNA
-- ============================================================
/*
   SIEMPRE validar nombres de objetos contra catálogos del sistema
   Nunca confiar en input del usuario para nombres de objetos
*/

-- Función para validar y obtener nombre de tabla
CREATE OR ALTER FUNCTION dbo.fn_ValidarTabla
(
    @Schema NVARCHAR(128),
    @Tabla NVARCHAR(128)
)
RETURNS NVARCHAR(500)
AS
BEGIN
    DECLARE @NombreCompleto NVARCHAR(500) = NULL;
    
    SELECT @NombreCompleto = QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = @Schema 
      AND TABLE_NAME = @Tabla
      AND TABLE_TYPE = 'BASE TABLE';
    
    RETURN @NombreCompleto;
END;
GO

-- Función para validar columna
CREATE OR ALTER FUNCTION dbo.fn_ValidarColumna
(
    @Schema NVARCHAR(128),
    @Tabla NVARCHAR(128),
    @Columna NVARCHAR(128)
)
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @NombreColumna NVARCHAR(128) = NULL;
    
    SELECT @NombreColumna = QUOTENAME(COLUMN_NAME)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @Schema 
      AND TABLE_NAME = @Tabla
      AND COLUMN_NAME = @Columna;
    
    RETURN @NombreColumna;
END;
GO

-- Procedimiento con validación completa
CREATE OR ALTER PROCEDURE ConsultarColumnaDinamica
    @Schema NVARCHAR(128) = 'dbo',
    @Tabla NVARCHAR(128),
    @Columna NVARCHAR(128),
    @Valor NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TablaValidada NVARCHAR(500);
    DECLARE @ColumnaValidada NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    
    -- Validar tabla
    SET @TablaValidada = dbo.fn_ValidarTabla(@Schema, @Tabla);
    IF @TablaValidada IS NULL
    BEGIN
        RAISERROR('Tabla no válida: %s.%s', 16, 1, @Schema, @Tabla);
        RETURN;
    END;
    
    -- Validar columna
    SET @ColumnaValidada = dbo.fn_ValidarColumna(@Schema, @Tabla, @Columna);
    IF @ColumnaValidada IS NULL
    BEGIN
        RAISERROR('Columna no válida: %s', 16, 1, @Columna);
        RETURN;
    END;
    
    -- Construir y ejecutar
    SET @sql = N'SELECT * FROM ' + @TablaValidada 
             + N' WHERE ' + @ColumnaValidada + N' = @Valor';
    
    PRINT 'SQL: ' + @sql;
    
    EXEC sp_executesql @sql, N'@Valor NVARCHAR(MAX)', @Valor = @Valor;
END;
GO

-- Uso
EXEC ConsultarColumnaDinamica 
    @Tabla = 'CLIENTES', 
    @Columna = 'Estado', 
    @Valor = 'Activo';

-- Rechaza columnas inválidas
EXEC ConsultarColumnaDinamica 
    @Tabla = 'CLIENTES', 
    @Columna = 'ColumnaFalsa', 
    @Valor = 'test';
GO

-- ============================================================
-- PARTE 8: GENERACIÓN DE DDL DINÁMICO
-- ============================================================
/*
   Casos comunes de DDL dinámico:
   - Crear índices basados en análisis
   - Generar scripts de backup
   - Automatizar creación de tablas
*/

-- Procedimiento para crear índice dinámicamente
CREATE OR ALTER PROCEDURE CrearIndiceDinamico
    @Schema NVARCHAR(128) = 'dbo',
    @Tabla NVARCHAR(128),
    @Columnas NVARCHAR(500),  -- Separadas por coma
    @NombreIndice NVARCHAR(128) = NULL,
    @Unico BIT = 0,
    @SoloValidar BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @TablaCompleta NVARCHAR(500);
    DECLARE @ColumnasValidadas NVARCHAR(500) = N'';
    DECLARE @Columna NVARCHAR(128);
    DECLARE @ColumnaValidada NVARCHAR(128);
    
    -- Validar tabla
    SET @TablaCompleta = dbo.fn_ValidarTabla(@Schema, @Tabla);
    IF @TablaCompleta IS NULL
    BEGIN
        RAISERROR('Tabla no existe: %s.%s', 16, 1, @Schema, @Tabla);
        RETURN;
    END;
    
    -- Validar cada columna
    DECLARE @xml XML = CAST('<c>' + REPLACE(@Columnas, ',', '</c><c>') + '</c>' AS XML);
    
    DECLARE curColumnas CURSOR LOCAL FAST_FORWARD FOR
        SELECT LTRIM(RTRIM(c.value('.', 'NVARCHAR(128)')))
        FROM @xml.nodes('/c') AS T(c);
    
    OPEN curColumnas;
    FETCH NEXT FROM curColumnas INTO @Columna;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ColumnaValidada = dbo.fn_ValidarColumna(@Schema, @Tabla, @Columna);
        
        IF @ColumnaValidada IS NULL
        BEGIN
            CLOSE curColumnas;
            DEALLOCATE curColumnas;
            RAISERROR('Columna no válida: %s', 16, 1, @Columna);
            RETURN;
        END;
        
        IF LEN(@ColumnasValidadas) > 0
            SET @ColumnasValidadas = @ColumnasValidadas + N', ';
        SET @ColumnasValidadas = @ColumnasValidadas + @ColumnaValidada;
        
        FETCH NEXT FROM curColumnas INTO @Columna;
    END;
    
    CLOSE curColumnas;
    DEALLOCATE curColumnas;
    
    -- Generar nombre de índice si no se proporcionó
    IF @NombreIndice IS NULL
        SET @NombreIndice = N'IX_' + @Tabla + N'_' + REPLACE(@Columnas, ',', '_');
    
    -- Construir DDL
    SET @sql = N'CREATE ' + 
               CASE WHEN @Unico = 1 THEN 'UNIQUE ' ELSE '' END +
               N'INDEX ' + QUOTENAME(@NombreIndice) +
               N' ON ' + @TablaCompleta +
               N' (' + @ColumnasValidadas + N')';
    
    PRINT '-- Script generado:';
    PRINT @sql;
    
    IF @SoloValidar = 0
    BEGIN
        EXEC sp_executesql @sql;
        PRINT '-- Índice creado exitosamente';
    END;
END;
GO

-- Solo generar el script (no ejecutar)
EXEC CrearIndiceDinamico 
    @Tabla = 'CLIENTES', 
    @Columnas = 'Estado, FechaRegistro',
    @SoloValidar = 1;
GO

-- ============================================================
-- PARTE 9: DEBUGGING DE SQL DINÁMICO
-- ============================================================
/*
   TÉCNICAS DE DEBUGGING:
   1. PRINT antes de EXEC
   2. Parámetro @Debug para habilitar/deshabilitar
   3. Guardar en tabla de log
   4. Usar TRY...CATCH para capturar errores
*/

-- Plantilla con debugging integrado
CREATE OR ALTER PROCEDURE PlantillaSQLDinamico
    @Parametro1 INT,
    @Parametro2 NVARCHAR(100) = NULL,
    @Debug BIT = 0,
    @SoloMostrarSQL BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(500);
    DECLARE @ErrorMessage NVARCHAR(4000);
    
    BEGIN TRY
        -- Construir SQL
        SET @sql = N'
            SELECT *
            FROM CLIENTES
            WHERE ClienteID >= @P1';
        
        IF @Parametro2 IS NOT NULL
            SET @sql = @sql + N' AND Nombre LIKE ''%'' + @P2 + ''%''';
        
        SET @params = N'@P1 INT, @P2 NVARCHAR(100)';
        
        -- Debug
        IF @Debug = 1 OR @SoloMostrarSQL = 1
        BEGIN
            PRINT '========================================';
            PRINT '-- SQL Generado:';
            PRINT @sql;
            PRINT '-- Parámetros:';
            PRINT '@P1 = ' + CAST(@Parametro1 AS NVARCHAR(20));
            PRINT '@P2 = ' + ISNULL(@Parametro2, 'NULL');
            PRINT '========================================';
        END;
        
        -- Ejecutar (si no es solo mostrar)
        IF @SoloMostrarSQL = 0
        BEGIN
            EXEC sp_executesql @sql, @params,
                @P1 = @Parametro1,
                @P2 = @Parametro2;
        END;
        
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        
        -- Log del error con el SQL que falló
        PRINT '=== ERROR ===';
        PRINT 'SQL: ' + @sql;
        PRINT 'Error: ' + @ErrorMessage;
        
        -- Re-lanzar el error
        THROW;
    END CATCH;
END;
GO

-- Probar con debug
EXEC PlantillaSQLDinamico @Parametro1 = 1, @Debug = 1;
EXEC PlantillaSQLDinamico @Parametro1 = 1, @Parametro2 = 'García', @SoloMostrarSQL = 1;
GO

-- Tabla para logging de SQL dinámico (útil en producción)
CREATE TABLE #SQLDinamicoLog (
    LogID INT IDENTITY PRIMARY KEY,
    FechaEjecucion DATETIME2 DEFAULT SYSDATETIME(),
    Procedimiento NVARCHAR(128),
    SQLGenerado NVARCHAR(MAX),
    Parametros NVARCHAR(MAX),
    DuracionMS INT,
    Error NVARCHAR(MAX) NULL
);
GO

-- ============================================================
-- PARTE 10: MEJORES PRÁCTICAS Y PATRONES
-- ============================================================

/*
   CHECKLIST DE SEGURIDAD PARA SQL DINÁMICO:
   
   ✓ SIEMPRE usar sp_executesql para valores
   ✓ SIEMPRE usar QUOTENAME para identificadores
   ✓ SIEMPRE validar tablas/columnas contra catálogos
   ✓ SIEMPRE usar lista blanca para ORDER BY
   ✓ NUNCA concatenar directamente input del usuario
   ✓ SIEMPRE incluir modo debug/validación
   ✓ USAR TRY...CATCH para manejo de errores
*/

-- PATRÓN RECOMENDADO: Procedimiento robusto completo
CREATE OR ALTER PROCEDURE sp_BusquedaUniversalSegura
    @Schema NVARCHAR(128) = 'dbo',
    @Tabla NVARCHAR(128),
    @ColumnaFiltro NVARCHAR(128) = NULL,
    @ValorFiltro NVARCHAR(MAX) = NULL,
    @ColumnaOrden NVARCHAR(128) = NULL,
    @Ascendente BIT = 1,
    @Top INT = 100,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(500);
    DECLARE @TablaValidada NVARCHAR(500);
    DECLARE @ColumnaFiltroValidada NVARCHAR(128);
    DECLARE @ColumnaOrdenValidada NVARCHAR(128);
    
    BEGIN TRY
        -- 1. Validar tabla (OBLIGATORIO)
        SET @TablaValidada = dbo.fn_ValidarTabla(@Schema, @Tabla);
        IF @TablaValidada IS NULL
        BEGIN
            RAISERROR('Tabla no existe o no es accesible: %s.%s', 16, 1, @Schema, @Tabla);
            RETURN;
        END;
        
        -- 2. Validar columna de filtro (si se proporciona)
        IF @ColumnaFiltro IS NOT NULL
        BEGIN
            SET @ColumnaFiltroValidada = dbo.fn_ValidarColumna(@Schema, @Tabla, @ColumnaFiltro);
            IF @ColumnaFiltroValidada IS NULL
            BEGIN
                RAISERROR('Columna de filtro no válida: %s', 16, 1, @ColumnaFiltro);
                RETURN;
            END;
        END;
        
        -- 3. Validar columna de orden (si se proporciona)
        IF @ColumnaOrden IS NOT NULL
        BEGIN
            SET @ColumnaOrdenValidada = dbo.fn_ValidarColumna(@Schema, @Tabla, @ColumnaOrden);
            IF @ColumnaOrdenValidada IS NULL
            BEGIN
                -- No error, usar orden por defecto
                SET @ColumnaOrdenValidada = NULL;
            END;
        END;
        
        -- 4. Construir SQL
        SET @sql = N'SELECT TOP (@TopN) * FROM ' + @TablaValidada;
        
        IF @ColumnaFiltroValidada IS NOT NULL AND @ValorFiltro IS NOT NULL
            SET @sql = @sql + N' WHERE ' + @ColumnaFiltroValidada + N' = @Valor';
        
        IF @ColumnaOrdenValidada IS NOT NULL
            SET @sql = @sql + N' ORDER BY ' + @ColumnaOrdenValidada 
                     + CASE WHEN @Ascendente = 1 THEN ' ASC' ELSE ' DESC' END;
        
        SET @params = N'@TopN INT, @Valor NVARCHAR(MAX)';
        
        -- 5. Debug
        IF @Debug = 1
        BEGIN
            PRINT '-- Tabla: ' + @TablaValidada;
            PRINT '-- SQL:';
            PRINT @sql;
        END;
        
        -- 6. Ejecutar
        EXEC sp_executesql @sql, @params,
            @TopN = @Top,
            @Valor = @ValorFiltro;
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log si hay tabla de log
        -- INSERT INTO SQLErrorLog ...
        
        RAISERROR(@ErrorMsg, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- Ejemplos de uso del patrón robusto
EXEC sp_BusquedaUniversalSegura 
    @Tabla = 'CLIENTES', 
    @Debug = 1;

EXEC sp_BusquedaUniversalSegura 
    @Tabla = 'CLIENTES', 
    @ColumnaFiltro = 'Estado', 
    @ValorFiltro = 'Activo',
    @ColumnaOrden = 'Nombre';

EXEC sp_BusquedaUniversalSegura 
    @Tabla = 'CUENTAS', 
    @Top = 10,
    @ColumnaOrden = 'Saldo',
    @Ascendente = 0;
GO

-- ============================================================
-- BONUS: PIVOT DINÁMICO
-- ============================================================
/*
   Caso típico donde SQL dinámico es necesario:
   Los valores del PIVOT no se conocen en tiempo de diseño
*/

CREATE OR ALTER PROCEDURE PivotTransaccionesPorMes
    @Anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @Anio = ISNULL(@Anio, YEAR(GETDATE()));
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columnas NVARCHAR(MAX);
    
    -- Obtener los meses que tienen datos
    SELECT @columnas = STRING_AGG(QUOTENAME(NombreMes), ',') 
                       WITHIN GROUP (ORDER BY NumMes)
    FROM (
        SELECT DISTINCT 
            MONTH(FechaTransaccion) AS NumMes,
            DATENAME(MONTH, FechaTransaccion) AS NombreMes
        FROM TRANSACCIONES_BANCARIAS
        WHERE YEAR(FechaTransaccion) = @Anio
    ) meses;
    
    IF @columnas IS NULL
    BEGIN
        PRINT 'No hay transacciones para el año ' + CAST(@Anio AS VARCHAR(4));
        RETURN;
    END;
    
    SET @sql = N'
        SELECT TipoTransaccion, ' + @columnas + N'
        FROM (
            SELECT 
                TipoTransaccion,
                DATENAME(MONTH, FechaTransaccion) AS Mes,
                Monto
            FROM TRANSACCIONES_BANCARIAS
            WHERE YEAR(FechaTransaccion) = @Anio
        ) AS Origen
        PIVOT (
            SUM(Monto)
            FOR Mes IN (' + @columnas + N')
        ) AS PivotTable
        ORDER BY TipoTransaccion';
    
    PRINT '-- SQL Pivot:';
    PRINT @sql;
    
    EXEC sp_executesql @sql, N'@Anio INT', @Anio = @Anio;
END;
GO

EXEC PivotTransaccionesPorMes @Anio = 2025;
GO

-- ============================================================
-- RESUMEN DE LA SESIÓN
-- ============================================================
/*
   PUNTOS CLAVE:
   
   1. EXEC (@sql) - Simple pero PELIGROSO
      - No usar con datos de usuario
      - No cachea planes eficientemente
   
   2. sp_executesql - SIEMPRE preferir
      - Parámetros seguros
      - Mejor reutilización de planes
      - Previene SQL Injection
   
   3. QUOTENAME - Para identificadores
      - Tablas, columnas, schemas
      - Escapa caracteres especiales
   
   4. VALIDACIÓN - Siempre validar
      - Nombres contra catálogos del sistema
      - Lista blanca para ORDER BY
      - Rechazar input inválido
   
   5. DEBUGGING - Incluir siempre
      - Parámetro @Debug
      - PRINT antes de EXEC
      - TRY...CATCH con logging
   
   REGLA DE ORO:
   "Si viene del usuario, es un parámetro.
    Si es un identificador, se valida primero."
*/

-- Limpieza
DROP FUNCTION IF EXISTS dbo.fn_ValidarTabla;
DROP FUNCTION IF EXISTS dbo.fn_ValidarColumna;
DROP TABLE IF EXISTS #SQLDinamicoLog;
GO

PRINT '✓ Sesión 13 completada: SQL Dinámico Seguro';
GO
