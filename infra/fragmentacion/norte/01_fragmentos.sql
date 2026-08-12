CREATE SCHEMA IF NOT EXISTS fragmento;

CREATE TABLE IF NOT EXISTS fragmento.paciente_norte (
  paciente_id bigint PRIMARY KEY,
  identificacion varchar(32) NOT NULL UNIQUE,
  nombre varchar(120) NOT NULL,
  region varchar(10) NOT NULL DEFAULT 'NORTE' CHECK (region = 'NORTE')
);

CREATE TABLE IF NOT EXISTS fragmento.paciente_publico (
  paciente_id bigint PRIMARY KEY,
  nombre varchar(120) NOT NULL,
  pais char(2) NOT NULL,
  fecha_nacimiento date NOT NULL
);

INSERT INTO fragmento.paciente_norte VALUES
  (1001, 'CR-1001', 'Ana Mora', 'NORTE'),
  (1002, 'CR-1002', 'Luis Vega', 'NORTE')
ON CONFLICT (paciente_id) DO NOTHING;

INSERT INTO fragmento.paciente_publico VALUES
  (1001, 'Ana Mora', 'CR', DATE '1988-04-12'),
  (1002, 'Luis Vega', 'CR', DATE '1979-09-21'),
  (2001, 'María López', 'PA', DATE '1992-01-15'),
  (2002, 'Carlos Díaz', 'GT', DATE '1985-07-30')
ON CONFLICT (paciente_id) DO NOTHING;
