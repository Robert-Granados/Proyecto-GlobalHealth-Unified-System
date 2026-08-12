const database = db.getSiblingDB('globalhealth_telemetry');

print('1) $match, $gt, $lte, $sort y $limit');
printjson(database.logs.find({
  tipo: 'FRECUENCIA_CARDIACA',
  valor: { $gt: 110, $lte: 135 }
}).sort({ registradoEn: -1 }).limit(10).toArray());

print('2) Pipeline de agregación por tipo');
printjson(database.logs.aggregate([
  { $match: { calidad: 'VALIDA' } },
  { $group: {
    _id: '$tipo', total: { $sum: 1 }, promedio: { $avg: '$valor' },
    minimo: { $min: '$valor' }, maximo: { $max: '$valor' }
  } },
  { $sort: { total: -1 } }
]).toArray());

print('3) Paciente → Sesión → Logs mediante dos $lookup');
printjson(database.pacientes.aggregate([
  { $match: { pacienteId: 1 } },
  { $lookup: {
    from: 'sesiones', localField: 'pacienteId', foreignField: 'pacienteId', as: 'sesiones'
  } },
  { $unwind: '$sesiones' },
  { $sort: { 'sesiones.iniciadaEn': -1 } },
  { $limit: 1 },
  { $lookup: {
    from: 'logs', localField: 'sesiones.sesionId', foreignField: 'sesionId', as: 'logs'
  } },
  { $project: { _id: 0, pacienteId: 1, pais: 1, sesion: '$sesiones', logs: { $slice: ['$logs', 10] } } }
]).toArray());
