-- ============================================================================
-- Script 04: CRUD interno con métodos XML nativos de SQL Server
-- ============================================================================

USE GlobalHealthXml;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- READ/query(): devuelve el subárbol completo del paciente.
WITH XMLNAMESPACES (DEFAULT 'urn:globalhealth:expediente:v1')
SELECT
    Codigo,
    Documento.query('/ExpedienteClinico/Paciente') AS SubarbolPaciente
FROM dbo.ExpedienteClinico
WHERE Codigo = 'EXP-CR-0001';
GO

-- READ/value(): convierte un valor XML escalar a un tipo SQL relacional.
WITH XMLNAMESPACES (DEFAULT 'urn:globalhealth:expediente:v1')
SELECT
    Codigo,
    Documento.value(
        '(/ExpedienteClinico/Paciente/Documento)[1]',
        'varchar(20)'
    ) AS DocumentoPaciente,
    Documento.value(
        '(/ExpedienteClinico/FirmaMedico/MedicoId)[1]',
        'varchar(20)'
    ) AS MedicoFirmante
FROM dbo.ExpedienteClinico
WHERE Codigo = 'EXP-CR-0001';
GO

-- READ/nodes(): desglosa diagnósticos en filas relacionales.
WITH XMLNAMESPACES ('urn:globalhealth:expediente:v1' AS gh)
SELECT
    e.Codigo,
    d.Nodo.value('(@id)[1]', 'varchar(20)') AS DiagnosticoId,
    d.Nodo.value('(gh:CodigoCIE10)[1]', 'varchar(10)') AS CodigoCIE10,
    d.Nodo.value('(gh:Descripcion)[1]', 'nvarchar(500)') AS Descripcion,
    d.Nodo.value('(gh:Severidad)[1]', 'varchar(12)') AS Severidad
FROM dbo.ExpedienteClinico AS e
CROSS APPLY e.Documento.nodes(
    '/gh:ExpedienteClinico/gh:Diagnosticos/gh:Diagnostico'
) AS d(Nodo)
WHERE e.Codigo = 'EXP-CR-0001';
GO

-- CREATE interno/modify(insert): agrega un diagnóstico que también debe pasar
-- la validación del XSD tipado.
UPDATE dbo.ExpedienteClinico
SET Documento.modify('
    declare default element namespace "urn:globalhealth:expediente:v1";
    insert
      <Diagnostico id="DX-005">
        <CodigoCIE10>E78.5</CodigoCIE10>
        <Descripcion>Hiperlipidemia no especificada en control</Descripcion>
        <Severidad>LEVE</Severidad>
        <FechaDiagnostico>2026-08-11</FechaDiagnostico>
      </Diagnostico>
    as last into (/ExpedienteClinico/Diagnosticos)[1]
'),
    ActualizadoEn = SYSUTCDATETIME()
WHERE Codigo = 'EXP-CR-0001';
GO

-- UPDATE interno/modify(replace value of): cambia un escalar existente.
UPDATE dbo.ExpedienteClinico
SET Documento.modify('
    declare default element namespace "urn:globalhealth:expediente:v1";
    declare namespace gh="urn:globalhealth:expediente:v1";
    replace value of
      (/ExpedienteClinico/Diagnosticos/Diagnostico
         [CodigoCIE10="I10"]/Severidad)[1]
    with gh:SeveridadType("MODERADO")
'),
    ActualizadoEn = SYSUTCDATETIME()
WHERE Codigo = 'EXP-CR-0001';
GO

-- DELETE interno/modify(delete): elimina solo TRAT-002, no el documento.
UPDATE dbo.ExpedienteClinico
SET Documento.modify('
    declare default element namespace "urn:globalhealth:expediente:v1";
    delete
      (/ExpedienteClinico/Tratamientos/Tratamiento[@id="TRAT-002"])[1]
'),
    ActualizadoEn = SYSUTCDATETIME()
WHERE Codigo = 'EXP-CR-0001';
GO

-- Evidencia posterior de las tres mutaciones.
WITH XMLNAMESPACES ('urn:globalhealth:expediente:v1' AS gh)
SELECT
    e.Codigo,
    d.Nodo.value('(@id)[1]', 'varchar(20)') AS DiagnosticoId,
    d.Nodo.value('(gh:CodigoCIE10)[1]', 'varchar(10)') AS CodigoCIE10,
    d.Nodo.value('(gh:Severidad)[1]', 'varchar(12)') AS Severidad
FROM dbo.ExpedienteClinico AS e
CROSS APPLY e.Documento.nodes(
    '/gh:ExpedienteClinico/gh:Diagnosticos/gh:Diagnostico'
) AS d(Nodo)
WHERE e.Codigo = 'EXP-CR-0001'
ORDER BY DiagnosticoId;
GO
