# Fragmentación distribuida

- Horizontal: `paciente_norte` vive en `postgres-norte` y `paciente_sur` en
  `postgres-sur`. La vista del coordinador usa `UNION ALL`.
- Vertical: los atributos públicos viven en Norte y los financieros en Sur;
  ambas tablas conservan `paciente_id` como PK idéntica y se reconstruyen con JOIN.
- `postgres-coordinador` consulta ambos nodos mediante `postgres_fdw`.

Verificación:

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new()
Get-Content -Raw -Encoding UTF8 .\infra\fragmentacion\02_verificacion.sql |
  docker compose exec -T postgres-coordinador psql -U postgres -d globalhealth_distribuida
```
