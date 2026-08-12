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
