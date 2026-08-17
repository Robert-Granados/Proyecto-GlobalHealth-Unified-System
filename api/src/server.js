'use strict';

const http = require('node:http');
const {
  closePools,
  ensureDemoData,
  inspectPool,
  inspectMongo,
  mongoCreateTelemetry,
  mongoDeleteTelemetry,
  mongoTelemetryList,
  mongoPatientTrace,
  mongoTelemetrySummary,
  mongoUpdateTelemetry,
  queryDistributed,
  queryRead,
  queryWrite,
  queryXml,
  readPool,
  sql,
  verifyPhysicalSeparation,
  waitForReplica,
  writePool
} = require('./db');

const port = Number.parseInt(process.env.PORT || '8080', 10);

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 64 * 1024) throw new Error('Cuerpo JSON demasiado grande');
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function parseTelemetryPayload(body) {
  const sesionId = Number.parseInt(body.sesionId, 10);
  const tipo = String(body.tipo || '').trim().toUpperCase();
  const valor = Number(body.valor);
  const calidad = String(body.calidad || '').trim().toUpperCase();
  const registradoEn = body.registradoEn ? new Date(body.registradoEn) : new Date();
  const rules = {
    FRECUENCIA_CARDIACA: { min: 20, max: 250, unidad: 'lpm' },
    SPO2: { min: 0, max: 100, unidad: '%' },
    TEMPERATURA: { min: 25, max: 50, unidad: 'C' }
  };
  const rule = rules[tipo];
  const errors = [];
  if (!Number.isInteger(sesionId) || sesionId < 1) errors.push('sesionId');
  if (!rule) errors.push('tipo');
  if (!Number.isFinite(valor) || (rule && (valor < rule.min || valor > rule.max))) errors.push('valor');
  if (!['VALIDA', 'REVISAR'].includes(calidad)) errors.push('calidad');
  if (Number.isNaN(registradoEn.getTime())) errors.push('registradoEn');
  if (errors.length) {
    const error = new Error(`Campos de telemetria invalidos: ${errors.join(', ')}`);
    error.code = 'VALIDATION_ERROR';
    throw error;
  }
  return { sesionId, tipo, valor, unidad: rule.unidad, calidad, registradoEn };
}

function publicError(error, pool) {
  return {
    ok: false,
    pool,
    code: error.code || 'CONNECTION_ERROR',
    message: error.message
  };
}

async function readDistributedNode(node, table, columns) {
  try {
    const result = await queryDistributed(
      `SELECT ${columns} FROM distribuido.${table} ORDER BY paciente_id`
    );
    return { node, ok: true, rows: result.rows };
  } catch (error) {
    return {
      node,
      ok: false,
      rows: [],
      error: { code: error.code || 'CONNECTION_ERROR', message: error.message }
    };
  }
}

function distributedResponse(response, parts, rows, reconstruction) {
  const nodes = Object.fromEntries(parts.map((part) => [part.node, {
    ok: part.ok,
    rowCount: part.rows.length,
    ...(part.error ? { error: part.error } : {})
  }]));
  const available = parts.filter((part) => part.ok).length;
  const complete = available === parts.length;
  return sendJson(response, complete ? 200 : 207, {
    ok: complete,
    partial: !complete && available > 0,
    pool: 'DISTRIBUTED_READ',
    coordinator: 'postgres-coordinador',
    reconstruction,
    nodes,
    rows
  });
}

async function handler(request, response) {
  const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);

  if (request.method === 'GET' && url.pathname === '/') {
    return sendJson(response, 200, {
      service: 'GlobalHealth API',
      writePool: 'DB_WRITE_URL -> postgres-master',
      readPool: 'DB_READ_URL -> postgres-replica',
      fallback: false
    });
  }

  if (request.method === 'GET' && url.pathname === '/health') {
    try {
      const topology = await verifyPhysicalSeparation();
      return sendJson(response, 200, { ok: true, ...topology });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'WRITE_AND_READ'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/health/read') {
    try {
      const reader = await inspectPool(readPool, 'READ_REPLICA');
      if (!reader.inRecovery) throw new Error('El pool de lectura no está en recuperación');
      return sendJson(response, 200, { ok: true, reader });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'READ_REPLICA'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/health/mongo') {
    try {
      return sendJson(response, 200, { ok: true, mongo: await inspectMongo() });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'MONGODB_TELEMETRY'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/api/telemetria/resumen') {
    try {
      return sendJson(response, 200, {
        ok: true, motor: 'MONGODB', rows: await mongoTelemetrySummary()
      });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'MONGODB_TELEMETRY'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/health/distributed') {
    const parts = await Promise.all([
      readDistributedNode('norte', 'paciente_norte', 'paciente_id'),
      readDistributedNode('sur', 'paciente_sur', 'paciente_id')
    ]);
    return distributedResponse(response, parts, [], 'HEALTH_CHECK');
  }

  if (request.method === 'GET' && url.pathname === '/api/pacientes-distribuidos/horizontal') {
    const parts = await Promise.all([
      readDistributedNode(
        'norte', 'paciente_norte',
        "paciente_id, identificacion, nombre, region, 'postgres-norte'::text AS nodo"
      ),
      readDistributedNode(
        'sur', 'paciente_sur',
        "paciente_id, identificacion, nombre, region, 'postgres-sur'::text AS nodo"
      )
    ]);
    const rows = parts.flatMap((part) => part.rows)
      .sort((a, b) => Number(a.paciente_id) - Number(b.paciente_id));
    return distributedResponse(response, parts, rows, 'UNION ALL por región');
  }

  if (request.method === 'GET' && url.pathname === '/api/pacientes-distribuidos/vertical') {
    const parts = await Promise.all([
      readDistributedNode(
        'norte', 'paciente_publico',
        'paciente_id, nombre, pais, fecha_nacimiento'
      ),
      readDistributedNode(
        'sur', 'paciente_financiero',
        'paciente_id, aseguradora, numero_poliza, saldo_pendiente'
      )
    ]);
    let rows = [];
    if (parts.every((part) => part.ok)) {
      const financialByPatient = new Map(
        parts[1].rows.map((row) => [String(row.paciente_id), row])
      );
      rows = parts[0].rows.flatMap((publicRow) => {
        const financial = financialByPatient.get(String(publicRow.paciente_id));
        return financial ? [{ ...publicRow, ...financial }] : [];
      });
    }
    return distributedResponse(response, parts, rows, 'JOIN por paciente_id');
  }

  if (request.method === 'GET' && url.pathname === '/api/telemetria') {
    const page = Number.parseInt(url.searchParams.get('page') || '1', 10);
    const limit = Number.parseInt(url.searchParams.get('limit') || '20', 10);
    const patientText = url.searchParams.get('pacienteId');
    const patientId = patientText ? Number.parseInt(patientText, 10) : undefined;
    const type = url.searchParams.get('tipo') || undefined;
    const quality = url.searchParams.get('calidad') || undefined;
    const validTypes = ['FRECUENCIA_CARDIACA', 'SPO2', 'TEMPERATURA'];
    const validQualities = ['VALIDA', 'REVISAR'];

    if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1 || limit > 100 ||
        (patientText && (!Number.isInteger(patientId) || patientId < 1)) ||
        (type && !validTypes.includes(type)) || (quality && !validQualities.includes(quality))) {
      return sendJson(response, 400, { ok: false, message: 'Filtros de telemetria invalidos' });
    }

    try {
      const result = await mongoTelemetryList({ page, limit, patientId, type, quality });
      return sendJson(response, 200, { ok: true, motor: 'MONGODB_ATLAS', ...result });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'MONGODB_TELEMETRY'));
    }
  }

  if (request.method === 'POST' && url.pathname === '/api/telemetria') {
    try {
      const data = parseTelemetryPayload(await readJson(request));
      const row = await mongoCreateTelemetry(data);
      return sendJson(response, 201, { ok: true, motor: 'MONGODB_ATLAS', row });
    } catch (error) {
      const status = error.code === 'VALIDATION_ERROR' ? 400
        : (error.code === 'SESSION_NOT_FOUND' ? 404 : (error.code === 11000 ? 409 : 503));
      return sendJson(response, status, publicError(error, 'MONGODB_ATLAS'));
    }
  }

  const telemetryLogMatch = url.pathname.match(/^\/api\/telemetria\/(\d+)$/);
  if (telemetryLogMatch && request.method === 'PUT') {
    const logId = Number.parseInt(telemetryLogMatch[1], 10);
    try {
      const data = parseTelemetryPayload(await readJson(request));
      const row = await mongoUpdateTelemetry(logId, data);
      return row
        ? sendJson(response, 200, { ok: true, motor: 'MONGODB_ATLAS', row })
        : sendJson(response, 404, { ok: false, message: `Log ${logId} no encontrado` });
    } catch (error) {
      const status = error.code === 'VALIDATION_ERROR' ? 400
        : (error.code === 'SESSION_NOT_FOUND' ? 404 : 503);
      return sendJson(response, status, publicError(error, 'MONGODB_ATLAS'));
    }
  }

  if (telemetryLogMatch && request.method === 'DELETE') {
    const logId = Number.parseInt(telemetryLogMatch[1], 10);
    try {
      const row = await mongoDeleteTelemetry(logId);
      return row
        ? sendJson(response, 200, { ok: true, motor: 'MONGODB_ATLAS', row })
        : sendJson(response, 404, { ok: false, message: `Log ${logId} no encontrado` });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'MONGODB_ATLAS'));
    }
  }

  if (request.method === 'GET' && url.pathname.startsWith('/api/telemetria/paciente/')) {
    const patientId = Number.parseInt(url.pathname.split('/').pop(), 10);
    if (!Number.isInteger(patientId) || patientId < 1) {
      return sendJson(response, 400, { ok: false, message: 'pacienteId debe ser un entero positivo' });
    }
    try {
      const row = await mongoPatientTrace(patientId);
      return row
        ? sendJson(response, 200, { ok: true, motor: 'MONGODB_LOOKUP', row })
        : sendJson(response, 404, { ok: false, message: 'Paciente no encontrado' });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'MONGODB_TELEMETRY'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/api/dashboard/signos-vitales') {
    try {
      const result = await queryRead(`
        SELECT id, paciente_id, frecuencia_cardiaca, registrado_en
        FROM demo_signos_vitales
        ORDER BY registrado_en DESC, id DESC
        LIMIT 20
      `);
      return sendJson(response, 200, {
        ok: true,
        pool: 'READ_REPLICA',
        rows: result.rows
      });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'READ_REPLICA'));
    }
  }

  if (request.method === 'POST' && url.pathname === '/api/signos-vitales') {
    let body;
    try {
      body = await readJson(request);
    } catch {
      return sendJson(response, 400, { ok: false, message: 'JSON inválido' });
    }

    const patientId = Number.parseInt(body.pacienteId, 10);
    const heartRate = Number.parseInt(body.frecuenciaCardiaca, 10);

    if (!Number.isInteger(patientId) || !Number.isInteger(heartRate)) {
      return sendJson(response, 400, {
        ok: false,
        message: 'pacienteId y frecuenciaCardiaca deben ser enteros'
      });
    }

    try {
      const result = await queryWrite(`
        INSERT INTO demo_signos_vitales (paciente_id, frecuencia_cardiaca)
        VALUES ($1, $2)
        RETURNING id, paciente_id, frecuencia_cardiaca, registrado_en
      `, [patientId, heartRate]);

      return sendJson(response, 201, {
        ok: true,
        pool: 'WRITE_MASTER',
        row: result.rows[0]
      });
    } catch (error) {
      const status = error.code === '23514' ? 400 : (error.code === '23505' ? 409 : 503);
      return sendJson(response, status, publicError(error, 'WRITE_MASTER'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/api/medicos') {
    try {
      const result = await queryRead(`
        SELECT
          m.objeto_oid::text AS objeto_oid,
          m.identificacion,
          gh_obj.nombre_completo(m) AS nombre_completo,
          m.numero_colegiado,
          m.pais_colegiatura::text AS pais,
          COALESCE(c.nombre, 'Sin clínica asignada') AS clinica,
          (
            SELECT string_agg(e.nombre, ', ' ORDER BY e.nombre)
            FROM unnest(m.especialidades) AS e
          ) AS especialidades
        FROM gh_obj.medico_t AS m
        LEFT JOIN gh_obj.clinica AS c ON c.objeto_oid = m.clinica_ref
        ORDER BY m.primer_apellido, m.nombres
      `);
      return sendJson(response, 200, { ok: true, pool: 'READ_REPLICA', rows: result.rows });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'READ_REPLICA'));
    }
  }

  if (request.method === 'POST' && url.pathname === '/api/medicos') {
    let body;
    try {
      body = await readJson(request);
    } catch {
      return sendJson(response, 400, { ok: false, message: 'JSON inválido' });
    }

    const campos = {
      identificacion: String(body.identificacion || '').trim(),
      nombres: String(body.nombres || '').trim(),
      primerApellido: String(body.primerApellido || '').trim(),
      segundoApellido: String(body.segundoApellido || '').trim() || null,
      fechaNacimiento: String(body.fechaNacimiento || '').trim(),
      pais: String(body.pais || '').trim().toUpperCase(),
      correo: String(body.correo || '').trim(),
      telefono: String(body.telefono || '').replace(/[^0-9]/g, ''),
      numeroColegiado: String(body.numeroColegiado || '').trim(),
      especialidad: String(body.especialidad || '').trim()
    };

    const REGIONES = {
      CR: { moneda: 'CRC', prefijoTel: '+506', provincia: 'San José', canton: 'San José', distrito: 'Carmen' },
      GT: { moneda: 'GTQ', prefijoTel: '+502', provincia: 'Guatemala', canton: 'Guatemala', distrito: 'Zona 1' },
      PA: { moneda: 'USD', prefijoTel: '+507', provincia: 'Panamá', canton: 'Panamá', distrito: 'San Felipe' }
    };
    const region = REGIONES[campos.pais];

    const errores = [];
    if (!/^[A-Za-z0-9-]{5,32}$/.test(campos.identificacion)) errores.push('identificacion (5-32, letras/números/guiones)');
    if (!campos.nombres) errores.push('nombres');
    if (!campos.primerApellido) errores.push('primerApellido');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(campos.fechaNacimiento)) errores.push('fechaNacimiento (AAAA-MM-DD)');
    if (!region) errores.push('pais (CR, GT o PA)');
    if (!campos.correo.includes('@')) errores.push('correo');
    if (!/^\d{7,8}$/.test(campos.telefono)) errores.push('telefono (7-8 dígitos)');
    if (!/^[A-Za-z0-9-]{4,32}$/.test(campos.numeroColegiado)) errores.push('numeroColegiado (4-32)');
    if (!campos.especialidad) errores.push('especialidad');
    if (errores.length > 0) {
      return sendJson(response, 400, { ok: false, message: `Campos inválidos: ${errores.join(', ')}` });
    }

    const codigoEspecialidad =
      (campos.especialidad.normalize('NFD').replace(/[^A-Za-z]/g, '').slice(0, 3) || 'GEN').toUpperCase();

    try {
      const result = await queryWrite(`
        INSERT INTO gh_obj.medico_t (
          identificacion, nombres, primer_apellido, segundo_apellido,
          fecha_nacimiento, fecha_contratacion,
          direccion, contacto, clinica_ref,
          salario_mensual, moneda,
          numero_colegiado, pais_colegiatura, fecha_vencimiento_licencia,
          especialidades, tipo_jornada, firma_digital_id
        )
        VALUES (
          $1, $2, $3, $4,
          $5::date, CURRENT_DATE,
          ROW($6, $7, $8, $9, $10, NULL)::gh_tipo.direccion_t,
          ROW(
            $11,
            ARRAY[ROW('MOVIL', $12, $13, NULL, true)::gh_tipo.telefono_t]::gh_tipo.telefono_t[],
            $14, $15
          )::gh_tipo.contacto_t,
          (SELECT objeto_oid FROM gh_obj.clinica WHERE pais = $6 ORDER BY nombre LIMIT 1),
          0, $16,
          $17, $6, CURRENT_DATE + INTERVAL '2 years',
          ARRAY[ROW($18, $19, $20, CURRENT_DATE, true)::gh_tipo.especialidad_t]::gh_tipo.especialidad_t[],
          'COMPLETA', gen_random_uuid()
        )
        RETURNING objeto_oid::text AS objeto_oid, identificacion, numero_colegiado
      `, [
        campos.identificacion, campos.nombres, campos.primerApellido, campos.segundoApellido,
        campos.fechaNacimiento,
        campos.pais, region.provincia, region.canton, region.distrito,
        'Dirección registrada desde el panel web',
        campos.correo, region.prefijoTel, campos.telefono,
        'Por registrar', 'Familiar',
        region.moneda,
        campos.numeroColegiado,
        codigoEspecialidad, campos.especialidad, 'Registro desde panel web'
      ]);

      return sendJson(response, 201, { ok: true, pool: 'WRITE_MASTER', row: result.rows[0] });
    } catch (error) {
      const status = error.code === '23505' ? 409 : (error.code === '23514' ? 400 : 503);
      return sendJson(response, status, {
        ok: false,
        pool: 'WRITE_MASTER',
        code: error.code || 'CONNECTION_ERROR',
        constraint: error.constraint,
        message: error.message
      });
    }
  }

  if (request.method === 'DELETE' && url.pathname.startsWith('/api/medicos/')) {
    const oid = url.pathname.split('/').pop();
    if (!/^[0-9a-fA-F-]{36}$/.test(oid)) {
      return sendJson(response, 400, { ok: false, message: 'OID inválido (debe ser UUID)' });
    }

    try {
      const result = await queryWrite(`
        DELETE FROM gh_obj.medico_t
        WHERE objeto_oid = $1::uuid
        RETURNING objeto_oid::text AS objeto_oid, identificacion, numero_colegiado
      `, [oid]);

      if (result.rowCount === 0) {
        return sendJson(response, 404, { ok: false, message: 'Médico no encontrado' });
      }

      return sendJson(response, 200, {
        ok: true,
        pool: 'WRITE_MASTER',
        message: 'Médico eliminado correctamente en master',
        row: result.rows[0]
      });
    } catch (error) {
      return sendJson(response, 503, publicError(error, 'WRITE_MASTER'));
    }
  }

  if (request.method === 'GET' && url.pathname === '/api/expedientes') {
    try {
      const result = await queryXml(`
        SELECT TOP 20
          ExpedienteId AS id,
          Codigo AS codigo,
          CONVERT(nvarchar(max), Documento) AS xml,
          CONVERT(char(19), CreadoEn, 126) AS creado_en
        FROM dbo.ExpedienteClinico
        ORDER BY ExpedienteId DESC
      `);
      return sendJson(response, 200, { ok: true, motor: 'SQL_SERVER_XML', rows: result.recordset });
    } catch (error) {
      return sendJson(response, 503, {
        ok: false,
        motor: 'SQL_SERVER_XML',
        message: `${error.message} ¿Ejecutaste "docker compose run --rm sqlserver-init"?`
      });
    }
  }

  if (request.method === 'GET' && /^\/api\/expedientes\/\d+\/xml$/.test(url.pathname)) {
    const expId = Number.parseInt(url.pathname.split('/')[3], 10);
    try {
      const result = await queryXml(`
        SELECT Codigo, CONVERT(nvarchar(max), Documento) AS DocumentoXml
        FROM dbo.ExpedienteClinico
        WHERE ExpedienteId = @id
      `, {
        id: { type: sql.Int, value: expId }
      });
      if (!result.recordset || result.recordset.length === 0) {
        return sendJson(response, 404, { ok: false, message: 'Expediente no encontrado' });
      }
      const { Codigo, DocumentoXml } = result.recordset[0];
      response.writeHead(200, {
        'content-type': 'application/xml; charset=utf-8',
        'content-disposition': `attachment; filename="${Codigo}.xml"`
      });
      return response.end(DocumentoXml);
    } catch (error) {
      return sendJson(response, 503, { ok: false, message: error.message });
    }
  }

  if (request.method === 'GET' && /^\/api\/expedientes\/\d+$/.test(url.pathname)) {
    const expId = Number.parseInt(url.pathname.split('/')[3], 10);
    try {
      const result = await queryXml(`
        SELECT
          ExpedienteId AS id,
          Codigo AS codigo,
          CONVERT(nvarchar(max), Documento) AS xml,
          CONVERT(char(19), CreadoEn, 126) AS creado_en
        FROM dbo.ExpedienteClinico
        WHERE ExpedienteId = @id
      `, {
        id: { type: sql.Int, value: expId }
      });
      if (!result.recordset || result.recordset.length === 0) {
        return sendJson(response, 404, { ok: false, message: 'Expediente no encontrado' });
      }
      return sendJson(response, 200, { ok: true, motor: 'SQL_SERVER_XML', row: result.recordset[0] });
    } catch (error) {
      return sendJson(response, 503, { ok: false, message: error.message });
    }
  }

  if (request.method === 'POST' && url.pathname === '/api/expedientes') {
    let body;
    try {
      body = await readJson(request);
    } catch {
      return sendJson(response, 400, { ok: false, message: 'JSON inválido' });
    }

    const codigo = String(body.codigo || '').trim();
    const documento = String(body.xml || '');
    if (!codigo || !documento.trim()) {
      return sendJson(response, 400, { ok: false, message: 'codigo y xml son obligatorios' });
    }

    try {
      // La columna Documento es xml(DOCUMENT dbo.ExpedienteClinicoXsd): el motor
      // valida el XSD en este INSERT. La API no valida nada por su cuenta.
      const result = await queryXml(`
        INSERT INTO dbo.ExpedienteClinico (Codigo, Documento)
        OUTPUT INSERTED.ExpedienteId, INSERTED.Codigo
        VALUES (@codigo, @documento)
      `, {
        codigo: { type: sql.VarChar(20), value: codigo },
        documento: { type: sql.NVarChar(sql.MAX), value: documento }
      });

      return sendJson(response, 201, {
        ok: true,
        motor: 'SQL_SERVER_XML',
        row: result.recordset[0]
      });
    } catch (error) {
      // El número y mensaje provienen del motor (p. ej. 6908/6926): son la
      // evidencia de que la validación ocurrió dentro de SQL Server.
      return sendJson(response, 422, {
        ok: false,
        motor: 'SQL_SERVER_XML',
        errorNumero: error.number || null,
        mensajeExacto: error.message
      });
    }
  }

  return sendJson(response, 404, { ok: false, message: 'Ruta no encontrada' });
}

async function start() {
  const topology = await verifyPhysicalSeparation();
  console.log('[startup] Pools verificados:', JSON.stringify(topology));

  await ensureDemoData();
  await waitForReplica();

  const server = http.createServer((request, response) => {
    handler(request, response).catch((error) => {
      console.error('[http] Error no controlado:', error);
      if (!response.headersSent) sendJson(response, 500, publicError(error, 'UNKNOWN'));
      else response.end();
    });
  });

  server.listen(port, '0.0.0.0', () => {
    console.log(`[startup] API escuchando en 0.0.0.0:${port}`);
  });

  async function shutdown(signal) {
    console.log(`[shutdown] ${signal}`);
    server.close(async () => {
      await closePools();
      process.exit(0);
    });
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

start().catch(async (error) => {
  console.error('[startup] No se pudo verificar la separación física:', error);
  await closePools();
  process.exit(1);
});

