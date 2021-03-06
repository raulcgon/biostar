USE [BioStar]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Raul González>
-- Create date: <25/09/2017>
/* Description:	<
					PROCEDIMIENTO PARA OBTENER LOS REGISTROS FALLIDOS PARA EL REPORTE DE CHECADORES.
					Debido a qué en la base de datos no se almacenan las fechas, sino un número que es agregado 
					al valor correspondiente al día y hora "1970-01-01 00:00:00", se debe obtener la fecha a partir
					de las funciones DATEADD y DATEDIFF dentro de este procedimiento.
					Los parámetros solicitados son fecha de inicio y fecha final.
					El resultado incluye los datos:
					- FECHA Y HORA
					- DISPOSITIVO
					- EVENTO
				>
-- =====================================================================================================================
*/
CREATE PROCEDURE [dbo].[getChecadasFails]
(
	-- PARÁMETROS:
	-- FECHA INICIAL Y FECHA FINAL (DATE): SE DEBEN OBTENER LAS FECHAS DE LAS CUALES SE CONSULTAN LOS VALORES, PASADOS
	-- COMO PARÁMETROS PARA REALIZAR LA CONSULTA.
	@pInicio date,
	@pFInal date
)
AS
BEGIN
	-- SE DECLARAN LAS VARIABLES QUE SE UTILIZARÁN PARA EL CÁLCULO CORRECTO DEL PERIODO DE FECHAS ENTRE EL CUAL SE OBTIENEN
	-- LOS DATOS.
	DECLARE
		@fInicio date, -- 
		@fFinal date, -- 
		@fechaInicial datetime, -- 
		@fechaFinal datetime --
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- SE PASA EL VALOR DE LOS PARÁMETROS A LAS VARIABLES (CON FORMATO CORRESPONDIENTE).
	SET @fInicio = @pInicio
	SET @fFinal = @pFInal

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

	-- SE REALIZA LA CONSULTA EN BASE A LAS FECHAS OBTENIDAS DE LOS PARÁMETROS.
	SELECT
		-- SE CONVIERTE EL VALOR DEL CAMPO nDateTime EN UNA FECHA A TRAVÉS DE LA FUNCIÓN DATEADD PARA MOSTRARLO
		DATEADD(S,t1.nDateTime,'1970-01-01 00:00:00') AS Date, -- LA FECHA BASE ES 1970-01-01 00:00:00
		t2.sName AS Device,
		t4.sName AS Event
/*		
		NOTA: Dado que un registro fallido no tiene relacionado al usuario que lo origina, no es
		posible obtener id de usuario ni nombre del mismo.
		t1.nUserID AS "User ID",
		ISNULL((SELECT t3.sUserName FROM TB_USER t3 WHERE t1.nUserID = t3.sUserID),'') AS Nombre
*/
		FROM
		TB_EVENT_LOG t1 INNER JOIN TB_READER t2 ON t1.nReaderIdn = t2.nReaderIdn
		INNER JOIN 
		TB_EVENT_DATA t4 ON t1.nEventIdn = t4.nEventIdn
		WHERE 
		t1.nEventIdn in (56)
		-- CONVERSIÓN DE LA FECHA EN NÚMERO PARA OBTENER EL RANGO CORRESPONDIENTE A LAS FECHAS.
		AND t1.nDateTime BETWEEN DATEDIFF(S,'1970-01-01 00:00:00',@fechaInicial) 
		AND DATEDIFF(S,'1970-01-01 00:00:00',@fechaFinal)
		ORDER BY t1.nDateTime ASC
END
