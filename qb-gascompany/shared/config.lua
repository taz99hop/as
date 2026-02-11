Config = {}

Config.Debug = false
Config.JobName = 'gascompany'
Config.BossGrades = { [4] = true }
Config.Target = 'qb-target' -- qb-target | ox_target

Config.Duty = {
    hub = vec3(1184.06, -330.12, 69.32),
    truckSpawn = vec4(1174.79, -330.86, 69.17, 96.0),
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

Config.Truck = {
    model = 'mule3',
    maxGasUnits = 100,
    missionUse = { min = 12, max = 26 },
    penaltyForNoReturn = 400,
}

Config.Payments = {
    base = 240,
    perTaskBonus = 50,
    milestone = {
        [5] = 300,
        [10] = 750,
        [20] = 1800,
    }
}

Config.Missions = {
    cooldownSec = 6,
    locations = {
        { label = 'Vinewood #11', coords = vec4(298.52, -208.14, 54.09, 156.0), use = 18 },
        { label = 'Alta #7', coords = vec4(350.02, -589.66, 43.28, 250.0), use = 14 },
        { label = 'Mirror Park #4', coords = vec4(1016.52, -525.88, 60.17, 210.0), use = 16 },
        { label = 'Rockford Office', coords = vec4(-827.44, -702.15, 28.06, 90.0), use = 20 },
        { label = 'Del Perro Cafe', coords = vec4(-1281.48, -1138.44, 6.95, 115.0), use = 22 },
        { label = 'Vespucci #2', coords = vec4(-1164.58, -1458.34, 4.43, 20.0), use = 15 },
        { label = 'La Mesa #15', coords = vec4(722.54, -1088.52, 22.18, 268.0), use = 19 },
        { label = 'Sandy Housing #6', coords = vec4(1675.52, 4958.26, 42.34, 138.0), use = 24 },
    }
}

Config.Peds = {
    model = 'a_m_y_business_02',
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

Config.Objects = {
    stationTank = 'prop_gas_tank_04a',
    cone = 'prop_roadcone02a',
    hoseStand = 'prop_gas_pump_1d'
}

Config.AntiExploit = {
    missionTimeout = 900,
    maxDistanceToInteract = 5.0,
}
