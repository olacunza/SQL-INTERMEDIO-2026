/***************************************************************
 * EJERCICIOS - SESIÓN 13: SQL DINÁMICO SEGURO
 * Curso: SQL Server Intermedio 2026
 * 
 * Base de datos: BancoDB
 * 
 * INSTRUCCIONES:
 * - Completar cada ejercicio usando SQL dinámico SEGURO
 * - Usar sp_executesql con parámetros
 * - Validar todos los identificadores con QUOTENAME
 * - Incluir manejo de errores donde se indique
 * - Las soluciones están al final del archivo
 ***************************************************************/

USE BancoDB;
GO

-- ============================================================
-- EJERCICIO 1: BÚSQUEDA PARAMETRIZADA BÁSICA
-- ============================================================
/*
   OBJETIVO: Crear un procedimiento que busque clientes por cualquier
             campo de texto (Nombre, Email, Direccion)
   
   REQUISITOS:
   - Parámetro @Campo: el nombre del campo a buscar
   - Parámetro @Valor: el valor a buscar (búsqueda parcial con LIKE)
   - Validar que @Campo sea uno de los permitidos (lista blanca)
   - Usar sp_executesql para el valor
   
   EJEMPLO DE USO:
   EXEC BuscarClientePorCampo @Campo = 'Nombre', @Valor = 'García';
   EXEC BuscarClientePorCampo @Campo = 'Email', @Valor = '@gmail';
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE BuscarClientePorCampo
    @Campo NVARCHAR(50),
    @Valor NVARCHAR(200)
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 2: ORDENAMIENTO DINÁMICO SEGURO
-- ============================================================
/*
   OBJETIVO: Crear un SP que liste transacciones con ordenamiento
             dinámico por cualquier columna válida
   
   REQUISITOS:
   - @ColumnaOrden: nombre de columna para ordenar
   - @Direccion: 'ASC' o 'DESC'
   - @Top: número máximo de registros (default 50)
   - Validar columna contra lista blanca de columnas permitidas
   - Validar que @Direccion sea 'ASC' o 'DESC'
   
   COLUMNAS PERMITIDAS: TransaccionID, CuentaID, Monto, 
                        FechaTransaccion, TipoTransaccion
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE ListarTransaccionesOrdenadas
    @ColumnaOrden NVARCHAR(50) = 'TransaccionID',
    @Direccion NVARCHAR(4) = 'ASC',
    @Top INT = 50
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 3: CONSULTA DE TABLA GENÉRICA
-- ============================================================
/*
   OBJETIVO: Crear un SP que consulte cualquier tabla del sistema
             de forma segura
   
   REQUISITOS:
   - @NombreTabla: nombre de la tabla a consultar
   - @Top: número de registros (default 100)
   - Validar que la tabla exista usando INFORMATION_SCHEMA
   - Usar QUOTENAME para el nombre de tabla
   - Retornar error si la tabla no existe
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE ConsultarTablaGenerica
    @NombreTabla NVARCHAR(128),
    @Top INT = 100
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 4: FILTROS OPCIONALES MÚLTIPLES
-- ============================================================
/*
   OBJETIVO: SP de búsqueda de cuentas con múltiples filtros opcionales
   
   REQUISITOS:
   - @TipoCuenta: filtro por tipo (opcional)
   - @SaldoMinimo: filtro por saldo >= (opcional)
   - @SaldoMaximo: filtro por saldo <= (opcional)
   - @Estado: filtro por estado (opcional)
   - @ClienteID: filtro por cliente (opcional)
   - Solo aplicar filtros que tengan valor (no NULL)
   - Usar sp_executesql con todos los parámetros
   
   NOTA: Los filtros deben sumarse (AND), no excluirse
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE BuscarCuentasFiltros
    @TipoCuenta NVARCHAR(20) = NULL,
    @SaldoMinimo DECIMAL(18,2) = NULL,
    @SaldoMaximo DECIMAL(18,2) = NULL,
    @Estado NVARCHAR(20) = NULL,
    @ClienteID INT = NULL
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 5: CONTEO DINÁMICO CON OUTPUT
-- ============================================================
/*
   OBJETIVO: SP que cuente registros de cualquier tabla con
             filtro opcional, retornando el conteo
   
   REQUISITOS:
   - @Tabla: nombre de tabla a contar
   - @ColumnaFiltro: columna para filtrar (opcional)
   - @ValorFiltro: valor del filtro (opcional)
   - @Conteo OUTPUT: parámetro de salida con el resultado
   - Validar tabla existe
   - Validar columna existe (si se proporciona)
   - Usar parámetro OUTPUT de sp_executesql
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE ContarRegistrosDinamico
    @Tabla NVARCHAR(128),
    @ColumnaFiltro NVARCHAR(128) = NULL,
    @ValorFiltro NVARCHAR(MAX) = NULL,
    @Conteo INT OUTPUT
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 6: IDENTIFICAR SQL INJECTION
-- ============================================================
/*
   OBJETIVO: Revisar el siguiente código e identificar TODAS las
             vulnerabilidades de SQL Injection
   
   INSTRUCCIONES:
   - Marcar cada línea vulnerable con un comentario
   - Explicar por qué es vulnerable
   - Proponer la corrección
*/

-- CÓDIGO A REVISAR:
CREATE OR ALTER PROCEDURE BusquedaVulnerable
    @Tabla NVARCHAR(128),
    @Columna NVARCHAR(128),
    @Valor NVARCHAR(500),
    @OrderBy NVARCHAR(128)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    
    SET @sql = 'SELECT * FROM ' + @Tabla 
             + ' WHERE ' + @Columna + ' = ''' + @Valor + ''''
             + ' ORDER BY ' + @OrderBy;
    
    EXEC (@sql);
END;
GO

-- Tu análisis aquí (como comentarios):
/*
   VULNERABILIDAD 1: 
   
   VULNERABILIDAD 2: 
   
   VULNERABILIDAD 3: 
   
   VULNERABILIDAD 4: 
   
   CORRECCIÓN PROPUESTA:
   
*/


-- ============================================================
-- EJERCICIO 7: REPORTE DINÁMICO CON DEBUG
-- ============================================================
/*
   OBJETIVO: Crear SP que genere reporte de clientes con sus
             cuentas, incluyendo modo debug
   
   REQUISITOS:
   - @Estado: filtrar por estado de cliente (opcional)
   - @TipoCuenta: filtrar por tipo de cuenta (opcional)
   - @MostrarSaldo: 1=incluir saldo, 0=no incluir
   - @Debug: 1=mostrar SQL sin ejecutar, 0=ejecutar normal
   - Incluir JOIN entre CLIENTES y CUENTAS
   - Contar cantidad de cuentas por cliente
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE ReporteClientesCuentas
    @Estado NVARCHAR(20) = NULL,
    @TipoCuenta NVARCHAR(20) = NULL,
    @MostrarSaldo BIT = 1,
    @Debug BIT = 0
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 8: DELETE DINÁMICO SEGURO
-- ============================================================
/*
   OBJETIVO: SP que elimine registros antiguos de cualquier tabla
             que tenga campo de fecha
   
   REQUISITOS:
   - @Tabla: tabla donde eliminar
   - @ColumnaFecha: nombre de la columna de fecha
   - @DiasAntiguedad: eliminar registros más antiguos que X días
   - @SoloContar: 1=solo mostrar cuántos se eliminarían, 0=eliminar
   - VALIDAR tabla y columna existen
   - La columna debe ser tipo fecha (date, datetime, datetime2)
   - Usar transacción para poder hacer rollback si @SoloContar=1
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE LimpiarRegistrosAntiguos
    @Tabla NVARCHAR(128),
    @ColumnaFecha NVARCHAR(128),
    @DiasAntiguedad INT = 365,
    @SoloContar BIT = 1
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 9: PIVOT DINÁMICO
-- ============================================================
/*
   OBJETIVO: Crear SP que genere pivot de transacciones por tipo
             para un rango de fechas
   
   REQUISITOS:
   - @FechaInicio: fecha inicio del reporte
   - @FechaFin: fecha fin del reporte
   - Pivot de Monto por TipoTransaccion
   - Los tipos de transacción deben obtenerse dinámicamente
   - Agrupar por CuentaID
   - Usar STRING_AGG para construir la lista de columnas
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE PivotTransaccionesTipo
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- EJERCICIO 10: PROCEDIMIENTO COMPLETO CON TODAS LAS PRÁCTICAS
-- ============================================================
/*
   OBJETIVO: Crear un SP de búsqueda avanzada que aplique TODAS
             las mejores prácticas de SQL dinámico
   
   REQUISITOS:
   - Múltiples filtros opcionales
   - Ordenamiento dinámico validado
   - Paginación (OFFSET/FETCH)
   - Conteo total como OUTPUT
   - Modo debug
   - Manejo de errores con TRY...CATCH
   - Logging opcional del SQL generado
   
   PARÁMETROS:
   - @Nombre: filtro parcial por nombre
   - @EmailDominio: filtro por dominio de email (ej: '@gmail.com')
   - @EstadoCliente: estado del cliente
   - @SaldoMinimo: saldo total mínimo en todas sus cuentas
   - @OrderBy: columna de orden ('Nombre', 'Email', 'FechaRegistro', 'SaldoTotal')
   - @Ascendente: dirección del orden
   - @Pagina: número de página (base 1)
   - @TamanoPagina: registros por página
   - @TotalRegistros OUTPUT
   - @Debug BIT
*/

-- Tu código aquí:
CREATE OR ALTER PROCEDURE BusquedaAvanzadaClientes
    @Nombre NVARCHAR(100) = NULL,
    @EmailDominio NVARCHAR(100) = NULL,
    @EstadoCliente NVARCHAR(20) = NULL,
    @SaldoMinimo DECIMAL(18,2) = NULL,
    @OrderBy NVARCHAR(50) = 'Nombre',
    @Ascendente BIT = 1,
    @Pagina INT = 1,
    @TamanoPagina INT = 20,
    @TotalRegistros INT OUTPUT,
    @Debug BIT = 0
AS
BEGIN
    -- COMPLETAR
    NULL;
END;
GO


-- ============================================================
-- ============================================================
--                    SOLUCIONES
-- ============================================================
-- ============================================================

-- ============================================================
-- SOLUCIÓN EJERCICIO 1
-- ============================================================
CREATE OR ALTER PROCEDURE BuscarClientePorCampo_Solucion
    @Campo NVARCHAR(50),
    @Valor NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    DECLARE @CampoValidado NVARCHAR(50);
    
    -- Validar campo contra lista blanca
    SET @CampoValidado = CASE @Campo
        WHEN 'Nombre' THEN 'Nombre'
        WHEN 'Email' THEN 'Email'
        WHEN 'Direccion' THEN 'Direccion'
        ELSE NULL
    END;
    
    IF @CampoValidado IS NULL
    BEGIN
        RAISERROR('Campo no válido. Use: Nombre, Email o Direccion', 16, 1);
        RETURN;
    END;
    
    SET @sql = N'SELECT * FROM CLIENTES WHERE ' + QUOTENAME(@CampoValidado) 
             + N' LIKE ''%'' + @Buscar + ''%''';
    SET @params = N'@Buscar NVARCHAR(200)';
    
    EXEC sp_executesql @sql, @params, @Buscar = @Valor;
END;
GO

-- Test
EXEC BuscarClientePorCampo_Solucion @Campo = 'Nombre', @Valor = 'García';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 2
-- ============================================================
CREATE OR ALTER PROCEDURE ListarTransaccionesOrdenadas_Solucion
    @ColumnaOrden NVARCHAR(50) = 'TransaccionID',
    @Direccion NVARCHAR(4) = 'ASC',
    @Top INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @ColumnaValidada NVARCHAR(50);
    DECLARE @DireccionValidada NVARCHAR(4);
    
    -- Validar columna (lista blanca)
    SET @ColumnaValidada = CASE @ColumnaOrden
        WHEN 'TransaccionID' THEN 'TransaccionID'
        WHEN 'CuentaID' THEN 'CuentaID'
        WHEN 'Monto' THEN 'Monto'
        WHEN 'FechaTransaccion' THEN 'FechaTransaccion'
        WHEN 'TipoTransaccion' THEN 'TipoTransaccion'
        ELSE 'TransaccionID'  -- Default
    END;
    
    -- Validar dirección
    SET @DireccionValidada = CASE UPPER(@Direccion)
        WHEN 'ASC' THEN 'ASC'
        WHEN 'DESC' THEN 'DESC'
        ELSE 'ASC'
    END;
    
    SET @sql = N'SELECT TOP (@TopN) * FROM TRANSACCIONES_BANCARIAS 
                 ORDER BY ' + QUOTENAME(@ColumnaValidada) + N' ' + @DireccionValidada;
    
    EXEC sp_executesql @sql, N'@TopN INT', @TopN = @Top;
END;
GO

-- Test
EXEC ListarTransaccionesOrdenadas_Solucion @ColumnaOrden = 'Monto', @Direccion = 'DESC', @Top = 10;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 3
-- ============================================================
CREATE OR ALTER PROCEDURE ConsultarTablaGenerica_Solucion
    @NombreTabla NVARCHAR(128),
    @Top INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    
    -- Validar que la tabla existe
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = @NombreTabla 
          AND TABLE_SCHEMA = 'dbo'
    )
    BEGIN
        RAISERROR('La tabla [%s] no existe en el esquema dbo.', 16, 1, @NombreTabla);
        RETURN;
    END;
    
    SET @sql = N'SELECT TOP (@TopN) * FROM ' + QUOTENAME(@NombreTabla);
    
    EXEC sp_executesql @sql, N'@TopN INT', @TopN = @Top;
END;
GO

-- Test
EXEC ConsultarTablaGenerica_Solucion @NombreTabla = 'CLIENTES', @Top = 5;
EXEC ConsultarTablaGenerica_Solucion @NombreTabla = 'TablaFalsa';  -- Error esperado
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 4
-- ============================================================
CREATE OR ALTER PROCEDURE BuscarCuentasFiltros_Solucion
    @TipoCuenta NVARCHAR(20) = NULL,
    @SaldoMinimo DECIMAL(18,2) = NULL,
    @SaldoMaximo DECIMAL(18,2) = NULL,
    @Estado NVARCHAR(20) = NULL,
    @ClienteID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(500);
    DECLARE @where NVARCHAR(MAX) = N'';
    
    SET @sql = N'SELECT * FROM CUENTAS WHERE 1=1';
    
    IF @TipoCuenta IS NOT NULL
        SET @where = @where + N' AND TipoCuenta = @pTipo';
    
    IF @SaldoMinimo IS NOT NULL
        SET @where = @where + N' AND Saldo >= @pSaldoMin';
    
    IF @SaldoMaximo IS NOT NULL
        SET @where = @where + N' AND Saldo <= @pSaldoMax';
    
    IF @Estado IS NOT NULL
        SET @where = @where + N' AND Estado = @pEstado';
    
    IF @ClienteID IS NOT NULL
        SET @where = @where + N' AND ClienteID = @pClienteID';
    
    SET @sql = @sql + @where + N' ORDER BY CuentaID';
    
    SET @params = N'@pTipo NVARCHAR(20), @pSaldoMin DECIMAL(18,2), 
                   @pSaldoMax DECIMAL(18,2), @pEstado NVARCHAR(20), 
                   @pClienteID INT';
    
    EXEC sp_executesql @sql, @params,
        @pTipo = @TipoCuenta,
        @pSaldoMin = @SaldoMinimo,
        @pSaldoMax = @SaldoMaximo,
        @pEstado = @Estado,
        @pClienteID = @ClienteID;
END;
GO

-- Test
EXEC BuscarCuentasFiltros_Solucion @SaldoMinimo = 5000, @Estado = 'Activa';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 5
-- ============================================================
CREATE OR ALTER PROCEDURE ContarRegistrosDinamico_Solucion
    @Tabla NVARCHAR(128),
    @ColumnaFiltro NVARCHAR(128) = NULL,
    @ValorFiltro NVARCHAR(MAX) = NULL,
    @Conteo INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    
    -- Validar tabla
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = @Tabla AND TABLE_SCHEMA = 'dbo'
    )
    BEGIN
        RAISERROR('Tabla no existe: %s', 16, 1, @Tabla);
        RETURN;
    END;
    
    -- Validar columna si se proporciona
    IF @ColumnaFiltro IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = @Tabla AND COLUMN_NAME = @ColumnaFiltro
        )
        BEGIN
            RAISERROR('Columna no existe: %s', 16, 1, @ColumnaFiltro);
            RETURN;
        END;
    END;
    
    -- Construir SQL
    SET @sql = N'SELECT @Total = COUNT(*) FROM ' + QUOTENAME(@Tabla);
    
    IF @ColumnaFiltro IS NOT NULL AND @ValorFiltro IS NOT NULL
        SET @sql = @sql + N' WHERE ' + QUOTENAME(@ColumnaFiltro) + N' = @Valor';
    
    SET @params = N'@Valor NVARCHAR(MAX), @Total INT OUTPUT';
    
    EXEC sp_executesql @sql, @params,
        @Valor = @ValorFiltro,
        @Total = @Conteo OUTPUT;
END;
GO

-- Test
DECLARE @Total INT;
EXEC ContarRegistrosDinamico_Solucion 
    @Tabla = 'CLIENTES', 
    @ColumnaFiltro = 'Estado', 
    @ValorFiltro = 'Activo',
    @Conteo = @Total OUTPUT;
SELECT @Total AS TotalClientesActivos;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 6 (Análisis de vulnerabilidades)
-- ============================================================
/*
   VULNERABILIDAD 1: @Tabla concatenado directamente
   - Permite injection: 'CLIENTES; DROP TABLE CLIENTES;--'
   - CORRECCIÓN: Validar contra INFORMATION_SCHEMA + QUOTENAME
   
   VULNERABILIDAD 2: @Columna concatenado directamente
   - Permite cambiar la lógica de la consulta
   - CORRECCIÓN: Lista blanca o validar contra COLUMNS + QUOTENAME
   
   VULNERABILIDAD 3: @Valor concatenado con comillas simples
   - Clásico SQL injection: ' OR '1'='1
   - CORRECCIÓN: Usar sp_executesql con parámetro
   
   VULNERABILIDAD 4: @OrderBy concatenado directamente
   - Permite injection en ORDER BY
   - CORRECCIÓN: Lista blanca de columnas permitidas
   
   VULNERABILIDAD 5: Usa EXEC() en lugar de sp_executesql
   - No permite parametrización
   - CORRECCIÓN: Usar sp_executesql
*/

-- VERSIÓN CORREGIDA:
CREATE OR ALTER PROCEDURE BusquedaSegura_Solucion
    @Tabla NVARCHAR(128),
    @Columna NVARCHAR(128),
    @Valor NVARCHAR(500),
    @OrderBy NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    
    -- 1. Validar tabla
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = @Tabla AND TABLE_SCHEMA = 'dbo'
    )
    BEGIN
        RAISERROR('Tabla no válida', 16, 1);
        RETURN;
    END;
    
    -- 2. Validar columna de filtro
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = @Tabla AND COLUMN_NAME = @Columna
    )
    BEGIN
        RAISERROR('Columna de filtro no válida', 16, 1);
        RETURN;
    END;
    
    -- 3. Validar columna de orden
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = @Tabla AND COLUMN_NAME = @OrderBy
    )
    BEGIN
        RAISERROR('Columna de orden no válida', 16, 1);
        RETURN;
    END;
    
    -- 4. Construir SQL seguro
    SET @sql = N'SELECT * FROM ' + QUOTENAME(@Tabla) 
             + N' WHERE ' + QUOTENAME(@Columna) + N' = @pValor'
             + N' ORDER BY ' + QUOTENAME(@OrderBy);
    
    SET @params = N'@pValor NVARCHAR(500)';
    
    -- 5. Ejecutar con sp_executesql
    EXEC sp_executesql @sql, @params, @pValor = @Valor;
END;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 7
-- ============================================================
CREATE OR ALTER PROCEDURE ReporteClientesCuentas_Solucion
    @Estado NVARCHAR(20) = NULL,
    @TipoCuenta NVARCHAR(20) = NULL,
    @MostrarSaldo BIT = 1,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(500);
    DECLARE @where NVARCHAR(MAX) = N'';
    DECLARE @selectSaldo NVARCHAR(200);
    
    SET @selectSaldo = CASE WHEN @MostrarSaldo = 1 
        THEN N', SUM(cu.Saldo) AS SaldoTotal' 
        ELSE N'' 
    END;
    
    SET @sql = N'
        SELECT 
            c.ClienteID,
            c.Nombre,
            c.Email,
            c.Estado,
            COUNT(cu.CuentaID) AS NumeroCuentas' + @selectSaldo + N'
        FROM CLIENTES c
        LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
        WHERE 1=1';
    
    IF @Estado IS NOT NULL
        SET @where = @where + N' AND c.Estado = @pEstado';
    
    IF @TipoCuenta IS NOT NULL
        SET @where = @where + N' AND cu.TipoCuenta = @pTipo';
    
    SET @sql = @sql + @where + N'
        GROUP BY c.ClienteID, c.Nombre, c.Email, c.Estado
        ORDER BY c.Nombre';
    
    SET @params = N'@pEstado NVARCHAR(20), @pTipo NVARCHAR(20)';
    
    IF @Debug = 1
    BEGIN
        PRINT '-- SQL Generado:';
        PRINT @sql;
        PRINT '-- Parámetros:';
        PRINT '@pEstado = ' + ISNULL(@Estado, 'NULL');
        PRINT '@pTipo = ' + ISNULL(@TipoCuenta, 'NULL');
    END
    ELSE
    BEGIN
        EXEC sp_executesql @sql, @params,
            @pEstado = @Estado,
            @pTipo = @TipoCuenta;
    END;
END;
GO

-- Test
EXEC ReporteClientesCuentas_Solucion @Estado = 'Activo', @Debug = 1;
EXEC ReporteClientesCuentas_Solucion @TipoCuenta = 'Ahorros', @MostrarSaldo = 0;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 8
-- ============================================================
CREATE OR ALTER PROCEDURE LimpiarRegistrosAntiguos_Solucion
    @Tabla NVARCHAR(128),
    @ColumnaFecha NVARCHAR(128),
    @DiasAntiguedad INT = 365,
    @SoloContar BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    DECLARE @Conteo INT;
    DECLARE @TipoDato NVARCHAR(50);
    
    -- Validar tabla
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = @Tabla AND TABLE_SCHEMA = 'dbo'
    )
    BEGIN
        RAISERROR('Tabla no existe: %s', 16, 1, @Tabla);
        RETURN;
    END;
    
    -- Validar columna y tipo de dato
    SELECT @TipoDato = DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = @Tabla 
      AND COLUMN_NAME = @ColumnaFecha;
    
    IF @TipoDato IS NULL
    BEGIN
        RAISERROR('Columna no existe: %s', 16, 1, @ColumnaFecha);
        RETURN;
    END;
    
    IF @TipoDato NOT IN ('date', 'datetime', 'datetime2', 'smalldatetime')
    BEGIN
        RAISERROR('La columna %s no es de tipo fecha (es %s)', 16, 1, @ColumnaFecha, @TipoDato);
        RETURN;
    END;
    
    SET @params = N'@FechaLimite DATE, @Count INT OUTPUT';
    
    -- Construir SQL para contar
    SET @sql = N'SELECT @Count = COUNT(*) FROM ' + QUOTENAME(@Tabla) 
             + N' WHERE ' + QUOTENAME(@ColumnaFecha) + N' < @FechaLimite';
    
    DECLARE @FechaLimite DATE = DATEADD(DAY, -@DiasAntiguedad, GETDATE());
    
    EXEC sp_executesql @sql, @params,
        @FechaLimite = @FechaLimite,
        @Count = @Conteo OUTPUT;
    
    PRINT 'Registros encontrados con más de ' + CAST(@DiasAntiguedad AS VARCHAR(10)) 
        + ' días de antigüedad: ' + CAST(@Conteo AS VARCHAR(10));
    
    IF @SoloContar = 0 AND @Conteo > 0
    BEGIN
        SET @sql = N'DELETE FROM ' + QUOTENAME(@Tabla) 
                 + N' WHERE ' + QUOTENAME(@ColumnaFecha) + N' < @FechaLimite';
        
        BEGIN TRY
            BEGIN TRANSACTION;
            
            EXEC sp_executesql @sql, N'@FechaLimite DATE', @FechaLimite = @FechaLimite;
            
            PRINT 'Registros eliminados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
            
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;
END;
GO

-- Test (solo contar)
EXEC LimpiarRegistrosAntiguos_Solucion 
    @Tabla = 'TRANSACCIONES_BANCARIAS', 
    @ColumnaFecha = 'FechaTransaccion',
    @DiasAntiguedad = 365,
    @SoloContar = 1;
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 9
-- ============================================================
CREATE OR ALTER PROCEDURE PivotTransaccionesTipo_Solucion
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(200);
    DECLARE @columnas NVARCHAR(MAX);
    
    -- Obtener tipos de transacción dinámicamente
    SELECT @columnas = STRING_AGG(QUOTENAME(TipoTransaccion), ',')
    FROM (SELECT DISTINCT TipoTransaccion FROM TRANSACCIONES_BANCARIAS
          WHERE FechaTransaccion BETWEEN @FechaInicio AND @FechaFin) t;
    
    IF @columnas IS NULL
    BEGIN
        PRINT 'No hay transacciones en el rango de fechas especificado.';
        RETURN;
    END;
    
    SET @sql = N'
        SELECT CuentaID, ' + @columnas + N'
        FROM (
            SELECT CuentaID, TipoTransaccion, Monto
            FROM TRANSACCIONES_BANCARIAS
            WHERE FechaTransaccion BETWEEN @Inicio AND @Fin
        ) src
        PIVOT (
            SUM(Monto)
            FOR TipoTransaccion IN (' + @columnas + N')
        ) pvt
        ORDER BY CuentaID';
    
    SET @params = N'@Inicio DATE, @Fin DATE';
    
    PRINT '-- SQL Pivot:';
    PRINT @sql;
    
    EXEC sp_executesql @sql, @params,
        @Inicio = @FechaInicio,
        @Fin = @FechaFin;
END;
GO

-- Test
EXEC PivotTransaccionesTipo_Solucion @FechaInicio = '2025-01-01', @FechaFin = '2025-12-31';
GO


-- ============================================================
-- SOLUCIÓN EJERCICIO 10
-- ============================================================
CREATE OR ALTER PROCEDURE BusquedaAvanzadaClientes_Solucion
    @Nombre NVARCHAR(100) = NULL,
    @EmailDominio NVARCHAR(100) = NULL,
    @EstadoCliente NVARCHAR(20) = NULL,
    @SaldoMinimo DECIMAL(18,2) = NULL,
    @OrderBy NVARCHAR(50) = 'Nombre',
    @Ascendente BIT = 1,
    @Pagina INT = 1,
    @TamanoPagina INT = 20,
    @TotalRegistros INT OUTPUT,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @sqlCount NVARCHAR(MAX);
    DECLARE @params NVARCHAR(1000);
    DECLARE @where NVARCHAR(MAX) = N'';
    DECLARE @orderColumn NVARCHAR(50);
    DECLARE @offset INT = (@Pagina - 1) * @TamanoPagina;
    
    BEGIN TRY
        -- Validar OrderBy (lista blanca)
        SET @orderColumn = CASE @OrderBy
            WHEN 'Nombre' THEN 'c.Nombre'
            WHEN 'Email' THEN 'c.Email'
            WHEN 'FechaRegistro' THEN 'c.FechaRegistro'
            WHEN 'SaldoTotal' THEN 'SaldoTotal'
            ELSE 'c.Nombre'
        END;
        
        -- Base de la consulta
        SET @sql = N'
            ;WITH ClientesConSaldo AS (
                SELECT 
                    c.ClienteID,
                    c.Nombre,
                    c.Email,
                    c.Estado,
                    c.FechaRegistro,
                    ISNULL(SUM(cu.Saldo), 0) AS SaldoTotal
                FROM CLIENTES c
                LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
                WHERE 1=1 ';
        
        -- Construir filtros
        IF @Nombre IS NOT NULL
            SET @where = @where + N' AND c.Nombre LIKE ''%'' + @pNombre + ''%''';
        
        IF @EmailDominio IS NOT NULL
            SET @where = @where + N' AND c.Email LIKE ''%'' + @pEmail';
        
        IF @EstadoCliente IS NOT NULL
            SET @where = @where + N' AND c.Estado = @pEstado';
        
        SET @sql = @sql + @where + N'
                GROUP BY c.ClienteID, c.Nombre, c.Email, c.Estado, c.FechaRegistro';
        
        IF @SaldoMinimo IS NOT NULL
            SET @sql = @sql + N' HAVING ISNULL(SUM(cu.Saldo), 0) >= @pSaldoMin';
        
        SET @sql = @sql + N'
            )
            SELECT * FROM ClientesConSaldo
            ORDER BY ' + @orderColumn + CASE WHEN @Ascendente = 1 THEN ' ASC' ELSE ' DESC' END + N'
            OFFSET @Offset ROWS
            FETCH NEXT @PageSize ROWS ONLY';
        
        -- SQL para contar total
        SET @sqlCount = N'
            SELECT @Total = COUNT(*)
            FROM CLIENTES c
            LEFT JOIN CUENTAS cu ON c.ClienteID = cu.ClienteID
            WHERE 1=1 ' + @where + N'
            GROUP BY c.ClienteID
            ' + CASE WHEN @SaldoMinimo IS NOT NULL 
                     THEN N'HAVING ISNULL(SUM(cu.Saldo), 0) >= @pSaldoMin' 
                     ELSE N'' END;
        
        SET @sqlCount = N'SELECT @Total = COUNT(*) FROM (' + @sqlCount + N') x';
        
        SET @params = N'
            @pNombre NVARCHAR(100),
            @pEmail NVARCHAR(100),
            @pEstado NVARCHAR(20),
            @pSaldoMin DECIMAL(18,2),
            @Offset INT,
            @PageSize INT,
            @Total INT OUTPUT';
        
        IF @Debug = 1
        BEGIN
            PRINT '========================================';
            PRINT '-- SQL Principal:';
            PRINT @sql;
            PRINT '';
            PRINT '-- SQL Conteo:';
            PRINT @sqlCount;
            PRINT '========================================';
        END
        ELSE
        BEGIN
            -- Obtener total
            EXEC sp_executesql @sqlCount, @params,
                @pNombre = @Nombre,
                @pEmail = @EmailDominio,
                @pEstado = @EstadoCliente,
                @pSaldoMin = @SaldoMinimo,
                @Offset = @offset,
                @PageSize = @TamanoPagina,
                @Total = @TotalRegistros OUTPUT;
            
            -- Obtener datos
            EXEC sp_executesql @sql, @params,
                @pNombre = @Nombre,
                @pEmail = @EmailDominio,
                @pEstado = @EstadoCliente,
                @pSaldoMin = @SaldoMinimo,
                @Offset = @offset,
                @PageSize = @TamanoPagina,
                @Total = @TotalRegistros OUTPUT;
        END;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        
        PRINT 'ERROR en BusquedaAvanzadaClientes:';
        PRINT 'SQL: ' + @sql;
        PRINT 'Error: ' + @ErrorMsg;
        
        THROW;
    END CATCH;
END;
GO

-- Test
DECLARE @Total INT;
EXEC BusquedaAvanzadaClientes_Solucion 
    @EstadoCliente = 'Activo',
    @OrderBy = 'Nombre',
    @Pagina = 1,
    @TamanoPagina = 10,
    @TotalRegistros = @Total OUTPUT,
    @Debug = 0;
SELECT @Total AS TotalRegistros;
GO

-- Con debug
DECLARE @Total INT;
EXEC BusquedaAvanzadaClientes_Solucion 
    @Nombre = 'García',
    @SaldoMinimo = 1000,
    @TotalRegistros = @Total OUTPUT,
    @Debug = 1;
GO

PRINT '✓ Ejercicios de SQL Dinámico completados';
GO
