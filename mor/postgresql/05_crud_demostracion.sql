-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 05: CRUD y demostración en vivo
-- Requiere: scripts 01 a 04
-- ============================================================================

-- --------------------------------------------------------------------------
-- CREATE: objeto temporal en la tabla tipada de equipos.
-- --------------------------------------------------------------------------

INSERT INTO gh_obj.equipo_medico (
    objeto_oid, clinica_ref, codigo_activo, nombre, categoria, marca, modelo,
    numero_serie, fecha_adquisicion, costo_adquisicion, moneda, criticidad,
    periodicidad_mantenimiento_meses, fecha_ultimo_mantenimiento,
    costo_base_mantenimiento, estado
)
VALUES (
    '4fffffff-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'EQ-CR-9999', 'Monitor de signos vitales para demostración', 'MONITOREO',
    'Mindray', 'BeneVision N12', 'DEMO-N12-0001', DATE '2026-08-01',
    5600000.00, 'CRC', 'MEDIA', 6, NULL, 95000.00, 'OPERATIVO'
)
ON CONFLICT (objeto_oid) DO UPDATE SET
    costo_base_mantenimiento = EXCLUDED.costo_base_mantenimiento,
    estado = EXCLUDED.estado;

-- --------------------------------------------------------------------------
-- READ: objeto completo, métodos y navegación de referencias.
-- --------------------------------------------------------------------------

SELECT
    e.codigo_activo,
    e.nombre AS equipo,
    c.nombre AS clinica_propietaria,
    gh_obj.costo_mantenimiento(e, DATE '2026-08-17') AS costo_estimado,
    gh_obj.proxima_fecha_mantenimiento(e) AS proximo_mantenimiento
FROM gh_obj.equipo_medico AS e
JOIN gh_obj.clinica AS c
  ON c.objeto_oid = e.clinica_ref
WHERE e.objeto_oid = '4fffffff-0000-4000-8000-000000000001';

-- La consulta al padre incluye automáticamente médicos y enfermeros.
SELECT
    e.tableoid::regclass AS tipo_concreto,
    e.identificacion,
    e.nombres,
    e.primer_apellido,
    e.clinica_ref
FROM gh_obj.empleado_base AS e
ORDER BY e.tableoid::regclass::text, e.identificacion;

-- ONLY consulta exclusivamente la superclase abstracta: debe devolver 0 filas.
SELECT count(*) AS instancias_directas_superclase
FROM ONLY gh_obj.empleado_base;

-- Método asociado al subtipo médico.
SELECT
    gh_obj.nombre_completo(m) AS medico,
    gh_obj.antiguedad(m, DATE '2026-08-17') AS antiguedad_al_defender,
    cardinality(m.especialidades) AS cantidad_especialidades
FROM gh_obj.medico_t AS m
ORDER BY medico;

-- Desglose relacional del array de tipos compuestos.
SELECT
    gh_obj.nombre_completo(m) AS medico,
    esp.codigo,
    esp.nombre AS especialidad,
    esp.institucion_certificadora
FROM gh_obj.medico_t AS m
CROSS JOIN LATERAL unnest(m.especialidades) AS esp
ORDER BY medico, esp.codigo;

-- Desglose de la colección de teléfonos anidada dentro de contacto_t.
SELECT
    gh_obj.nombre_completo(m) AS medico,
    tel.tipo,
    tel.codigo_pais || ' ' || tel.numero AS telefono,
    tel.principal
FROM gh_obj.medico_t AS m
CROSS JOIN LATERAL unnest((m.contacto).telefonos) AS tel
ORDER BY medico, tel.principal DESC;

-- --------------------------------------------------------------------------
-- UPDATE 1: atributo interno de un tipo compuesto.
-- --------------------------------------------------------------------------

UPDATE gh_obj.medico_t
SET direccion.detalle = 'Residencial Los Yoses, casa 18-A'
WHERE objeto_oid = 'a1000000-0000-4000-8000-000000000001';

SELECT
    gh_obj.nombre_completo(m) AS medico,
    (m.direccion).detalle AS direccion_actualizada
FROM gh_obj.medico_t AS m
WHERE m.objeto_oid = 'a1000000-0000-4000-8000-000000000001';

-- --------------------------------------------------------------------------
-- UPDATE 2: reemplazo de un elemento de la colección anidada de teléfonos.
-- Se reconstruye contacto_t, pero array_replace cambia únicamente el elemento
-- localizado; los demás teléfonos y atributos permanecen intactos.
-- --------------------------------------------------------------------------

UPDATE gh_obj.medico_t AS m
SET contacto = ROW(
    (m.contacto).correo_electronico,
    array_replace(
        (m.contacto).telefonos,
        ((m.contacto).telefonos)[1],
        ROW('MOVIL', '+506', '88884321', NULL, true)::gh_tipo.telefono_t
    ),
    (m.contacto).persona_emergencia,
    (m.contacto).parentesco_emergencia
)::gh_tipo.contacto_t
WHERE m.objeto_oid = 'a1000000-0000-4000-8000-000000000001';

SELECT
    gh_obj.nombre_completo(m) AS medico,
    ((m.contacto).telefonos)[1] AS telefono_reemplazado
FROM gh_obj.medico_t AS m
WHERE m.objeto_oid = 'a1000000-0000-4000-8000-000000000001';

-- UPDATE 3: inserción idempotente de un objeto en especialidades[].
UPDATE gh_obj.medico_t AS m
SET especialidades = m.especialidades || ARRAY[
    ROW(
        'ECO', 'Ecocardiografía',
        'Colegio de Médicos y Cirujanos de Costa Rica',
        DATE '2014-04-25', true
    )::gh_tipo.especialidad_t
]
WHERE m.objeto_oid = 'a1000000-0000-4000-8000-000000000001'
  AND NOT EXISTS (
      SELECT 1
      FROM unnest(m.especialidades) AS esp
      WHERE esp.codigo = 'ECO'
  );

-- UPDATE 4: modificación normal de la tabla tipada de equipos.
UPDATE gh_obj.equipo_medico
SET estado = 'MANTENIMIENTO',
    fecha_ultimo_mantenimiento = DATE '2026-08-11',
    costo_base_mantenimiento = 102500.00
WHERE objeto_oid = '4fffffff-0000-4000-8000-000000000001';

SELECT
    codigo_activo,
    estado,
    fecha_ultimo_mantenimiento,
    costo_base_mantenimiento
FROM gh_obj.equipo_medico
WHERE objeto_oid = '4fffffff-0000-4000-8000-000000000001';

-- --------------------------------------------------------------------------
-- DELETE: eliminación del objeto temporal con evidencia mediante RETURNING.
-- --------------------------------------------------------------------------

DELETE FROM gh_obj.equipo_medico
WHERE objeto_oid = '4fffffff-0000-4000-8000-000000000001'
RETURNING objeto_oid, codigo_activo, nombre;

-- El resultado debe ser cero: el CRUD dejó limpio el objeto de demostración.
SELECT count(*) AS equipos_demo_restantes
FROM gh_obj.equipo_medico
WHERE objeto_oid = '4fffffff-0000-4000-8000-000000000001';
