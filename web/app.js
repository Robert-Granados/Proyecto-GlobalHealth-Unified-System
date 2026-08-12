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
  btnExp: document.getElementById('btn-exp')
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
      '<tr class="empty-row"><td colspan="5">Sin médicos registrados.</td></tr>';
    return;
  }
  els.medicosBody.innerHTML = rows.map((m) => `
    <tr>
      <td>${escapeHtml(m.nombre_completo)}</td>
      <td>${escapeHtml(m.numero_colegiado)}</td>
      <td>${escapeHtml(m.pais)}</td>
      <td>${escapeHtml(m.especialidades || '—')}</td>
      <td>${escapeHtml(m.clinica)}</td>
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
      `<tr class="empty-row"><td colspan="5">No se pudo leer (HTTP ${status}): ${escapeHtml(body?.message || '')}</td></tr>`;
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

async function loadExpedientes() {
  const { status, body } = await apiFetch('/api/expedientes');
  if (status === 200 && body.ok) {
    if (!body.rows || body.rows.length === 0) {
      els.expBody.innerHTML =
        '<tr class="empty-row"><td colspan="3">Sin expedientes todavía.</td></tr>';
      return;
    }
    els.expBody.innerHTML = body.rows.map((r) => `
      <tr>
        <td>${escapeHtml(r.id)}</td>
        <td>${escapeHtml(r.codigo)}</td>
        <td>${escapeHtml(String(r.creado_en).replace('T', ' '))}</td>
      </tr>`).join('');
  } else {
    els.expBody.innerHTML =
      `<tr class="empty-row"><td colspan="3">${escapeHtml(body?.message || `HTTP ${status}`)}</td></tr>`;
  }
}

async function refreshAll() {
  els.btnRefresh.disabled = true;
  await Promise.allSettled([loadHealth(), loadVitals(), loadMedicos(), loadExpedientes()]);
  if (els.lastUpdated) {
    els.lastUpdated.textContent =
      'Actualizado ' + new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }
  els.btnRefresh.disabled = false;
}

els.vitalsForm.addEventListener('submit', submitVitals);
els.medicoForm.addEventListener('submit', submitMedico);
els.expForm.addEventListener('submit', submitExpediente);
document.querySelectorAll('[data-preset]').forEach((btn) => {
  btn.addEventListener('click', () => cargarPreset(btn.dataset.preset));
});
els.btnRefresh.addEventListener('click', refreshAll);
els.btnHealth.addEventListener('click', loadHealth);

refreshAll();