const app = document.getElementById('app');
const overview = document.getElementById('overview');
const personnel = document.getElementById('personnel');
const alerts = document.getElementById('alerts');
const troops = document.getElementById('troops');
const missionSelect = document.getElementById('missionSelect');
const jamBanner = document.getElementById('jamBanner');
const radar = document.getElementById('radar');
const ctx = radar.getContext('2d');

let state = { missions: [], activeMissions: [] };
let radarEntities = [];

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
});

function renderOverview(payload) {
  const cards = [
    `القبة الحديدية: ${payload.overview?.domeEnabled ? 'مفعلة' : 'معطلة'}`,
    `وضع الاعتراض: ${payload.overview?.domeAuto ? 'تلقائي' : 'يدوي'}`,
    `المهام النشطة: ${payload.overview?.missions || 0}`
  ];
  overview.innerHTML = cards.map(c => `<div class="card">${c}</div>`).join('');
}

function renderPersonnel(list = []) {
  personnel.innerHTML = list.map(p => `<div>${p.name} - ${p.rank} (${p.onduty ? 'On' : 'Off'})</div>`).join('');
}

function renderAlerts(list = []) {
  alerts.innerHTML = list.map(a => `<div>[${a.at}] ${a.text}</div>`).join('');
}

function renderMissions(missions = []) {
  state.missions = missions;
  missionSelect.innerHTML = missions.map(m => `<option value="${m.id}">${m.title} ($${m.reward})</option>`).join('');
}

function renderTroops(units = []) {
  troops.innerHTML = units.map(u => `<div>${u.name} | HP:${u.hp} | AR:${u.armor} | ${u.coords.x.toFixed(1)}, ${u.coords.y.toFixed(1)}</div>`).join('');
}

function drawRadar() {
  ctx.clearRect(0, 0, radar.width, radar.height);
  const c = radar.width / 2;
  ctx.strokeStyle = '#2f9b46';
  ctx.beginPath(); ctx.arc(c, c, c - 2, 0, Math.PI * 2); ctx.stroke();
  ctx.fillStyle = '#00ff6a';
  ctx.beginPath(); ctx.arc(c, c, 4, 0, Math.PI * 2); ctx.fill();

  radarEntities.forEach(e => {
    const x = c + (e.x / 500) * c;
    const y = c + (e.y / 500) * c;
    if (Math.hypot(x - c, y - c) > c) return;
    ctx.fillStyle = e.ally ? '#00d4ff' : '#ff5252';
    ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2); ctx.fill();
  });
}
setInterval(drawRadar, 120);

window.addEventListener('message', (event) => {
  const { action, payload, entities, units, state: jamState } = event.data;
  if (action === 'toggle') app.classList.toggle('hidden', !event.data.state);
  if (action === 'hydrate') {
    state = payload;
    renderOverview(payload);
    renderPersonnel(payload.personnel);
    renderAlerts(payload.alerts);
    renderMissions(payload.missions);
    document.getElementById('domeAuto').checked = payload.overview?.domeAuto !== false;
  }
  if (action === 'radar') radarEntities = entities || [];
  if (action === 'troops') renderTroops(units || []);
  if (action === 'jammed') jamBanner.classList.toggle('hidden', !jamState);
});

document.getElementById('close').onclick = () => post('close');
document.getElementById('startMission').onclick = () => post('startMission', { id: missionSelect.value });
document.getElementById('completeMission').onclick = () => post('completeMission', { id: missionSelect.value });
document.getElementById('launch').onclick = () => post('launchMissile', {
  x: document.getElementById('mx').value,
  y: document.getElementById('my').value,
  z: document.getElementById('mz').value
});
document.getElementById('domeAuto').onchange = (e) => post('toggleDomeMode', { auto: e.target.checked });

setInterval(async () => {
  if (app.classList.contains('hidden')) return;
  const response = await post('refreshDashboard');
  const payload = await response.json();
  renderOverview(payload);
  renderPersonnel(payload.personnel || []);
  renderAlerts(payload.alerts || []);
}, 4000);
