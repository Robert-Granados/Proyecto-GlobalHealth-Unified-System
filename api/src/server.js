'use strict';

const http = require('node:http');
const {
  closePools,
  ensureDemoData,
  inspectPool,
  queryRead,
  queryWrite,
  readPool,
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

function publicError(error, pool) {
  return {
    ok: false,
    pool,
    code: error.code || 'CONNECTION_ERROR',
    message: error.message
  };
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
    try {
      const body = await readJson(request);
      const patientId = Number.parseInt(body.pacienteId, 10);
      const heartRate = Number.parseInt(body.frecuenciaCardiaca, 10);

      if (!Number.isInteger(patientId) || !Number.isInteger(heartRate)) {
        return sendJson(response, 400, {
          ok: false,
          message: 'pacienteId y frecuenciaCardiaca deben ser enteros'
        });
      }

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
      return sendJson(response, 503, publicError(error, 'WRITE_MASTER'));
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

