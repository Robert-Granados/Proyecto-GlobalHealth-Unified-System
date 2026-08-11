# Entregable 2: XML tipado y validado por SQL Server

La validación no se realiza en el backend. `Documento` está declarado como
`xml(DOCUMENT dbo.ExpedienteClinicoXsd)`, por lo que SQL Server aplica el XSD al
insertar y modificar cada instancia.

## Ejecución con Docker Compose

```powershell
docker compose up -d sqlserver
docker compose run --rm sqlserver-init
```

El segundo comando termina con código `0` solo si pasan los scripts 01 a 06.
Los tres mensajes de XML inválido y el error de `DROP` se consultan así:

```powershell
docker compose exec sqlserver bash -lc `
  '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d GlobalHealthXml -Q "SELECT Categoria,Caso,ErrorNumero,MensajeExacto FROM dbo.PruebaRechazoXML ORDER BY PruebaId"'
```

La validación de referencia se ejecutó en SQL Server 2022 RTM-CU26,
versión `16.0.4265.3`, Developer Edition para Linux.

## Evidencias de la cláusula crítica

- `02_xsd_y_tabla_tipificada.sql` registra el XSD y crea la columna tipada.
- `03_datos_y_rechazos.sql` inserta directamente en esa columna; no usa una
  librería de validación de aplicación.
- Los tres `CATCH` guardan `ERROR_NUMBER()` y `ERROR_MESSAGE()` del motor.
- `04_crud_xml.sql` usa `query`, `value`, `nodes` y las tres formas de `modify`.
- `05_ciclo_vida_xsd.sql` demuestra `ALTER`, el `DROP` rechazado por dependencia
  y el `DROP` exitoso después de retirar la columna, dentro de una transacción
  reversible.

## Cinco preguntas probables

1. **¿Quién valida el XML?** SQL Server, al convertir el valor a la columna XML
   asociada con `ExpedienteClinicoXsd`.
2. **¿Ser XML bien formado es suficiente?** No. Un XML sin firma puede estar
   bien formado y aun así ser rechazado por `minOccurs=1` del XSD.
3. **¿Por qué falla `DROP XML SCHEMA COLLECTION`?** Porque la columna
   `Documento` conserva una dependencia de metadatos con la colección.
4. **¿Qué hace realmente `ALTER`?** Agrega nuevos componentes o namespaces; no
   reescribe de forma destructiva componentes ya importados.
5. **¿Puede `modify()` dejar XML inválido?** No. SQL Server vuelve a comprobar
   el tipo XML y rechaza el estado final si viola la colección registrada.
