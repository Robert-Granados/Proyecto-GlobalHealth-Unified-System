#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/../.."

green='\033[0;32m'
red='\033[0;31m'
cyan='\033[0;36m'
reset='\033[0m'

restore_master() {
  docker compose start postgres-master >/dev/null 2>&1 || true
}
trap restore_master EXIT

api_get() {
  local path="$1"
  docker compose exec -T api node -e "
    fetch('http://localhost:8080${path}')
      .then(async response => {
        const body = await response.text();
        console.log(body);
        if (!response.ok) process.exit(1);
      })
      .catch(error => { console.error(error.message); process.exit(1); });
  "
}

echo -e "${cyan}GLOBALHEALTH — CHAOS DEMO DESDE EL BACKEND${reset}"
echo "writePool -> DB_WRITE_URL -> postgres-master:5432"
echo "readPool  -> DB_READ_URL  -> postgres-replica:5432"
echo "No existe fallback entre pools."

echo -e "\n${green}[1/5] Topología verificada por la aplicación:${reset}"
api_get /health

echo -e "\n${green}[2/5] Dashboard leído mediante readPool:${reset}"
api_get /api/dashboard/signos-vitales

echo -e "\n${red}[3/5] Deteniendo exclusivamente el master...${reset}"
docker compose stop postgres-master
docker compose ps postgres-master postgres-replica api

echo -e "\n${red}[4/5] Endpoint de escritura: debe fallar con pool=WRITE_MASTER:${reset}"
if docker compose exec -T api node -e "
  fetch('http://localhost:8080/api/signos-vitales', {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({pacienteId: 9999, frecuenciaCardiaca: 82})
  }).then(async response => {
    const body = await response.text();
    console.log(body);
    process.exit(response.ok ? 0 : 1);
  }).catch(error => { console.error(error.message); process.exit(1); });
"; then
  echo "ERROR: el endpoint escribió aunque el master estaba detenido." >&2
  exit 1
else
  echo "OK esperado: writePool no pudo llegar al master."
fi

echo -e "\n${green}[5/5] Dashboard: debe seguir respondiendo desde readPool:${reset}"
api_get /health/read
api_get /api/dashboard/signos-vitales

echo -e "\n${green}RESULTADO: backend vivo, escritura caída y lectura disponible.${reset}"
echo "Restaurando master..."
restore_master
trap - EXIT
