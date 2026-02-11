const app = document.getElementById('app');
const dutyBtn = document.getElementById('dutyBtn');
const missionBtn = document.getElementById('missionBtn');
const closeBtn = document.getElementById('closeBtn');
const managerBox = document.getElementById('managerBox');
const employeesEl = document.getElementById('employees');
const refreshEmployeesBtn = document.getElementById('refreshEmployees');

const tasksEl = document.getElementById('tasks');
const earningsEl = document.getElementById('earnings');
const gasEl = document.getElementById('gas');

let currentState = { onDuty: false, isBoss: false };

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
    info.innerHTML = `<strong>${emp.name}</strong><small>مهام: ${emp.completed} | أرباح: $${emp.earned}</small>`;

    const fire = document.createElement('button');
    fire.textContent = 'طرد';
    fire.addEventListener('click', () => post('managerAction', { action: 'kick', target: emp.id }));

    li.appendChild(info);
    li.appendChild(fire);
    employeesEl.appendChild(li);
  });
};

const syncPanel = (data) => {
  currentState = data;
  tasksEl.textContent = data.stats?.completed ?? 0;
  earningsEl.textContent = `$${data.stats?.earned ?? 0}`;
  gasEl.textContent = data.gasUnits ?? 0;
  dutyBtn.textContent = data.onDuty ? 'إنهاء الدوام' : 'بدء الدوام';

  managerBox.classList.toggle('hidden', !data.isBoss);
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data;

  if (action === 'open') {
    app.classList.remove('hidden');
    syncPanel(data);
  }

  if (action === 'refresh') {
    if (data.employees) renderEmployees(data.employees);
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

missionBtn.addEventListener('click', () => post('requestMission'));
refreshEmployeesBtn.addEventListener('click', () => post('managerAction', { action: 'panel' }));

document.addEventListener('keyup', (e) => {
  if (e.key === 'Escape') {
    app.classList.add('hidden');
    post('close');
  }
});
