const app = document.getElementById('app');

const state = {
  permissions: {},
  quickActions: [],
  cases: [],
  incidents: [],
  reports: [],
  rankLabel: '-'
};

const post = (event, data = {}) => {
  fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
};

const parseList = (raw) => (raw || '').split(',').map(v => v.trim()).filter(Boolean);

const setPermissionState = () => {
  const map = [
    ['interrogationForm', 'canUseInterrogation'],
    ['patrolForm', 'canAssignPatrols'],
    ['academyForm', 'canRunAcademy']
  ];

  map.forEach(([id, key]) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.closest('.module').style.display = state.permissions[key] ? 'block' : 'none';
  });
};

const renderPins = () => {
  const pins = document.getElementById('incidentPins');
  const items = state.incidents.slice(0, 12);
  pins.innerHTML = items.map((_, index) => {
    const x = 8 + ((index * 17) % 82);
    const y = 12 + ((index * 11) % 72);
    return `<span class="pin" style="left:${x}%;top:${y}%"></span>`;
  }).join('');
};

const renderFeed = () => {
  const feed = document.getElementById('feed');
  const entries = [
    ...state.cases.slice(0, 3).map(c => `📁 ${c.id} - ${c.title}`),
    ...state.incidents.slice(0, 4).map(i => `🚨 ${i.title} (${i.status})`),
    ...state.reports.slice(0, 2).map(r => `🧾 ${r.id} - ${r.officer || ''}`)
  ];

  feed.innerHTML = (entries.length ? entries : ['لا توجد بيانات حديثة']).map(item => `<div class="feed-item">${item}</div>`).join('');
};

const syncCaseSelectors = () => {
  const opts = state.cases.map(c => `<option value="${c.id}">${c.id} - ${c.title}</option>`).join('');
  document.querySelectorAll('.case-ref, #caseSelect').forEach(select => {
    select.innerHTML = opts || '<option value="">لا توجد قضايا</option>';
  });
};

const renderQuickActions = () => {
  const wrapper = document.getElementById('quickActions');
  wrapper.innerHTML = (state.quickActions || []).map(item => `<div class="quick">${item.icon} ${item.label}</div>`).join('');
};

const render = () => {
  document.getElementById('rankLabel').textContent = state.rankLabel;
  document.getElementById('caseCount').textContent = state.cases.length;
  document.getElementById('incidentCount').textContent = state.incidents.length;
  const stats = state.myStats || {};
  const efficiency = Math.min(100, (stats.callsHandled || 0) * 5 + (stats.forensics || 0) * 4 + (stats.pursuits || 0) * 3);
  document.getElementById('efficiency').textContent = `${efficiency}%`;

  renderQuickActions();
  renderPins();
  renderFeed();
  syncCaseSelectors();
  setPermissionState();
};

window.addEventListener('message', (event) => {
  const { action, payload, state: nuiState } = event.data;

  if (action === 'toggle') {
    app.classList.toggle('hidden', !nuiState);
  }

  if (action === 'hydrate') {
    state.permissions = payload.permissions || {};
    state.quickActions = payload.quickActions || [];
    state.cases = payload.cases || [];
    state.incidents = payload.incidents || [];
    state.reports = payload.reports || [];
    state.myStats = payload.myStats || {};
    state.rankLabel = payload.rankLabel || '-';
    render();
  }
});

const dispatchSimpleAction = (action, extra = {}) => {
  post('runAction', { action, ...extra });
  setTimeout(() => {
    fetch(`https://${GetParentResourceName()}/refresh`, { method: 'POST' })
      .then(res => res.json())
      .then(payload => {
        state.permissions = payload.permissions || {};
        state.quickActions = payload.quickActions || [];
        state.cases = payload.cases || [];
        state.incidents = payload.incidents || [];
        state.reports = payload.reports || [];
        state.myStats = payload.myStats || {};
        state.rankLabel = payload.rankLabel || '-';
        render();
      });
  }, 220);
};

document.getElementById('closeBtn').addEventListener('click', () => post('close'));
document.querySelectorAll('[data-action]').forEach(btn => {
  btn.addEventListener('click', () => dispatchSimpleAction(btn.dataset.action));
});

document.getElementById('caseForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  post('createCase', {
    title: form.get('title'),
    type: form.get('type'),
    summary: form.get('summary'),
    suspects: parseList(form.get('suspects'))
  });
  e.currentTarget.reset();
  setTimeout(() => dispatchSimpleAction('dispatch_backup', { title: 'تحديث مركز القيادة', area: 'HQ' }), 180);
});

document.getElementById('interrogationForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  dispatchSimpleAction('interrogation', {
    caseId: form.get('caseId'),
    question: form.get('question'),
    answer: form.get('answer'),
    impact: form.get('impact')
  });
});

document.getElementById('evidenceForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  dispatchSimpleAction('tag_evidence', {
    caseId: form.get('caseId'),
    evidenceType: form.get('evidenceType'),
    media: form.get('media'),
    notes: form.get('notes')
  });
});

document.getElementById('k9Btn').addEventListener('click', () => {
  const form = new FormData(document.getElementById('opsForm'));
  dispatchSimpleAction('k9_command', { command: form.get('command'), area: form.get('area') });
});

document.getElementById('pursuitBtn').addEventListener('click', () => {
  const form = new FormData(document.getElementById('opsForm'));
  dispatchSimpleAction('pursuit_tool', { tool: form.get('tool'), area: form.get('area') });
});

document.getElementById('academyForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  dispatchSimpleAction('academy_run', {
    trainee: form.get('trainee'),
    driving: form.get('driving'),
    shooting: form.get('shooting'),
    aiDecision: form.get('aiDecision')
  });
});

document.getElementById('patrolForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  dispatchSimpleAction('assign_patrol', {
    unit: form.get('unit'),
    zone: form.get('zone'),
    priority: form.get('priority')
  });
});
