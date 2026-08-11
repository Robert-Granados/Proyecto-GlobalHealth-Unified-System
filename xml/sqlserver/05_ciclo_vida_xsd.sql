-- ============================================================================
-- Script 05: CREATE (script 02), ALTER y DROP de la colección XSD
-- ============================================================================

USE GlobalHealthXml;
GO

-- ALTER no sustituye componentes existentes: agrega un nuevo componente o
-- namespace a la colección. Esta extensión representa la versión interoperable.
ALTER XML SCHEMA COLLECTION dbo.ExpedienteClinicoXsd ADD N'
<xs:schema
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    targetNamespace="urn:globalhealth:expediente:extension:v1"
    xmlns:ext="urn:globalhealth:expediente:extension:v1"
    elementFormDefault="qualified">
  <xs:element name="NotaInteroperabilidad">
    <xs:simpleType>
      <xs:restriction base="xs:string">
        <xs:minLength value="5"/>
        <xs:maxLength value="200"/>
      </xs:restriction>
    </xs:simpleType>
  </xs:element>
</xs:schema>';
GO

-- DROP debe fallar mientras ExpedienteClinico.Documento dependa de la
-- colección. Se registra el mensaje exacto entregado por SQL Server.
BEGIN TRY
    EXEC(N'DROP XML SCHEMA COLLECTION dbo.ExpedienteClinicoXsd;');
    THROW 51004, 'DROP fue aceptado a pesar de existir una columna dependiente.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51004 THROW;
    INSERT INTO dbo.PruebaRechazoXML
        (Categoria, Caso, ErrorNumero, MensajeExacto)
    VALUES
        ('CICLO_XSD', 'DROP con columna XML dependiente', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

SELECT Caso, ErrorNumero, MensajeExacto
FROM dbo.PruebaRechazoXML
WHERE Categoria = 'CICLO_XSD';
GO

-- Demostración reversible del DROP exitoso. Al retirar la tabla dependiente,
-- la colección puede eliminarse. ROLLBACK restaura ambos objetos y los datos.
BEGIN TRANSACTION;

DROP TABLE dbo.ExpedienteClinico;
DROP XML SCHEMA COLLECTION dbo.ExpedienteClinicoXsd;

IF EXISTS (
    SELECT 1
    FROM sys.xml_schema_collections
    WHERE name = N'ExpedienteClinicoXsd'
      AND schema_id = SCHEMA_ID(N'dbo')
)
BEGIN
    THROW 51005, 'La colección XSD continuó existiendo después de DROP.', 1;
END;

PRINT N'DROP exitoso después de retirar la columna dependiente.';
ROLLBACK TRANSACTION;
GO

-- La transacción fue revertida para dejar la demo lista y utilizable.
IF OBJECT_ID(N'dbo.ExpedienteClinico', N'U') IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM sys.xml_schema_collections
       WHERE name = N'ExpedienteClinicoXsd'
         AND schema_id = SCHEMA_ID(N'dbo')
   )
BEGIN
    THROW 51006, 'ROLLBACK no restauró la tabla y su colección XSD.', 1;
END;
GO

