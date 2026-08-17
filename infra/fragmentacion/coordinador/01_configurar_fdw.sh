#!/usr/bin/env bash
set -Eeuo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=fdw_password="$FRAGMENT_DB_PASSWORD" \
  --set=app_user="$APP_DB_USER" \
  --set=app_password="$APP_DB_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SCHEMA IF NOT EXISTS distribuido;

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
\gexec

CREATE SERVER nodo_norte FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'postgres-norte', dbname 'globalhealth_fragmento', port '5432');
CREATE SERVER nodo_sur FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'postgres-sur', dbname 'globalhealth_fragmento', port '5432');

CREATE USER MAPPING FOR CURRENT_USER SERVER nodo_norte
  OPTIONS (user 'postgres', password :'fdw_password');
CREATE USER MAPPING FOR CURRENT_USER SERVER nodo_sur
  OPTIONS (user 'postgres', password :'fdw_password');

SELECT format(
  'CREATE USER MAPPING FOR %I SERVER nodo_norte OPTIONS (user %L, password %L)',
  :'app_user', 'postgres', :'fdw_password'
) WHERE NOT EXISTS (
  SELECT 1 FROM pg_user_mappings
  WHERE srvname = 'nodo_norte' AND usename = :'app_user'
) \gexec
SELECT format(
  'CREATE USER MAPPING FOR %I SERVER nodo_sur OPTIONS (user %L, password %L)',
  :'app_user', 'postgres', :'fdw_password'
) WHERE NOT EXISTS (
  SELECT 1 FROM pg_user_mappings
  WHERE srvname = 'nodo_sur' AND usename = :'app_user'
) \gexec

IMPORT FOREIGN SCHEMA fragmento LIMIT TO (paciente_norte, paciente_publico)
  FROM SERVER nodo_norte INTO distribuido;
IMPORT FOREIGN SCHEMA fragmento LIMIT TO (paciente_sur, paciente_financiero)
  FROM SERVER nodo_sur INTO distribuido;

CREATE OR REPLACE VIEW distribuido.paciente_horizontal AS
SELECT paciente_id, identificacion, nombre, region, 'postgres-norte'::text AS nodo
FROM distribuido.paciente_norte
UNION ALL
SELECT paciente_id, identificacion, nombre, region, 'postgres-sur'::text AS nodo
FROM distribuido.paciente_sur;

CREATE OR REPLACE VIEW distribuido.paciente_vertical AS
SELECT p.paciente_id, p.nombre, p.pais, p.fecha_nacimiento,
       f.aseguradora, f.numero_poliza, f.saldo_pendiente
FROM distribuido.paciente_publico p
JOIN distribuido.paciente_financiero f USING (paciente_id);

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'app_user') \gexec
SELECT format('GRANT USAGE ON SCHEMA distribuido TO %I', :'app_user') \gexec
SELECT format('GRANT SELECT ON ALL TABLES IN SCHEMA distribuido TO %I', :'app_user') \gexec
SQL
