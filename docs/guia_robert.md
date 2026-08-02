# Plan de Trabajo — GlobalHealth Unified System
**Integrantes:** Alejandro y Robert · **Defensa:** lunes 17/08/2026 · **Tiempo real disponible:** 26 días

---

## 1. Decisión técnica previa (háganla hoy, condiciona todo)

Hay un punto crítico escondido en la cláusula anti-plagio: exige un **XSD registrado en la base de datos**, no una validación hecha en el código. Esto define su stack:

| Capa | Opción recomendada | Por qué |
|---|---|---|
| MOR | **PostgreSQL 16** | Tipos compuestos, `CREATE TABLE ... OF tipo`, herencia (`INHERITS`), arrays para teléfonos/especialidades. Es el motor más limpio para MOR. |
| XML | **SQL Server 2022 en Docker** (`CREATE XML SCHEMA COLLECTION`) | Es el único de los sugeridos con registro nativo de XSD + `.query()`, `.value()`, `.modify()` para el CRUD sobre nodos. Cumple la cláusula sin discusión. |
| XML (alternativa) | PostgreSQL + `plpython3u` con `lxml` y el XSD guardado en tabla, validado por trigger | Sirve si no quieren un tercer motor, pero **deben** poder defender que el XSD vive en la BD y el trigger bloquea inserciones inválidas. |
| NoSQL | MongoDB local (dev) → **Atlas M0** (producción) | Mismo código, solo cambia el connection string. |

Mi recomendación: PostgreSQL + SQL Server + MongoDB. Son tres contenedores, y ya necesitan Docker de todos modos para la replicación.

**Regla de oro para la replicación:** el backend debe tener **dos pools de conexión separados** (`DB_WRITE_URL` → master, `DB_READ_URL` → réplica), no un proxy ni un failover automático. La rúbrica pide demostrar que al apagar el master, las lecturas siguen vivas.

---

## 2. División de responsabilidades

El reparto sigue los porcentajes de la rúbrica para que ambos carguen ~12.5%.

**Alejandro — Arquitecto de Datos (capa lógica)**
- Unidad I completa de MOR: tipos compuestos, herencia, agregación/composición, tablas tipadas, tablas anidadas, CRUD.
- Capa XML: diseño del XSD del expediente clínico, registro de la colección de esquemas, CRUD sobre nodos internos, casos de prueba de rechazo.
- Diagramas de clases/tipos y modelo de datos para el PDF.

**Robert — Ingeniero de Infraestructura (capa física)**
- `docker-compose.yml` de todo el entorno.
- Replicación streaming Master/Esclavo en PostgreSQL + script de demo de caída.
- Fragmentación horizontal (por región) y vertical (financiero vs. contacto) con `postgres_fdw`.
- MongoDB: modelo Paciente → Sesión → Logs, agregaciones, `$lookup`, migración a Atlas y análisis costo/beneficio.

**Trabajo compartido (50/50)**
- API de consumo (FastAPI o Express) que expone el enrutamiento read/write y consume Atlas.
- Documento PDF final.
- Ensayos de defensa.

> Aunque cada uno construya su mitad, **ambos deben poder defender todo**. El profesor puede preguntarle a Robert sobre herencia de tipos o a Alejandro sobre el Teorema CAP. Reserven 45 minutos los domingos para explicarse mutuamente lo hecho en la semana.

---

## 3. Cronograma por bloques

### Bloque 0 — Diseño y arranque (mié 22 – dom 26 jul)
*Ambos, sesión conjunta de 3 horas + trabajo individual*

- Repositorio Git con estructura: `/mor`, `/xml`, `/nosql`, `/infra`, `/api`, `/docs`.
- Diagrama de arquitectura general (los 3 motores + master/slave + Atlas).
- Modelo conceptual: entidades de GlobalHealth (Clínica, Médico, Equipo, Paciente, Expediente, Sesión de telemetría).
- Definir el XSD en papel antes de escribirlo.
- `docker-compose.yml` levantando los 3 motores vacíos. **Checkpoint: los tres motores responden a un ping.**

### Bloque 1 — Modelos de datos (lun 27 jul – dom 2 ago)
| Alejandro | Robert |
|---|---|
| Tipos compuestos (`empleado_t`, `direccion_t`, `equipo_t`), herencia (`medico_t` ← `empleado_t`), tablas tipadas, arrays de especialidades/teléfonos, funciones miembro del tipo, CRUD completo con scripts idempotentes | Colecciones MongoDB con la jerarquía Abuelo-Padre-Hijo, generador de datos sintéticos de telemetría (~50k documentos), consultas con `$match`/`$limit`/`$gt`, pipeline de agregación y `$lookup` contra colección de pacientes |

**Checkpoint domingo 2/08:** demo cruzada de 10 min cada uno.

### Bloque 2 — XML y Replicación (lun 3 – dom 9 ago)
*Este es el bloque de mayor riesgo. Empiecen el lunes, no el jueves.*

| Alejandro | Robert |
|---|---|
| XSD del expediente clínico registrado en la BD; columna tipada contra la colección; pruebas que demuestren rechazo de XML inválido; CRUD de nodos (extraer, insertar, modificar, borrar sub-elementos); ciclo completo de la plantilla: registrar → actualizar → eliminar | Replicación física: `wal_level=replica`, usuario de replicación, `pg_basebackup`, standby en hot_standby; validación de la réplica (`pg_stat_replication`); script `demo-caida.sh` que apaga el master y muestra lecturas funcionando |

**Checkpoint domingo 9/08:** Alejandro intenta insertar XML corrupto y falla; Robert apaga el master en vivo y las lecturas siguen.

### Bloque 3 — Fragmentación, Nube e Integración (lun 10 – vie 14 ago)
*Ambos, con la API como punto de encuentro*

- **Robert:** fragmentación horizontal `pacientes_norte` / `pacientes_sur` en nodos separados con vista/tabla particionada de reconstrucción; fragmentación vertical con PK idéntica (`paciente_publico` / `paciente_financiero`); cluster Atlas aprovisionado con usuario de solo lectura, IP allowlist y string en variables de entorno; tabla comparativa de costos (self-hosted vs. M10/M20 a 12 y 36 meses, incluyendo horas-persona de operación).
- **Alejandro:** endpoints de la API que consumen las tres capas; redacción del PDF (justificación de diseño, diagramas de fragmentación, decisiones de arquitectura).
- **Viernes 14:** *feature freeze*. Nada nuevo se programa después de esta fecha.

### Cierre — Ensayos (sáb 15 – dom 16 ago)
- Sábado: PDF final revisado por ambos, guion de los 15 minutos escrito y cronometrado.
- Domingo: dos ensayos completos con cronómetro + ronda de preguntas duras entre ustedes.

---

## 4. Guion sugerido para los 15 minutos

| Tiempo | Contenido | Quién |
|---|---|---|
| 0:00–2:00 | Problema de negocio y decisión de arquitectura multi-modelo | Robert |
| 2:00–6:00 | MOR en vivo: herencia + tabla tipada + consulta sobre tabla anidada | Alejandro |
| 6:00–8:30 | XML: inserción válida, inserción rechazada por el XSD, extracción de nodo | Alejandro |
| 8:30–11:00 | Mongo: jerarquía + agregación con `$lookup` sobre Atlas | Robert |
| 11:00–13:30 | **Chaos engineering:** `docker stop master` → la app sigue leyendo | Robert |
| 13:30–15:00 | Fragmentación (diagrama) + costo/beneficio + cierre | Alejandro |

Dejen las preguntas conceptuales (CAP, BASE, consistencia eventual) para el turno de preguntas, pero tengan una respuesta preparada de 30 segundos para cada una.

---

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| La replicación no levanta y consume una semana | Robert hace un *spike* de 3 horas el 27/07 (fuera de su bloque) solo para validar que la técnica funciona |
| PostgreSQL no valida XSD nativamente | Decidido hoy: usar SQL Server, o tener el plan B de `plpython3u` documentado |
| La demo en vivo falla el 17/08 | Grabar video de respaldo de cada demo el 14/08; llevar todo en un solo `docker compose up` probado en ambas laptops |
| Atlas bloquea la IP de la universidad | Configurar allowlist `0.0.0.0/0` temporal el día anterior, y llevar hotspot móvil |
| Uno se enferma la última semana | Cross-training obligatorio los domingos; ningún script sin comentarios |