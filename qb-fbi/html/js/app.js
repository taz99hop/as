const app = document.getElementById('app');
const views = document.querySelectorAll('.view');
const tabs = document.querySelectorAll('.tab');

const state = {
  cases: [],
  npcFiles: [],
  approvals: [],
  rolePermissions: {}
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

function canApprove() {
  return Boolean(state.rolePermissions?.canApproveTap);
}

function renderApprovals() {
  const list = document.getElementById('approvalList');
  const approvals = state.approvals || [];

  if (!approvals.length) {
    list.innerHTML = '<div class="card"><strong>لا توجد طلبات موافقة حالياً.</strong></div>';
    return;
  }

  list.innerHTML = approvals.map((a) => {
    const statusClass = a.status === 'approved' ? 'ok' : a.status === 'rejected' ? 'bad' : 'wait';
    const controls = (a.status === 'pending' && canApprove()) ? `
      <div class="row actions">
        <input type="text" data-note="${a.id}" placeholder="ملاحظة القائد (اختياري)" />
        <button class="btn-approve" data-action="approve" data-id="${a.id}">موافقة</button>
        <button class="btn-reject" data-action="reject" data-id="${a.id}">رفض</button>
      </div>
    ` : '';

    return `
      <div class="card">
        <strong>${a.id} | ${a.operation}</strong>
        <div class="meta">
          القضية: ${a.caseId} | الحالة: <span class="status ${statusClass}">${a.status}</span>
        </div>
        <p><b>السبب:</b> ${a.reason || 'بدون سبب'}</p>
        <p><b>مقدم الطلب:</b> ${a.requestedBy || 'غير معروف'}</p>
        <p><b>المراجعة:</b> ${a.reviewedBy || '-'}</p>
        ${controls}
      </div>
    `;
  }).join('');
}

function render() {
  document.getElementById('metricCases').textContent = state.cases.length;
  document.getElementById('metricUndercover').textContent = state.undercoverCount || 0;

  const caseList = document.getElementById('caseList');
  caseList.innerHTML = state.cases.map(c => `
    <div class="card">
      <strong>${c.id} - ${c.title}</strong>
      <div class="meta">الحالة: ${c.status || 'نشطة'} | بواسطة ${c.createdBy || 'غير معروف'}</div>
      <p>${c.summary || ''}</p>
      <div class="log">${(c.logs || []).slice(-1)[0]?.text || 'لا توجد سجلات عمليات بعد.'}</div>
    </div>
  `).join('');

  const npcFiles = document.getElementById('npcFiles');
  npcFiles.innerHTML = (state.npcFiles || []).map(n => `
    <div class="card">
      <strong>${n.title}</strong>
      <div class="meta">مستوى التهديد: ${n.threat}</div>
      <p>${n.note}</p>
    </div>
  `).join('');

  const caseOptions = state.cases.map(c => `<option value="${c.id}">${c.id} - ${c.title}</option>`).join('');
  document.getElementById('opsCaseId').innerHTML = caseOptions;
  document.getElementById('raidCaseId').innerHTML = caseOptions;

  renderApprovals();
}

window.addEventListener('message', (event) => {
  const { action, payload, view, state: nuiState } = event.data;

  if (action === 'toggle') {
    app.classList.toggle('hidden', !nuiState);
  }

  if (action === 'hydrate') {
    state.cases = payload.cases || [];
    state.npcFiles = payload.npcFiles || [];
    state.approvals = payload.approvals || [];
    state.undercoverCount = payload.undercoverCount || 0;
    state.rolePermissions = payload.rolePermissions || {};
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
  setTimeout(() => post('requestDataRefresh'), 250);
});

document.getElementById('opsForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const form = new FormData(e.currentTarget);
  post('startOperation', {
    caseId: form.get('caseId'),
    operation: form.get('operation'),
    reason: form.get('reason')
  });
  setTimeout(() => post('requestDataRefresh'), 250);
});

document.getElementById('advanceRaid').addEventListener('click', () => {
  const caseId = document.getElementById('raidCaseId').value;
  if (!caseId) return;
  post('advanceRaid', { caseId });
  setTimeout(() => post('requestDataRefresh'), 250);
});

document.getElementById('approvalList').addEventListener('click', (e) => {
  const button = e.target.closest('button[data-id]');
  if (!button) return;

  const approvalId = button.dataset.id;
  const decision = button.dataset.action;
  const noteInput = document.querySelector(`input[data-note="${approvalId}"]`);
  const note = noteInput ? noteInput.value : '';

  post('reviewApproval', { approvalId, decision, note });
  setTimeout(() => post('requestDataRefresh'), 250);
});
