Config = {}

Config.ProjectName = 'qb-smartdispatch | Tactical Command System'
Config.JobName = 'police'
Config.CommandName = 'smartdispatch'

Config.DispatchCenter = {
    coords = vector3(441.2, -981.9, 30.7),
    size = vector3(1.2, 1.0, 2.0),
    heading = 90.0,
    icon = 'fas fa-headset',
    label = 'فتح غرفة العمليات'
}

Config.Ranks = {
    [0] = 'officer',
    [1] = 'officer',
    [2] = 'sergeant',
    [3] = 'sergeant',
    [4] = 'chief'
}

Config.RankLabels = {
    officer = 'Officer',
    sergeant = 'Sergeant',
    chief = 'Chief'
}

Config.Permissions = {
    officer = {
        canViewIncidents = true,
        canClaimIncident = true,
        canCloseIncident = false,
        canDispatch = false,
        canViewCameras = false,
        canManageSettings = false,
        canCityEmergency = false
    },
    sergeant = {
        canViewIncidents = true,
        canClaimIncident = true,
        canCloseIncident = true,
        canDispatch = true,
        canViewCameras = true,
        canManageSettings = false,
        canCityEmergency = false
    },
    chief = {
        canViewIncidents = true,
        canClaimIncident = true,
        canCloseIncident = true,
        canDispatch = true,
        canViewCameras = true,
        canManageSettings = true,
        canCityEmergency = true
    }
}

Config.UnitStatuses = {
    'Available',
    'Busy',
    'Pursuit',
    'Emergency'
}

Config.Cameras = {
    { id = 'CAM-001', label = 'Mission Row Gate', pos = vector3(449.37, -997.04, 36.0), lookAt = vector3(438.7, -991.8, 30.8), minRank = 'sergeant' },
    { id = 'CAM-002', label = 'Vespucci Blvd', pos = vector3(307.1, -579.4, 59.0), lookAt = vector3(326.9, -574.8, 28.8), minRank = 'sergeant' },
    { id = 'CAM-003', label = 'Downtown Bridge', pos = vector3(2518.6, -415.7, 101.2), lookAt = vector3(2486.4, -406.0, 93.0), minRank = 'chief' }
}

Config.AutoAlerts = {
    gunshotCooldown = 45,
    collisionCooldown = 60,
    wantedZoneCooldown = 60,
    wantedZone = { center = vector3(250.0, -1050.0, 29.0), radius = 130.0 }
}

Config.TelemetryTickMs = 2500
Config.PanicSoundFile = 'alarm.ogg'
