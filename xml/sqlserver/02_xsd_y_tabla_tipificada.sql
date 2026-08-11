-- ============================================================================
-- Script 02: XSD registrado y columna XML vinculada dentro del motor
-- ============================================================================

USE GlobalHealthXml;
GO

-- Reinicio idempotente en orden de dependencia.
DROP TABLE IF EXISTS dbo.ExpedienteClinico;
DROP TABLE IF EXISTS dbo.PruebaRechazoXML;
GO

IF EXISTS (
    SELECT 1
    FROM sys.xml_schema_collections
    WHERE name = N'ExpedienteClinicoXsd'
      AND schema_id = SCHEMA_ID(N'dbo')
)
BEGIN
    DROP XML SCHEMA COLLECTION dbo.ExpedienteClinicoXsd;
END;
GO

-- El XSD se importa a los metadatos de SQL Server. Patrones, enumeraciones y
-- cardinalidades son evaluados por el motor en cada INSERT y UPDATE.
CREATE XML SCHEMA COLLECTION dbo.ExpedienteClinicoXsd AS N'
<xs:schema
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    targetNamespace="urn:globalhealth:expediente:v1"
    xmlns:gh="urn:globalhealth:expediente:v1"
    elementFormDefault="qualified"
    attributeFormDefault="unqualified">

  <xs:simpleType name="ExpedienteIdType">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z]{3}-[0-9]{8}-[0-9]{4}"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="PacienteIdType">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z]{2}-[0-9]{8}"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="TextoCortoType">
    <xs:restriction base="xs:string">
      <xs:whiteSpace value="collapse"/>
      <xs:minLength value="2"/>
      <xs:maxLength value="120"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="DescripcionType">
    <xs:restriction base="xs:string">
      <xs:whiteSpace value="collapse"/>
      <xs:minLength value="5"/>
      <xs:maxLength value="500"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="DocumentoType">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z0-9-]{5,20}"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="PaisType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="CR"/>
      <xs:enumeration value="GT"/>
      <xs:enumeration value="PA"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="SexoType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="F"/>
      <xs:enumeration value="M"/>
      <xs:enumeration value="X"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="TipoSangreType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="A+"/>
      <xs:enumeration value="A-"/>
      <xs:enumeration value="B+"/>
      <xs:enumeration value="B-"/>
      <xs:enumeration value="AB+"/>
      <xs:enumeration value="AB-"/>
      <xs:enumeration value="O+"/>
      <xs:enumeration value="O-"/>
      <xs:enumeration value="DESCONOCIDO"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="TipoAntecedenteType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="ALERGIA"/>
      <xs:enumeration value="CRONICO"/>
      <xs:enumeration value="QUIRURGICO"/>
      <xs:enumeration value="FAMILIAR"/>
      <xs:enumeration value="MEDICAMENTO"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="Cie10Type">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z][0-9][0-9](\.[0-9A-Z]{1,4})?"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="SeveridadType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="LEVE"/>
      <xs:enumeration value="MODERADO"/>
      <xs:enumeration value="GRAVE"/>
      <xs:enumeration value="CRITICO"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="TipoTratamientoType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="FARMACOLOGICO"/>
      <xs:enumeration value="QUIRURGICO"/>
      <xs:enumeration value="TERAPIA"/>
      <xs:enumeration value="OBSERVACION"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="EstadoTratamientoType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="ACTIVO"/>
      <xs:enumeration value="SUSPENDIDO"/>
      <xs:enumeration value="COMPLETADO"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="MedicoIdType">
    <xs:restriction base="xs:string">
      <xs:pattern value="MED-(CR|GT|PA)-[0-9]{6}"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="AlgoritmoFirmaType">
    <xs:restriction base="xs:string">
      <xs:enumeration value="RSA-SHA256"/>
      <xs:enumeration value="ECDSA-SHA256"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="FirmaBase64Type">
    <xs:restriction base="xs:base64Binary">
      <xs:minLength value="32"/>
      <xs:maxLength value="512"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:complexType name="PacienteType">
    <xs:sequence>
      <xs:element name="Nombres" type="gh:TextoCortoType"/>
      <xs:element name="Apellidos" type="gh:TextoCortoType"/>
      <xs:element name="FechaNacimiento" type="xs:date"/>
      <xs:element name="Sexo" type="gh:SexoType"/>
      <xs:element name="Documento" type="gh:DocumentoType"/>
      <xs:element name="Pais" type="gh:PaisType"/>
      <xs:element name="TipoSangre" type="gh:TipoSangreType"/>
    </xs:sequence>
    <xs:attribute name="id" type="gh:PacienteIdType" use="required"/>
  </xs:complexType>

  <xs:complexType name="AntecedenteType">
    <xs:sequence>
      <xs:element name="Tipo" type="gh:TipoAntecedenteType"/>
      <xs:element name="Descripcion" type="gh:DescripcionType"/>
      <xs:element name="FechaRegistro" type="xs:date"/>
    </xs:sequence>
    <xs:attribute name="id" type="xs:positiveInteger" use="required"/>
  </xs:complexType>

  <xs:complexType name="DiagnosticoType">
    <xs:sequence>
      <xs:element name="CodigoCIE10" type="gh:Cie10Type"/>
      <xs:element name="Descripcion" type="gh:DescripcionType"/>
      <xs:element name="Severidad" type="gh:SeveridadType"/>
      <xs:element name="FechaDiagnostico" type="xs:date"/>
    </xs:sequence>
    <xs:attribute name="id" type="xs:string" use="required"/>
  </xs:complexType>

  <xs:complexType name="TratamientoType">
    <xs:sequence>
      <xs:element name="Tipo" type="gh:TipoTratamientoType"/>
      <xs:element name="Descripcion" type="gh:DescripcionType"/>
      <xs:element name="FechaInicio" type="xs:date"/>
      <xs:element name="FechaFin" type="xs:date" minOccurs="0"/>
      <xs:element name="Estado" type="gh:EstadoTratamientoType"/>
    </xs:sequence>
    <xs:attribute name="id" type="xs:string" use="required"/>
  </xs:complexType>

  <xs:complexType name="FirmaMedicoType">
    <xs:sequence>
      <xs:element name="MedicoId" type="gh:MedicoIdType"/>
      <xs:element name="NombreCompleto" type="gh:TextoCortoType"/>
      <xs:element name="NumeroColegiado" type="gh:DocumentoType"/>
      <xs:element name="FechaFirma" type="xs:dateTime"/>
      <xs:element name="Algoritmo" type="gh:AlgoritmoFirmaType"/>
      <xs:element name="ValorFirma" type="gh:FirmaBase64Type"/>
    </xs:sequence>
  </xs:complexType>

  <xs:element name="ExpedienteClinico">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="Paciente" type="gh:PacienteType"/>
        <xs:element name="Antecedentes">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Antecedente" type="gh:AntecedenteType"
                          minOccurs="0" maxOccurs="20"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="Diagnosticos">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Diagnostico" type="gh:DiagnosticoType"
                          minOccurs="1" maxOccurs="20"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="Tratamientos">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Tratamiento" type="gh:TratamientoType"
                          minOccurs="0" maxOccurs="20"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="FirmaMedico" type="gh:FirmaMedicoType"/>
      </xs:sequence>
      <xs:attribute name="expedienteId" type="gh:ExpedienteIdType" use="required"/>
      <xs:attribute name="version" use="required">
        <xs:simpleType>
          <xs:restriction base="xs:string">
            <xs:enumeration value="1.0"/>
            <xs:enumeration value="1.1"/>
          </xs:restriction>
        </xs:simpleType>
      </xs:attribute>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

-- Esta es la vinculación crítica: DOCUMENT + colección registrada. Todo valor
-- asignado a Documento se valida dentro de SQL Server.
CREATE TABLE dbo.ExpedienteClinico
(
    ExpedienteId bigint IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_ExpedienteClinico PRIMARY KEY,
    Codigo varchar(20) NOT NULL
        CONSTRAINT UQ_ExpedienteClinico_Codigo UNIQUE,
    Documento xml(DOCUMENT dbo.ExpedienteClinicoXsd) NOT NULL,
    CreadoEn datetime2(0) NOT NULL
        CONSTRAINT DF_ExpedienteClinico_CreadoEn DEFAULT SYSUTCDATETIME(),
    ActualizadoEn datetime2(0) NOT NULL
        CONSTRAINT DF_ExpedienteClinico_ActualizadoEn DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.PruebaRechazoXML
(
    PruebaId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_PruebaRechazoXML PRIMARY KEY,
    Categoria varchar(30) NOT NULL,
    Caso varchar(80) NOT NULL,
    ErrorNumero int NOT NULL,
    MensajeExacto nvarchar(4000) NOT NULL,
    RegistradoEn datetime2(0) NOT NULL
        CONSTRAINT DF_PruebaRechazoXML_RegistradoEn DEFAULT SYSUTCDATETIME()
);
GO

