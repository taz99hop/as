const app = document.getElementById('app');
const closeBtn = document.getElementById('closeBtn');
const dutyBtn = document.getElementById('dutyBtn');
const managerTab = document.getElementById('managerTab');

const fields = {
    delivered: document.getElementById('delivered'),
    earnings: document.getElementById('earnings'),
    rating: document.getElementById('rating'),
    level: document.getElementById('level'),
    onlineDrivers: document.getElementById('onlineDrivers'),
    activeTasks: document.getElementById('activeTasks'),
    dayProfit: document.getElementById('dayProfit')
};

const EXPECTED_UI_TOKEN = 'parcel_secure_v1';

let tabletState = {
    onDuty: false,
    isManager: false
};

function isTrustedPayload(payload = {}) {
    return payload && payload.uiToken === EXPECTED_UI_TOKEN;
}

function post(event, data = {}) {
    fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

function setDutyText() {
    dutyBtn.textContent = tabletState.onDuty ? 'تسجيل خروج الدوام' : 'تسجيل دخول الدوام';
    dutyBtn.style.background = tabletState.onDuty ? '#dc2626' : '#16a34a';
}

function renderManagerDrivers(drivers = []) {
    const container = document.getElementById('driversList');
    container.innerHTML = '';

    if (!drivers.length) {
        container.innerHTML = '<div class="driver-row">لا يوجد سائقون على الدوام حالياً.</div>';
        return;
    }

    drivers.forEach((driver) => {
        const row = document.createElement('div');
        row.className = 'driver-row';
        row.innerHTML = `<span>${driver.name} (ID: ${driver.source})</span><span>مسلَّم: ${driver.delivered} | محمّل: ${driver.loaded}</span>`;
        container.appendChild(row);
    });
}

window.addEventListener('message', (event) => {
    const { action, payload } = event.data;

    if (action === 'openTablet') {
        if (!isTrustedPayload(payload)) return;
        app.classList.remove('hidden');
        tabletState.onDuty = !!payload.onDuty;
        tabletState.isManager = !!payload.isManager;

        document.getElementById('welcome').textContent = `مرحباً ${payload.playerName}`;
        managerTab.style.display = tabletState.isManager ? 'inline-block' : 'none';

        fields.delivered.textContent = payload.delivered ?? 0;
        fields.earnings.textContent = `$${payload.earnings ?? 0}`;
        fields.rating.textContent = `${payload.rating ?? 0} / 5`;
        fields.level.textContent = payload.level ?? 1;

        setDutyText();
    }

    if (action === 'closeTablet') {
        app.classList.add('hidden');
    }

    if (action === 'updateTablet') {
        if (!isTrustedPayload(payload)) return;
        if (typeof payload.onDuty !== 'undefined') tabletState.onDuty = payload.onDuty;
        if (typeof payload.delivered !== 'undefined') fields.delivered.textContent = payload.delivered;
        if (typeof payload.earnings !== 'undefined') fields.earnings.textContent = `$${payload.earnings}`;
        if (typeof payload.rating !== 'undefined') fields.rating.textContent = `${payload.rating} / 5`;
        if (typeof payload.level !== 'undefined') fields.level.textContent = payload.level;
        if (typeof payload.onlineDrivers !== 'undefined') fields.onlineDrivers.textContent = payload.onlineDrivers;
        if (typeof payload.activeTasks !== 'undefined') fields.activeTasks.textContent = payload.activeTasks;
        if (typeof payload.dayProfit !== 'undefined') fields.dayProfit.textContent = `$${payload.dayProfit}`;
        setDutyText();
    }

    if (action === 'updateManager') {
        if (!isTrustedPayload(payload)) return;
        renderManagerDrivers(payload.drivers || []);
    }
});

closeBtn.addEventListener('click', () => post('close'));
dutyBtn.addEventListener('click', () => post('toggleDuty'));

managerTab.addEventListener('click', () => post('requestManagerData'));

document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));

        button.classList.add('active');
        document.getElementById(button.dataset.tab).classList.add('active');
    });
});

document.getElementById('saveBasePay').addEventListener('click', () => {
    post('managerAction', { action: 'changeBasePay', amount: Number(document.getElementById('basePay').value) });
});

document.getElementById('fireDriver').addEventListener('click', () => {
    post('managerAction', { action: 'fireDriver', target: Number(document.getElementById('fireTarget').value) });
});

document.getElementById('resetStats').addEventListener('click', () => {
    post('managerAction', { action: 'resetStats', citizenid: document.getElementById('resetCitizen').value.trim() });
});


window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('close');
    }
});
