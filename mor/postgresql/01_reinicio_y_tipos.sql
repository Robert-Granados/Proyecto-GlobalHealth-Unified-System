-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 01: reinicio, dominios, enumeraciones y tipos
-- Motor objetivo: PostgreSQL 16
-- ============================================================================

-- Reinicio idempotente del módulo MOR. CASCADE se limita a los dos esquemas
-- propiedad de este entregable y no afecta los objetos de infraestructura.
DROP SCHEMA IF EXISTS gh_obj CASCADE;
DROP SCHEMA IF EXISTS gh_tipo CASCADE;

CREATE SCHEMA gh_tipo;
CREATE SCHEMA gh_obj;

COMMENT ON SCHEMA gh_tipo IS
    'Dominios, enumeraciones y tipos compuestos del modelo objeto-relacional.';
COMMENT ON SCHEMA gh_obj IS
    'Objetos persistentes, herencia, métodos y reglas de negocio.';

-- --------------------------------------------------------------------------
-- Dominios: permiten que las reglas escalares viajen dentro de los tipos
-- compuestos. Un CREATE TYPE AS no acepta restricciones CHECK propias.
-- --------------------------------------------------------------------------

CREATE DOMAIN gh_tipo.objeto_oid_t AS uuid;

CREATE DOMAIN gh_tipo.correo_t AS varchar(254)
    CHECK (
        VALUE ~* '^[A-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$'
    );

CREATE DOMAIN gh_tipo.numero_telefono_t AS varchar(8)
    CHECK (VALUE ~ '^[0-9]{7,8}$');

CREATE DOMAIN gh_tipo.extension_telefono_t AS varchar(6)
    CHECK (VALUE ~ '^[0-9]{1,6}$');

CREATE DOMAIN gh_tipo.identificacion_t AS varchar(32)
    CHECK (VALUE ~ '^[A-Za-z0-9-]{5,32}$');

CREATE DOMAIN gh_tipo.codigo_clinica_t AS varchar(12)
    CHECK (VALUE ~ '^GH-(CR|GT|PA)-[0-9]{3}$');

CREATE DOMAIN gh_tipo.codigo_activo_t AS varchar(20)
    CHECK (VALUE ~ '^EQ-(CR|GT|PA)-[0-9]{4}$');

CREATE DOMAIN gh_tipo.monto_no_negativo_t AS numeric(14,2)
    CHECK (VALUE >= 0);

-- --------------------------------------------------------------------------
-- Enumeraciones del dominio.
-- --------------------------------------------------------------------------

CREATE TYPE gh_tipo.pais_codigo_t AS ENUM ('CR', 'GT', 'PA');
CREATE TYPE gh_tipo.moneda_t AS ENUM ('CRC', 'GTQ', 'USD');
CREATE TYPE gh_tipo.tipo_telefono_t AS ENUM
    ('MOVIL', 'RESIDENCIAL', 'TRABAJO', 'EMERGENCIA');
CREATE TYPE gh_tipo.estado_clinica_t AS ENUM
    ('ACTIVA', 'SUSPENDIDA', 'CERRADA');
CREATE TYPE gh_tipo.categoria_equipo_t AS ENUM
    ('DIAGNOSTICO', 'MONITOREO', 'TERAPEUTICO', 'SOPORTE_VITAL');
CREATE TYPE gh_tipo.criticidad_equipo_t AS ENUM
    ('BAJA', 'MEDIA', 'ALTA', 'VITAL');
CREATE TYPE gh_tipo.estado_equipo_t AS ENUM
    ('OPERATIVO', 'MANTENIMIENTO', 'FUERA_SERVICIO', 'RETIRADO');
CREATE TYPE gh_tipo.estado_laboral_t AS ENUM
    ('ACTIVO', 'SUSPENDIDO', 'LICENCIA', 'RETIRADO');
CREATE TYPE gh_tipo.tipo_jornada_t AS ENUM
    ('COMPLETA', 'PARCIAL', 'GUARDIAS');
CREATE TYPE gh_tipo.nivel_enfermeria_t AS ENUM
    ('AUXILIAR', 'TECNICO', 'LICENCIATURA');
CREATE TYPE gh_tipo.area_clinica_t AS ENUM
    ('EMERGENCIA', 'HOSPITALIZACION', 'QUIROFANO', 'UCI', 'CONSULTA');

-- --------------------------------------------------------------------------
-- Tipos compuestos de valor.
-- --------------------------------------------------------------------------

CREATE TYPE gh_tipo.direccion_t AS (
    pais                   gh_tipo.pais_codigo_t,
    provincia_departamento varchar(80),
    canton_municipio       varchar(80),
    distrito_zona          varchar(80),
    detalle                varchar(220),
    codigo_postal          varchar(12)
);

CREATE TYPE gh_tipo.telefono_t AS (
    tipo        gh_tipo.tipo_telefono_t,
    codigo_pais varchar(4),
    numero      gh_tipo.numero_telefono_t,
    extension   gh_tipo.extension_telefono_t,
    principal   boolean
);

CREATE TYPE gh_tipo.contacto_t AS (
    correo_electronico   gh_tipo.correo_t,
    telefonos            gh_tipo.telefono_t[],
    persona_emergencia   varchar(120),
    parentesco_emergencia varchar(50)
);

CREATE TYPE gh_tipo.especialidad_t AS (
    codigo                    varchar(12),
    nombre                    varchar(100),
    institucion_certificadora varchar(140),
    fecha_certificacion       date,
    vigente                   boolean
);

-- --------------------------------------------------------------------------
-- Tipos compuestos que definen las clases persistentes.
-- --------------------------------------------------------------------------

CREATE TYPE gh_tipo.clinica_t AS (
    objeto_oid    gh_tipo.objeto_oid_t,
    codigo        gh_tipo.codigo_clinica_t,
    nombre        varchar(120),
    nombre_legal  varchar(160),
    pais          gh_tipo.pais_codigo_t,
    direccion     gh_tipo.direccion_t,
    contacto      gh_tipo.contacto_t,
    zona_horaria  varchar(64),
    fecha_apertura date,
    estado        gh_tipo.estado_clinica_t
);

CREATE TYPE gh_tipo.equipo_medico_t AS (
    objeto_oid                       gh_tipo.objeto_oid_t,
    clinica_ref                      gh_tipo.objeto_oid_t,
    codigo_activo                    gh_tipo.codigo_activo_t,
    nombre                           varchar(120),
    categoria                        gh_tipo.categoria_equipo_t,
    marca                            varchar(80),
    modelo                           varchar(80),
    numero_serie                     varchar(80),
    fecha_adquisicion                date,
    costo_adquisicion                gh_tipo.monto_no_negativo_t,
    moneda                           gh_tipo.moneda_t,
    criticidad                       gh_tipo.criticidad_equipo_t,
    periodicidad_mantenimiento_meses smallint,
    fecha_ultimo_mantenimiento       date,
    costo_base_mantenimiento         gh_tipo.monto_no_negativo_t,
    estado                           gh_tipo.estado_equipo_t
);

CREATE TYPE gh_tipo.empleado_t AS (
    objeto_oid        gh_tipo.objeto_oid_t,
    identificacion    gh_tipo.identificacion_t,
    nombres           varchar(100),
    primer_apellido   varchar(70),
    segundo_apellido  varchar(70),
    fecha_nacimiento  date,
    fecha_contratacion date,
    direccion         gh_tipo.direccion_t,
    contacto          gh_tipo.contacto_t,
    clinica_ref       gh_tipo.objeto_oid_t,
    salario_mensual   gh_tipo.monto_no_negativo_t,
    moneda            gh_tipo.moneda_t,
    estado_laboral    gh_tipo.estado_laboral_t
);

-- --------------------------------------------------------------------------
-- Validadores reutilizables para atributos y colecciones compuestas.
-- --------------------------------------------------------------------------

CREATE FUNCTION gh_tipo.direccion_valida(p_direccion gh_tipo.direccion_t)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT (p_direccion).pais IS NOT NULL
       AND NULLIF(btrim((p_direccion).provincia_departamento), '') IS NOT NULL
       AND NULLIF(btrim((p_direccion).canton_municipio), '') IS NOT NULL
       AND NULLIF(btrim((p_direccion).distrito_zona), '') IS NOT NULL
       AND NULLIF(btrim((p_direccion).detalle), '') IS NOT NULL;
$$;

CREATE FUNCTION gh_tipo.contacto_valido(p_contacto gh_tipo.contacto_t)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT (p_contacto).correo_electronico IS NOT NULL
       AND (p_contacto).telefonos IS NOT NULL
       AND cardinality((p_contacto).telefonos) BETWEEN 1 AND 5
       AND NOT EXISTS (
            SELECT 1
              FROM unnest((p_contacto).telefonos) AS t
             WHERE t.tipo IS NULL
                OR t.codigo_pais NOT IN ('+506', '+502', '+507')
                OR t.numero IS NULL
                OR t.principal IS NULL
       )
       AND 1 >= (
            SELECT count(*)
              FROM unnest((p_contacto).telefonos) AS t
             WHERE t.principal
       )
       AND cardinality((p_contacto).telefonos) = (
            SELECT count(DISTINCT concat_ws('|', t.codigo_pais, t.numero,
                                                   COALESCE(t.extension, '')))
              FROM unnest((p_contacto).telefonos) AS t
       )
       AND NULLIF(btrim((p_contacto).persona_emergencia), '') IS NOT NULL
       AND NULLIF(btrim((p_contacto).parentesco_emergencia), '') IS NOT NULL;
$$;

CREATE FUNCTION gh_tipo.especialidades_validas(
    p_especialidades gh_tipo.especialidad_t[]
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT cardinality(p_especialidades) BETWEEN 1 AND 5
       AND NOT EXISTS (
            SELECT 1
              FROM unnest(p_especialidades) AS e
             WHERE NULLIF(btrim(e.codigo), '') IS NULL
                OR NULLIF(btrim(e.nombre), '') IS NULL
                OR NULLIF(btrim(e.institucion_certificadora), '') IS NULL
                OR e.fecha_certificacion IS NULL
                OR e.vigente IS NULL
       )
       AND cardinality(p_especialidades) = (
            SELECT count(DISTINCT upper(e.codigo))
              FROM unnest(p_especialidades) AS e
       );
$$;

COMMENT ON TYPE gh_tipo.direccion_t IS
    'Dirección regional neutral para Costa Rica, Guatemala y Panamá.';
COMMENT ON TYPE gh_tipo.contacto_t IS
    'Contacto con una colección vectorizada de teléfonos compuestos.';
COMMENT ON TYPE gh_tipo.empleado_t IS
    'Superclase lógica de médicos y enfermeros.';

