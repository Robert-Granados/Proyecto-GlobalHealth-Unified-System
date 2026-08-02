# Entregable 2 — replicación física PostgreSQL 16

## Arquitectura y decisión

`postgres-master` acepta escrituras y genera WAL. `postgres-replica` obtiene una
copia física inicial mediante `pg_basebackup -R` y luego recibe/aplica WAL por
streaming. La réplica permanece en recuperación (`hot_standby`) y admite
consultas de sólo lectura.

La aplicación debe mantener dos pools independientes:

```dotenv
DB_WRITE_URL=postgresql://globalhealth_app:CLAVE_APP@localhost:55432/globalhealth
DB_READ_URL=postgresql://globalhealth_app:CLAVE_APP@localhost:55433/globalhealth
```

Dentro de la red de Compose, una API usaría `postgres-master:5432` y
`postgres-replica:5432`. No hay proxy, balanceador ni promoción automática.
Que las lecturas sobrevivan no implica que las escrituras sobrevivan: ésa es
precisamente la separación física que exige la rúbrica.

## Primera ejecución, en orden

Los comandos se ejecutan desde la raíz del repositorio. En Windows, los scripts
`.sh` se ejecutan desde Git Bash o WSL; los comandos de Docker también pueden
copiarse uno por uno en PowerShell.

1. Crear el archivo local de secretos:

   ```bash
   cp .env.example .env
   ```

   Cambiar las cuatro contraseñas. `.env` está ignorado por Git.

2. Validar la definición sin iniciar nada:

   ```bash
   docker compose config --quiet
   ```

   Salida esperada: ninguna y código de salida `0`.

3. Iniciar Docker Desktop y levantar el entorno:

   ```bash
   docker compose up -d
   docker compose ps
   ```

   Salida esperada: master, réplica y MongoDB en estado `Up (healthy)`. La
   primera copia puede tardar entre varios segundos y un minuto.

4. Observar la copia base si la réplica aún no está saludable:

   ```bash
   docker compose logs -f postgres-replica
   ```

   Salida esperada aproximada:

   ```text
   [replica] Volumen vacío: ejecutando pg_basebackup...
   .../.... kB (100%), 1/1 tablespace
   database system is ready to accept read-only connections
   ```

5. Ejecutar la validación integral:

   ```bash
   bash infra/postgres/validar-replicacion.sh
   ```

   Debe mostrar una fila `streaming`, luego `t` para
   `pg_is_in_recovery()` y finalmente:

   ```text
   OK: la réplica leyó 3 filas replicadas.
   ```

## Verificaciones manuales

En el master:

```bash
docker compose exec postgres-master psql -U postgres -d globalhealth \
  -c "SELECT application_name,client_addr,state,sync_state FROM pg_stat_replication;"
```

Se espera `state = streaming`. `sync_state = async` es correcto: esta
configuración favorece latencia de escritura y permite un pequeño retraso o
pérdida de los WAL aún no recibidos si el master desaparece.

En la réplica:

```bash
docker compose exec postgres-replica psql -U postgres -d globalhealth \
  -c "SELECT pg_is_in_recovery();"
```

Se espera `t`. Una escritura directa debe ser rechazada:

```bash
docker compose exec postgres-replica psql -U postgres -d globalhealth \
  -c "CREATE TABLE esto_debe_fallar(id int);"
```

Salida esperada:

```text
ERROR: cannot execute CREATE TABLE in a read-only transaction
```

Lag desde el master:

```bash
docker compose exec -T postgres-master psql -U postgres -d globalhealth \
  -f /dev/stdin < infra/postgres/lag-replicacion.sql
```

En reposo, `lag_bytes` normalmente será `0 bytes`; los campos temporales pueden
ser `NULL` cuando no hubo actividad reciente.

## Demo de caída

Primero ejecutar la validación integral. Después:

```bash
bash infra/postgres/demo-caida.sh
```

El guion muestra la lectura antes de la caída, detiene sólo el master, prueba
que el destino de escritura ya no responde y realiza tres lecturas consecutivas
en la réplica. La réplica no se promueve y no acepta escrituras.

Restaurar el laboratorio:

```bash
docker compose start postgres-master
docker compose exec postgres-master psql -U postgres -d globalhealth \
  -c "SELECT state,sync_state FROM pg_stat_replication;"
```

Tras unos segundos vuelve a aparecer `streaming`.

## Reinicio limpio y advertencias

`docker compose down` conserva datos. `docker compose down -v` elimina las bases
y obliga a repetir `init-primary.sh` y `pg_basebackup`; úsese únicamente cuando
se quiera reinicializar todo.

- **Docker Desktop apagado:** el error menciona
  `dockerDesktopLinuxEngine`. Abrir Docker Desktop y esperar a que diga
  “Engine running”.
- **Puerto ocupado:** el laboratorio publica el master en `55432` y la réplica
  en `55433`, configurables mediante `POSTGRES_MASTER_PORT` y
  `POSTGRES_REPLICA_PORT` en `.env`. Dentro de Docker ambos conservan `5432`.
- **Permisos/CRLF en Windows:** invocar los scripts con `bash script.sh`. Los
  scripts dentro de contenedores se invocan explícitamente con `/bin/bash`, por
  lo que no dependen del bit ejecutable del host.
- **`pg_hba.conf`:** la regla de replicación acepta únicamente al rol
  `replicator` desde `172.28.0.0/24` y usa SCRAM. Si se cambia la subred en
  Compose, debe cambiarse también la regla antes de crear el volumen del master.
- **Resolución DNS:** entre contenedores se usan nombres de servicio
  (`postgres-master`, `postgres-replica`), no `localhost`. Desde la laptop sí se
  usan `localhost:5432` y `localhost:5433`.
- **Credencial modificada con volumen existente:** los scripts de inicialización
  sólo corren con un volumen vacío. Cambiar `.env` no altera roles existentes.
- **Crecimiento de WAL:** `wal_keep_size=256MB` ayuda ante cortes breves, pero no
  garantiza retención ilimitada. Para desconexiones largas conviene un slot
  físico monitorizado, que también puede llenar el disco si la réplica muere.
- **Consultas largas:** pueden ser canceladas si chocan con limpieza de tuples
  en el master. `hot_standby_feedback=on` reduce cancelaciones a costa de posible
  bloat en el master.

## Cinco preguntas probables

1. **¿Por qué `wal_level=replica`?**  
   Hace que el WAL contenga la información necesaria para reconstruir los
   cambios en otra instancia. `minimal` no sirve para streaming; `logical`
   añade información que aquí no necesitamos.

2. **¿El usuario `replicator` tiene privilegios mínimos?**  
   Sí: sólo `LOGIN REPLICATION` y contraseña SCRAM. No es superusuario, no es
   dueño de la base y `pg_hba.conf` limita origen, rol y tipo de conexión.

3. **¿Qué ocurre con CAP en esta arquitectura?**  
   Ante una partición de red, el master sigue aceptando escrituras y la réplica
   puede servir datos atrasados: para el dashboard se priorizan disponibilidad
   y tolerancia a particiones sobre consistencia inmediata (AP en esa ruta de
   lectura). La ruta transaccional permanece dirigida a un solo master y
   prioriza consistencia; al caer éste se sacrifica disponibilidad de escritura
   porque deliberadamente no hay promoción automática.

4. **¿Dónde aparece BASE?**  
   El dashboard es “básicamente disponible” durante la caída, su estado puede
   ser temporalmente blando porque la réplica asíncrona lleva retraso, y converge
   eventualmente cuando recibe/aplica WAL. Las operaciones clínicas escritas en
   el master siguen usando transacciones ACID; BASE no reemplaza ACID en toda la
   solución, describe la vista de lectura replicada.

5. **¿Por qué no hacer failover automático o usar un proxy?**  
   La consigna exige dos conexiones físicamente explícitas. Los dos pools hacen
   visible qué operaciones van al master y cuáles a la réplica. La demo evalúa
   continuidad de lectura, no alta disponibilidad de escritura. En producción,
   promoción, fencing y redirección requerirían un diseño adicional para evitar
   split-brain.
