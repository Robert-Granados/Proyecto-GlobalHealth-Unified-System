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
reemplazando la prueba por consola (`Invoke-RestMethod`/`curl`). El backend Node
no fue modificado: conserva sus rutas intactas y sigue exponiendo los mismos
endpoints (`/health`, `/health/read`, `/api/dashboard/signos-vitales`,
`/api/signos-vitales`).

```powershell
docker compose up -d --build
# Abrir http://localhost:8090
```

## Inicio local

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose run --rm sqlserver-init
.\infra\postgres\validar-backend.ps1
```

La validación XML ocurre exclusivamente dentro de SQL Server. El backend crea
dos objetos `Pool` distintos y no contiene fallback entre master y réplica.
