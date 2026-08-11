# Controles críticos: XML tipado y separación física de conexiones

## 1. Capa XML en SQL Server 2022

La fuente de autoridad de la validación es SQL Server. El backend no contiene
una librería XSD ni decide si un expediente es válido.

El script `xml/sqlserver/02_xsd_y_tabla_tipificada.sql` realiza dos operaciones
inseparables:

1. importa el XSD con `CREATE XML SCHEMA COLLECTION`;
2. declara `Documento xml(DOCUMENT dbo.ExpedienteClinicoXsd)`.

Por ello, cualquier asignación a `Documento`, incluida una mutación con XML
DML, se valida contra los componentes XSD registrados en los metadatos.

### Restricciones no triviales

- patrones para expediente, paciente, médico y CIE-10;
- enumeraciones de país, sexo, sangre, antecedente, severidad, tratamiento,
  estado y algoritmo de firma;
- fechas y fecha-hora con tipos XSD nativos;
- longitudes mínimas y máximas;
- un diagnóstico obligatorio y hasta veinte;
- hasta veinte antecedentes y tratamientos;
- firma médica obligatoria;
- firma base64 entre 32 y 512 bytes.

### Errores exactos observados

La ejecución validada en SQL Server 2022 RTM-CU26 `16.0.4265.3` produjo:

| Caso | Número | `ERROR_MESSAGE()` |
|---|---:|---|
| Firma faltante | 6908 | `XML Validation: Invalid content. Expected element(s): '{urn:globalhealth:expediente:v1}FirmaMedico'. Location: /*:ExpedienteClinico[1]` |
| Fecha incorrecta | 6926 | `XML Validation: Invalid simple type value: '1988-99-45'. Location: /*:ExpedienteClinico[1]/*:Paciente[1]/*:FechaNacimiento[1]` |
| Severidad fuera de enumeración | 6926 | `XML Validation: Invalid simple type value: 'URGENTE'. Location: /*:ExpedienteClinico[1]/*:Diagnosticos[1]/*:Diagnostico[1]/*:Severidad[1]` |
| DROP con dependencia | 6328 | `Specified collection 'ExpedienteClinicoXsd' cannot be dropped because it is used by object 'dbo.ExpedienteClinico'.` |

Los mensajes también quedan persistidos en `dbo.PruebaRechazoXML`. Esto evita
depender del idioma o de copiar manualmente la salida en otra instalación.

### Ciclo de vida

- `CREATE`: registra la versión base.
- `ALTER ... ADD`: incorpora el namespace de interoperabilidad.
- `DROP` con columna dependiente: falla y su error se registra.
- `DROP` después de retirar la tabla: funciona dentro de una transacción.
- `ROLLBACK`: recupera colección, tabla y datos para dejar la demo operativa.

## 2. Dos conexiones físicas en el backend

`api/src/db.js` crea dos instancias independientes de `pg.Pool`:

```text
queryWrite -> writePool -> DB_WRITE_URL -> postgres-master
queryRead  -> readPool  -> DB_READ_URL  -> postgres-replica
```

No existe código de fallback. Al arrancar, el backend consulta ambos nodos:

| Pool | Dirección validada | `pg_is_in_recovery()` |
|---|---|---:|
| `writePool` | `172.28.0.10/32` | `false` |
| `readPool` | `172.28.0.11/32` | `true` |

La aplicación aborta si se invierten las URLs o ambas resuelven la misma
dirección.

### Evidencia de caída

La prueba `infra/postgres/demo-caida.ps1` ejecuta:

1. lectura del dashboard mediante `readPool`;
2. detención exclusiva de `postgres-master`;
3. POST de escritura, que responde HTTP 503 desde `WRITE_MASTER`;
4. lectura de salud y dashboard, que siguen respondiendo desde `READ_REPLICA`;
5. restauración automática del master en un bloque `finally`.

La demo no usa `psql` para fingir que existe un backend: todas las operaciones
evaluadas pasan por endpoints HTTP de la aplicación.

## 3. Comandos de verificación

```powershell
docker compose up -d --build postgres-master postgres-replica api sqlserver
docker compose run --rm sqlserver-init
.\infra\postgres\validar-backend.ps1
.\infra\postgres\demo-caida.ps1
```

## 4. Cinco preguntas probables

1. **¿Dónde se valida el XML?** En la asignación a la columna XML tipada dentro
   de SQL Server; los errores 6908 y 6926 proceden del motor.
2. **¿Por qué una columna `xml` normal no basta?** Solo garantiza sintaxis XML;
   sin `xml_schema_collection` no exige firma, CIE-10 ni enumeraciones.
3. **¿Cómo prueban que existen dos pools?** `/health` muestra aplicaciones,
   direcciones e indicador de recuperación distintos, obtenidos por cada pool.
4. **¿Qué pasa si se intercambian las URLs?** El backend aborta: write debe
   devolver `false` y read debe devolver `true` para `pg_is_in_recovery()`.
5. **¿Por qué la lectura sobrevive?** La réplica es otro proceso PostgreSQL con
   almacenamiento propio y hot standby; el dashboard nunca depende del pool de
   escritura.
