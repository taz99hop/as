Config = {}

Config.JobName = 'army'
Config.CommanderGrade = 9
Config.MissionReward = 3500
Config.AlertRange = 220.0
Config.RadarRange = 500.0
Config.JammingRange = 120.0

Config.Webhooks = {
    duty = '',
    launch = '',
    intercept = ''
}

Config.Base = {
    label = 'Fort Zancudo HQ',
    center = vector3(-2050.73, 3133.95, 32.81),
    radius = 550.0,
    zones = {
        duty = vector3(-1830.1, 3010.7, 32.81),
        armory = vector3(-1858.4, 3069.4, 32.81),
        locker = vector3(-1838.2, 3006.3, 32.81),
        command = vector3(-1849.7, 3021.7, 32.81),
        missile = vector3(-1861.9, 3024.2, 32.81),
        dome = vector3(-1865.0, 3026.9, 32.81)
    }
}

Config.Ranks = {
    [0] = { label = 'مجند', salary = 900, permissions = { duty = true, gear = true, uniform = true } },
    [1] = { label = 'جندي أول', salary = 1200, permissions = { duty = true, gear = true, uniform = true } },
    [2] = { label = 'عريف', salary = 1400, permissions = { duty = true, gear = true, uniform = true, mission = true } },
    [3] = { label = 'رقيب', salary = 1700, permissions = { duty = true, gear = true, uniform = true, mission = true } },
    [4] = { label = 'رقيب أول', salary = 2000, permissions = { duty = true, gear = true, uniform = true, mission = true, jam = true } },
    [5] = { label = 'ملازم', salary = 2400, permissions = { duty = true, gear = true, uniform = true, mission = true, jam = true, radar = true } },
    [6] = { label = 'نقيب', salary = 2800, permissions = { duty = true, gear = true, uniform = true, mission = true, jam = true, radar = true, missile = true } },
    [7] = { label = 'رائد', salary = 3300, permissions = { duty = true, gear = true, uniform = true, mission = true, jam = true, radar = true, missile = true, dome = true } },
    [8] = { label = 'عقيد', salary = 3900, permissions = { duty = true, gear = true, uniform = true, mission = true, jam = true, radar = true, missile = true, dome = true, command = true } },
    [9] = { label = 'قائد الجيش', salary = 5000, permissions = { all = true } }
}

Config.Missions = {
    { id = 'patrol', title = 'دورية نقاط', reward = 1800 },
    { id = 'checkpoint', title = 'نقطة تفتيش تفاعلية', reward = 2000 },
    { id = 'recon', title = 'مهمة استطلاع', reward = 2200 },
    { id = 'vip', title = 'حماية VIP', reward = 2500 },
    { id = 'breach', title = 'عملية اقتحام', reward = 3000 },
    { id = 'air_support', title = 'دعم جوي', reward = 2800 },
    { id = 'base_defense', title = 'الدفاع عن القاعدة', reward = 3200 }
}

Config.Weapons = {
    'weapon_carbinerifle',
    'weapon_combatmg',
    'weapon_pistol',
    'weapon_stungun',
    'weapon_flashbang'
}
