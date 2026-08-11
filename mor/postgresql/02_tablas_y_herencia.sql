-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 02: tablas tipadas, herencia y relaciones
-- Requiere: 01_reinicio_y_tipos.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- CLÍNICA: tabla tipada. Sus columnas provienen de gh_tipo.clinica_t.
-- --------------------------------------------------------------------------

CREATE TABLE gh_obj.clinica OF gh_tipo.clinica_t (
    objeto_oid WITH OPTIONS DEFAULT gen_random_uuid() NOT NULL,
    codigo WITH OPTIONS NOT NULL,
    nombre WITH OPTIONS NOT NULL,
    nombre_legal WITH OPTIONS NOT NULL,
    pais WITH OPTIONS NOT NULL,
    direccion WITH OPTIONS NOT NULL,
    contacto WITH OPTIONS NOT NULL,
    zona_horaria WITH OPTIONS NOT NULL,
    fecha_apertura WITH OPTIONS NOT NULL,
    estado WITH OPTIONS DEFAULT 'ACTIVA'::gh_tipo.estado_clinica_t NOT NULL,

    CONSTRAINT pk_clinica PRIMARY KEY (objeto_oid),
    CONSTRAINT uq_clinica_codigo UNIQUE (codigo),
    CONSTRAINT ck_clinica_nombre
        CHECK (NULLIF(btrim(nombre), '') IS NOT NULL),
    CONSTRAINT ck_clinica_nombre_legal
        CHECK (NULLIF(btrim(nombre_legal), '') IS NOT NULL),
    CONSTRAINT ck_clinica_direccion
        CHECK (gh_tipo.direccion_valida(direccion)),
    CONSTRAINT ck_clinica_contacto
        CHECK (gh_tipo.contacto_valido(contacto)),
    CONSTRAINT ck_clinica_pais_direccion
        CHECK ((direccion).pais = pais),
    CONSTRAINT ck_clinica_zona_horaria
        CHECK (
            (pais = 'CR' AND zona_horaria = 'America/Costa_Rica') OR
            (pais = 'GT' AND zona_horaria = 'America/Guatemala') OR
            (pais = 'PA' AND zona_horaria = 'America/Panama')
        )
);

COMMENT ON TABLE gh_obj.clinica IS
    'Tabla tipada de clínicas de Costa Rica, Guatemala y Panamá.';
COMMENT ON COLUMN gh_obj.clinica.objeto_oid IS
    'OID lógico estable implementado con UUID.';

-- --------------------------------------------------------------------------
-- EQUIPO: tabla tipada y composición con clínica.
-- ON DELETE CASCADE expresa que el equipo no existe sin su clínica propietaria.
-- --------------------------------------------------------------------------

CREATE TABLE gh_obj.equipo_medico OF gh_tipo.equipo_medico_t (
    objeto_oid WITH OPTIONS DEFAULT gen_random_uuid() NOT NULL,
    clinica_ref WITH OPTIONS NOT NULL,
    codigo_activo WITH OPTIONS NOT NULL,
    nombre WITH OPTIONS NOT NULL,
    categoria WITH OPTIONS NOT NULL,
    marca WITH OPTIONS NOT NULL,
    modelo WITH OPTIONS NOT NULL,
    numero_serie WITH OPTIONS NOT NULL,
    fecha_adquisicion WITH OPTIONS NOT NULL,
    costo_adquisicion WITH OPTIONS NOT NULL,
    moneda WITH OPTIONS NOT NULL,
    criticidad WITH OPTIONS NOT NULL,
    periodicidad_mantenimiento_meses WITH OPTIONS NOT NULL,
    costo_base_mantenimiento WITH OPTIONS NOT NULL,
    estado WITH OPTIONS DEFAULT 'OPERATIVO'::gh_tipo.estado_equipo_t NOT NULL,

    CONSTRAINT pk_equipo_medico PRIMARY KEY (objeto_oid),
    CONSTRAINT uq_equipo_codigo_activo UNIQUE (codigo_activo),
    CONSTRAINT uq_equipo_numero_serie UNIQUE (numero_serie),
    CONSTRAINT fk_equipo_clinica
        FOREIGN KEY (clinica_ref)
        REFERENCES gh_obj.clinica (objeto_oid)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,
    CONSTRAINT ck_equipo_nombre
        CHECK (NULLIF(btrim(nombre), '') IS NOT NULL),
    CONSTRAINT ck_equipo_datos_fabricante
        CHECK (
            NULLIF(btrim(marca), '') IS NOT NULL AND
            NULLIF(btrim(modelo), '') IS NOT NULL AND
            NULLIF(btrim(numero_serie), '') IS NOT NULL
        ),
    CONSTRAINT ck_equipo_periodicidad
        CHECK (periodicidad_mantenimiento_meses BETWEEN 1 AND 24),
    CONSTRAINT ck_equipo_ultimo_mantenimiento
        CHECK (
            fecha_ultimo_mantenimiento IS NULL OR
            fecha_ultimo_mantenimiento >= fecha_adquisicion
        )
);

CREATE INDEX ix_equipo_clinica
    ON gh_obj.equipo_medico (clinica_ref);

COMMENT ON TABLE gh_obj.equipo_medico IS
    'Tabla tipada de equipos; composición mediante FK con borrado en cascada.';
COMMENT ON COLUMN gh_obj.equipo_medico.clinica_ref IS
    'REF lógico hacia el OID UUID de la clínica propietaria.';

-- --------------------------------------------------------------------------
-- EMPLEADO: superclase tipada y abstracta.
-- CHECK (false) NO INHERIT impide instancias directas, sin bloquear a los hijos.
-- --------------------------------------------------------------------------

CREATE TABLE gh_obj.empleado_base OF gh_tipo.empleado_t (
    objeto_oid WITH OPTIONS DEFAULT gen_random_uuid() NOT NULL,
    identificacion WITH OPTIONS NOT NULL,
    nombres WITH OPTIONS NOT NULL,
    primer_apellido WITH OPTIONS NOT NULL,
    fecha_nacimiento WITH OPTIONS NOT NULL,
    fecha_contratacion WITH OPTIONS NOT NULL,
    direccion WITH OPTIONS NOT NULL,
    contacto WITH OPTIONS NOT NULL,
    salario_mensual WITH OPTIONS NOT NULL,
    moneda WITH OPTIONS NOT NULL,
    estado_laboral WITH OPTIONS DEFAULT 'ACTIVO'::gh_tipo.estado_laboral_t NOT NULL,

    CONSTRAINT pk_empleado_base PRIMARY KEY (objeto_oid),
    CONSTRAINT uq_empleado_base_identificacion UNIQUE (identificacion),
    CONSTRAINT fk_empleado_base_clinica
        FOREIGN KEY (clinica_ref)
        REFERENCES gh_obj.clinica (objeto_oid)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    CONSTRAINT ck_empleado_base_abstracto CHECK (false) NO INHERIT,
    CONSTRAINT ck_empleado_nombre
        CHECK (
            NULLIF(btrim(nombres), '') IS NOT NULL AND
            NULLIF(btrim(primer_apellido), '') IS NOT NULL
        ),
    CONSTRAINT ck_empleado_mayor_edad
        CHECK (fecha_contratacion >= fecha_nacimiento + INTERVAL '18 years'),
    CONSTRAINT ck_empleado_direccion
        CHECK (gh_tipo.direccion_valida(direccion)),
    CONSTRAINT ck_empleado_contacto
        CHECK (gh_tipo.contacto_valido(contacto)),
    CONSTRAINT ck_empleado_moneda_pais
        CHECK (
            ((direccion).pais = 'CR' AND moneda = 'CRC') OR
            ((direccion).pais = 'GT' AND moneda = 'GTQ') OR
            ((direccion).pais = 'PA' AND moneda = 'USD')
        )
);

COMMENT ON TABLE gh_obj.empleado_base IS
    'Superclase tipada abstracta; una consulta incluye sus tablas hijas.';

-- --------------------------------------------------------------------------
-- HERENCIA: cada tabla hija hereda atributos y CHECK de empleado_base.
-- PostgreSQL crea automáticamente los tipos de fila gh_obj.medico_t y
-- gh_obj.enfermero_t.
-- --------------------------------------------------------------------------

CREATE TABLE gh_obj.medico_t (
    numero_colegiado            varchar(32) NOT NULL,
    pais_colegiatura            gh_tipo.pais_codigo_t NOT NULL,
    fecha_vencimiento_licencia  date NOT NULL,
    especialidades              gh_tipo.especialidad_t[] NOT NULL,
    tipo_jornada                gh_tipo.tipo_jornada_t NOT NULL,
    firma_digital_id            uuid NOT NULL,

    CONSTRAINT pk_medico PRIMARY KEY (objeto_oid),
    CONSTRAINT uq_medico_identificacion UNIQUE (identificacion),
    CONSTRAINT uq_medico_colegiatura UNIQUE (pais_colegiatura, numero_colegiado),
    CONSTRAINT uq_medico_firma UNIQUE (firma_digital_id),
    CONSTRAINT fk_medico_clinica
        FOREIGN KEY (clinica_ref)
        REFERENCES gh_obj.clinica (objeto_oid)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    CONSTRAINT ck_medico_colegiado
        CHECK (numero_colegiado ~ '^[A-Za-z0-9-]{4,32}$'),
    CONSTRAINT ck_medico_especialidades
        CHECK (gh_tipo.especialidades_validas(especialidades)),
    CONSTRAINT ck_medico_licencia
        CHECK (fecha_vencimiento_licencia > fecha_contratacion)
) INHERITS (gh_obj.empleado_base);

CREATE TABLE gh_obj.enfermero_t (
    numero_colegiado            varchar(32) NOT NULL,
    pais_colegiatura            gh_tipo.pais_codigo_t NOT NULL,
    fecha_vencimiento_licencia  date NOT NULL,
    nivel_profesional           gh_tipo.nivel_enfermeria_t NOT NULL,
    area_clinica                gh_tipo.area_clinica_t NOT NULL,
    certificaciones             varchar(120)[] NOT NULL DEFAULT ARRAY[]::varchar(120)[],

    CONSTRAINT pk_enfermero PRIMARY KEY (objeto_oid),
    CONSTRAINT uq_enfermero_identificacion UNIQUE (identificacion),
    CONSTRAINT uq_enfermero_colegiatura UNIQUE (pais_colegiatura, numero_colegiado),
    CONSTRAINT fk_enfermero_clinica
        FOREIGN KEY (clinica_ref)
        REFERENCES gh_obj.clinica (objeto_oid)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    CONSTRAINT ck_enfermero_colegiado
        CHECK (numero_colegiado ~ '^[A-Za-z0-9-]{4,32}$'),
    CONSTRAINT ck_enfermero_licencia
        CHECK (fecha_vencimiento_licencia > fecha_contratacion),
    CONSTRAINT ck_enfermero_certificaciones
        CHECK (
            cardinality(certificaciones) <= 8 AND
            array_position(certificaciones, NULL) IS NULL
        )
) INHERITS (gh_obj.empleado_base);

CREATE INDEX ix_medico_clinica ON gh_obj.medico_t (clinica_ref);
CREATE INDEX ix_enfermero_clinica ON gh_obj.enfermero_t (clinica_ref);

COMMENT ON TABLE gh_obj.medico_t IS
    'Subclase de empleado con colección de especialidades médicas.';
COMMENT ON TABLE gh_obj.enfermero_t IS
    'Subclase de empleado con nivel profesional y área clínica.';

-- Vista de apoyo: muestra el tipo concreto sin ocultar la consulta heredada.
CREATE VIEW gh_obj.v_personal AS
SELECT
    e.tableoid::regclass::text AS tipo_concreto,
    e.objeto_oid,
    e.identificacion,
    e.nombres,
    e.primer_apellido,
    e.segundo_apellido,
    e.clinica_ref,
    e.estado_laboral
FROM gh_obj.empleado_base AS e;

