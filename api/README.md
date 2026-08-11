# Backend con separación física Master/Réplica

El proceso crea dos instancias independientes de `pg.Pool`:

- `writePool` usa exclusivamente `DB_WRITE_URL` y exige
  `pg_is_in_recovery() = false`.
- `readPool` usa exclusivamente `DB_READ_URL` y exige
  `pg_is_in_recovery() = true`.

No existe fallback. Las rutas de escritura llaman únicamente `queryWrite` y el
dashboard llama únicamente `queryRead`.

## Endpoints

| Método y ruta | Pool esperado |
|---|---|
| `GET /health` | comprueba ambos |
| `GET /health/read` | réplica |
| `GET /api/dashboard/signos-vitales` | réplica |
| `POST /api/signos-vitales` | master |

## Prueba

```powershell
docker compose up -d --build postgres-master postgres-replica api
Invoke-RestMethod http://localhost:8080/health | ConvertTo-Json -Depth 6
Invoke-RestMethod http://localhost:8080/api/dashboard/signos-vitales
```

Validación automática y demo de caída en Windows:

```powershell
.\infra\postgres\validar-backend.ps1
.\infra\postgres\demo-caida.ps1
```

La respuesta de `/health` debe mostrar dos direcciones físicas diferentes,
`writer.inRecovery=false`, `reader.inRecovery=true` y
`physicallySeparated=true`.
