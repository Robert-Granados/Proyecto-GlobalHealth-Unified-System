'use strict';

/* API base es relativa: nginx sirve /api y /health como reverse proxy.
 * En desarrollo fuera de contenedor se puede sobreescribir con ?api=http://localhost:8080
 */
const params = new URLSearchParams(location.search);
const API_BASE = params.get('api') || '';

const els = {
  vitalsBody: document.getElementById('vitals-body'),
  vitalsForm: document.getElementById('vitals-form'),
  registerMessage: document.getElementById('register-message'),
  topologyMessage: document.getElementById('topology-message'),
  physicallySeparatedBadge: document.getElementById('physically-separated-badge'),
  vitalsPoolTag: document.getElementById('vitals-pool-tag'),
  writerDl: document.getElementById('writer-dl'),
  readerDl: document.getElementById('reader-dl'),
  toast: document.getElementById('toast'),
  btnRefresh: document.getElementById('btn-refresh'),
  btnHealth: document.getElementById('btn-health'),
  btnSubmit: document.getElementById('btn-submit'),
  lastUpdated: document.getElementById('last-updated'),
  medicoForm: document.getElementById('medico-form'),
  medicoMessage: document.getElementById('medico-message'),
  medicosBody: document.getElementById('medicos-body'),
  medicosPoolTag: document.getElementById('medicos-pool-tag'),
  btnMedico: document.getElementById('btn-medico'),
  expForm: document.getElementById('exp-form'),
  expCodigo: document.getElementById('exp-codigo'),
  expXml: document.getElementById('exp-xml'),
  expResult: document.getElementById('exp-result'),
  expBody: document.getElementById('exp-body'),
  btnExp: document.getElementById('btn-exp'),
  xmlModal: document.getElementById('xml-modal'),
  xmlModalTitle: document.getElementById('xml-modal-title'),
  xmlModalCode: document.getElementById('xml-modal-code'),
  xmlModalClose: document.getElementById('xml-modal-close'),
  xmlModalCopy: document.getElementById('xml-modal-copy'),
  xmlModalDownload: document.getElementById('xml-modal-download'),
  mongoProviderBadge: document.getElementById('mongo-provider-badge'),
  mongoStatus: document.getElementById('mongo-status'),
  telemetrySummary: document.getElementById('telemetry-summary'),
  telemetryFilterForm: document.getElementById('telemetry-filter-form'),
  telemetryPatientId: document.getElementById('telemetry-patient-id'),
  telemetryType: document.getElementById('telemetry-type'),
  telemetryQuality: document.getElementById('telemetry-quality'),
  telemetryBody: document.getElementById('telemetry-body'),
  telemetryPageInfo: document.getElementById('telemetry-page-info'),
  telemetryPrev: document.getElementById('telemetry-prev'),
  telemetryNext: document.getElementById('telemetry-next'),
  btnTelemetryFilter: document.getElementById('btn-telemetry-filter'),
  btnTelemetryNew: document.getElementById('btn-telemetry-new'),
  telemetryModal: document.getElementById('telemetry-modal'),
  telemetryModalTitle: document.getElementById('telemetry-modal-title'),
  telemetryModalClose: document.getElementById('telemetry-modal-close'),
  telemetryModalCancel: document.getElementById('telemetry-modal-cancel'),
  telemetryForm: document.getElementById('telemetry-form'),
  telemetryLogId: document.getElementById('telemetry-log-id'),
  telemetrySessionId: document.getElementById('telemetry-session-id'),
  telemetryEditType: document.getElementById('telemetry-edit-type'),
  telemetryValue: document.getElementById('telemetry-value'),
  telemetryEditQuality: document.getElementById('telemetry-edit-quality'),
  telemetryRecordedAt: document.getElementById('telemetry-recorded-at'),
  telemetryFormMessage: document.getElementById('telemetry-form-message'),
  btnTelemetrySave: document.getElementById('btn-telemetry-save'),
  distributedBadge: document.getElementById('distributed-badge'),
  distributedMessage: document.getElementById('distributed-message'),
  nodeNorthBadge: document.getElementById('node-north-badge'),
  nodeSouthBadge: document.getElementById('node-south-badge'),
  nodeNorthDot: document.getElementById('node-north-dot'),
  nodeSouthDot: document.getElementById('node-south-dot'),
  distributedHorizontalBody: document.getElementById('distributed-horizontal-body'),
  distributedVerticalBody: document.getElementById('distributed-vertical-body')
};

function showToast(message, kind = 'info') {
  els.toast.textContent = message;
  els.toast.dataset.kind = kind;
  els.toast.classList.add('visible');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => els.toast.classList.remove('visible'), 3500);
}

async function apiFetch(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'content-type': 'application/json' },
    ...options
  });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : {}; }
  catch { json = { ok: false, raw: text }; }
  return { status: res.status, body: json };
}

function fillDl(dl, obj) {
  for (const dd of dl.querySelectorAll('dd[data-key]')) {
    const key = dd.dataset.key;
    let value = obj?.[key];
    if (typeof value === 'boolean') value = value ? 'sí' : 'no';
    if (value === undefined || value === null || value === '') value = '—';
    dd.textContent = value;
  }
}

function setBadge(el, ok, okText = 'OK', failText = 'ERROR') {
  el.classList.remove('badge-good', 'badge-bad', 'badge-neutral', 'badge-info');
  if (ok === null) el.classList.add('badge-neutral');
  else el.classList.add(ok ? 'badge-good' : 'badge-bad');
  el.textContent = ok === null ? '--' : (ok ? okText : failText);
}

async function loadHealth() {
  const { status, body } = await apiFetch('/health');
  if (status !== 200 || !body.ok) {
    setBadge(els.physicallySeparatedBadge, false);
    els.physicallySeparatedBadge.textContent = 'NO';
    els.topologyMessage.textContent =
      `Error verificando pools (HTTP ${status}): ${body?.message || body?.code || 'desconocido'}`;
    fillDl(els.writerDl, {});
    fillDl(els.readerDl, {});
    return;
  }
  fillDl(els.writerDl, body.writer);
  fillDl(els.readerDl, body.reader);
  setBadge(els.physicallySeparatedBadge, body.physicallySeparated === true, 'SEPARADOS', 'NO');
  els.topologyMessage.textContent =
    `writer.inRecovery=${body.writer.inRecovery} · reader.inRecovery=${body.reader.inRecovery}`;
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return escapeHtml(iso);
  return d.toLocaleString('es-ES', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  });
}

function fcChip(fc) {
  const n = Number(fc);
  let cls = 'fc-ok';
  if (Number.isFinite(n)) {
    if (n < 60) cls = 'fc-low';
    else if (n > 100) cls = 'fc-high';
  }
  return `<span class="fc-chip ${cls}">${escapeHtml(fc)}<small>lpm</small></span>`;
}

function renderVitals(rows) {
  if (!rows || rows.length === 0) {
    els.vitalsBody.innerHTML =
      '<tr class="empty-row"><td colspan="4">Sin registros.</td></tr>';
    return;
  }
  els.vitalsBody.innerHTML = rows.map((r) => `
    <tr>
      <td>${escapeHtml(r.id)}</td>
      <td>${escapeHtml(r.paciente_id)}</td>
      <td>${fcChip(r.frecuencia_cardiaca)}</td>
      <td>${fmtDate(r.registrado_en)}</td>
    </tr>`).join('');
}

async function loadVitals() {
  els.vitalsPoolTag.textContent = 'cargando…';
  const { status, body } = await apiFetch('/api/dashboard/signos-vitales');
  if (status === 200 && body.ok) {
    renderVitals(body.rows);
    els.vitalsPoolTag.textContent = 'READ_REPLICA';
    els.vitalsPoolTag.classList.remove('badge-bad');
    els.vitalsPoolTag.classList.add('badge-info');
  } else {
    els.vitalsPoolTag.textContent = 'ERROR';
    els.vitalsPoolTag.classList.remove('badge-info');
    els.vitalsPoolTag.classList.add('badge-bad');
    els.vitalsBody.innerHTML =
      `<tr class="empty-row"><td colspan="4">No se pudo leer (HTTP ${status}): ${escapeHtml(body?.message || '')}</td></tr>`;
  }
}

/* ---------------- Pacientes distribuidos (postgres_fdw) ---------------- */

function updateDistributedNode(name, state) {
  const badge = name === 'norte' ? els.nodeNorthBadge : els.nodeSouthBadge;
  const dot = name === 'norte' ? els.nodeNorthDot : els.nodeSouthDot;
  setBadge(badge, state?.ok === true, 'EN LÍNEA', 'CAÍDO');
  dot.classList.toggle('dot-on', state?.ok === true);
  dot.classList.toggle('dot-off', state?.ok !== true);
}

function distributedFailures(nodes) {
  return Object.entries(nodes || {})
    .filter(([, state]) => !state.ok)
    .map(([name, state]) => `${name}: ${state.error?.message || 'sin conexión'}`);
}

async function loadDistributedPatients() {
  const [horizontal, vertical] = await Promise.all([
    apiFetch('/api/pacientes-distribuidos/horizontal'),
    apiFetch('/api/pacientes-distribuidos/vertical')
  ]);
  const h = horizontal.body || {};
  const v = vertical.body || {};
  const nodes = h.nodes || v.nodes || {};
  updateDistributedNode('norte', nodes.norte);
  updateDistributedNode('sur', nodes.sur);

  const complete = horizontal.status === 200 && vertical.status === 200 && h.ok && v.ok;
  const partial = horizontal.status === 207 || vertical.status === 207;
  setBadge(els.distributedBadge, complete, 'COMPLETO', partial ? 'DEGRADADO' : 'ERROR');

  const failures = [...new Set([
    ...distributedFailures(h.nodes), ...distributedFailures(v.nodes)
  ])];
  els.distributedMessage.textContent = complete
    ? 'Coordinador disponible · reconstrucción horizontal y vertical completa.'
    : `Reconstrucción ${partial ? 'parcial' : 'fallida'} · ${failures.join(' · ') || 'coordinador no disponible'}`;

  els.distributedHorizontalBody.innerHTML = h.rows?.length
    ? h.rows.map((row) => `<tr>
        <td>${escapeHtml(row.paciente_id)}</td>
        <td>${escapeHtml(row.identificacion)}</td>
        <td><strong>${escapeHtml(row.nombre)}</strong></td>
        <td>${escapeHtml(row.region)}</td>
        <td><code>${escapeHtml(row.nodo)}</code></td>
      </tr>`).join('')
    : `<tr class="empty-row"><td colspan="5">${escapeHtml(failures[0] || 'Sin pacientes disponibles.')}</td></tr>`;

  els.distributedVerticalBody.innerHTML = v.rows?.length
    ? v.rows.map((row) => `<tr>
        <td>${escapeHtml(row.paciente_id)}</td>
        <td><strong>${escapeHtml(row.nombre)}</strong></td>
        <td>${escapeHtml(row.pais)}</td>
        <td>${escapeHtml(row.aseguradora)}</td>
        <td>${Number(row.saldo_pendiente).toLocaleString('es-CR', { minimumFractionDigits: 2 })}</td>
      </tr>`).join('')
    : `<tr class="empty-row"><td colspan="5">${escapeHtml(
        partial ? 'No se puede ejecutar el JOIN: falta uno de los fragmentos.' : (failures[0] || 'Sin datos.')
      )}</td></tr>`;
}

function formatMetric(value, digits = 1) {
  const number = Number(value);
  return Number.isFinite(number)
    ? number.toLocaleString('es-ES', { maximumFractionDigits: digits })
    : '--';
}

const telemetryState = { page: 1, pages: 1 };

async function loadTelemetry() {
  els.mongoProviderBadge.textContent = 'CARGANDO';
  els.mongoProviderBadge.className = 'badge badge-neutral';

  const [healthResult, summaryResult] = await Promise.all([
    apiFetch('/health/mongo'),
    apiFetch('/api/telemetria/resumen')
  ]);

  if (healthResult.status !== 200 || !healthResult.body.ok) {
    els.mongoProviderBadge.textContent = 'ERROR';
    els.mongoProviderBadge.className = 'badge badge-bad';
    els.mongoStatus.classList.add('error');
    fillDl(els.mongoStatus, {
      provider: healthResult.body?.message || `HTTP ${healthResult.status}`
    });
  } else {
    const mongo = healthResult.body.mongo;
    els.mongoProviderBadge.textContent = mongo.provider;
    els.mongoProviderBadge.className = 'badge badge-good';
    els.mongoStatus.classList.remove('error');
    fillDl(els.mongoStatus, {
      ...mongo,
      pacientes: formatMetric(mongo.pacientes, 0),
      sesiones: formatMetric(mongo.sesiones, 0),
      logs: formatMetric(mongo.logs, 0)
    });
  }

  if (summaryResult.status !== 200 || !summaryResult.body.ok) {
    els.telemetrySummary.innerHTML =
      `<div class="telemetry-empty">${escapeHtml(summaryResult.body?.message || `HTTP ${summaryResult.status}`)}</div>`;
    return;
  }

  const labels = {
    FRECUENCIA_CARDIACA: 'Frecuencia cardiaca',
    SPO2: 'Saturacion de oxigeno',
    TEMPERATURA: 'Temperatura'
  };
  const units = { FRECUENCIA_CARDIACA: 'lpm', SPO2: '%', TEMPERATURA: 'C' };
  els.telemetrySummary.innerHTML = summaryResult.body.rows.map((row) => `
    <div class="telemetry-metric">
      <h4>${escapeHtml(labels[row._id] || row._id)}</h4>
      <div class="telemetry-range">Prom. ${formatMetric(row.promedio)} | ${formatMetric(row.minimo)}-${formatMetric(row.maximo)} ${escapeHtml(units[row._id] || '')}</div>
      <div class="telemetry-total">${formatMetric(row.total, 0)}</div>
    </div>`).join('');
}

function showTelemetryLoadError(error) {
  els.mongoProviderBadge.textContent = 'ERROR';
  els.mongoProviderBadge.className = 'badge badge-bad';
  els.mongoStatus.classList.add('error');
  fillDl(els.mongoStatus, { provider: error?.message || 'MongoDB no disponible' });
  els.telemetrySummary.innerHTML = '<div class="telemetry-empty">No se pudo cargar el resumen.</div>';
  els.telemetryBody.innerHTML = '<tr class="empty-row"><td colspan="7">No se pudo cargar la telemetria de Atlas.</td></tr>';
  els.telemetryPageInfo.textContent = '--';
}

async function loadTelemetryRows(page = telemetryState.page) {
  const query = new URLSearchParams({ page: String(page), limit: '20' });
  if (els.telemetryPatientId.value) query.set('pacienteId', els.telemetryPatientId.value);
  if (els.telemetryType.value) query.set('tipo', els.telemetryType.value);
  if (els.telemetryQuality.value) query.set('calidad', els.telemetryQuality.value);

  els.btnTelemetryFilter.disabled = true;
  els.telemetryBody.innerHTML = '<tr class="empty-row"><td colspan="7">Consultando Atlas...</td></tr>';
  const { status, body } = await apiFetch(`/api/telemetria?${query}`);
  els.btnTelemetryFilter.disabled = false;

  if (status !== 200 || !body.ok) {
    els.telemetryBody.innerHTML = `<tr class="empty-row"><td colspan="7">${escapeHtml(body?.message || `HTTP ${status}`)}</td></tr>`;
    els.telemetryPageInfo.textContent = 'No se pudieron cargar los registros';
    els.telemetryPrev.disabled = true;
    els.telemetryNext.disabled = true;
    return;
  }

  telemetryState.page = body.page;
  telemetryState.pages = body.pages;
  telemetryState.rows = new Map(body.rows.map((row) => [String(row.logId), row]));
  els.telemetryBody.innerHTML = body.rows.length ? body.rows.map((row) => `
    <tr>
      <td><strong>${escapeHtml(row.identificacion)}</strong><br><small>${escapeHtml(row.pais)} | ID ${escapeHtml(row.pacienteId)}</small></td>
      <td>${escapeHtml(row.dispositivo)}</td>
      <td>${escapeHtml(row.tipo.replaceAll('_', ' '))}</td>
      <td>${escapeHtml(row.valor)} ${escapeHtml(row.unidad)}</td>
      <td><span class="quality-chip ${row.calidad === 'VALIDA' ? 'quality-valid' : 'quality-review'}">${escapeHtml(row.calidad)}</span></td>
      <td>${fmtDate(row.registradoEn)}</td>
      <td><div class="telemetry-row-actions">
        <button type="button" class="btn-action telemetry-edit" data-log-id="${escapeHtml(row.logId)}" title="Editar lectura" aria-label="Editar lectura">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/></svg>
        </button>
        <button type="button" class="btn-action btn-delete telemetry-delete" data-log-id="${escapeHtml(row.logId)}" title="Eliminar lectura" aria-label="Eliminar lectura">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v5M14 11v5"/></svg>
        </button>
      </div></td>
    </tr>`).join('') : '<tr class="empty-row"><td colspan="7">No hay registros para estos filtros.</td></tr>';
  const first = body.total ? ((body.page - 1) * body.limit) + 1 : 0;
  const last = Math.min(body.page * body.limit, body.total);
  els.telemetryPageInfo.textContent = `${formatMetric(first, 0)}-${formatMetric(last, 0)} de ${formatMetric(body.total, 0)} registros`;
  els.telemetryPrev.disabled = body.page <= 1;
  els.telemetryNext.disabled = body.page >= body.pages;
}

async function filterTelemetry(event) {
  event.preventDefault();
  await loadTelemetryRows(1);
}

function localDateTimeValue(value = new Date()) {
  const date = new Date(value);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function openTelemetryModal(row = null) {
  els.telemetryForm.reset();
  els.telemetryLogId.value = row?.logId || '';
  els.telemetrySessionId.value = row?.sesionId || '';
  els.telemetryEditType.value = row?.tipo || 'FRECUENCIA_CARDIACA';
  els.telemetryValue.value = row?.valor ?? '';
  els.telemetryEditQuality.value = row?.calidad || 'VALIDA';
  els.telemetryRecordedAt.value = localDateTimeValue(row?.registradoEn || new Date());
  els.telemetryModalTitle.textContent = row ? `Editar lectura #${row.logId}` : 'Nueva lectura de telemetria';
  els.telemetryFormMessage.textContent = '';
  els.telemetryModal.classList.add('open');
  els.telemetryModal.setAttribute('aria-hidden', 'false');
  els.telemetrySessionId.focus();
}

function closeTelemetryModal() {
  els.telemetryModal.classList.remove('open');
  els.telemetryModal.setAttribute('aria-hidden', 'true');
}

async function saveTelemetry(event) {
  event.preventDefault();
  const logId = els.telemetryLogId.value;
  const payload = {
    sesionId: Number(els.telemetrySessionId.value),
    tipo: els.telemetryEditType.value,
    valor: Number(els.telemetryValue.value),
    calidad: els.telemetryEditQuality.value,
    registradoEn: new Date(els.telemetryRecordedAt.value).toISOString()
  };
  els.btnTelemetrySave.disabled = true;
  els.telemetryFormMessage.textContent = 'Guardando en Atlas...';
  const { status, body } = await apiFetch(logId ? `/api/telemetria/${logId}` : '/api/telemetria', {
    method: logId ? 'PUT' : 'POST',
    body: JSON.stringify(payload)
  });
  els.btnTelemetrySave.disabled = false;
  if ((status === 200 || status === 201) && body.ok) {
    closeTelemetryModal();
    showToast(logId ? `Lectura #${logId} actualizada en Atlas` : `Lectura #${body.row.logId} creada en Atlas`, 'good');
    await Promise.all([loadTelemetry(), loadTelemetryRows(1)]);
    return;
  }
  els.telemetryFormMessage.textContent = body?.message || `Error HTTP ${status}`;
}

async function deleteTelemetry(logId) {
  if (!confirm(`Eliminar permanentemente la lectura #${logId} de MongoDB Atlas?`)) return;
  const { status, body } = await apiFetch(`/api/telemetria/${logId}`, { method: 'DELETE' });
  if (status === 200 && body.ok) {
    showToast(`Lectura #${logId} eliminada de Atlas`, 'good');
    await Promise.all([loadTelemetry(), loadTelemetryRows(telemetryState.page)]);
  } else {
    showToast(body?.message || `Error HTTP ${status}`, 'bad');
  }
}

async function submitVitals(event) {
  event.preventDefault();
  els.btnSubmit.disabled = true;
  els.registerMessage.textContent = 'Enviando…';

  const formData = new FormData(els.vitalsForm);
  const payload = {
    pacienteId: Number(formData.get('pacienteId')),
    frecuenciaCardiaca: Number(formData.get('frecuenciaCardiaca'))
  };

  if (!Number.isInteger(payload.pacienteId) || !Number.isInteger(payload.frecuenciaCardiaca)) {
    els.registerMessage.textContent = 'pacienteId y frecuenciaCardiaca deben ser enteros.';
    els.btnSubmit.disabled = false;
    return;
  }

  const { status, body } = await apiFetch('/api/signos-vitales', {
    method: 'POST',
    body: JSON.stringify(payload)
  });

  if (status === 201 && body.ok) {
    els.registerMessage.textContent =
      `Registrado en WRITE_MASTER · id=${body.row.id} · fc=${body.row.frecuencia_cardiaca}`;
    showToast('Signo vital registrado en master', 'good');
    els.vitalsForm.reset();
    await loadVitals();
  } else {
    els.registerMessage.textContent =
      `Error (HTTP ${status}): ${body?.message || body?.code || 'desconocido'}`;
    showToast('No se pudo registrar', 'bad');
  }
  els.btnSubmit.disabled = false;
}

/* ---------------- Médicos (modelo objeto-relacional) ---------------- */

function renderMedicos(rows) {
  if (!rows || rows.length === 0) {
    els.medicosBody.innerHTML =
      '<tr class="empty-row"><td colspan="6">Sin médicos registrados.</td></tr>';
    return;
  }
  els.medicosBody.innerHTML = rows.map((m) => `
    <tr>
      <td><strong>${escapeHtml(m.nombre_completo)}</strong></td>
      <td>${escapeHtml(m.numero_colegiado)}</td>
      <td>${escapeHtml(m.pais)}</td>
      <td>${escapeHtml(m.especialidades || '—')}</td>
      <td>${escapeHtml(m.clinica)}</td>
      <td style="text-align: right;">
        <button type="button" class="btn-action btn-delete" data-medico-oid="${escapeHtml(m.objeto_oid)}" data-medico-name="${escapeHtml(m.nombre_completo)}" title="Eliminar médico en master">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/></svg>
          Borrar
        </button>
      </td>
    </tr>`).join('');
}

async function loadMedicos() {
  const { status, body } = await apiFetch('/api/medicos');
  if (status === 200 && body.ok) {
    renderMedicos(body.rows);
    els.medicosPoolTag.textContent = 'READ_REPLICA';
    els.medicosPoolTag.classList.remove('badge-bad');
    els.medicosPoolTag.classList.add('badge-info');
  } else {
    els.medicosPoolTag.textContent = 'ERROR';
    els.medicosPoolTag.classList.remove('badge-info');
    els.medicosPoolTag.classList.add('badge-bad');
    els.medicosBody.innerHTML =
      `<tr class="empty-row"><td colspan="6">No se pudo leer (HTTP ${status}): ${escapeHtml(body?.message || '')}</td></tr>`;
  }
}

async function submitMedico(event) {
  event.preventDefault();
  els.btnMedico.disabled = true;
  els.medicoMessage.textContent = 'Enviando…';

  const formData = new FormData(els.medicoForm);
  const payload = Object.fromEntries(formData.entries());

  const { status, body } = await apiFetch('/api/medicos', {
    method: 'POST',
    body: JSON.stringify(payload)
  });

  if (status === 201 && body.ok) {
    els.medicoMessage.textContent =
      `Registrado en WRITE_MASTER · colegiado ${body.row.numero_colegiado}. La réplica lo mostrará al aplicar el WAL.`;
    showToast('Médico registrado en master', 'good');
    els.medicoForm.reset();
    setTimeout(loadMedicos, 1200);
  } else {
    const detalle = body?.constraint ? ` [${body.constraint}]` : '';
    els.medicoMessage.textContent = `Error (HTTP ${status})${detalle}: ${body?.message || 'desconocido'}`;
    showToast('El motor rechazó el registro', 'bad');
  }
  els.btnMedico.disabled = false;
}

/* ---------------- Expediente XML (validación dentro de SQL Server) ---------------- */

function xmlEjemplo(expedienteId) {
  return `<ExpedienteClinico xmlns="urn:globalhealth:expediente:v1" expedienteId="${expedienteId}" version="1.0">
  <Paciente id="CR-87654321">
    <Nombres>María Fernanda</Nombres>
    <Apellidos>Jiménez Vargas</Apellidos>
    <FechaNacimiento>1988-05-14</FechaNacimiento>
    <Sexo>F</Sexo>
    <Documento>1-1234-5678</Documento>
    <Pais>CR</Pais>
    <TipoSangre>O+</TipoSangre>
  </Paciente>
  <Antecedentes/>
  <Diagnosticos>
    <Diagnostico id="DX-001">
      <CodigoCIE10>I10</CodigoCIE10>
      <Descripcion>Hipertensión arterial esencial primaria</Descripcion>
      <Severidad>LEVE</Severidad>
      <FechaDiagnostico>2026-08-10</FechaDiagnostico>
    </Diagnostico>
  </Diagnosticos>
  <Tratamientos>
    <Tratamiento id="TRAT-001">
      <Tipo>FARMACOLOGICO</Tipo>
      <Descripcion>Losartán 50 mg por vía oral cada día</Descripcion>
      <FechaInicio>2026-08-10</FechaInicio>
      <Estado>ACTIVO</Estado>
    </Tratamiento>
  </Tratamientos>
  <FirmaMedico>
    <MedicoId>MED-CR-000001</MedicoId>
    <NombreCompleto>Ana Sofía Vega Mora</NombreCompleto>
    <NumeroColegiado>MED-18472</NumeroColegiado>
    <FechaFirma>2026-08-11T15:30:00-06:00</FechaFirma>
    <Algoritmo>RSA-SHA256</Algoritmo>
    <ValorFirma>QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo1Njc4OTBBQkNERUY=</ValorFirma>
  </FirmaMedico>
</ExpedienteClinico>`;
}

const XML_PRESETS = {
  'valido': (id) => xmlEjemplo(id),
  'sin-firma': (id) => xmlEjemplo(id).replace(/\n  <FirmaMedico>[\s\S]*?<\/FirmaMedico>/, ''),
  'fecha-mala': (id) => xmlEjemplo(id).replace('1988-05-14', '1988-99-45')
};

function cargarPreset(nombre) {
  const d = new Date();
  const ymd = d.toISOString().slice(0, 10).replace(/-/g, '');
  const sufijo = String(Math.floor(Math.random() * 9000) + 1000);
  els.expCodigo.value = `EXP-WEB-${ymd.slice(2)}-${sufijo}`.slice(0, 20);
  els.expXml.value = XML_PRESETS[nombre](`EXP-${ymd}-${sufijo}`);
  els.expResult.className = 'exp-result neutral';
  els.expResult.textContent = 'Preset cargado. Pulsa "Insertar en SQL Server" para ver la respuesta del motor.';
}

async function submitExpediente(event) {
  event.preventDefault();
  els.btnExp.disabled = true;
  els.expResult.className = 'exp-result neutral';
  els.expResult.textContent = 'Enviando al motor…';

  const { status, body } = await apiFetch('/api/expedientes', {
    method: 'POST',
    body: JSON.stringify({ codigo: els.expCodigo.value, xml: els.expXml.value })
  });

  if (status === 201 && body.ok) {
    els.expResult.className = 'exp-result ok';
    els.expResult.textContent =
      `ACEPTADO por SQL Server\nExpedienteId: ${body.row.ExpedienteId} · Código: ${body.row.Codigo}\nEl XSD registrado validó el documento dentro del motor.`;
    showToast('Expediente aceptado por SQL Server', 'good');
    loadExpedientes();
  } else {
    els.expResult.className = 'exp-result error';
    const numero = body?.errorNumero ? `Error ${body.errorNumero}` : `HTTP ${status}`;
    els.expResult.textContent =
      `RECHAZADO por SQL Server\n${numero}\n${body?.mensajeExacto || body?.message || 'desconocido'}`;
    showToast('SQL Server rechazó el XML', 'bad');
  }
  els.btnExp.disabled = false;
}

/* ---------------- Gestión y Visualización de Expedientes XML ---------------- */

let currentExpedientes = new Map();
let activeExpediente = null;

function formatXml(xml) {
  if (!xml) return '';
  let formatted = '';
  let indent = '';
  const tab = '  ';
  xml.split(/>\s*</).forEach((node) => {
    if (node.match(/^\/\w/)) indent = indent.substring(tab.length);
    formatted += indent + '<' + node + '>\r\n';
    if (node.match(/^<?\w[^>]*[^\/]$/)) indent += tab;
  });
  return formatted.trim();
}

function openXmlModal(expediente) {
  if (!expediente) return;
  activeExpediente = expediente;
  els.xmlModalTitle.textContent = `Expediente: ${expediente.codigo}`;
  els.xmlModalCode.textContent = formatXml(expediente.xml || '');
  els.xmlModal.classList.add('open');
  els.xmlModal.removeAttribute('aria-hidden');
  document.body.style.overflow = 'hidden';
}

function closeXmlModal() {
  els.xmlModal.classList.remove('open');
  els.xmlModal.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
  activeExpediente = null;
}

function triggerDownloadXml(codigo, xmlContent) {
  if (!xmlContent) {
    showToast('No hay contenido XML disponible', 'bad');
    return;
  }
  const blob = new Blob([xmlContent], { type: 'application/xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${codigo || 'expediente'}.xml`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast(`Descargando ${codigo}.xml`, 'good');
}

async function loadExpedientes() {
  const { status, body } = await apiFetch('/api/expedientes');
  if (status === 200 && body.ok) {
    currentExpedientes.clear();
    if (!body.rows || body.rows.length === 0) {
      els.expBody.innerHTML =
        '<tr class="empty-row"><td colspan="4">Sin expedientes todavía.</td></tr>';
      return;
    }
    body.rows.forEach((r) => currentExpedientes.set(String(r.id), r));
    els.expBody.innerHTML = body.rows.map((r) => `
      <tr>
        <td>${escapeHtml(r.id)}</td>
        <td><strong>${escapeHtml(r.codigo)}</strong></td>
        <td>${escapeHtml(String(r.creado_en).replace('T', ' '))}</td>
        <td>
          <div class="action-btns">
            <button type="button" class="btn-action btn-view" data-exp-id="${escapeHtml(r.id)}" title="Ver XML">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
              Ver XML
            </button>
            <button type="button" class="btn-action btn-download" data-exp-id="${escapeHtml(r.id)}" title="Descargar XML">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
              Descargar
            </button>
          </div>
        </td>
      </tr>`).join('');
  } else {
    els.expBody.innerHTML =
      `<tr class="empty-row"><td colspan="4">${escapeHtml(body?.message || `HTTP ${status}`)}</td></tr>`;
  }
}

async function refreshAll() {
  els.btnRefresh.disabled = true;
  const results = await Promise.allSettled([
    loadHealth(), loadVitals(), loadTelemetry(), loadTelemetryRows(1), loadMedicos(),
    loadExpedientes(), loadDistributedPatients()
  ]);
  const telemetryError = results.slice(2, 4).find((result) => result.status === 'rejected');
  if (telemetryError) showTelemetryLoadError(telemetryError.reason);
  if (els.lastUpdated) {
    els.lastUpdated.textContent =
      'Actualizado ' + new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }
  els.btnRefresh.disabled = false;
}

// Delegación de clics en la tabla de expedientes para Ver y Descargar
els.expBody.addEventListener('click', (event) => {
  const btnView = event.target.closest('.btn-view');
  if (btnView) {
    const id = btnView.dataset.expId;
    const exp = currentExpedientes.get(id);
    if (exp) openXmlModal(exp);
    return;
  }

  const btnDownload = event.target.closest('.btn-download');
  if (btnDownload) {
    const id = btnDownload.dataset.expId;
    const exp = currentExpedientes.get(id);
    if (exp) triggerDownloadXml(exp.codigo, exp.xml);
    return;
  }
});

// Eventos del modal
els.xmlModalClose.addEventListener('click', closeXmlModal);
els.xmlModal.addEventListener('click', (e) => {
  if (e.target === els.xmlModal) closeXmlModal();
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && els.xmlModal.classList.contains('open')) {
    closeXmlModal();
  }
  if (e.key === 'Escape' && els.telemetryModal.classList.contains('open')) {
    closeTelemetryModal();
  }
});

els.xmlModalCopy.addEventListener('click', async () => {
  if (activeExpediente?.xml) {
    try {
      await navigator.clipboard.writeText(activeExpediente.xml);
      showToast('XML copiado al portapapeles', 'good');
    } catch {
      showToast('No se pudo copiar automáticamente', 'bad');
    }
  }
});

els.xmlModalDownload.addEventListener('click', () => {
  if (activeExpediente) {
    triggerDownloadXml(activeExpediente.codigo, activeExpediente.xml);
  }
});

// Delegación de clic para eliminar médico
els.medicosBody.addEventListener('click', async (event) => {
  const btnDelete = event.target.closest('.btn-delete');
  if (!btnDelete) return;

  const oid = btnDelete.dataset.medicoOid;
  const name = btnDelete.dataset.medicoName;
  if (!oid) return;

  if (!confirm(`¿Estás seguro de eliminar al médico "${name}"?\nEsta acción se ejecutará en WRITE_MASTER y se propagará a la réplica.`)) {
    return;
  }

  btnDelete.disabled = true;
  try {
    const { status, body } = await apiFetch(`/api/medicos/${oid}`, {
      method: 'DELETE'
    });

    if (status === 200 && body.ok) {
      showToast(`Médico "${name}" eliminado en master`, 'good');
      loadMedicos();
    } else {
      showToast(`Error al eliminar: ${body?.message || `HTTP ${status}`}`, 'bad');
      btnDelete.disabled = false;
    }
  } catch (error) {
    showToast(`Error de conexión: ${error.message}`, 'bad');
    btnDelete.disabled = false;
  }
});

els.vitalsForm.addEventListener('submit', submitVitals);
els.medicoForm.addEventListener('submit', submitMedico);
els.expForm.addEventListener('submit', submitExpediente);
els.telemetryFilterForm.addEventListener('submit', filterTelemetry);
els.telemetryForm.addEventListener('submit', saveTelemetry);
els.btnTelemetryNew.addEventListener('click', () => openTelemetryModal());
els.telemetryModalClose.addEventListener('click', closeTelemetryModal);
els.telemetryModalCancel.addEventListener('click', closeTelemetryModal);
els.telemetryModal.addEventListener('click', (event) => {
  if (event.target === els.telemetryModal) closeTelemetryModal();
});
els.telemetryBody.addEventListener('click', (event) => {
  const editButton = event.target.closest('.telemetry-edit');
  if (editButton) {
    const row = telemetryState.rows?.get(editButton.dataset.logId);
    if (row) openTelemetryModal(row);
    return;
  }
  const deleteButton = event.target.closest('.telemetry-delete');
  if (deleteButton) deleteTelemetry(deleteButton.dataset.logId);
});
els.telemetryPrev.addEventListener('click', () => loadTelemetryRows(telemetryState.page - 1));
els.telemetryNext.addEventListener('click', () => loadTelemetryRows(telemetryState.page + 1));
document.querySelectorAll('[data-preset]').forEach((btn) => {
  btn.addEventListener('click', () => cargarPreset(btn.dataset.preset));
});
els.btnRefresh.addEventListener('click', refreshAll);
els.btnHealth.addEventListener('click', loadHealth);

refreshAll();
