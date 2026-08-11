-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 06: verificaciones para la defensa
-- Requiere: scripts 01 a 05
-- ============================================================================

-- 1. Evidencia de tablas creadas mediante CREATE TABLE ... OF tipo.
SELECT
    table_schema,
    table_name,
    is_typed,
    user_defined_type_schema,
    user_defined_type_name
FROM information_schema.tables
WHERE table_schema = 'gh_obj'
  AND table_name IN ('clinica', 'equipo_medico', 'empleado_base')
ORDER BY table_name;

-- 2. OID de catálogo del tipo y relación con su tabla tipada.
-- Este OID identifica metadatos; objeto_oid identifica instancias del negocio.
SELECT
    c.oid AS oid_catalogo_tabla,
    c.relname AS tabla,
    c.reloftype AS oid_tipo_base,
    t.typname AS tipo_base
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
LEFT JOIN pg_type AS t ON t.oid = c.reloftype
WHERE n.nspname = 'gh_obj'
  AND c.relname IN ('clinica', 'equipo_medico', 'empleado_base')
ORDER BY c.relname;

-- 3. Evidencia de la jerarquía registrada por PostgreSQL.
SELECT
    padre.oid::regclass AS superclase,
    hija.oid::regclass AS subclase
FROM pg_inherits AS i
JOIN pg_class AS padre ON padre.oid = i.inhparent
JOIN pg_class AS hija ON hija.oid = i.inhrelid
WHERE padre.oid = 'gh_obj.empleado_base'::regclass
ORDER BY hija.oid::regclass::text;

-- 4. Comparación polimórfica: consulta heredada frente a ONLY.
SELECT
    (SELECT count(*) FROM gh_obj.empleado_base) AS total_con_subtipos,
    (SELECT count(*) FROM ONLY gh_obj.empleado_base) AS solo_superclase,
    (SELECT count(*) FROM gh_obj.medico_t) AS medicos,
    (SELECT count(*) FROM gh_obj.enfermero_t) AS enfermeros;

-- 5. Composición: equipos contenidos por cada clínica.
SELECT
    c.codigo,
    c.nombre,
    count(e.objeto_oid) AS equipos
FROM gh_obj.clinica AS c
LEFT JOIN gh_obj.equipo_medico AS e ON e.clinica_ref = c.objeto_oid
GROUP BY c.objeto_oid, c.codigo, c.nombre
ORDER BY c.codigo;

-- 6. Agregación: personal asignado sin copiar el objeto empleado en clínica.
SELECT
    c.codigo,
    c.nombre,
    count(p.objeto_oid) AS personal_asignado
FROM gh_obj.clinica AS c
LEFT JOIN gh_obj.empleado_base AS p ON p.clinica_ref = c.objeto_oid
GROUP BY c.objeto_oid, c.codigo, c.nombre
ORDER BY c.codigo;

-- 7. Asserts automáticos. Cualquier incumplimiento detiene psql.
DO $$
DECLARE
    v_total integer;
BEGIN
    SELECT count(*) INTO v_total FROM gh_obj.clinica;
    IF v_total <> 3 THEN
        RAISE EXCEPTION 'Se esperaban 3 clínicas y se obtuvieron %', v_total;
    END IF;

    SELECT count(*) INTO v_total FROM gh_obj.empleado_base;
    IF v_total <> 6 THEN
        RAISE EXCEPTION 'Se esperaban 6 empleados heredados y se obtuvieron %',
            v_total;
    END IF;

    SELECT count(*) INTO v_total FROM ONLY gh_obj.empleado_base;
    IF v_total <> 0 THEN
        RAISE EXCEPTION 'La superclase abstracta contiene % filas directas',
            v_total;
    END IF;

    SELECT count(*) INTO v_total FROM gh_obj.equipo_medico;
    IF v_total <> 6 THEN
        RAISE EXCEPTION 'Se esperaban 6 equipos y se obtuvieron %', v_total;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gh_obj.medico_t AS m
        WHERE m.objeto_oid = 'a1000000-0000-4000-8000-000000000001'
          AND cardinality(m.especialidades) = 3
          AND (((m.contacto).telefonos)[1]).numero = '88884321'
          AND (m.direccion).detalle = 'Residencial Los Yoses, casa 18-A'
    ) THEN
        RAISE EXCEPTION
            'No se verificaron las actualizaciones compuesta y vectorizada';
    END IF;

    RAISE NOTICE 'Verificación MOR completada correctamente.';
END;
$$;

-- 8. Prueba reversible de composición: borrar clínica borra su equipo.
BEGIN;

INSERT INTO gh_obj.clinica (
    objeto_oid, codigo, nombre, nombre_legal, pais, direccion, contacto,
    zona_horaria, fecha_apertura, estado
)
VALUES (
    '99999999-9999-4999-8999-999999999999',
    'GH-CR-999', 'Clínica temporal', 'Clínica temporal de demostración S.A.',
    'CR',
    ROW('CR', 'San José', 'San José', 'Carmen',
        'Objeto temporal para demostrar composición', '10101')::gh_tipo.direccion_t,
    ROW(
        'temporal@globalhealth.example',
        ARRAY[
            ROW('TRABAJO', '+506', '22223333', NULL, true)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Coordinación temporal', 'Administración'
    )::gh_tipo.contacto_t,
    'America/Costa_Rica', DATE '2026-01-01', 'ACTIVA'
);

INSERT INTO gh_obj.equipo_medico (
    objeto_oid, clinica_ref, codigo_activo, nombre, categoria, marca, modelo,
    numero_serie, fecha_adquisicion, costo_adquisicion, moneda, criticidad,
    periodicidad_mantenimiento_meses, fecha_ultimo_mantenimiento,
    costo_base_mantenimiento, estado
)
VALUES (
    '99999999-0000-4000-8000-000000000001',
    '99999999-9999-4999-8999-999999999999',
    'EQ-CR-9999', 'Equipo temporal', 'MONITOREO', 'Demo', 'Demo-1',
    'COMPOSICION-DEMO-1', DATE '2026-01-01', 1000.00, 'CRC', 'BAJA',
    12, NULL, 100.00, 'OPERATIVO'
);

DELETE FROM gh_obj.clinica
WHERE objeto_oid = '99999999-9999-4999-8999-999999999999';

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM gh_obj.equipo_medico
        WHERE objeto_oid = '99999999-0000-4000-8000-000000000001'
    ) THEN
        RAISE EXCEPTION 'Falló ON DELETE CASCADE de la composición';
    END IF;
    RAISE NOTICE 'Composición verificada: el equipo temporal fue eliminado.';
END;
$$;

ROLLBACK;

-- 9. Prueba reversible conjunta:
--    composición elimina equipos; agregación conserva empleados.
BEGIN;

DELETE FROM gh_obj.clinica
WHERE objeto_oid = '11111111-1111-4111-8111-111111111111';

DO $$
DECLARE
    v_personal_conservado integer;
    v_equipos_restantes integer;
BEGIN
    SELECT count(*)
      INTO v_personal_conservado
      FROM gh_obj.empleado_base
     WHERE objeto_oid IN (
        'a1000000-0000-4000-8000-000000000001',
        'b1000000-0000-4000-8000-000000000001'
     )
       AND clinica_ref IS NULL;

    SELECT count(*)
      INTO v_equipos_restantes
      FROM gh_obj.equipo_medico
     WHERE clinica_ref = '11111111-1111-4111-8111-111111111111';

    IF v_personal_conservado <> 2 THEN
        RAISE EXCEPTION
            'Falló la agregación: se conservaron % de 2 empleados',
            v_personal_conservado;
    END IF;

    IF v_equipos_restantes <> 0 THEN
        RAISE EXCEPTION
            'Falló la composición: permanecen % equipos',
            v_equipos_restantes;
    END IF;

    RAISE NOTICE
        'Ciclos de vida verificados: 0 equipos y 2 empleados conservados.';
END;
$$;

ROLLBACK;

-- 10. El trigger debe impedir duplicados entre subtipos distintos.
DO $$
BEGIN
    BEGIN
        UPDATE gh_obj.enfermero_t
           SET identificacion = '1-1234-5678'
         WHERE objeto_oid = 'b1000000-0000-4000-8000-000000000001';

        RAISE EXCEPTION
            'La prueba esperaba que se rechazara la identificación duplicada';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'Unicidad global verificada: médico y enfermero no comparten documento.';
    END;
END;
$$;
