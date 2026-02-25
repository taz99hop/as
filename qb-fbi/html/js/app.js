const app = document.getElementById('app');

const state = {
  incidents: [],
  units: [],
  cameras: [],
  permissions: {},
  heatmap: {},
  unitStatuses: [],
  cityEmergency: false,
  stats: {}
};

const alerts = [];

const post = (event, data = {}) => {
  fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
};

const esc = (x) => String(x ?? '').replace(/[<>&]/g, s => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[s]));

function addAlert(text) {
  alerts.unshift({ text, at: new Date().toLocaleTimeString() });
  while (alerts.length > 20) alerts.pop();
  document.getElementById('alertsFeed').innerHTML = alerts.map(a => `<div class="feed-item">${esc(a.at)} - ${esc(a.text)}</div>`).join('');
}

function setPermissionUI() {
  const canDispatch = !!state.permissions.canDispatch;
  const canClose = !!state.permissions.canCloseIncident;
  const canViewCameras = !!state.permissions.canViewCameras;
  const canEmergency = !!state.permissions.canCityEmergency;

  document.getElementById('dispatchForm').style.display = canDispatch ? 'grid' : 'none';
  document.getElementById('cameraForm').style.display = canViewCameras ? 'grid' : 'none';
  document.getElementById('emergencyBtn').style.display = canEmergency ? 'inline-block' : 'none';

  document.querySelectorAll('.close-incident').forEach(btn => {
    btn.style.display = canClose ? 'inline-block' : 'none';
  });
}

function renderPins() {
  const pins = document.getElementById('pins');
  pins.innerHTML = state.units.map((u, i) => {
    const x = 8 + ((i * 13) % 82);
    const y = 10 + ((i * 19) % 76);
    const color = u.status === 'Emergency' ? '#ff4f4f' : (u.status === 'Pursuit' ? '#ffba3b' : '#73e6ff');
    return `<span class="pin" style="left:${x}%;top:${y}%;background:${color}"></span>`;
  }).join('');
}

function renderUnits() {
  const el = document.getElementById('unitsList');
  el.innerHTML = state.units.map(u => (
    `<div class="feed-item"><b>${esc(u.name)}</b><br/>${esc(u.rankLabel)} | ${esc(u.status)} | ${Math.floor(u.speed || 0)} km/h${u.signalLost ? ' ⚠️ Signal Lost' : ''}${u.panic ? ' 🚨 PANIC' : ''}</div>`
  )).join('') || '<div class="feed-item">لا توجد وحدات</div>';
}

function renderIncidents() {
  const list = document.getElementById('incidentsList');
  list.innerHTML = state.incidents.map(i => `
    <div class="feed-item">
      <b>${esc(i.id)}</b> | ${esc(i.type)} | <span>${esc(i.priority)}</span><br/>
      ${esc(i.locationText)}<br/>
      <small>${esc(i.status)}</small>
      <div style="display:flex;gap:6px;margin-top:6px;flex-wrap:wrap;">
        <button class="claim-incident" data-id="${esc(i.id)}">استلام</button>
        <button class="close-incident" data-id="${esc(i.id)}">إغلاق</button>
      </div>
    </div>
  `).join('') || '<div class="feed-item">لا توجد بلاغات</div>';

  const opts = state.incidents.map(i => `<option value="${esc(i.id)}">${esc(i.id)} - ${esc(i.type)}</option>`).join('') || '<option value="">-</option>';
  document.getElementById('dispatchIncident').innerHTML = opts;
  document.getElementById('cameraIncident').innerHTML = opts;

  document.querySelectorAll('.claim-incident').forEach(btn => {
    btn.addEventListener('click', () => post('claimIncident', { incidentId: btn.dataset.id }));
  });
  document.querySelectorAll('.close-incident').forEach(btn => {
    btn.addEventListener('click', () => post('closeIncident', { incidentId: btn.dataset.id }));
  });
}

function renderCameras() {
  const opts = state.cameras.map(c => `<option value="${esc(c.id)}">${esc(c.id)} - ${esc(c.label)}</option>`).join('') || '<option value="">لا يوجد كاميرات</option>';
  document.getElementById('cameraSelect').innerHTML = opts;
}

function renderHeatmap() {
  const entries = Object.entries(state.heatmap || {}).sort((a, b) => b[1] - a[1]).slice(0, 10);
  document.getElementById('heatmapList').innerHTML = entries.map(([zone, count]) => `<div class="feed-item">${esc(zone)} : ${count}</div>`).join('') || '<div class="feed-item">لا توجد بيانات</div>';
}

function renderStats() {
  document.getElementById('activeIncidents').textContent = state.stats.totalIncidents || 0;
  document.getElementById('activeUnits').textContent = state.stats.onDutyUnits || 0;
  document.getElementById('cityState').textContent = state.cityEmergency ? 'EMERGENCY' : 'NORMAL';
}

function renderStatuses() {
  document.getElementById('myStatus').innerHTML = (state.unitStatuses || []).map(s => `<option value="${esc(s)}">${esc(s)}</option>`).join('');
}

function render() {
  document.getElementById('projectTitle').textContent = state.projectName || 'qb-smartdispatch';
  document.getElementById('rankLabel').textContent = state.rankLabel || '-';
  renderPins();
  renderUnits();
  renderIncidents();
  renderCameras();
  renderHeatmap();
  renderStats();
  renderStatuses();
  setPermissionUI();
}

window.addEventListener('message', (event) => {
  const { action, payload, state: nuiState } = event.data;

  if (action === 'toggle') app.classList.toggle('hidden', !nuiState);

  if (action === 'hydrate') {
    Object.assign(state, payload || {});
    render();
  }

  if (action === 'panicAlarm') {
    addAlert(`🚨 Panic Alert ${payload?.id || ''}`);
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('close'));
document.getElementById('newIncidentBtn').addEventListener('click', () => {
  const form = new FormData(document.getElementById('incidentForm'));
  post('createIncident', {
    type: form.get('type'),
    locationText: form.get('locationText'),
    priority: form.get('priority'),
    description: form.get('description')
  });
  addAlert('تم إرسال بلاغ جديد');
});

document.getElementById('panicBtn').addEventListener('click', () => {
  post('createIncident', { type: 'PANIC BUTTON', locationText: 'Manual panic from dispatch', priority: 'Critical', description: 'Panic test', isPanic: true });
  addAlert('تم إطلاق Panic تنبيهي');
});

document.getElementById('emergencyBtn').addEventListener('click', () => {
  state.cityEmergency = !state.cityEmergency;
  post('setCityEmergency', { state: state.cityEmergency });
  renderStats();
});

document.getElementById('myStatus').addEventListener('change', (e) => {
  post('setStatus', { status: e.target.value });
});

document.getElementById('dispatchForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  post('dispatchIncident', {
    incidentId: document.getElementById('dispatchIncident').value,
    mode: form.get('mode'),
    rank: form.get('rank'),
    targetSource: form.get('targetSource')
  });
  addAlert('تم تنفيذ توزيع البلاغ');
});

document.getElementById('openCameraBtn').addEventListener('click', () => {
  post('openCamera', { cameraId: document.getElementById('cameraSelect').value });
  addAlert('تم فتح الكاميرا');
});

document.getElementById('linkCameraBtn').addEventListener('click', () => {
  post('linkCamera', {
    cameraId: document.getElementById('cameraSelect').value,
    incidentId: document.getElementById('cameraIncident').value
  });
  addAlert('تم ربط الكاميرا بالبلاغ');
});

document.getElementById('historyForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  fetch(`https://${GetParentResourceName()}/getHistory`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({
      dateFrom: form.get('dateFrom'),
      dateTo: form.get('dateTo'),
      officer: form.get('officer'),
      crimeType: form.get('crimeType')
    })
  }).then(r => r.json()).then(rows => {
    document.getElementById('historyList').innerHTML = (rows || []).map(row => (
      `<div class="feed-item"><b>${esc(row.incident_id)}</b> | ${esc(row.type)}<br/>${esc(row.location_text)}<br/>By: ${esc(row.claimed_by_name || '-')} / Closed: ${esc(row.closed_by_name || '-')}<br/>Resp: ${row.response_seconds || 0}s | Handle: ${row.handle_seconds || 0}s</div>`
    )).join('') || '<div class="feed-item">لا توجد نتائج</div>';
  });
});
