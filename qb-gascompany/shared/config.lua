Config = {}

Config.Debug = false
Config.JobName = 'gascompany'
Config.BossGrades = { [4] = true }
-- Config.Target (legacy): لم يعد مستخدماً بعد التحويل إلى تفاعل زر E

Config.Duty = {
    hub = vec3(1184.06, -330.12, 69.32),
    truckSpawn = vec4(1174.79, -330.86, 69.17, 96.0),
    trailerSpawn = vec4(1168.60, -330.50, 69.17, 96.0),
    returnPoint = vec3(1171.95, -320.77, 69.18),
    stash = vec3(1187.42, -317.91, 69.18)
}

Config.Uniform = {
    male = {
        tshirt_1 = 59, tshirt_2 = 1,
        torso_1 = 65, torso_2 = 0,
        arms = 19,
        pants_1 = 36, pants_2 = 0,
        shoes_1 = 25, shoes_2 = 0,
        helmet_1 = 14, helmet_2 = 0,
    },
    female = {
        tshirt_1 = 36, tshirt_2 = 1,
        torso_1 = 59, torso_2 = 0,
        arms = 14,
        pants_1 = 35, pants_2 = 0,
        shoes_1 = 26, shoes_2 = 0,
        helmet_1 = 14, helmet_2 = 0,
    }
}

Config.Tools = {
    hoseProp = 'prop_cs_fuel_nozle',
    scannerProp = 'prop_notepad_01'
}

Config.FleetTiers = {
    standard = { label = 'Standard', model = 'phantom', trailerModel = 'tanker', maxGasUnits = 100, upkeep = 0 },
    heavy = { label = 'Heavy', model = 'hauler', trailerModel = 'tanker', maxGasUnits = 130, upkeep = 200 },
}

Config.Truck = {
    model = 'phantom',
    trailerModel = 'tanker',
    maxGasUnits = 100,
    missionUse = { min = 12, max = 26 },
    penaltyForNoReturn = 400,
}

Config.Payments = {
    base = 240,
    perTaskBonus = 50,
    companyCutPercent = 22,
    milestone = {
        [5] = 300,
        [10] = 750,
        [20] = 1800,
    }
}

Config.Company = {
    initialStock = 800,
    initialFunds = 5000,
    import = {
        liters = 500,
        cost = 9000,
    }
}

Config.DynamicEconomy = {
    enabled = true,
    stockLowThreshold = 200,
    lowStockPayoutBonus = 1.15,
    peakHours = { start = 19, ['end'] = 23 },
    peakPayoutBonus = 1.10,
}

Config.Reputation = {
    start = 50,
    min = 0,
    max = 100,
    fastMissionSec = 300,
    fastBonus = 2,
    slowPenalty = 1,
}

Config.OperatingCosts = {
    enabled = true,
    intervalMinutes = 30,
    baseCost = 1200,
}

Config.Shifts = {
    default = 'open',
    list = {
        open = { label = 'Open Shift', start = 0, ['end'] = 23 },
        morning = { label = 'Morning Shift', start = 8, ['end'] = 15 },
        evening = { label = 'Evening Shift', start = 16, ['end'] = 23 },
    }
}

Config.Contracts = {
    {
        id = 'sandy-food-chain',
        label = 'Sandy Food Chain',
        region = 'sandy',
        target = 6,
        bonusFunds = 8500,
    },
    {
        id = 'paleto-industry',
        label = 'Paleto Industry',
        region = 'paleto',
        target = 5,
        bonusFunds = 7600,
    },
}

Config.Alerts = {
    enabled = true,
    intervalMinutes = 20,
    messages = {
        'Operational alert: Sandy demand surge detected.',
        'Operational alert: City reserve pressure increased.',
        'Operational alert: Paleto clients requesting rapid service.',
    }
}

Config.Integrations = {
    billing = false,
    phone = false,
    policeEscort = false,
}

Config.Missions = {
    cooldownSec = 6,
    minBatch = 1,
    maxBatch = 5,
    locations = {
        { label = 'Vinewood #11', region = 'city', payoutMult = 1.00, coords = vec4(298.52, -208.14, 54.09, 156.0), use = 18 },
        { label = 'Alta #7', region = 'city', payoutMult = 1.00, coords = vec4(350.02, -589.66, 43.28, 250.0), use = 14 },
        { label = 'Mirror Park #4', region = 'city', payoutMult = 1.00, coords = vec4(1016.52, -525.88, 60.17, 210.0), use = 16 },
        { label = 'Rockford Office', region = 'city', payoutMult = 1.00, coords = vec4(-827.44, -702.15, 28.06, 90.0), use = 20 },
        { label = 'Del Perro Cafe', region = 'city', payoutMult = 1.00, coords = vec4(-1281.48, -1138.44, 6.95, 115.0), use = 22 },
        { label = 'Vespucci #2', region = 'city', payoutMult = 1.00, coords = vec4(-1164.58, -1458.34, 4.43, 20.0), use = 15 },
        { label = 'La Mesa #15', region = 'city', payoutMult = 1.00, coords = vec4(722.54, -1088.52, 22.18, 268.0), use = 19 },

        { label = 'Sandy Housing #6', region = 'sandy', payoutMult = 1.45, coords = vec4(1675.52, 4958.26, 42.34, 138.0), use = 24 },
        { label = 'Sandy Market', region = 'sandy', payoutMult = 1.40, coords = vec4(1963.24, 3740.92, 32.34, 122.0), use = 21 },

        { label = 'Paleto Bay House #3', region = 'paleto', payoutMult = 1.15, coords = vec4(-130.35, 6471.28, 31.58, 312.0), use = 20 },
        { label = 'Paleto Workshop', region = 'paleto', payoutMult = 1.20, coords = vec4(96.13, 6618.59, 32.44, 46.0), use = 23 },
    }
}

Config.Peds = {
    model = 'a_m_y_business_02',
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

Config.Objects = {
    stationTank = 'prop_gas_tank_04a',
    cone = 'prop_roadcone02a',
    hoseStand = 'prop_gas_pump_1d',
    missionTank = 'prop_gas_tank_04a'
}

Config.AntiExploit = {
    missionTimeout = 900,
    maxDistanceToInteract = 5.0,
}
