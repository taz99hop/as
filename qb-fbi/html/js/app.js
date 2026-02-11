const app = document.getElementById('app');
const views = document.querySelectorAll('.view');
const tabs = document.querySelectorAll('.tab');

const state = {
  cases: [],
  npcFiles: []
};

const post = (event, data = {}) => {
  fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
};

const parseList = (value) => (value || '').split(',').map(v => v.trim()).filter(Boolean);

function setView(name) {
  views.forEach(v => v.classList.toggle('active', v.id === name));
  tabs.forEach(t => t.classList.toggle('active', t.dataset.view === name));
}

function render() {
  document.getElementById('metricCases').textContent = state.cases.length;
  document.getElementById('metricUndercover').textContent = state.undercoverCount || 0;

  const caseList = document.getElementById('caseList');
  caseList.innerHTML = state.cases.map(c => `
    <div class="card">
      <strong>${c.id} - ${c.title}</strong>
      <div class="meta">${c.status || 'Active'} | by ${c.createdBy || 'Unknown'}</div>
      <p>${c.summary || ''}</p>
      <div class="log">${(c.logs || []).slice(-1)[0]?.text || 'No operation logs yet.'}</div>
    </div>
  `).join('');

  const npcFiles = document.getElementById('npcFiles');
  npcFiles.innerHTML = (state.npcFiles || []).map(n => `
    <div class="card">
      <strong>${n.title}</strong>
      <div class="meta">Threat: ${n.threat}</div>
      <p>${n.note}</p>
    </div>
  `).join('');

  const caseOptions = state.cases.map(c => `<option value="${c.id}">${c.id} - ${c.title}</option>`).join('');
  document.getElementById('opsCaseId').innerHTML = caseOptions;
  document.getElementById('raidCaseId').innerHTML = caseOptions;
}

window.addEventListener('message', (event) => {
  const { action, payload, view, state: nuiState } = event.data;

  if (action === 'toggle') {
    app.classList.toggle('hidden', !nuiState);
  }

  if (action === 'hydrate') {
    state.cases = payload.cases || [];
    state.npcFiles = payload.npcFiles || [];
    state.undercoverCount = payload.undercoverCount || 0;
    render();
    if (view) setView(view);
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('close'));

tabs.forEach(tab => tab.addEventListener('click', () => setView(tab.dataset.view)));

document.getElementById('caseForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  post('createCase', {
    title: form.get('title'),
    summary: form.get('summary'),
    suspects: parseList(form.get('suspects')),
    plates: parseList(form.get('plates')),
    weapons: parseList(form.get('weapons')),
    linkedVehicles: parseList(form.get('linkedVehicles')),
    notes: form.get('notes'),
    media: parseList(form.get('media'))
  });
  e.currentTarget.reset();
  setTimeout(() => post('requestDataRefresh'), 200);
});

document.getElementById('opsForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  post('startOperation', {
    caseId: form.get('caseId'),
    operation: form.get('operation')
  });
  setTimeout(() => post('requestDataRefresh'), 200);
});

document.getElementById('advanceRaid').addEventListener('click', () => {
  const caseId = document.getElementById('raidCaseId').value;
  if (!caseId) return;
  post('advanceRaid', { caseId });
  setTimeout(() => post('requestDataRefresh'), 200);
});
