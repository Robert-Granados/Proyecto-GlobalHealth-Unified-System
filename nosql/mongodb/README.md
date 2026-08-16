# MongoDB: telemetría clínica

Modelo documental normalizado para demostrar la relación `Paciente → Sesión → Logs`.
El generador es idempotente y crea 1.000 pacientes, 5.000 sesiones y exactamente
50.000 documentos de telemetría.

```powershell
Get-Content -Raw .\nosql\mongodb\01_modelo_y_datos.js |
  docker compose exec -T mongodb mongosh --quiet `
    -u root -p $env:MONGO_ROOT_PASSWORD --authenticationDatabase admin globalhealth_telemetry

Get-Content -Raw .\nosql\mongodb\02_consultas.js |
  docker compose exec -T mongodb mongosh --quiet `
    -u root -p $env:MONGO_ROOT_PASSWORD --authenticationDatabase admin globalhealth_telemetry
```

En el arranque normal, `mongodb-init` ejecuta automáticamente ambos archivos.

El panel web expone el CRUD de `logs` directamente sobre Atlas mediante
`POST`, `PUT` y `DELETE /api/telemetria`. Cada escritura valida que la
`sesionId` exista, conserva la dependencia Paciente -> Sesión -> Log, asigna
un `logId` único y deriva la unidad desde el tipo de medición.

## Cobertura del requerimiento

- **JSON/BSON e IDs únicos:** índices únicos en `pacienteId`, `sesionId` y
  `logId`.
- **Abuelo-Padre-Hijo:** `Paciente -> Sesión -> Log`, comprobado con dos
  `$lookup` en `02_consultas.js` y mediante la API.
- **Relación y límites:** `$gt`, `$lte`, `$match`, `$sort`, `$limit`, filtros y
  paginación.
- **Agregación:** total, promedio, mínimo y máximo por tipo de medición.
- **Inserción, actualización y eliminación:** disponibles en el panel y en
  `/api/telemetria`.
- **Atlas:** `ATLAS_MONGO_URL` tiene prioridad; `/health/mongo` informa el
  proveedor y los conteos reales.

Rangos validados: frecuencia cardiaca `20-250 lpm`, SpO2 `0-100 %` y
temperatura `25-50 C`. Solo se aceptan las calidades `VALIDA` y `REVISAR`.

Consulta la matriz completa en
[`docs/05-cumplimiento-mongodb-atlas.md`](../../docs/05-cumplimiento-mongodb-atlas.md).
