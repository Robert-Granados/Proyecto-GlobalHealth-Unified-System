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
| `GET /health/mongo` | MongoDB y conteos de colecciones |
| `GET /api/telemetria/resumen` | agregación MongoDB |
| `GET /api/telemetria/paciente/:id` | `$lookup` Paciente → Sesión → Logs |
| `GET /api/telemetria` | lista paginada y filtrada de logs en Atlas |
| `POST /api/telemetria` | crea una lectura validando su sesión padre |
| `PUT /api/telemetria/:logId` | actualiza una lectura y su unidad clínica |
| `DELETE /api/telemetria/:logId` | elimina una lectura de Atlas |
| `GET /api/dashboard/signos-vitales` | réplica |
| `POST /api/signos-vitales` | master |
| `GET /api/medicos` | réplica |
| `POST /api/medicos` | master |
| `DELETE /api/medicos/:oid` | master |
| `GET /api/expedientes` | SQL Server (capa XML) |
| `POST /api/expedientes` | SQL Server (valida el XSD dentro del motor) |

## Médicos (modelo objeto-relacional)

`GET /api/medicos` lee de la réplica usando el método `gh_obj.nombre_completo(m)`
y descompone el array `especialidades`. `POST /api/medicos` inserta en el master
construyendo los tipos compuestos (`ROW(...)::gh_tipo.direccion_t`, `contacto_t`,
`especialidad_t[]`); las restricciones del motor (dominios, `CHECK`, unicidad
entre tablas hijas) responden con `400`/`409` y el nombre de la restricción.

Requisito: cargar los scripts del MOR y otorgar acceso al rol de la aplicación:

```powershell
$archivos = Get-ChildItem .\mor\postgresql\0[1-4]_*.sql | Sort-Object Name
foreach ($archivo in $archivos) {
    Get-Content -Raw $archivo.FullName |
        docker compose exec -T postgres-master psql -v ON_ERROR_STOP=1 -U postgres -d globalhealth
}
docker compose exec -T postgres-master psql -U postgres -d globalhealth -c "GRANT USAGE ON SCHEMA gh_tipo, gh_obj TO globalhealth_app; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gh_obj TO globalhealth_app; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gh_tipo TO globalhealth_app; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gh_obj TO globalhealth_app;"
```

## Expedientes XML (SQL Server)

La conexión `MSSQL_URL` es perezosa: se abre con la primera petición y no
participa en la topología master/réplica. Requiere
`docker compose run --rm sqlserver-init` (crea `GlobalHealthXml`, registra el
XSD y la columna tipada).

`POST /api/expedientes` recibe `{ "codigo", "xml" }` e inserta directamente en
`dbo.ExpedienteClinico`. Si el documento viola el XSD, responde `422` con
`errorNumero` y `mensajeExacto` producidos por el motor (p. ej. `6908` firma
faltante, `6926` valor inválido); la API no contiene ninguna librería XSD.

## Telemetría MongoDB Atlas

Si `ATLAS_MONGO_URL` está definida, la API la prioriza sobre el MongoDB local.
`GET /api/telemetria` pagina 20 documentos y acepta los filtros `pacienteId`,
`tipo` y `calidad`. El resumen usa `$match` y `$group`; la trazabilidad de un
paciente usa dos `$lookup` entre `pacientes`, `sesiones` y `logs`.

El CRUD conserva la jerarquía documental: `POST` y `PUT` rechazan una
`sesionId` que no exista. La API valida el rango del valor, deriva `unidad` del
tipo y genera `logId` mediante un contador atómico. `DELETE` elimina únicamente
el log indicado. La URI real vive en `.env`, archivo excluido de Git.

## Prueba

```powershell
docker compose up -d --build postgres-master postgres-replica api
Invoke-RestMethod http://localhost:8080/health | ConvertTo-Json -Depth 6
Invoke-RestMethod http://localhost:8080/api/dashboard/signos-vitales
Invoke-RestMethod http://localhost:8080/health/mongo
Invoke-RestMethod 'http://localhost:8080/api/telemetria?page=1&limit=20'
```

Validación automática y demo de caída en Windows:

```powershell
.\infra\postgres\validar-backend.ps1
.\infra\postgres\demo-caida.ps1
```

La respuesta de `/health` debe mostrar dos direcciones físicas diferentes,
`writer.inRecovery=false`, `reader.inRecovery=true` y
`physicallySeparated=true`.
