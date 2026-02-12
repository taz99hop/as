const app = document.getElementById('app');
const dutyBtn = document.getElementById('dutyBtn');
const missionBtn = document.getElementById('missionBtn');
const missionCount = document.getElementById('missionCount');
const closeBtn = document.getElementById('closeBtn');
const managerBox = document.getElementById('managerBox');
const employeesEl = document.getElementById('employees');
const refreshEmployeesBtn = document.getElementById('refreshEmployees');
const companyFundsEl = document.getElementById('companyFunds');
const companyStockEl = document.getElementById('companyStock');
const withdrawAmountEl = document.getElementById('withdrawAmount');
const withdrawBtn = document.getElementById('withdrawBtn');
const importBtn = document.getElementById('importBtn');
const importMeta = document.getElementById('importMeta');

const tasksEl = document.getElementById('tasks');
const earningsEl = document.getElementById('earnings');
const gasEl = document.getElementById('gas');

const tankHud = document.getElementById('tankHud');
const tankLiters = document.getElementById('tankLiters');
const tankMax = document.getElementById('tankMax');
const tankBarFill = document.getElementById('tankBarFill');

const fillOverlay = document.getElementById('fillOverlay');
const fillLabel = document.getElementById('fillLabel');
const fillBarFill = document.getElementById('fillBarFill');

let fillTimer = null;
let currentState = { onDuty: false, isBoss: false, company: null };

const post = async (event, data = {}) => {
  await fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
};

const renderEmployees = (employees = []) => {
  employeesEl.innerHTML = '';
  if (!employees.length) {
    const li = document.createElement('li');
    li.textContent = 'لا يوجد موظفين متاحين الآن.';
    employeesEl.appendChild(li);
    return;
  }

  employees.forEach((emp) => {
    const li = document.createElement('li');
    const info = document.createElement('div');
    info.innerHTML = `<strong>${emp.name}</strong><small>رتبة: ${emp.grade} | مهام: ${emp.completed} | أرباح: $${emp.earned}</small>`;

    const controls = document.createElement('div');

    const promote = document.createElement('button');
    promote.textContent = 'ترقية';
    promote.addEventListener('click', () => post('managerAction', { action: 'promote', target: emp.id }));

    const fire = document.createElement('button');
    fire.textContent = 'طرد';
    fire.addEventListener('click', () => post('managerAction', { action: 'kick', target: emp.id }));

    controls.appendChild(promote);
    controls.appendChild(fire);

    li.appendChild(info);
    li.appendChild(controls);
    employeesEl.appendChild(li);
  });
};

const setTankHud = (liters = 0, max = 100) => {
  const safeMax = Math.max(max, 1);
  const ratio = Math.max(0, Math.min(100, (liters / safeMax) * 100));
  tankLiters.textContent = String(liters);
  tankMax.textContent = String(max);
  tankBarFill.style.width = `${ratio}%`;
};

const startFillOverlay = (duration = 5000, label = 'تعبئة الغاز') => {
  if (fillTimer) clearInterval(fillTimer);
  fillOverlay.classList.remove('hidden');
  fillLabel.textContent = label;
  fillBarFill.style.width = '0%';

  const started = Date.now();
  fillTimer = setInterval(() => {
    const elapsed = Date.now() - started;
    const pct = Math.max(0, Math.min(100, (elapsed / duration) * 100));
    fillBarFill.style.width = `${pct}%`;
    if (pct >= 100) {
      clearInterval(fillTimer);
      fillTimer = null;
    }
  }, 40);
};

const stopFillOverlay = () => {
  if (fillTimer) clearInterval(fillTimer);
  fillTimer = null;
  fillOverlay.classList.add('hidden');
};

const syncPanel = (data) => {
  currentState = data;
  tasksEl.textContent = data.stats?.completed ?? 0;
  earningsEl.textContent = `$${data.stats?.earned ?? 0}`;
  gasEl.textContent = data.gasUnits ?? 0;
  dutyBtn.textContent = data.onDuty ? 'إنهاء الدوام' : 'بدء الدوام';
  managerBox.classList.toggle('hidden', !data.isBoss);

  const company = data.company ?? currentState.company ?? null;
  currentState.company = company;
  if (company) {
    companyFundsEl.textContent = `$${company.funds ?? 0}`;
    companyStockEl.textContent = `${company.stock ?? 0}L`;
    importMeta.textContent = `الاستيراد: ${company.importLiters ?? 0}L مقابل $${company.importCost ?? 0} | نسبة الشركة: ${company.cutPercent ?? 0}%`;
  }

  const min = data.minBatch ?? 1;
  const max = data.maxBatch ?? 5;
  missionCount.innerHTML = '';
  for (let i = min; i <= max; i += 1) {
    const opt = document.createElement('option');
    opt.value = String(i);
    opt.textContent = String(i);
    missionCount.appendChild(opt);
  }
  const preferred = String(Math.min(Math.max(3, min), max));
  missionCount.value = preferred;
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data;

  if (action === 'open') {
    app.classList.remove('hidden');
    syncPanel(data);
  }

  if (action === 'refresh') {
    if (data.employees) renderEmployees(data.employees);
    if (data.company) {
      currentState.company = data.company;
      companyFundsEl.textContent = `$${data.company.funds ?? 0}`;
      companyStockEl.textContent = `${data.company.stock ?? 0}L`;
      importMeta.textContent = `الاستيراد: ${data.company.importLiters ?? 0}L مقابل $${data.company.importCost ?? 0} | نسبة الشركة: ${data.company.cutPercent ?? 0}%`;
    }
  }

  if (action === 'tankHudShow') {
    tankHud.classList.remove('hidden');
  }

  if (action === 'tankHudHide') {
    tankHud.classList.add('hidden');
  }

  if (action === 'tankHud') {
    setTankHud(data?.liters ?? 0, data?.max ?? 100);
  }

  if (action === 'fillStart') {
    startFillOverlay(data?.duration ?? 5000, data?.label ?? 'تعبئة الغاز');
  }

  if (action === 'fillEnd') {
    stopFillOverlay();
  }
});

closeBtn.addEventListener('click', () => {
  app.classList.add('hidden');
  post('close');
});

dutyBtn.addEventListener('click', () => {
  const value = !currentState.onDuty;
  currentState.onDuty = value;
  dutyBtn.textContent = value ? 'إنهاء الدوام' : 'بدء الدوام';
  post('toggleDuty', { value });
});

missionBtn.addEventListener('click', () => post('requestMission', { count: Number(missionCount.value || 1) }));
refreshEmployeesBtn.addEventListener('click', () => post('managerAction', { action: 'panel' }));

withdrawBtn.addEventListener('click', () => {
  const amount = Number(withdrawAmountEl.value || 0);
  if (amount > 0) post('managerAction', { action: 'companyWithdraw', amount });
});

importBtn.addEventListener('click', () => post('managerAction', { action: 'companyImport' }));

document.addEventListener('keyup', (e) => {
  if (e.key === 'Escape') {
    app.classList.add('hidden');
    post('close');
  }
});
