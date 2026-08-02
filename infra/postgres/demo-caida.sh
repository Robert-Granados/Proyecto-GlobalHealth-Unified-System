#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/../.."

green='\033[0;32m'
red='\033[0;31m'
cyan='\033[0;36m'
reset='\033[0m'

echo -e "${cyan}GLOBALHEALTH — CHAOS DEMO (separación física read/write)${reset}"
echo "DB_WRITE_URL -> postgres-master:5432"
echo "DB_READ_URL  -> postgres-replica:5432"

echo -e "\n${green}[ANTES] Lectura desde la réplica:${reset}"
docker compose exec -T postgres-replica psql -U postgres -d globalhealth \
  -c "SELECT count(*) AS lecturas_dashboard FROM demo_signos_vitales;"

echo -e "\n${red}[CAOS] Deteniendo exclusivamente el master...${reset}"
docker compose stop postgres-master
docker compose ps

echo -e "\n${red}[WRITE POOL] La escritura debe fallar:${reset}"
if docker compose exec -T postgres-replica sh -c \
  "pg_isready --host=postgres-master --port=5432 --timeout=3 --dbname=globalhealth" \
  >/dev/null 2>&1; then
  echo "ERROR: el master respondió inesperadamente."
  exit 1
else
  echo "OK esperado: DB_WRITE_URL no está disponible."
fi

echo -e "\n${green}[READ POOL] El dashboard continúa leyendo:${reset}"
for vuelta in 1 2 3; do
  docker compose exec -T postgres-replica psql -U postgres -d globalhealth -tAc \
    "SELECT now() AS hora, count(*) AS filas FROM demo_signos_vitales;"
  sleep 1
done

echo -e "\n${green}RESULTADO: master caído; réplica en hot standby sigue atendiendo SELECT.${reset}"
echo "Recuperación: docker compose start postgres-master"
