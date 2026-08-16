# Cumplimiento de MongoDB Atlas

Auditoria contra `Proyecto_Final_Avanzado_BBDD.pdf`, seccion NoSQL y nube.

| Requisito | Estado | Evidencia |
|---|---|---|
| JSON/BSON e identificadores unicos | Cumple | Colecciones `pacientes`, `sesiones` y `logs`; indices unicos sobre `pacienteId`, `sesionId` y `logId`. |
| Dependencia Paciente -> Sesion -> Log | Cumple | Referencias `sesiones.pacienteId` y `logs.sesionId`; las escrituras de la API rechazan sesiones inexistentes. |
| Inserciones | Cumple | Carga idempotente de 50.000 logs y `POST /api/telemetria` sobre Atlas. |
| Actualizaciones | Cumple | `PUT /api/telemetria/:logId`, con validacion de tipo, rango, calidad y sesion. |
| Eliminaciones solicitadas para el panel | Cumple | `DELETE /api/telemetria/:logId`, con confirmacion desde la interfaz. |
| Operadores de relacion y limites | Cumple | `$gt`, `$lte`, `$match`, `$sort` y `$limit` en `02_consultas.js`; filtros y paginacion en la API. |
| Agregaciones | Cumple | Pipeline `$match` + `$group` para total, promedio, minimo y maximo por tipo. |
| JOIN NoSQL | Cumple | Dos `$lookup` para Paciente -> Sesion -> Logs, disponible en `/api/telemetria/paciente/:id`. |
| Cluster real en la nube | Cumple funcionalmente | `/health/mongo` identifica `MONGODB_ATLAS` y cuenta 1.000 pacientes, 5.000 sesiones y 50.000 logs. |
| Interfaz de consumo | Cumple | Panel y API permiten listar, filtrar, crear, editar y eliminar telemetria de Atlas. |
| Cadena fuera del repositorio | Cumple | `ATLAS_MONGO_URL` se inyecta desde `.env`; `.env` esta ignorado por Git. |
| TLS | Cumple por configuracion | La plantilla usa `mongodb+srv`, cuyo trafico hacia Atlas usa TLS. |
| Evaluacion cuantitativa costo/beneficio | Cumple con supuestos | `docs/04-nube-y-costos.md` compara M10, M20 y self-hosted a 12 y 36 meses. |
| Tier, region y calculador oficial | Evidencia pendiente | Adjuntar captura actual de Atlas y del calculador antes de entregar. |
| Usuario limitado a la base | Evidencia pendiente | Adjuntar captura del rol `readWrite` solo para `globalhealth_telemetry`, ocultando el secreto. |
| Network Access | Evidencia pendiente | Adjuntar captura de la IP/CIDR del backend o private endpoint; evitar `0.0.0.0/0` permanente. |
| Backups y monitoreo | Evidencia pendiente | Documentar configuracion real del cluster si el tier utilizado ofrece estas funciones. |

## Prueba funcional ejecutada

Se creo el log `50001` en la sesion `1`, se actualizo de valor `97 / VALIDA`
a `98 / REVISAR`, se comprobo mediante el listado filtrado y se elimino. El
conteo de Atlas regreso de `50.001` a `50.000`, sin dejar datos de prueba.
