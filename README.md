# Proyecto-GlobalHealth-Unified-System

Arquitectura híbrida para clínicas de Costa Rica, Guatemala y Panamá:

- PostgreSQL 16 master/réplica y modelo objeto-relacional;
- SQL Server 2022 con XML tipado contra XSD registrado;
- MongoDB para telemetría;
- backend Node con pools físicos separados para escritura y lectura.

## Controles críticos

- [Modelo objeto-relacional](docs/02-modelo-objeto-relacional.md)
- [XML tipado y separación de conexiones](docs/03-capa-xml-y-conexiones.md)
- [Scripts XML](xml/sqlserver/README.md)
- [Backend read/write](api/README.md)
- [Replicación PostgreSQL](docs/01-replicacion-postgresql.md)

## Interfaz gráfica (panel web)

Se añadió un contenedor `web` (nginx) que sirve un panel en
`http://localhost:${WEB_PORT:-8090}` y actúa como reverse proxy hacia `api`,
reemplazando la prueba por consola (`Invoke-RestMethod`/`curl`). El panel
demuestra en vivo cinco recorridos: signos vitales (master/réplica),
médicos del modelo objeto-relacional (INSERT con tipos compuestos y herencia)
y expedientes XML validados por SQL Server con el error exacto del motor, además
del listado, filtros, agregaciones y CRUD de telemetría sobre MongoDB Atlas.
Endpoints: `/health`, `/health/read`, `/api/dashboard/signos-vitales`,
`/api/signos-vitales`, `/api/medicos`, `/api/expedientes` y
`/api/telemetria` (ver
[api/README.md](api/README.md)).

```powershell
docker compose up -d --build
# Abrir http://localhost:8090
```

El arranque también crea tres nodos para fragmentación distribuida y carga en
MongoDB 1.000 pacientes, 5.000 sesiones y 50.000 logs. La primera carga puede
tardar aproximadamente un minuto adicional.

Además, `web/explicacion.html` es una página estática y autocontenida que explica
qué es el proyecto y cómo funciona (arquitectura, flujos y controles críticos).
Se puede abrir directamente con doble clic o en
`http://localhost:8090/explicacion.html` cuando el stack está arriba.

## Inicio local

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose run --rm sqlserver-init
.\infra\postgres\validar-backend.ps1
```

## Verificación distribuida

```powershell
Invoke-RestMethod http://localhost:8080/health/mongo
Invoke-RestMethod http://localhost:8080/api/telemetria/resumen
Invoke-RestMethod http://localhost:8080/api/telemetria/paciente/1
Invoke-RestMethod 'http://localhost:8080/api/telemetria?page=1&limit=20'

$OutputEncoding = [System.Text.UTF8Encoding]::new()
Get-Content -Raw -Encoding UTF8 .\infra\fragmentacion\02_verificacion.sql |
  docker compose exec -T postgres-coordinador psql -U postgres -d globalhealth_distribuida
```

Ver [MongoDB](nosql/mongodb/README.md),
[fragmentación](infra/fragmentacion/README.md) y
[nube/costos](docs/04-nube-y-costos.md).

La matriz de requisitos y evidencias pendientes de Atlas está en
[cumplimiento MongoDB Atlas](docs/05-cumplimiento-mongodb-atlas.md).

La validación XML ocurre exclusivamente dentro de SQL Server. El backend crea
dos objetos `Pool` distintos y no contiene fallback entre master y réplica.
