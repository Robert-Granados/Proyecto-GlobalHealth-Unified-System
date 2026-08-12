/* Ejecutar con: mongosh "$MONGO_URL" --file 01_modelo_y_datos.js */
const database = db.getSiblingDB('globalhealth_telemetry');

database.pacientes.createIndex({ pacienteId: 1 }, { unique: true });
database.sesiones.createIndex({ sesionId: 1 }, { unique: true });
database.sesiones.createIndex({ pacienteId: 1, iniciadaEn: -1 });
database.logs.createIndex({ logId: 1 }, { unique: true });
database.logs.createIndex({ sesionId: 1, registradoEn: -1 });
database.logs.createIndex({ tipo: 1, valor: 1 });

if (database.pacientes.countDocuments({ generadoPor: 'globalhealth-seed-v1' }) === 0) {
  const paises = ['CR', 'GT', 'PA'];
  const pacientes = [];
  for (let i = 1; i <= 1000; i += 1) {
    pacientes.push({
      pacienteId: i,
      identificacion: `GH-${String(i).padStart(6, '0')}`,
      pais: paises[(i - 1) % paises.length],
      fechaNacimiento: new Date(1950 + (i % 55), i % 12, (i % 28) + 1),
      generadoPor: 'globalhealth-seed-v1'
    });
  }
  database.pacientes.insertMany(pacientes, { ordered: false });
}

if (database.sesiones.countDocuments({ generadoPor: 'globalhealth-seed-v1' }) === 0) {
  const sesiones = [];
  for (let i = 1; i <= 5000; i += 1) {
    sesiones.push({
      sesionId: i,
      pacienteId: ((i - 1) % 1000) + 1,
      dispositivo: `MON-${String(((i - 1) % 250) + 1).padStart(4, '0')}`,
      iniciadaEn: new Date(Date.UTC(2026, 0, 1, 0, i % 60, 0) + i * 3600000),
      estado: i % 20 === 0 ? 'CERRADA_CON_ALERTA' : 'CERRADA',
      generadoPor: 'globalhealth-seed-v1'
    });
  }
  database.sesiones.insertMany(sesiones, { ordered: false });
}

if (database.logs.countDocuments({ generadoPor: 'globalhealth-seed-v1' }) === 0) {
  let lote = [];
  for (let i = 1; i <= 50000; i += 1) {
    const sesionId = ((i - 1) % 5000) + 1;
    const selector = i % 3;
    const tipo = selector === 0 ? 'FRECUENCIA_CARDIACA' : (selector === 1 ? 'SPO2' : 'TEMPERATURA');
    const valor = tipo === 'FRECUENCIA_CARDIACA' ? 55 + (i % 80) : (tipo === 'SPO2' ? 88 + (i % 13) : 35 + ((i % 35) / 10));
    lote.push({
      logId: i,
      sesionId,
      tipo,
      valor,
      unidad: tipo === 'FRECUENCIA_CARDIACA' ? 'lpm' : (tipo === 'SPO2' ? '%' : 'C'),
      registradoEn: new Date(Date.UTC(2026, 0, 1) + i * 60000),
      calidad: i % 50 === 0 ? 'REVISAR' : 'VALIDA',
      generadoPor: 'globalhealth-seed-v1'
    });
    if (lote.length === 1000) {
      database.logs.insertMany(lote, { ordered: false });
      lote = [];
    }
  }
  if (lote.length > 0) database.logs.insertMany(lote, { ordered: false });
}

printjson({
  pacientes: database.pacientes.countDocuments({}),
  sesiones: database.sesiones.countDocuments({}),
  logs: database.logs.countDocuments({})
});
