-- ============================================================================
-- Script 06: asserts de cumplimiento y mensajes exactos del motor
-- ============================================================================

USE GlobalHealthXml;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- Colección registrada dentro de la base de datos.
SELECT
    s.name AS Esquema,
    x.name AS Coleccion,
    x.create_date AS CreadaEn
FROM sys.xml_schema_collections AS x
JOIN sys.schemas AS s ON s.schema_id = x.schema_id
WHERE s.name = N'dbo'
  AND x.name = N'ExpedienteClinicoXsd';
GO

-- Evidencia crítica: xml_collection_id distinto de cero y DOCUMENT = 1.
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS Esquema,
    OBJECT_NAME(c.object_id) AS Tabla,
    c.name AS Columna,
    c.xml_collection_id,
    c.is_xml_document,
    x.name AS ColeccionVinculada
FROM sys.columns AS c
JOIN sys.xml_schema_collections AS x
  ON x.xml_collection_id = c.xml_collection_id
WHERE c.object_id = OBJECT_ID(N'dbo.ExpedienteClinico')
  AND c.name = N'Documento';
GO

DECLARE @Rechazos int = (
    SELECT count(*)
    FROM dbo.PruebaRechazoXML
    WHERE Categoria = 'XML_INVALIDO'
);

IF @Rechazos <> 3
    THROW 51100, 'Deben existir exactamente tres rechazos XML nativos.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.ExpedienteClinico')
      AND name = N'Documento'
      AND xml_collection_id <> 0
      AND is_xml_document = 1
)
    THROW 51101, 'Documento no está vinculado como XML DOCUMENT tipado.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ExpedienteClinico
    WHERE Codigo = 'EXP-CR-0001'
      AND Documento.exist('
        declare default element namespace "urn:globalhealth:expediente:v1";
        /ExpedienteClinico/Diagnosticos/Diagnostico[CodigoCIE10="E78.5"]
      ') = 1
)
    THROW 51102, 'modify(insert) no agregó el diagnóstico E78.5.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ExpedienteClinico
    WHERE Codigo = 'EXP-CR-0001'
      AND Documento.value('
        declare default element namespace "urn:globalhealth:expediente:v1";
        (/ExpedienteClinico/Diagnosticos/Diagnostico
          [CodigoCIE10="I10"]/Severidad)[1]
      ', 'varchar(12)') = 'MODERADO'
)
    THROW 51103, 'modify(replace value of) no cambió la severidad.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ExpedienteClinico
    WHERE Codigo = 'EXP-CR-0001'
      AND Documento.exist('
        declare default element namespace "urn:globalhealth:expediente:v1";
        /ExpedienteClinico/Tratamientos/Tratamiento[@id="TRAT-002"]
      ') = 1
)
    THROW 51104, 'modify(delete) no eliminó TRAT-002.', 1;

PRINT N'VERIFICACIÓN XML COMPLETA: XSD registrado, columna tipada y CRUD válido.';
GO

-- Mensajes exactos para copiar al informe; dependen de versión e idioma.
SELECT Categoria, Caso, ErrorNumero, MensajeExacto
FROM dbo.PruebaRechazoXML
ORDER BY PruebaId;
GO
