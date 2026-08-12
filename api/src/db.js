'use strict';

const { Pool } = require('pg');
const sql = require('mssql');
const { MongoClient } = require('mongodb');

function requiredEnvironment(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Falta la variable obligatoria ${name}`);
  }
  return value;
}

const writeConnectionString = requiredEnvironment('DB_WRITE_URL');
const readConnectionString = requiredEnvironment('DB_READ_URL');

if (writeConnectionString === readConnectionString) {
  throw new Error('DB_WRITE_URL y DB_READ_URL no pueden apuntar a la misma conexión');
}

// Dos instancias Pool físicamente independientes. Ninguna función contiene
// fallback del pool de lectura al de escritura ni viceversa.
const writePool = new Pool({
  connectionString: writeConnectionString,
  application_name: 'globalhealth-api-write',
  max: 5,
  connectionTimeoutMillis: 2000,
  idleTimeoutMillis: 30000
});

const readPool = new Pool({
  connectionString: readConnectionString,
  application_name: 'globalhealth-api-read',
  max: 10,
  connectionTimeoutMillis: 2000,
  idleTimeoutMillis: 30000
});

writePool.on('error', (error) => {
  console.error('[writePool] Error de conexión inactiva:', error.message);
});

readPool.on('error', (error) => {
  console.error('[readPool] Error de conexión inactiva:', error.message);
});

async function inspectPool(pool, expectedRole) {
  const result = await pool.query(`
    SELECT
      pg_is_in_recovery() AS en_recuperacion,
      inet_server_addr()::text AS direccion_servidor,
      inet_server_port() AS puerto_servidor,
      current_database() AS base_datos,
      current_setting('application_name') AS aplicacion
  `);

  return {
    role: expectedRole,
    inRecovery: result.rows[0].en_recuperacion,
    serverAddress: result.rows[0].direccion_servidor,
    serverPort: result.rows[0].puerto_servidor,
    database: result.rows[0].base_datos,
    applicationName: result.rows[0].aplicacion
  };
}

async function verifyPhysicalSeparation() {
  const [writer, reader] = await Promise.all([
    inspectPool(writePool, 'WRITE_MASTER'),
    inspectPool(readPool, 'READ_REPLICA')
  ]);

  if (writer.inRecovery !== false) {
    throw new Error('DB_WRITE_URL apunta a un servidor en recuperación; no es el master');
  }

  if (reader.inRecovery !== true) {
    throw new Error('DB_READ_URL no apunta a una réplica hot-standby');
  }

  if (writer.serverAddress === reader.serverAddress) {
    throw new Error('Los pools write/read resolvieron la misma dirección física');
  }

  return { writer, reader, physicallySeparated: true };
}

async function ensureDemoData() {
  await writePool.query(`
    CREATE TABLE IF NOT EXISTS demo_signos_vitales (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      paciente_id bigint NOT NULL,
      frecuencia_cardiaca smallint NOT NULL
        CHECK (frecuencia_cardiaca BETWEEN 20 AND 250),
      registrado_en timestamptz NOT NULL DEFAULT clock_timestamp()
    )
  `);

  const count = await writePool.query(
    'SELECT count(*)::integer AS total FROM demo_signos_vitales'
  );

  if (count.rows[0].total === 0) {
    await writePool.query(`
      INSERT INTO demo_signos_vitales (paciente_id, frecuencia_cardiaca)
      VALUES (1001, 78), (1002, 91), (1003, 66)
    `);
  }
}

async function waitForReplica(maxAttempts = 20) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const result = await readPool.query(
        'SELECT count(*)::integer AS total FROM demo_signos_vitales'
      );
      if (result.rows[0].total >= 3) return;
    } catch (error) {
      if (error.code !== '42P01') throw error;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error('La réplica no recibió demo_signos_vitales dentro del plazo');
}

function queryWrite(text, parameters = []) {
  return writePool.query(text, parameters);
}

function queryRead(text, parameters = []) {
  return readPool.query(text, parameters);
}

// Conexión perezosa a SQL Server (capa XML). No forma parte de la topología
// master/réplica: se crea en la primera petición de expedientes para que la
// API pueda arrancar aunque el motor XML todavía no esté listo. Si el intento
// falla, la promesa se descarta y la siguiente petición reintenta.
let xmlPoolPromise = null;
let mongoClientPromise = null;

function getXmlPool() {
  if (!xmlPoolPromise) {
    const connectionString = process.env.MSSQL_URL;
    if (!connectionString) {
      return Promise.reject(new Error('Falta la variable MSSQL_URL'));
    }
    const pool = new sql.ConnectionPool(connectionString);
    xmlPoolPromise = pool.connect()
      .then(() => pool)
      .catch((error) => {
        xmlPoolPromise = null;
        throw error;
      });
  }
  return xmlPoolPromise;
}

async function queryXml(text, inputs = {}) {
  const pool = await getXmlPool();
  const request = pool.request();
  for (const [name, spec] of Object.entries(inputs)) {
    request.input(name, spec.type, spec.value);
  }
  return request.query(text);
}

function getMongoDatabase() {
  if (!mongoClientPromise) {
    let connectionString = process.env.ATLAS_MONGO_URL || process.env.MONGO_URL;
    if (!connectionString) return Promise.reject(new Error('Falta la variable MONGO_URL'));
    // Atlas entrega normalmente mongodb+srv. Se tolera el esquema mongodb
    // cuando el host termina en mongodb.net para corregir copias incompletas.
    if (connectionString.startsWith('mongodb://') && connectionString.includes('.mongodb.net')) {
      connectionString = connectionString.replace(/^mongodb:\/\//, 'mongodb+srv://');
    }
    const client = new MongoClient(connectionString, { serverSelectionTimeoutMS: 3000 });
    mongoClientPromise = client.connect()
      .then(() => client)
      .catch((error) => {
        mongoClientPromise = null;
        throw error;
      });
  }
  return mongoClientPromise.then((client) => client.db('globalhealth_telemetry'));
}

async function inspectMongo() {
  const database = await getMongoDatabase();
  await database.command({ ping: 1 });
  const [pacientes, sesiones, logs] = await Promise.all([
    database.collection('pacientes').countDocuments(),
    database.collection('sesiones').countDocuments(),
    database.collection('logs').countDocuments()
  ]);
  return {
    provider: process.env.ATLAS_MONGO_URL ? 'MONGODB_ATLAS' : 'MONGODB_LOCAL',
    database: database.databaseName,
    pacientes,
    sesiones,
    logs
  };
}

async function mongoTelemetrySummary() {
  const database = await getMongoDatabase();
  return database.collection('logs').aggregate([
    { $match: { calidad: 'VALIDA' } },
    { $group: {
      _id: '$tipo', total: { $sum: 1 }, promedio: { $avg: '$valor' },
      minimo: { $min: '$valor' }, maximo: { $max: '$valor' }
    } },
    { $sort: { total: -1 } }
  ]).toArray();
}

async function mongoPatientTrace(patientId) {
  const database = await getMongoDatabase();
  const rows = await database.collection('pacientes').aggregate([
    { $match: { pacienteId: patientId } },
    { $lookup: { from: 'sesiones', localField: 'pacienteId', foreignField: 'pacienteId', as: 'sesiones' } },
    { $unwind: '$sesiones' },
    { $sort: { 'sesiones.iniciadaEn': -1 } },
    { $limit: 1 },
    { $lookup: { from: 'logs', localField: 'sesiones.sesionId', foreignField: 'sesionId', as: 'logs' } },
    { $project: { _id: 0, pacienteId: 1, identificacion: 1, pais: 1, sesion: '$sesiones', logs: { $slice: ['$logs', 20] } } }
  ]).toArray();
  return rows[0] || null;
}

async function closePools() {
  const xmlClose = xmlPoolPromise
    ? xmlPoolPromise.then((pool) => pool.close()).catch(() => {})
    : Promise.resolve();
  const mongoClose = mongoClientPromise
    ? mongoClientPromise.then((client) => client.close()).catch(() => {})
    : Promise.resolve();
  await Promise.allSettled([writePool.end(), readPool.end(), xmlClose, mongoClose]);
}

module.exports = {
  closePools,
  ensureDemoData,
  inspectPool,
  inspectMongo,
  mongoPatientTrace,
  mongoTelemetrySummary,
  queryRead,
  queryWrite,
  queryXml,
  readPool,
  sql,
  verifyPhysicalSeparation,
  waitForReplica,
  writePool
};

