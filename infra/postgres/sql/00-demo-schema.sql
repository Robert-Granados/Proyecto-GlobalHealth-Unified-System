CREATE TABLE IF NOT EXISTS demo_signos_vitales (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paciente_id bigint NOT NULL,
    frecuencia_cardiaca smallint NOT NULL CHECK (frecuencia_cardiaca BETWEEN 20 AND 250),
    registrado_en timestamptz NOT NULL DEFAULT clock_timestamp()
);

TRUNCATE demo_signos_vitales RESTART IDENTITY;

INSERT INTO demo_signos_vitales (paciente_id, frecuencia_cardiaca)
VALUES (1001, 78), (1002, 91), (1003, 66);
