-- ============================================================================
-- GlobalHealth Unified System
-- Entregable 1 - Script 04: datos médicos centroamericanos
-- Requiere: scripts 01, 02 y 03
-- ============================================================================

-- Limpieza controlada para poder repetir la carga sin duplicar objetos.
TRUNCATE TABLE
    gh_obj.medico_t,
    gh_obj.enfermero_t,
    gh_obj.equipo_medico,
    gh_obj.clinica
CASCADE;

-- --------------------------------------------------------------------------
-- Clínicas de los tres países aprobados.
-- --------------------------------------------------------------------------

INSERT INTO gh_obj.clinica (
    objeto_oid, codigo, nombre, nombre_legal, pais, direccion, contacto,
    zona_horaria, fecha_apertura, estado
)
VALUES
(
    '11111111-1111-4111-8111-111111111111',
    'GH-CR-001',
    'GlobalHealth Escazú',
    'GlobalHealth Costa Rica S.A.',
    'CR',
    ROW(
        'CR', 'San José', 'Escazú', 'San Rafael',
        'Avenida Escazú, edificio médico 2, piso 3', '10203'
    )::gh_tipo.direccion_t,
    ROW(
        'recepcion.escazu@globalhealth.example',
        ARRAY[
            ROW('TRABAJO', '+506', '22081200', '100', true)::gh_tipo.telefono_t,
            ROW('EMERGENCIA', '+506', '22081299', NULL, false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Central de coordinación clínica', 'Administración'
    )::gh_tipo.contacto_t,
    'America/Costa_Rica', DATE '2018-03-12', 'ACTIVA'
),
(
    '22222222-2222-4222-8222-222222222222',
    'GH-GT-001',
    'GlobalHealth Zona 10',
    'GlobalHealth Guatemala, S.A.',
    'GT',
    ROW(
        'GT', 'Guatemala', 'Guatemala', 'Zona 10',
        '15 avenida 8-42, centro médico corporativo', '01010'
    )::gh_tipo.direccion_t,
    ROW(
        'recepcion.zona10@globalhealth.example',
        ARRAY[
            ROW('TRABAJO', '+502', '23851000', '210', true)::gh_tipo.telefono_t,
            ROW('EMERGENCIA', '+502', '23851911', NULL, false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Coordinación médica Zona 10', 'Administración'
    )::gh_tipo.contacto_t,
    'America/Guatemala', DATE '2019-08-05', 'ACTIVA'
),
(
    '33333333-3333-4333-8333-333333333333',
    'GH-PA-001',
    'GlobalHealth Costa del Este',
    'GlobalHealth Panamá, S.A.',
    'PA',
    ROW(
        'PA', 'Panamá', 'Panamá', 'Costa del Este',
        'Avenida Centenario, torre salud, nivel 4', '07189'
    )::gh_tipo.direccion_t,
    ROW(
        'recepcion.panama@globalhealth.example',
        ARRAY[
            ROW('TRABAJO', '+507', '3104500', '300', true)::gh_tipo.telefono_t,
            ROW('EMERGENCIA', '+507', '3104911', NULL, false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Centro de operaciones clínicas', 'Administración'
    )::gh_tipo.contacto_t,
    'America/Panama', DATE '2020-11-16', 'ACTIVA'
);

-- --------------------------------------------------------------------------
-- Equipos: su clinica_ref demuestra composición y REF/OID lógico.
-- --------------------------------------------------------------------------

INSERT INTO gh_obj.equipo_medico (
    objeto_oid, clinica_ref, codigo_activo, nombre, categoria, marca, modelo,
    numero_serie, fecha_adquisicion, costo_adquisicion, moneda, criticidad,
    periodicidad_mantenimiento_meses, fecha_ultimo_mantenimiento,
    costo_base_mantenimiento, estado
)
VALUES
(
    '41000000-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'EQ-CR-0001', 'Ultrasonido Doppler', 'DIAGNOSTICO', 'GE Healthcare',
    'LOGIQ P9', 'CR-US-P9-0042', DATE '2022-02-15', 42500000.00, 'CRC',
    'ALTA', 6, DATE '2026-02-20', 680000.00, 'OPERATIVO'
),
(
    '41000000-0000-4000-8000-000000000002',
    '11111111-1111-4111-8111-111111111111',
    'EQ-CR-0002', 'Desfibrilador bifásico', 'SOPORTE_VITAL', 'ZOLL',
    'R Series', 'CR-ZOLL-R-1188', DATE '2021-06-10', 9800000.00, 'CRC',
    'VITAL', 3, DATE '2026-05-12', 185000.00, 'OPERATIVO'
),
(
    '42000000-0000-4000-8000-000000000001',
    '22222222-2222-4222-8222-222222222222',
    'EQ-GT-0001', 'Ventilador mecánico', 'SOPORTE_VITAL', 'Dräger',
    'Evita V600', 'GT-EV600-7710', DATE '2023-01-24', 315000.00, 'GTQ',
    'VITAL', 3, DATE '2026-06-30', 7200.00, 'OPERATIVO'
),
(
    '42000000-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'EQ-GT-0002', 'Electrocardiógrafo de 12 canales', 'DIAGNOSTICO', 'Schiller',
    'CARDIOVIT AT-102', 'GT-AT102-2335', DATE '2020-09-08', 68500.00, 'GTQ',
    'MEDIA', 12, DATE '2025-09-15', 1600.00, 'MANTENIMIENTO'
),
(
    '43000000-0000-4000-8000-000000000001',
    '33333333-3333-4333-8333-333333333333',
    'EQ-PA-0001', 'Monitor multiparámetro', 'MONITOREO', 'Philips',
    'IntelliVue MX550', 'PA-MX550-5409', DATE '2024-04-19', 18500.00, 'USD',
    'ALTA', 6, DATE '2026-04-22', 480.00, 'OPERATIVO'
),
(
    '43000000-0000-4000-8000-000000000002',
    '33333333-3333-4333-8333-333333333333',
    'EQ-PA-0002', 'Bomba de infusión volumétrica', 'TERAPEUTICO', 'B. Braun',
    'Infusomat Space', 'PA-SPACE-8912', DATE '2022-07-11', 4900.00, 'USD',
    'ALTA', 6, DATE '2026-01-18', 165.00, 'OPERATIVO'
);

-- --------------------------------------------------------------------------
-- Médicos: filas del subtipo con especialidades compuestas vectorizadas.
-- --------------------------------------------------------------------------

INSERT INTO gh_obj.medico_t (
    objeto_oid, identificacion, nombres, primer_apellido, segundo_apellido,
    fecha_nacimiento, fecha_contratacion, direccion, contacto, clinica_ref,
    salario_mensual, moneda, estado_laboral, numero_colegiado,
    pais_colegiatura, fecha_vencimiento_licencia, especialidades,
    tipo_jornada, firma_digital_id
)
VALUES
(
    'a1000000-0000-4000-8000-000000000001', '1-1234-5678',
    'Ana Sofía', 'Vega', 'Mora', DATE '1984-09-17', DATE '2015-04-06',
    ROW(
        'CR', 'San José', 'Montes de Oca', 'San Pedro',
        'Residencial Los Yoses, casa 18', '11501'
    )::gh_tipo.direccion_t,
    ROW(
        'ana.vega@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+506', '88881234', NULL, true)::gh_tipo.telefono_t,
            ROW('TRABAJO', '+506', '22081200', '231', false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Esteban Mora Jiménez', 'Hermano'
    )::gh_tipo.contacto_t,
    '11111111-1111-4111-8111-111111111111', 2850000.00, 'CRC', 'ACTIVO',
    'MED-18472', 'CR', DATE '2027-12-31',
    ARRAY[
        ROW('CAR', 'Cardiología', 'Colegio de Médicos y Cirujanos de Costa Rica',
            DATE '2012-11-20', true)::gh_tipo.especialidad_t,
        ROW('MIN', 'Medicina interna', 'Universidad de Costa Rica',
            DATE '2009-06-30', true)::gh_tipo.especialidad_t
    ]::gh_tipo.especialidad_t[],
    'COMPLETA', 'a1111111-1111-4111-8111-111111111111'
),
(
    'a2000000-0000-4000-8000-000000000001', '2456789010101',
    'Luis Fernando', 'Caal', 'Xol', DATE '1979-02-11', DATE '2012-10-15',
    ROW(
        'GT', 'Guatemala', 'Mixco', 'Zona 4',
        'Condominio El Naranjo, bloque C, apartamento 12', '01057'
    )::gh_tipo.direccion_t,
    ROW(
        'luis.caal@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+502', '55123478', NULL, true)::gh_tipo.telefono_t,
            ROW('TRABAJO', '+502', '23851000', '315', false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Marta Lucía Xol', 'Cónyuge'
    )::gh_tipo.contacto_t,
    '22222222-2222-4222-8222-222222222222', 24800.00, 'GTQ', 'ACTIVO',
    'COLMED-12654', 'GT', DATE '2028-03-31',
    ARRAY[
        ROW('PED', 'Pediatría', 'Colegio de Médicos y Cirujanos de Guatemala',
            DATE '2008-08-22', true)::gh_tipo.especialidad_t
    ]::gh_tipo.especialidad_t[],
    'COMPLETA', 'a2222222-2222-4222-8222-222222222222'
),
(
    'a3000000-0000-4000-8000-000000000001', '8-999-1234',
    'Ricardo José', 'Batista', 'Ríos', DATE '1987-12-03', DATE '2018-01-08',
    ROW(
        'PA', 'Panamá', 'Panamá', 'San Francisco',
        'Calle 74 Este, edificio Bahía, apartamento 6B', '07196'
    )::gh_tipo.direccion_t,
    ROW(
        'ricardo.batista@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+507', '66123456', NULL, true)::gh_tipo.telefono_t,
            ROW('TRABAJO', '+507', '3104500', '418', false)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Laura Ríos de Batista', 'Madre'
    )::gh_tipo.contacto_t,
    '33333333-3333-4333-8333-333333333333', 5200.00, 'USD', 'ACTIVO',
    'CMP-17439', 'PA', DATE '2027-09-30',
    ARRAY[
        ROW('ANE', 'Anestesiología', 'Consejo Técnico de Salud de Panamá',
            DATE '2016-10-14', true)::gh_tipo.especialidad_t
    ]::gh_tipo.especialidad_t[],
    'GUARDIAS', 'a3333333-3333-4333-8333-333333333333'
);

-- --------------------------------------------------------------------------
-- Enfermeros de los tres países.
-- --------------------------------------------------------------------------

INSERT INTO gh_obj.enfermero_t (
    objeto_oid, identificacion, nombres, primer_apellido, segundo_apellido,
    fecha_nacimiento, fecha_contratacion, direccion, contacto, clinica_ref,
    salario_mensual, moneda, estado_laboral, numero_colegiado,
    pais_colegiatura, fecha_vencimiento_licencia, nivel_profesional,
    area_clinica, certificaciones
)
VALUES
(
    'b1000000-0000-4000-8000-000000000001', '2-0876-0456',
    'Gabriela', 'Solano', 'Pérez', DATE '1992-05-28', DATE '2019-07-01',
    ROW(
        'CR', 'Heredia', 'Heredia', 'Mercedes',
        'Urbanización Zumbado, casa 24', '40102'
    )::gh_tipo.direccion_t,
    ROW(
        'gabriela.solano@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+506', '87004561', NULL, true)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Marco Solano Vargas', 'Padre'
    )::gh_tipo.contacto_t,
    '11111111-1111-4111-8111-111111111111', 1180000.00, 'CRC', 'ACTIVO',
    'ENF-09231', 'CR', DATE '2027-06-30', 'LICENCIATURA', 'UCI',
    ARRAY['Soporte vital cardiovascular avanzado', 'Control de infecciones']
),
(
    'b2000000-0000-4000-8000-000000000001', '2789012340101',
    'Rosa Elena', 'López', 'Ajpacajá', DATE '1989-10-19', DATE '2017-03-20',
    ROW(
        'GT', 'Guatemala', 'Villa Nueva', 'Zona 1',
        'Colonia El Frutal, sector 5, casa 31', '01064'
    )::gh_tipo.direccion_t,
    ROW(
        'rosa.lopez@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+502', '58774410', NULL, true)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Juana Ajpacajá', 'Madre'
    )::gh_tipo.contacto_t,
    '22222222-2222-4222-8222-222222222222', 9100.00, 'GTQ', 'ACTIVO',
    'AEG-55418', 'GT', DATE '2028-01-31', 'LICENCIATURA', 'EMERGENCIA',
    ARRAY['Soporte vital básico', 'Triage de Manchester']
),
(
    'b3000000-0000-4000-8000-000000000001', 'PE-12-3456',
    'Mariela', 'González', 'De León', DATE '1995-04-07', DATE '2021-02-15',
    ROW(
        'PA', 'Panamá', 'Panamá', 'Juan Díaz',
        'Residencial Versalles, casa 104', '07113'
    )::gh_tipo.direccion_t,
    ROW(
        'mariela.gonzalez@globalhealth.example',
        ARRAY[
            ROW('MOVIL', '+507', '67784512', NULL, true)::gh_tipo.telefono_t
        ]::gh_tipo.telefono_t[],
        'Daniel González', 'Hermano'
    )::gh_tipo.contacto_t,
    '33333333-3333-4333-8333-333333333333', 2100.00, 'USD', 'ACTIVO',
    'ANEP-44182', 'PA', DATE '2027-11-30', 'LICENCIATURA', 'QUIROFANO',
    ARRAY['Enfermería perioperatoria', 'Seguridad del paciente']
);

