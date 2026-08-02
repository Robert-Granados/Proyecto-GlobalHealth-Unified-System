#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/../.."

echo "=== 1/4 Servicios ==="
docker compose ps

echo "=== 2/4 Vista del master (debe mostrar state=streaming) ==="
docker compose exec -T postgres-master psql -U postgres -d globalhealth -P pager=off \
  -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"

echo "=== 3/4 Vista de la réplica (debe devolver t) ==="
docker compose exec -T postgres-replica psql -U postgres -d globalhealth -tAc \
  "SELECT pg_is_in_recovery();"

echo "=== 4/4 Escritura en master y lectura en réplica ==="
docker compose exec -T postgres-master psql -U postgres -d globalhealth \
  -f /dev/stdin < infra/postgres/sql/00-demo-schema.sql

for intento in {1..10}; do
  filas="$(docker compose exec -T postgres-replica psql -U postgres -d globalhealth -tAc \
    "SELECT count(*) FROM demo_signos_vitales;" 2>/dev/null || true)"
  if [[ "${filas//[[:space:]]/}" == "3" ]]; then
    echo "OK: la réplica leyó 3 filas replicadas."
    exit 0
  fi
  sleep 1
done

echo "ERROR: la réplica no recibió las filas dentro de 10 segundos." >&2
exit 1

