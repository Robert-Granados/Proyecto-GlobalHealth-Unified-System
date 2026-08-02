#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
  echo "[replica] Volumen vacío: ejecutando pg_basebackup desde ${PRIMARY_HOST}:${PRIMARY_PORT}"
  rm -rf "${PGDATA:?}/"*
  export PGPASSWORD="$REPLICATION_PASSWORD"

  until gosu postgres pg_basebackup \
    --host="$PRIMARY_HOST" \
    --port="$PRIMARY_PORT" \
    --username="$REPLICATION_USER" \
    --pgdata="$PGDATA" \
    --wal-method=stream \
    --write-recovery-conf \
    --checkpoint=fast \
    --progress
  do
    echo "[replica] Master aún no disponible; reintentando en 2 segundos..."
    sleep 2
  done
  unset PGPASSWORD
else
  echo "[replica] PGDATA existente: se reutiliza la copia física."
fi

# hot_standby permite SELECT mientras se aplican registros WAL.
exec gosu postgres postgres -c hot_standby=on -c hot_standby_feedback=on

