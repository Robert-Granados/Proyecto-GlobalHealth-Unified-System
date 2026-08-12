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
  btnSubmit: document.getElementById('btn-submit')
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
      <td>${escapeHtml(r.frecuencia_cardiaca)}</td>
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

async function refreshAll() {
  els.btnRefresh.disabled = true;
  await Promise.allSettled([loadHealth(), loadVitals()]);
  els.btnRefresh.disabled = false;
}

els.vitalsForm.addEventListener('submit', submitVitals);
els.btnRefresh.addEventListener('click', refreshAll);
els.btnHealth.addEventListener('click', loadHealth);

refreshAll();