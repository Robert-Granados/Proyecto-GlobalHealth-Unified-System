# MongoDB Atlas y evaluación de costos

Fecha de referencia: 12 de agosto de 2026. Moneda: USD, sin impuestos ni
transferencia de salida. Los precios de Atlas dependen del proveedor, región,
almacenamiento, respaldos y tráfico; antes de contratar debe guardarse una
captura del [calculador oficial](https://www.mongodb.com/pricing/calculator/).

## Despliegue propuesto

1. Crear un proyecto Atlas y un cluster en la región más cercana a las clínicas.
2. Para demostración usar M10; para mayor memoria usar M20. M10/M20 usan
   rendimiento burstable; M30+ es preferible para tráfico alto de producción.
3. Crear un usuario con `readWrite` solo sobre `globalhealth_telemetry`.
4. Autorizar solamente las IP/CIDR del backend o configurar un private endpoint.
5. Exigir TLS, rotar la contraseña y guardar la URI en el secreto `MONGO_URL`.
6. Ejecutar `nosql/mongodb/01_modelo_y_datos.js` contra Atlas y comprobar
   `/health/mongo`. Nunca versionar la URI real ni sus credenciales.

Atlas factura clusters dedicados por hora y muestra el costo antes de aplicar la
configuración. El almacenamiento predeterminado se incluye en la tarifa; espacio
personalizado, backups y transferencia pueden sumar cargos. Fuente:
[facturación oficial](https://www.mongodb.com/docs/atlas/billing/cluster-configuration-costs/).

## Comparación cuantitativa a 12 y 36 meses

Escenario académico: operación continua, 730 horas/mes, una región,
almacenamiento predeterminado, soporte básico y sin egreso. Las tarifas horarias
son supuestos que deben sustituirse por el calculador al momento de entregar.

| Alternativa | Inicial | Mensual | 12 meses | 36 meses |
|---|---:|---:|---:|---:|
| Atlas M10, supuesto $0,08/h | $0 | $58,40 | $700,80 | $2.102,40 |
| Atlas M20, supuesto $0,20/h | $0 | $146,00 | $1.752,00 | $5.256,00 |
| Self-hosted | $900,00 | $155,00 | $2.760,00 | $6.480,00 |

Fórmulas: `Atlas = tarifa × 730 × meses`; `self-hosted = 900 + 155 × meses`.
El mensual self-hosted supone electricidad/red $45, backup $10 y cuatro horas
de administración a $25/h. No incluye alta disponibilidad.

## Decisión y evidencia

M10 es razonable para demostración y cargas pequeñas; M20 agrega memoria para
crecimiento. Atlas reduce operación y complejidad, mientras self-hosted ofrece
control físico pero exige mantenimiento, monitoreo y recuperación.

Crear el cluster real requiere cuenta Atlas, medio de pago y autorización
externa. La evidencia debe incluir capturas del cluster, región/tier, usuario
ocultando secretos, Network Access, conexión exitosa y `/health/mongo`.
