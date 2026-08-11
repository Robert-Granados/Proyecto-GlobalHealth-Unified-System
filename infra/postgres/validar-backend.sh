#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/../.."

echo "=== 1/4 Estado de los servicios ==="
docker compose ps postgres-master postgres-replica api

echo "=== 2/4 El backend comprueba dos roles físicos ==="
docker compose exec -T api node -e "
  fetch('http://localhost:8080/health')
    .then(async response => {
      const data = await response.json();
      console.log(JSON.stringify(data, null, 2));
      if (!response.ok || !data.physicallySeparated) process.exit(1);
      if (data.writer.inRecovery !== false) process.exit(2);
      if (data.reader.inRecovery !== true) process.exit(3);
      if (data.writer.serverAddress === data.reader.serverAddress) process.exit(4);
    })
    .catch(error => { console.error(error); process.exit(1); });
"

echo "=== 3/4 Escritura mediante writePool ==="
docker compose exec -T api node -e "
  fetch('http://localhost:8080/api/signos-vitales', {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({pacienteId: 7777, frecuenciaCardiaca: 79})
  }).then(async response => {
    const data = await response.json();
    console.log(JSON.stringify(data, null, 2));
    if (response.status !== 201 || data.pool !== 'WRITE_MASTER') process.exit(1);
  }).catch(error => { console.error(error); process.exit(1); });
"

echo "=== 4/4 Lectura replicada mediante readPool ==="
for intento in {1..20}; do
  if docker compose exec -T api node -e "
    fetch('http://localhost:8080/api/dashboard/signos-vitales')
      .then(async response => {
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
        const found = data.rows?.some(row => Number(row.paciente_id) === 7777);
        if (!response.ok || data.pool !== 'READ_REPLICA' || !found) process.exit(1);
      }).catch(() => process.exit(1));
  "; then
    echo "OK: writePool escribió y readPool leyó la fila replicada."
    exit 0
  fi
  sleep 1
done

echo "ERROR: el backend no leyó la fila desde la réplica." >&2
exit 1

