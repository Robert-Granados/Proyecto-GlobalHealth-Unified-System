#!/usr/bin/env bash
set -Eeuo pipefail

sqlcmd=/opt/mssql-tools18/bin/sqlcmd

if [[ ! -x "$sqlcmd" ]]; then
  sqlcmd=/opt/mssql-tools/bin/sqlcmd
fi

if [[ ! -x "$sqlcmd" ]]; then
  echo "ERROR: sqlcmd no está disponible en la imagen de SQL Server." >&2
  exit 1
fi

cd /scripts

echo "[sqlserver-init] Ejecutando capa XML con validación nativa..."
"$sqlcmd" \
  -S sqlserver \
  -U sa \
  -P "$MSSQL_SA_PASSWORD" \
  -C \
  -b \
  -r 1 \
  -i 00_ejecutar_todo.sql

echo "[sqlserver-init] XML SCHEMA COLLECTION, CRUD y rechazos verificados."
