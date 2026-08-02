Prompt para Robert — Infraestructura (Docker, Replicación, Fragmentación, Nube)
Actúa como ingeniero de infraestructura de datos senior y mentor técnico. Estoy en
un proyecto final universitario de Bases de Datos Avanzadas (25% de la nota) que se
defiende oralmente el 17/08/2026 con demo en vivo. Trabajo en pareja; yo soy
responsable de la capa física y distribuida.

CASO: "GlobalHealth Unified System", corporación médica con clínicas en tres países
de Centroamérica, migrando de infraestructura centralizada por problemas de
latencia y seguridad.

MIS CUATRO ENTREGABLES:

=== 1. MongoDB: telemetría médica ===
- Modelo de dependencia documental Abuelo-Padre-Hijo:
  Paciente → Sesión de monitoreo → Logs de sensores.
  Necesito la justificación de dónde embeber y dónde referenciar, considerando
  que los logs son de ingesta masiva y alta cardinalidad.
- Generador de datos sintéticos: ~50.000 documentos de telemetría realista
  (frecuencia cardíaca, SpO2, presión, temperatura) con timestamps coherentes.
- Consultas complejas con operadores de relación ($gt, $lte, $in), $limit, $sort.
- Pipeline de agregación no trivial (promedios por sesión, detección de valores
  fuera de rango, agrupación temporal).
- $lookup entre colecciones (JOIN NoSQL) y explicación de su costo.

=== 2. Replicación Maestro/Esclavo en Docker ===
- PostgreSQL 16, replicación por streaming, DOS contenedores aislados.
- Master procesa escrituras; Esclavo sirve las lecturas pesadas del dashboard.
- RESTRICCIÓN CRÍTICA del enunciado: el backend debe tener separación física
  nativa de conexiones (dos pools: DB_WRITE_URL al master, DB_READ_URL a la
  réplica). Nada de proxies ni failover automático que oculten la separación.
- Necesito: configuración de wal_level, usuario de replicación con permisos
  mínimos, pg_basebackup, hot_standby, y las queries de validación
  (pg_stat_replication, pg_is_in_recovery, lag de replicación).
- Script demo-caida.sh para la defensa: apaga el master en consola y demuestra
  que las lecturas siguen sirviéndose. La rúbrica lo evalúa como "chaos
  engineering en vivo", así que debe ser visualmente contundente.

=== 3. Fragmentación de datos ===
- Horizontal: pacientes divididos por región (Clínica Norte / Clínica Sur) en
  nodos SEPARADOS, no solo particiones locales. Usar postgres_fdw.
- Vertical: separar datos financieros confidenciales de los datos públicos de
  contacto, respetando la regla de llaves primarias idénticas para poder
  reconstruir la relación original.
- Necesito la consulta de reconstrucción de cada fragmentación y una explicación
  de qué se rompe (rendimiento, transaccionalidad) al fragmentar.

=== 4. Nube ===
- Despliegue del cluster en MongoDB Atlas: usuario de solo lectura, IP allowlist,
  connection string en variables de entorno, nunca en el repositorio.
- Evaluación CUANTITATIVA de costo/beneficio: self-hosted vs. Atlas M10/M20,
  proyectado a 12 y 36 meses, incluyendo horas-persona de operación,
  backups, y costo de egreso de datos. Con tabla y supuestos explícitos.
- Interfaz de consumo funcional que exponga la conexión de forma segura.

FORMATO DE RESPUESTA QUE NECESITO:
1. docker-compose.yml completo y comentado como punto de partida.
2. Comandos ejecutables en orden, con la salida esperada de cada uno para poder
   verificar que voy bien.
3. Advertencias explícitas donde algo suela fallar (permisos de volúmenes,
   pg_hba.conf, resolución de nombres entre contenedores).
4. Al final de cada entregable: las 5 preguntas más probables del profesor y su
   respuesta, incluyendo Teorema CAP y modelo BASE aplicados a MI arquitectura
   concreta, no en abstracto.

Empecemos por el docker-compose.yml del entorno completo y la replicación
master/slave, que es mi mayor riesgo técnico. Quiero validarla esta semana.