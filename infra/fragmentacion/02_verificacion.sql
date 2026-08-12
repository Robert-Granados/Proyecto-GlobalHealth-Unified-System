\pset pager off
SELECT 'HORIZONTAL' AS tipo, nodo, region, count(*) AS filas
FROM distribuido.paciente_horizontal
GROUP BY nodo, region ORDER BY nodo;

SELECT 'VERTICAL' AS tipo, paciente_id, nombre, pais, aseguradora, saldo_pendiente
FROM distribuido.paciente_vertical
ORDER BY paciente_id;

SELECT s.srvname AS servidor, o.option_name, o.option_value
FROM pg_foreign_server s,
LATERAL pg_options_to_table(s.srvoptions) o
ORDER BY s.srvname, o.option_name;
