# Entregable 1: modelo objeto-relacional

## Orden de ejecución

1. `01_reinicio_y_tipos.sql`
2. `02_tablas_y_herencia.sql`
3. `03_metodos_y_reglas.sql`
4. `04_datos_prueba.sql`
5. `05_crud_demostracion.sql`
6. `06_verificacion.sql`

El archivo `00_ejecutar_todo.sql` incluye los seis scripts mediante `\ir` y
activa `ON_ERROR_STOP` para detener la ejecución ante el primer error.

Desde una instalación local de `psql`:

```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d globalhealth -f .\mor\postgresql\00_ejecutar_todo.sql
```

Con el contenedor principal del proyecto ya iniciado:

```powershell
$archivos = Get-ChildItem .\mor\postgresql\0[1-6]_*.sql | Sort-Object Name
foreach ($archivo in $archivos) {
    Get-Content -Raw $archivo.FullName |
        docker compose exec -T postgres-master \
            psql -v ON_ERROR_STOP=1 -U postgres -d globalhealth
    if ($LASTEXITCODE -ne 0) { throw "Falló $($archivo.Name)" }
}
```

El script 01 elimina y reconstruye únicamente los esquemas `gh_obj` y
`gh_tipo`. Esto hace idempotente la demostración sin tocar la infraestructura,
la replicación ni otros modelos del proyecto.

## Cobertura del enunciado

| Requisito | Evidencia principal |
|---|---|
| Tipos compuestos | `direccion_t`, `contacto_t`, `equipo_medico_t`, `empleado_t` |
| Herencia | `medico_t` y `enfermero_t` heredan de `empleado_base` |
| Composición | `equipo_medico.clinica_ref` con `ON DELETE CASCADE` |
| Agregación | `empleado_base.clinica_ref` con `ON DELETE SET NULL` |
| Tablas tipadas | `clinica`, `equipo_medico` y `empleado_base` |
| REF/OID | dominio UUID `objeto_oid_t`, PK y referencias del mismo dominio |
| Colecciones | `contacto.telefonos[]` y `medico_t.especialidades[]` |
| Métodos | `nombre_completo`, `antiguedad`, `costo_mantenimiento` |
| CRUD | `05_crud_demostracion.sql` |
| Catálogos y asserts | `06_verificacion.sql` |

## Guion corto para la demostración

1. Ejecutar los scripts 01 a 04 para reconstruir el estado base.
2. Mostrar `information_schema.tables` y `pg_inherits` con el script 06.
3. Ejecutar el script 05 por bloques: crear equipo, consultar métodos, actualizar
   dirección y teléfono, y eliminar el equipo temporal.
4. Mostrar que una consulta a `empleado_base` devuelve ambos subtipos y que
   `ONLY empleado_base` devuelve cero filas.
5. Ejecutar la prueba reversible de composición del script 06.

## Cinco preguntas probables del profesor

### 1. ¿Por qué `medico_t` no se definió con `CREATE TYPE ... UNDER empleado_t`?

PostgreSQL 16 no implementa herencia de tipos estructurados mediante `UNDER`.
Su mecanismo nativo es `INHERITS` entre tablas. Cada tabla crea automáticamente
un tipo compuesto para sus filas, por lo que `medico_t` y `enfermero_t` son
tipos de fila especializados y la relación se puede comprobar en `pg_inherits`.

### 2. ¿El UUID utilizado es el OID interno de PostgreSQL?

No. Es un OID lógico del dominio. PostgreSQL eliminó los OID implícitos de las
tablas de usuario y sus OID internos son de 32 bits. El UUID es estable, tiene
una probabilidad despreciable de colisión y puede viajar entre los tres países.

### 3. ¿Por qué equipo-clínica es composición y personal-clínica agregación?

El equipo depende de la clínica propietaria y su FK usa `ON DELETE CASCADE`.
El empleado posee identidad y ciclo de vida propios; puede estar sin sede y su
FK usa `ON DELETE SET NULL`. El comportamiento de borrado materializa la
diferencia conceptual.

### 4. ¿Los tipos compuestos garantizan por sí mismos que sus campos sean válidos?

No completamente. Un tipo compuesto es una estructura y no admite restricciones
de tabla. Por eso los valores escalares usan dominios y las tablas aplican
funciones `CHECK` para validar la dirección, el contacto y las colecciones.

### 5. ¿Cómo se evita una identificación duplicada entre dos tablas hijas?

Las restricciones `UNIQUE` de PostgreSQL no abarcan automáticamente una
jerarquía. Cada hijo tiene su restricción local y un trigger consulta el padre,
que incluye todas las tablas hijas. Además toma un advisory lock transaccional
por documento y OID para evitar una carrera entre inserciones concurrentes.
