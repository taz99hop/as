local QBCore = exports['qb-core']:GetCoreObject()

local dataFile = 'server/police_data.json'
local state = {
    cases = {},
    evidence = {},
    incidents = {},
    patrols = {},
    academyRuns = {},
    reports = {},
    stats = {}
}

local function getRole(player)
    if not player or not player.PlayerData or not player.PlayerData.job then
        return 'cadet'
    end

    local grade = player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
    return Config.Ranks[grade] or 'cadet'
end

local function hasPermission(player, permission)
    if not player then return false end

    local job = player.PlayerData.job
    if not job or job.name ~= Config.JobName then
        return false
    end

    local perms = Config.Permissions[getRole(player)] or {}
    return perms[permission] == true
end

local function readFile()
    local file = LoadResourceFile(GetCurrentResourceName(), dataFile)
    if not file or file == '' then
        return
    end

    local decoded = json.decode(file)
    if decoded then
        state = decoded
    end
end

local function saveFile()
    SaveResourceFile(GetCurrentResourceName(), dataFile, json.encode(state, { indent = true }), -1)
end

local function ensurePlayerStats(citizenId)
    if not state.stats[citizenId] then
        state.stats[citizenId] = {
            arrests = 0,
            violations = 0,
            callsHandled = 0,
            forensics = 0,
            evidenceTagged = 0,
            pursuits = 0,
            academyScore = 0
        }
    end

    return state.stats[citizenId]
end

local function toList(map)
    local list = {}
    for _, v in pairs(map or {}) do
        list[#list + 1] = v
    end

    table.sort(list, function(a, b)
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)

    return list
end

local function createReportForPlayer(player)
    local cid = player.PlayerData.citizenid
    local name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
    local stats = ensurePlayerStats(cid)

    local report = {
        id = ('RPT-%s'):format(os.time()),
        officer = name,
        citizenId = cid,
        generatedAt = os.time(),
        arrests = stats.arrests,
        violations = stats.violations,
        callsHandled = stats.callsHandled,
        forensics = stats.forensics,
        evidenceTagged = stats.evidenceTagged,
        pursuits = stats.pursuits,
        academyScore = stats.academyScore,
        export = ('reports/%s_%s.pdf'):format(cid, os.time())
    }

    state.reports[report.id] = report
    return report
end

local function dashboardPayload(player)
    local role = getRole(player)
    local cid = player.PlayerData.citizenid
    local perms = Config.Permissions[role] or {}

    return {
        rank = role,
        rankLabel = Config.RankLabels[role] or role,
        permissions = perms,
        quickActions = Config.QuickActions,
        cases = toList(state.cases),
        evidence = toList(state.evidence),
        incidents = toList(state.incidents),
        patrols = toList(state.patrols),
        academyRuns = toList(state.academyRuns),
        reports = toList(state.reports),
        myStats = ensurePlayerStats(cid)
    }
end

local function notify(src, msg, nType)
    TriggerClientEvent('qb-fbi:client:notify', src, msg, nType or 'primary')
end

readFile()

QBCore.Functions.CreateCallback('qb-fbi:server:getDashboardData', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        cb({})
        return
    end

    cb(dashboardPayload(player))
end)

RegisterNetEvent('qb-fbi:server:createCase', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not hasPermission(player, 'canUseForensics') then
        notify(src, 'ليس لديك صلاحية فتح القضايا.', 'error')
        return
    end

    local id = ('CASE-%s'):format(os.time())
    state.cases[id] = {
        id = id,
        title = data.title or 'بدون عنوان',
        type = data.type or 'عام',
        status = 'مفتوح',
        suspects = data.suspects or {},
        summary = data.summary or '',
        timeline = {
            { label = 'تحليل بصمات', done = false },
            { label = 'تحليل DNA', done = false },
            { label = 'فحص الدم', done = false },
            { label = 'توقيت الوفاة', done = false }
        },
        createdAt = os.time(),
        createdBy = player.PlayerData.citizenid
    }

    saveFile()
    notify(src, 'تم إنشاء ملف القضية بنجاح.', 'success')
end)

RegisterNetEvent('qb-fbi:server:runAction', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local cid = player.PlayerData.citizenid
    local stats = ensurePlayerStats(cid)
    local action = data.action

    if action == 'dispatch_backup' and hasPermission(player, 'canUseDispatch') then
        local id = ('INC-%s'):format(os.time())
        state.incidents[id] = {
            id = id,
            title = data.title or 'طلب دعم طارئ',
            status = 'تم إرسال دوريات NPC',
            area = data.area or 'غير محدد',
            createdAt = os.time()
        }
        stats.callsHandled = stats.callsHandled + 1
        notify(src, 'تم إرسال دعم ذكي للموقع.', 'success')
    elseif action == 'forensics_step' and hasPermission(player, 'canUseForensics') then
        local caseData = state.cases[data.caseId]
        if caseData and caseData.timeline[data.step] then
            caseData.timeline[data.step].done = true
            stats.forensics = stats.forensics + 1
            notify(src, 'تم تحديث خطوة التحقيق.', 'success')
        end
    elseif action == 'interrogation' and hasPermission(player, 'canUseInterrogation') then
        local caseData = state.cases[data.caseId]
        if caseData then
            caseData.interrogation = caseData.interrogation or {}
            caseData.interrogation[#caseData.interrogation + 1] = {
                question = data.question,
                answer = data.answer,
                impact = data.impact,
                at = os.time()
            }
            notify(src, 'تم حفظ جلسة التحقيق الصوتي/الاعتراف.', 'success')
        end
    elseif action == 'drone_record' and hasPermission(player, 'canUseDrone') then
        local id = ('EVD-%s'):format(os.time())
        state.evidence[id] = {
            id = id,
            caseId = data.caseId,
            type = 'Drone/Bridge Cam',
            notes = data.notes or 'تسجيل جوي',
            media = data.media or 'video://pending',
            createdAt = os.time()
        }
        stats.evidenceTagged = stats.evidenceTagged + 1
        notify(src, 'تم حفظ تسجيل الدرون كدليل.', 'success')
    elseif action == 'tag_evidence' and hasPermission(player, 'canTagEvidence') then
        local id = ('EVD-%s'):format(os.time())
        state.evidence[id] = {
            id = id,
            caseId = data.caseId,
            type = data.evidenceType or 'ملف',
            notes = data.notes,
            media = data.media,
            createdAt = os.time()
        }
        stats.evidenceTagged = stats.evidenceTagged + 1
        notify(src, 'تم وسم الدليل وحفظه للنيابة.', 'success')
    elseif action == 'k9_command' and hasPermission(player, 'canUseK9') then
        local id = ('INC-%s'):format(os.time())
        state.incidents[id] = {
            id = id,
            title = 'وحدة K9: ' .. (data.command or 'تتبع'),
            status = 'تم تنفيذ أمر صوتي',
            area = data.area or 'غير محدد',
            createdAt = os.time()
        }
        notify(src, 'نفذت وحدة K9 الأمر المطلوب.', 'success')
    elseif action == 'pursuit_tool' and hasPermission(player, 'canUsePursuitTools') then
        local id = ('INC-%s'):format(os.time())
        state.incidents[id] = {
            id = id,
            title = 'مطاردة ذكية - ' .. (data.tool or 'حاجز'),
            status = 'مفعل',
            area = data.area or 'غير محدد',
            createdAt = os.time()
        }
        stats.pursuits = stats.pursuits + 1
        notify(src, 'تم نشر أدوات المطاردة بنجاح.', 'success')
    elseif action == 'academy_run' and hasPermission(player, 'canRunAcademy') then
        local id = ('TRN-%s'):format(os.time())
        state.academyRuns[id] = {
            id = id,
            trainee = data.trainee or player.PlayerData.citizenid,
            driving = tonumber(data.driving) or 0,
            shooting = tonumber(data.shooting) or 0,
            aiDecision = tonumber(data.aiDecision) or 0,
            createdAt = os.time()
        }
        local total = (tonumber(data.driving) or 0) + (tonumber(data.shooting) or 0) + (tonumber(data.aiDecision) or 0)
        stats.academyScore = math.max(stats.academyScore, total)
        notify(src, 'تم حفظ نتيجة أكاديمية الشرطة.', 'success')
    elseif action == 'assign_patrol' and hasPermission(player, 'canAssignPatrols') then
        local id = ('PTR-%s'):format(os.time())
        state.patrols[id] = {
            id = id,
            unit = data.unit,
            zone = data.zone,
            priority = data.priority,
            createdAt = os.time()
        }
        notify(src, 'تم توزيع الدورية من مركز القيادة.', 'success')
    elseif action == 'shift_report' and hasPermission(player, 'canGenerateReports') then
        local report = createReportForPlayer(player)
        notify(src, ('تم إنشاء تقرير الشفت: %s'):format(report.id), 'success')
    else
        notify(src, 'الإجراء غير مسموح لهذه الرتبة.', 'error')
        return
    end

    saveFile()
    TriggerClientEvent('qb-fbi:client:syncDashboard', src, dashboardPayload(player))
end)
