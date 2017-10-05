USE [BioStar]
GO
/****** Object:  StoredProcedure [dbo].[getFotosPorFecha]    Script Date: 03/10/2017 17:18:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =====================================================================================================================
-- Author:		<Raul González>
-- Create date: <25/09/2017>
/* Description:	<
					Consultar los registros fallidos de acuerdo a fechas enviadas como parámetros de la tabla LOG.
					En base a estos registros, obtener la fotografía de cada registro fallido y guardarlas en archivos
					individuales en la ruta indicada.
					Tanto las fechas a consultar, como la ruta deseada para guardar las fotografías serán enviadas
					desde un archivo en excel, el cual ejecuta este procedimiento almacenado por medio de macro.
				>
-- EJECUTAR INSTRUCCIONES PARA ACTIVAR FILE IO EN SQL MANAGEMENT Y PERMITIR EXTRAER FOTOGRAFÍAS DE CAMPO BINARIO
sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
sp_configure 'Ole Automation Procedures', 1;
GO
RECONFIGURE;
GO
-- =====================================================================================================================
*/
ALTER PROCEDURE [dbo].[getFotosPorFecha]
(
	-- PARÁMETROS:
	-- FECHA INICIAL Y FECHA FINAL: VALORES TIPO FECHA QUE SE PASAN COMO RANGO DE TIEMPO PARA OBTENER EL REPORTE.
	@pInicio date,
	@pFinal date,
	@pRuta varchar(4000)
)
AS
BEGIN
	-- SE DECLARAN LAS VARIABLES QUE SE UTILIZARÁN PARA EL CÁLCULO CORRECTO DEL PERIODO DE FECHAS ENTRE EL CUAL SE OBTIENEN
	-- LOS DATOS.
	DECLARE
		@fInicio date, -- 
		@fFinal date, -- 
		@fechaInicial datetime, -- 
		@fechaFinal datetime, --
		@direcotrio varchar(4000)
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- SE PASA EL VALOR DE LOS PARÁMETROS A LAS VARIABLES (CON FORMATO CORRESPONDIENTE).
	SET @fInicio = @pInicio
	SET @fFinal = @pFInal
	SET @direcotrio = @pRuta

	-- SI LA FECHA INICIO ES UN VALOR NULO, TOMA LAS 00:00:00 HORAS DEL DÍA DE HOY, DE OTRA FORMA LAS 00:00:00 HORAS 
	-- DEL DÍA QUE SE ENVIÓ COMO PARÁMETRO.
	IF @fInicio = NULL 
		set @fechaInicial = DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)
	ELSE
		set @fechaInicial = DATEADD(dd,DATEDIFF(dd,0,@fInicio),0)
	-- SI LA FECHA FINAL ES UN VALOR NULO, TOMA LAS 23:59:59 HORAS DEL DÍA DE HOY, EN CASO CONTRARIO LAS 23:59:59 HORAS 
	-- DEL DÍA ENVIADO COMO FECHA FINAL.
	IF @fFInal = NULL
		set @fechaFinal = DATEADD(ms, -3, DATEADD(dd, DATEDIFF(dd, -1, GETDATE()), 0))
	ELSE
		set @fechaFinal = DATEADD(ms, -3, DATEADD(dd, DATEDIFF(dd, -1, @fFInal), 0))

	
	-- SE REALIZA LA CONSULTA EN BASE A LAS FECHAS Y PASANDO EL DIRECTORIO PARA ALMACENAR LAS FOTOGRAFÍAS.
	DECLARE cursor_getFotos CURSOR  FOR
	-- OBTENER LOS ID DE FOTOGRAFÍAS CONSULTANDO LA TABLA LOG Y LA TABLA FACE DEL EVENTO CORRESPONDIENTE. EN ESTE CASO, SOLAMENTE
	-- SE RETORNAN LOS VALORES DE LOS EVENTOS FAIL (56).
	(SELECT 
	t2.nEventFaceIdn
	FROM [BioStar].[dbo].[TB_EVENT_LOG] t1
	INNER JOIN [BioStar].[dbo].[TB_EVENT_FACE] t2
	ON t1.nDateTime = t2.nDateTime
	AND t1.nEventIdn = t2.nEventIdn
	WHERE
	t1.nDateTime BETWEEN DATEDIFF(S,'1970-01-01 00:00:00',@fechaInicial)
	AND DATEDIFF(S,'1970-01-01 00:00:00',@fechaFinal)
	AND t1.nEventIdn = 56)
	ORDER BY t1.nDateTime ASC;

	DECLARE @idFoto INT;
	OPEN cursor_getFotos;
	FETCH NEXT FROM cursor_getFotos INTO @idFoto;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		--SELECT @idFoto;
		DECLARE @ImageData varbinary(max);
		SELECT @ImageData = (SELECT convert(varbinary(max), bFaceImage, 1) FROM [BioStar].[dbo].[TB_EVENT_FACE] WHERE nEventFaceIdn = @idFoto);
		--SELECT @ImageData = (SELECT convert(varbinary(max), bFaceImage, 1) FROM [BioStar].[dbo].[TB_EVENT_FACE] WHERE nUserID = 5216001);
	
		DECLARE @Path nvarchar(1024);
		-- Nombra la carpeta con la fecha del día solicitado. 
		-- Debe obtenerse la fecha y hora del parámetro enviado
		SELECT @Path = @direcotrio + '\' + CONVERT(VARCHAR,@fInicio,105);
	
		--VALIDAR SI LA CARPETA ESPECIFICADA EXSITE EN EL EQUIPO.
		EXEC BioStar.dbo.validarRuta @Path;
	
		DECLARE @datePicture DATETIME;
		DECLARE @timePicture DATETIME;
		--Obtener la fecha y hora de la fotografía para nombrar el archivo con estos datos
		SELECT @datePicture = (SELECT DATEADD(S,nDateTime,'1970-01-01 00:00:00') FROM [BioStar].[dbo].[TB_EVENT_FACE] WHERE nEventFaceIdn = @idFoto);
		SELECT @timePicture = (SELECT DATEADD(S,nDateTime,'1970-01-01 00:00:00') FROM [BioStar].[dbo].[TB_EVENT_FACE] WHERE nEventFaceIdn = @idFoto);
		DECLARE @fechaArchivo VARCHAR(50);
		DECLARE @horaArchivo VARCHAR(50)
		SELECT @fechaArchivo = (SELECT CONVERT(VARCHAR,@datePicture,12)); --Se da formato a la fecha yymmdd y se convierte en cadena
		SELECT @horaArchivo = REPLACE((SELECT CONVERT(VARCHAR,@timePicture,8)),':','_'); --Se convierte la hora en cadena y se cambian los dos puntos por guión bajo

		DECLARE @Filename NVARCHAR(1024);
		SELECT @Filename = (SELECT nUserID FROM [BioStar].[dbo].[TB_EVENT_FACE] where nEventFaceIdn = @idFoto);

		DECLARE @FullPathToOutputFile NVARCHAR(2048);
		SELECT @FullPathToOutputFile = @Path + '\' + @Filename + ' ' + @fechaArchivo + ' ' + @horaArchivo +'.jpg';

		DECLARE @ObjectToken INT
		EXEC sp_OACreate 'ADODB.Stream', @ObjectToken OUTPUT;
		EXEC sp_OASetProperty @ObjectToken, 'Type', 1;
		EXEC sp_OAMethod @ObjectToken, 'Open';
		EXEC sp_OAMethod @ObjectToken, 'Write', NULL, @ImageData;
		EXEC sp_OAMethod @ObjectToken, 'SaveToFile', NULL, @FullPathToOutputFile, 2;
		EXEC sp_OAMethod @ObjectToken, 'Close';
		EXEC sp_OADestroy @ObjectToken;
		FETCH NEXT FROM cursor_getFotos INTO @idFoto;
	END
	CLOSE cursor_getFotos;
	DEALLOCATE cursor_getFotos;
END
