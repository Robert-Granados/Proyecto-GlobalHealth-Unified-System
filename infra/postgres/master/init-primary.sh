#!/usr/bin/env bash
set -Eeuo pipefail

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_user="$APP_DB_USER" \
  --set=app_password="$APP_DB_PASSWORD" \
  --set=repl_user="$REPLICATION_USER" \
  --set=repl_password="$REPLICATION_PASSWORD" <<'SQL'
SET password_encryption = 'scram-sha-256';

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
\gexec

SELECT format('CREATE ROLE %I LOGIN REPLICATION PASSWORD %L',
              :'repl_user', :'repl_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'repl_user')
\gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', current_database(), :'app_user')
\gexec
SQL

# Sólo el rol replicator puede abrir conexiones de replicación desde data_net.
# PostgreSQL usa la primera regla coincidente, por eso esta regla es explícita.
printf '\nhost replication %s 172.28.0.0/24 scram-sha-256\n' \
  "$REPLICATION_USER" >> "$PGDATA/pg_hba.conf"

