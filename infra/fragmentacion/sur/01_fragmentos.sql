CREATE SCHEMA IF NOT EXISTS fragmento;

CREATE TABLE IF NOT EXISTS fragmento.paciente_sur (
  paciente_id bigint PRIMARY KEY,
  identificacion varchar(32) NOT NULL UNIQUE,
  nombre varchar(120) NOT NULL,
  region varchar(10) NOT NULL DEFAULT 'SUR' CHECK (region = 'SUR')
);

CREATE TABLE IF NOT EXISTS fragmento.paciente_financiero (
  paciente_id bigint PRIMARY KEY,
  aseguradora varchar(120),
  numero_poliza varchar(64),
  saldo_pendiente numeric(14,2) NOT NULL DEFAULT 0
);

INSERT INTO fragmento.paciente_sur VALUES
  (2001, 'PA-2001', 'María López', 'SUR'),
  (2002, 'GT-2002', 'Carlos Díaz', 'SUR')
ON CONFLICT (paciente_id) DO NOTHING;

INSERT INTO fragmento.paciente_financiero VALUES
  (1001, 'INS', 'POL-1001', 15000),
  (1002, 'INS', 'POL-1002', 0),
  (2001, 'ASSA', 'POL-2001', 225.50),
  (2002, 'Seguros G&T', 'POL-2002', 980.00)
ON CONFLICT (paciente_id) DO NOTHING;
