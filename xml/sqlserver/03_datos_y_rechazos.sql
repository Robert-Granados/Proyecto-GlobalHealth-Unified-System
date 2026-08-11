-- ============================================================================
-- Script 03: XML válido y tres rechazos producidos por el motor
-- ============================================================================

USE GlobalHealthXml;
GO

DELETE FROM dbo.ExpedienteClinico;
DELETE FROM dbo.PruebaRechazoXML;
GO

DBCC CHECKIDENT (N'dbo.ExpedienteClinico', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT (N'dbo.PruebaRechazoXML', RESEED, 0) WITH NO_INFOMSGS;
GO

DECLARE @Valido nvarchar(max) = N'
<ExpedienteClinico xmlns="urn:globalhealth:expediente:v1"
                    expedienteId="EXP-20260817-0001" version="1.0">
  <Paciente id="CR-12345678">
    <Nombres>María Fernanda</Nombres>
    <Apellidos>Jiménez Vargas</Apellidos>
    <FechaNacimiento>1988-05-14</FechaNacimiento>
    <Sexo>F</Sexo>
    <Documento>1-1234-5678</Documento>
    <Pais>CR</Pais>
    <TipoSangre>O+</TipoSangre>
  </Paciente>
  <Antecedentes>
    <Antecedente id="1">
      <Tipo>ALERGIA</Tipo>
      <Descripcion>Reacción confirmada a la penicilina</Descripcion>
      <FechaRegistro>2021-03-10</FechaRegistro>
    </Antecedente>
  </Antecedentes>
  <Diagnosticos>
    <Diagnostico id="DX-001">
      <CodigoCIE10>I10</CodigoCIE10>
      <Descripcion>Hipertensión arterial esencial primaria</Descripcion>
      <Severidad>LEVE</Severidad>
      <FechaDiagnostico>2026-08-10</FechaDiagnostico>
    </Diagnostico>
  </Diagnosticos>
  <Tratamientos>
    <Tratamiento id="TRAT-001">
      <Tipo>FARMACOLOGICO</Tipo>
      <Descripcion>Losartán 50 mg por vía oral cada día</Descripcion>
      <FechaInicio>2026-08-10</FechaInicio>
      <Estado>ACTIVO</Estado>
    </Tratamiento>
    <Tratamiento id="TRAT-002">
      <Tipo>OBSERVACION</Tipo>
      <Descripcion>Control domiciliario de presión arterial</Descripcion>
      <FechaInicio>2026-08-10</FechaInicio>
      <Estado>ACTIVO</Estado>
    </Tratamiento>
  </Tratamientos>
  <FirmaMedico>
    <MedicoId>MED-CR-000001</MedicoId>
    <NombreCompleto>Ana Sofía Vega Mora</NombreCompleto>
    <NumeroColegiado>MED-18472</NumeroColegiado>
    <FechaFirma>2026-08-11T15:30:00-06:00</FechaFirma>
    <Algoritmo>RSA-SHA256</Algoritmo>
    <ValorFirma>QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo1Njc4OTBBQkNERUY=</ValorFirma>
  </FirmaMedico>
</ExpedienteClinico>';

INSERT INTO dbo.ExpedienteClinico (Codigo, Documento)
VALUES ('EXP-CR-0001', @Valido);
GO

-- Caso 1: falta FirmaMedico, cuyo minOccurs implícito es 1.
BEGIN TRY
    DECLARE @SinFirma nvarchar(max) = N'
    <ExpedienteClinico xmlns="urn:globalhealth:expediente:v1"
                        expedienteId="EXP-20260817-0002" version="1.0">
      <Paciente id="GT-12345678">
        <Nombres>José Manuel</Nombres><Apellidos>Caal López</Apellidos>
        <FechaNacimiento>1975-02-18</FechaNacimiento><Sexo>M</Sexo>
        <Documento>2456789010101</Documento><Pais>GT</Pais>
        <TipoSangre>A+</TipoSangre>
      </Paciente>
      <Antecedentes/>
      <Diagnosticos>
        <Diagnostico id="DX-002"><CodigoCIE10>E11.9</CodigoCIE10>
          <Descripcion>Diabetes mellitus tipo dos sin complicaciones</Descripcion>
          <Severidad>MODERADO</Severidad>
          <FechaDiagnostico>2026-08-01</FechaDiagnostico>
        </Diagnostico>
      </Diagnosticos>
      <Tratamientos/>
    </ExpedienteClinico>';

    INSERT INTO dbo.ExpedienteClinico (Codigo, Documento)
    VALUES ('INVALIDO-SIN-FIRMA', @SinFirma);

    THROW 51001, 'La base de datos aceptó un XML sin FirmaMedico.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51001 THROW;
    INSERT INTO dbo.PruebaRechazoXML
        (Categoria, Caso, ErrorNumero, MensajeExacto)
    VALUES
        ('XML_INVALIDO', 'Elemento obligatorio faltante', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

-- Caso 2: FechaNacimiento no pertenece a xs:date.
BEGIN TRY
    DECLARE @FechaIncorrecta nvarchar(max) = N'
    <ExpedienteClinico xmlns="urn:globalhealth:expediente:v1"
                        expedienteId="EXP-20260817-0003" version="1.0">
      <Paciente id="PA-12345678">
        <Nombres>Elena María</Nombres><Apellidos>Batista Ríos</Apellidos>
        <FechaNacimiento>1988-99-45</FechaNacimiento><Sexo>F</Sexo>
        <Documento>8-999-1234</Documento><Pais>PA</Pais>
        <TipoSangre>AB+</TipoSangre>
      </Paciente>
      <Antecedentes/>
      <Diagnosticos>
        <Diagnostico id="DX-003"><CodigoCIE10>J45.9</CodigoCIE10>
          <Descripcion>Asma no especificada sin complicación aguda</Descripcion>
          <Severidad>LEVE</Severidad><FechaDiagnostico>2026-08-02</FechaDiagnostico>
        </Diagnostico>
      </Diagnosticos>
      <Tratamientos/>
      <FirmaMedico><MedicoId>MED-PA-000001</MedicoId>
        <NombreCompleto>Ricardo José Batista Ríos</NombreCompleto>
        <NumeroColegiado>CMP-17439</NumeroColegiado>
        <FechaFirma>2026-08-11T16:00:00-05:00</FechaFirma>
        <Algoritmo>ECDSA-SHA256</Algoritmo>
        <ValorFirma>QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo1Njc4OTBBQkNERUY=</ValorFirma>
      </FirmaMedico>
    </ExpedienteClinico>';

    INSERT INTO dbo.ExpedienteClinico (Codigo, Documento)
    VALUES ('INVALIDO-FECHA', @FechaIncorrecta);

    THROW 51002, 'La base de datos aceptó una fecha XML incorrecta.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51002 THROW;
    INSERT INTO dbo.PruebaRechazoXML
        (Categoria, Caso, ErrorNumero, MensajeExacto)
    VALUES
        ('XML_INVALIDO', 'Tipo de dato xs:date incorrecto', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

-- Caso 3: URGENTE está fuera de la enumeración SeveridadType.
BEGIN TRY
    DECLARE @EnumIncorrecta nvarchar(max) = N'
    <ExpedienteClinico xmlns="urn:globalhealth:expediente:v1"
                        expedienteId="EXP-20260817-0004" version="1.0">
      <Paciente id="CR-87654321">
        <Nombres>Carlos Andrés</Nombres><Apellidos>Solano Pérez</Apellidos>
        <FechaNacimiento>1991-11-09</FechaNacimiento><Sexo>M</Sexo>
        <Documento>2-0876-0456</Documento><Pais>CR</Pais><TipoSangre>B+</TipoSangre>
      </Paciente>
      <Antecedentes/>
      <Diagnosticos>
        <Diagnostico id="DX-004"><CodigoCIE10>R07.4</CodigoCIE10>
          <Descripcion>Dolor torácico sin etiología determinada</Descripcion>
          <Severidad>URGENTE</Severidad><FechaDiagnostico>2026-08-11</FechaDiagnostico>
        </Diagnostico>
      </Diagnosticos>
      <Tratamientos/>
      <FirmaMedico><MedicoId>MED-CR-000001</MedicoId>
        <NombreCompleto>Ana Sofía Vega Mora</NombreCompleto>
        <NumeroColegiado>MED-18472</NumeroColegiado>
        <FechaFirma>2026-08-11T15:30:00-06:00</FechaFirma>
        <Algoritmo>RSA-SHA256</Algoritmo>
        <ValorFirma>QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo1Njc4OTBBQkNERUY=</ValorFirma>
      </FirmaMedico>
    </ExpedienteClinico>';

    INSERT INTO dbo.ExpedienteClinico (Codigo, Documento)
    VALUES ('INVALIDO-ENUM', @EnumIncorrecta);

    THROW 51003, 'La base de datos aceptó una severidad fuera de enumeración.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 51003 THROW;
    INSERT INTO dbo.PruebaRechazoXML
        (Categoria, Caso, ErrorNumero, MensajeExacto)
    VALUES
        ('XML_INVALIDO', 'Valor fuera de enumeración', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

-- Los mensajes se capturan, no se fabrican: son exactamente ERROR_MESSAGE().
SELECT Caso, ErrorNumero, MensajeExacto
FROM dbo.PruebaRechazoXML
WHERE Categoria = 'XML_INVALIDO'
ORDER BY PruebaId;
GO

