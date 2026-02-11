Config = {}

Config.JobName = 'fbi'
Config.MaxAgents = 8
Config.UndercoverCooldown = 300 -- seconds

Config.Permissions = {
    analyst = {
        canCreateCase = true,
        canViewAllCases = true,
        canRequestTap = false,
        canApproveTap = false,
        canStartRaid = false,
        canApproveRaid = false,
        canManageAgents = false
    },
    field_agent = {
        canCreateCase = true,
        canViewAllCases = true,
        canRequestTap = true,
        canApproveTap = false,
        canStartRaid = true,
        canApproveRaid = false,
        canManageAgents = false
    },
    hrt = {
        canCreateCase = true,
        canViewAllCases = true,
        canRequestTap = true,
        canApproveTap = false,
        canStartRaid = true,
        canApproveRaid = false,
        canManageAgents = false
    },
    regional_lead = {
        canCreateCase = true,
        canViewAllCases = true,
        canRequestTap = true,
        canApproveTap = true,
        canStartRaid = true,
        canApproveRaid = true,
        canManageAgents = true
    }
}

Config.Grades = {
    [0] = 'analyst',
    [1] = 'field_agent',
    [2] = 'hrt',
    [3] = 'regional_lead'
}

Config.TargetZones = {
    command_terminal = {
        coords = vector3(136.58, -764.76, 45.75),
        size = vector3(1.2, 0.8, 1.8),
        heading = 340.0,
        icon = 'fas fa-laptop-code',
        label = 'FBI Intelligence Terminal'
    },
    evidence_board = {
        coords = vector3(140.15, -762.92, 45.75),
        size = vector3(1.8, 0.8, 1.8),
        heading = 340.0,
        icon = 'fas fa-diagram-project',
        label = 'FBI Case Board'
    }
}

Config.RaidStages = {
    'Evidence Ready',
    'Judicial Authorization',
    'Team Assembly',
    'Entry & Breach',
    'After Action Report'
}

Config.Cooldowns = {
    phoneTrace = 900,
    bugPlant = 600,
    raidStart = 1200
}

Config.RequiredApprovals = {
    phoneTrace = 'canApproveTap',
    bugPlant = 'canApproveTap',
    raidStart = 'canApproveRaid'
}

Config.NpcFiles = {
    { id = 'org-redwire', title = 'Redwire Cartel', threat = 'High', note = 'Synthetic weapon trafficking ring.' },
    { id = 'cell-blackreef', title = 'Blackreef Cell', threat = 'Critical', note = 'Potential terror financing and explosives.' },
    { id = 'smug-ironline', title = 'Ironline Smuggling', threat = 'Medium', note = 'Cross-border firearm route in port districts.' }
}

Config.CivilianIdentities = {
    'IT Consultant',
    'Insurance Investigator',
    'Freelance Journalist',
    'Logistics Auditor',
    'Security Analyst'
}

Config.Outfits = {
    male = {
        tshirt_1 = 31, tshirt_2 = 0,
        torso_1 = 4, torso_2 = 0,
        arms = 4,
        pants_1 = 24, pants_2 = 0,
        shoes_1 = 21, shoes_2 = 0
    },
    female = {
        tshirt_1 = 14, tshirt_2 = 0,
        torso_1 = 361, torso_2 = 0,
        arms = 4,
        pants_1 = 25, pants_2 = 0,
        shoes_1 = 21, shoes_2 = 0
    }
}
