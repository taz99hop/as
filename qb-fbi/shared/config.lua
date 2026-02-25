Config = {}

Config.JobName = 'police'
Config.CommandName = 'policehub'
Config.MaxOfficersOnDuty = 24

Config.Ranks = {
    [0] = 'cadet',
    [1] = 'officer',
    [2] = 'sergeant',
    [3] = 'lieutenant',
    [4] = 'chief'
}

Config.RankLabels = {
    cadet = 'مستجد',
    officer = 'ضابط',
    sergeant = 'رقيب',
    lieutenant = 'ملازم',
    chief = 'قائد'
}

Config.Permissions = {
    cadet = {
        canViewCommandCenter = true,
        canUseForensics = true,
        canUseDispatch = false,
        canUseInterrogation = false,
        canUseDrone = false,
        canTagEvidence = true,
        canUseK9 = false,
        canUsePursuitTools = true,
        canRunAcademy = true,
        canGenerateReports = true,
        canAssignPatrols = false
    },
    officer = {
        canViewCommandCenter = true,
        canUseForensics = true,
        canUseDispatch = true,
        canUseInterrogation = true,
        canUseDrone = true,
        canTagEvidence = true,
        canUseK9 = true,
        canUsePursuitTools = true,
        canRunAcademy = true,
        canGenerateReports = true,
        canAssignPatrols = false
    },
    sergeant = {
        canViewCommandCenter = true,
        canUseForensics = true,
        canUseDispatch = true,
        canUseInterrogation = true,
        canUseDrone = true,
        canTagEvidence = true,
        canUseK9 = true,
        canUsePursuitTools = true,
        canRunAcademy = true,
        canGenerateReports = true,
        canAssignPatrols = true
    },
    lieutenant = {
        canViewCommandCenter = true,
        canUseForensics = true,
        canUseDispatch = true,
        canUseInterrogation = true,
        canUseDrone = true,
        canTagEvidence = true,
        canUseK9 = true,
        canUsePursuitTools = true,
        canRunAcademy = true,
        canGenerateReports = true,
        canAssignPatrols = true
    },
    chief = {
        canViewCommandCenter = true,
        canUseForensics = true,
        canUseDispatch = true,
        canUseInterrogation = true,
        canUseDrone = true,
        canTagEvidence = true,
        canUseK9 = true,
        canUsePursuitTools = true,
        canRunAcademy = true,
        canGenerateReports = true,
        canAssignPatrols = true
    }
}

Config.TargetZones = {
    police_command = {
        coords = vector3(441.2, -981.9, 30.7),
        size = vector3(1.2, 1.0, 2.0),
        heading = 90.0,
        icon = 'fas fa-shield-halved',
        label = 'نظام التوجيه والسيطرة'
    }
}

Config.QuickActions = {
    { key = 'forensics', label = 'التحقيق الجنائي', icon = '🧬' },
    { key = 'dispatch', label = 'الدعم الذكي', icon = '🚓' },
    { key = 'drone', label = 'كاميرات الجسور والدرون', icon = '📡' },
    { key = 'k9', label = 'وحدة K9', icon = '🐕' },
    { key = 'pursuit', label = 'المطاردة الذكية', icon = '🚧' },
    { key = 'academy', label = 'أكاديمية الشرطة', icon = '🎯' },
    { key = 'reports', label = 'تقارير نهاية الشفت', icon = '📄' }
}
