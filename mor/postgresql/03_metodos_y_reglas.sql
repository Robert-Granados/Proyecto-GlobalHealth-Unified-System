-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 03: métodos y reglas de la jerarquía
-- Requiere: 01_reinicio_y_tipos.sql, 02_tablas_y_herencia.sql
-- ============================================================================

-- --------------------------------------------------------------------------
-- MÉTODOS nombre_completo(): sobrecarga por tipo compuesto de fila.
-- En PostgreSQL son funciones cuyo primer argumento es el objeto.
-- --------------------------------------------------------------------------

CREATE FUNCTION gh_obj.nombre_completo(p_empleado gh_obj.empleado_base)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT concat_ws(
        ' ',
        NULLIF(btrim((p_empleado).nombres), ''),
        NULLIF(btrim((p_empleado).primer_apellido), ''),
        NULLIF(btrim((p_empleado).segundo_apellido), '')
    );
$$;

CREATE FUNCTION gh_obj.nombre_completo(p_medico gh_obj.medico_t)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT concat_ws(
        ' ',
        NULLIF(btrim((p_medico).nombres), ''),
        NULLIF(btrim((p_medico).primer_apellido), ''),
        NULLIF(btrim((p_medico).segundo_apellido), '')
    );
$$;

CREATE FUNCTION gh_obj.nombre_completo(p_enfermero gh_obj.enfermero_t)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT concat_ws(
        ' ',
        NULLIF(btrim((p_enfermero).nombres), ''),
        NULLIF(btrim((p_enfermero).primer_apellido), ''),
        NULLIF(btrim((p_enfermero).segundo_apellido), '')
    );
$$;

-- --------------------------------------------------------------------------
-- MÉTODOS antiguedad(): devuelve un interval con años y meses completos.
-- La fecha de corte explícita hace reproducibles las pruebas de la defensa.
-- --------------------------------------------------------------------------

CREATE FUNCTION gh_obj.antiguedad(
    p_empleado gh_obj.empleado_base,
    p_fecha_corte date DEFAULT CURRENT_DATE
)
RETURNS interval
LANGUAGE sql
STABLE
STRICT
AS $$
    SELECT age(p_fecha_corte, (p_empleado).fecha_contratacion);
$$;

CREATE FUNCTION gh_obj.antiguedad(
    p_medico gh_obj.medico_t,
    p_fecha_corte date DEFAULT CURRENT_DATE
)
RETURNS interval
LANGUAGE sql
STABLE
STRICT
AS $$
    SELECT age(p_fecha_corte, (p_medico).fecha_contratacion);
$$;

CREATE FUNCTION gh_obj.antiguedad(
    p_enfermero gh_obj.enfermero_t,
    p_fecha_corte date DEFAULT CURRENT_DATE
)
RETURNS interval
LANGUAGE sql
STABLE
STRICT
AS $$
    SELECT age(p_fecha_corte, (p_enfermero).fecha_contratacion);
$$;

-- --------------------------------------------------------------------------
-- MÉTODO costo_mantenimiento(): costo de la siguiente intervención.
-- Fórmula defendible:
--   costo base × factor de criticidad × factor de antigüedad.
-- El factor de antigüedad suma 3 % por año y se limita a 30 %.
-- Un equipo retirado no genera una nueva intervención.
-- --------------------------------------------------------------------------

CREATE FUNCTION gh_obj.costo_mantenimiento(
    p_equipo gh_obj.equipo_medico,
    p_fecha_corte date DEFAULT CURRENT_DATE
)
RETURNS numeric(14,2)
LANGUAGE sql
STABLE
STRICT
AS $$
    SELECT CASE
        WHEN (p_equipo).estado = 'RETIRADO' THEN 0.00::numeric(14,2)
        ELSE round(
            (p_equipo).costo_base_mantenimiento::numeric
            * CASE (p_equipo).criticidad
                WHEN 'BAJA'  THEN 1.00
                WHEN 'MEDIA' THEN 1.10
                WHEN 'ALTA'  THEN 1.25
                WHEN 'VITAL' THEN 1.40
              END
            * LEAST(
                1.30::numeric,
                1.00::numeric + 0.03::numeric * GREATEST(
                    0::numeric,
                    date_part(
                        'year',
                        age(p_fecha_corte, (p_equipo).fecha_adquisicion)
                    )::numeric
                )
              ),
            2
        )::numeric(14,2)
    END;
$$;

CREATE FUNCTION gh_obj.proxima_fecha_mantenimiento(
    p_equipo gh_obj.equipo_medico
)
RETURNS date
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT (
        COALESCE(
            (p_equipo).fecha_ultimo_mantenimiento,
            (p_equipo).fecha_adquisicion
        )
        + make_interval(months => (p_equipo).periodicidad_mantenimiento_meses)
    )::date;
$$;

-- --------------------------------------------------------------------------
-- UNICIDAD GLOBAL EN LA JERARQUÍA.
-- PK y UNIQUE no se heredan. Las restricciones de cada hijo evitan duplicados
-- locales; este trigger evita duplicados entre médico_t y enfermero_t.
-- Los advisory locks cierran la carrera entre dos inserciones concurrentes.
-- --------------------------------------------------------------------------

CREATE FUNCTION gh_obj.validar_unicidad_personal()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.objeto_oid IS DISTINCT FROM OLD.objeto_oid THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'El objeto_oid de un empleado es inmutable';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended('gh-personal-doc:' || NEW.identificacion::text, 0)
    );

    IF TG_OP = 'INSERT' THEN
        PERFORM pg_advisory_xact_lock(
            hashtextextended('gh-personal-oid:' || NEW.objeto_oid::text, 0)
        );

        IF EXISTS (
            SELECT 1
              FROM gh_obj.empleado_base AS e
             WHERE e.objeto_oid = NEW.objeto_oid
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE = '23505',
                MESSAGE = format(
                    'OID de personal duplicado en la jerarquía: %s',
                    NEW.objeto_oid
                );
        END IF;

        IF EXISTS (
            SELECT 1
              FROM gh_obj.empleado_base AS e
             WHERE e.identificacion = NEW.identificacion
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE = '23505',
                MESSAGE = format(
                    'Identificación duplicada en la jerarquía: %s',
                    NEW.identificacion
                );
        END IF;
    ELSE
        IF EXISTS (
            SELECT 1
              FROM gh_obj.empleado_base AS e
             WHERE e.identificacion = NEW.identificacion
               AND NOT (
                    e.tableoid = TG_RELID
                    AND e.objeto_oid = OLD.objeto_oid
               )
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE = '23505',
                MESSAGE = format(
                    'Identificación duplicada en la jerarquía: %s',
                    NEW.identificacion
                );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_medico_unicidad_personal
BEFORE INSERT OR UPDATE OF objeto_oid, identificacion
ON gh_obj.medico_t
FOR EACH ROW
EXECUTE FUNCTION gh_obj.validar_unicidad_personal();

CREATE TRIGGER trg_enfermero_unicidad_personal
BEFORE INSERT OR UPDATE OF objeto_oid, identificacion
ON gh_obj.enfermero_t
FOR EACH ROW
EXECUTE FUNCTION gh_obj.validar_unicidad_personal();

COMMENT ON FUNCTION gh_obj.nombre_completo(gh_obj.medico_t) IS
    'Método sobrecargado para el subtipo médico.';
COMMENT ON FUNCTION gh_obj.antiguedad(gh_obj.medico_t, date) IS
    'Calcula antigüedad laboral del médico a una fecha de corte.';
COMMENT ON FUNCTION gh_obj.costo_mantenimiento(gh_obj.equipo_medico, date) IS
    'Estima el costo de la siguiente intervención del equipo.';

-- Permisos para la capa de aplicación
GRANT USAGE ON SCHEMA gh_tipo TO PUBLIC;
GRANT USAGE ON SCHEMA gh_obj TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gh_obj TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gh_tipo TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gh_obj TO PUBLIC;

