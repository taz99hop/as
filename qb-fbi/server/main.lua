local QBCore = exports['qb-core']:GetCoreObject()

local activeCases = {}
local pendingApprovals = {}
local operationsCooldown = {}
local undercoverAgents = {}
local approvalCounter = 0

local function countUndercoverAgents()
    local count = 0
    for _ in pairs(undercoverAgents) do
        count = count + 1
    end
    return count
end

local function getRoleKey(player)
    return Config.Grades[player.PlayerData.job.grade.level] or 'analyst'
end

local function hasPermission(player, key)
    if not player or player.PlayerData.job.name ~= Config.JobName then
        return false
    end

    local roleKey = getRoleKey(player)
    local perms = Config.Permissions[roleKey] or {}
    return perms[key] == true
end

local function isLimitReached()
    local count = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.JobName then
            count = count + 1
        end
    end
    return count > Config.MaxAgents
end

local function serializeCases()
    local arr = {}
    for _, caseData in pairs(activeCases) do
        arr[#arr + 1] = caseData
    end
    table.sort(arr, function(a, b) return a.createdAt > b.createdAt end)
    return arr
end

local function serializeApprovals()
    local arr = {}
    for _, approvalData in pairs(pendingApprovals) do
        arr[#arr + 1] = approvalData
    end
    table.sort(arr, function(a, b) return a.requestedAt > b.requestedAt end)
    return arr
end

local function saveCases()
    SaveResourceFile(GetCurrentResourceName(), 'server/cases.json', json.encode(activeCases, { indent = true }), -1)
end

local function saveApprovals()
    SaveResourceFile(GetCurrentResourceName(), 'server/approvals.json', json.encode(pendingApprovals, { indent = true }), -1)
end

local function loadCases()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'server/cases.json')
    if not raw or raw == '' then return end

    local decoded = json.decode(raw)
    if type(decoded) == 'table' then
        activeCases = decoded
    end
end

local function loadApprovals()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'server/approvals.json')
    if not raw or raw == '' then return end

    local decoded = json.decode(raw)
    if type(decoded) == 'table' then
        pendingApprovals = decoded
    end

    for approvalId in pairs(pendingApprovals) do
        local numeric = tonumber(tostring(approvalId):gsub('APR%-', '')) or 0
        if numeric > approvalCounter then
            approvalCounter = numeric
        end
    end
end

local function broadcastDashboard()
    local payload = {
        cases = serializeCases(),
        npcFiles = Config.NpcFiles,
        approvals = serializeApprovals(),
        undercoverCount = countUndercoverAgents()
    }

    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        if player.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('qb-fbi:client:syncDashboard', player.PlayerData.source, payload)
        end
    end
end

local function addCaseLog(caseData, text, by)
    caseData.logs = caseData.logs or {}
    caseData.logs[#caseData.logs + 1] = {
        text = text,
        by = by,
        at = os.time()
    }
end

local function createApproval(caseData, src, player, opType, reason)
    approvalCounter = approvalCounter + 1
    local approvalId = ('APR-%06d'):format(approvalCounter)

    pendingApprovals[approvalId] = {
        id = approvalId,
        caseId = caseData.id,
        operation = opType,
        reason = reason or 'بدون سبب مفصل',
        status = 'pending',
        requestedBy = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        requestedBySrc = src,
        requestedAt = os.time(),
        reviewedBy = nil,
        reviewedAt = nil,
        decisionNote = nil
    }

    addCaseLog(caseData, ('تم إنشاء طلب موافقة %s للعملية %s.'):format(approvalId, opType), src)
    saveApprovals()
end

local function executeOperation(caseData, opType, src)
    if opType == 'phoneTrace' then
        caseData.status = 'تنصت هاتف مفعل'
        addCaseLog(caseData, 'تمت الموافقة: تتبع الهاتف بدأ بنجاح.', src)
        return true, 'تم تفعيل تتبع الهاتف بنجاح.'
    end

    if opType == 'bugPlant' then
        caseData.status = 'جهاز تتبع مزروع'
        addCaseLog(caseData, 'تمت الموافقة: زرع جهاز التنصت بالمركبة.', src)
        return true, 'تم زرع جهاز التنصت بنجاح.'
    end

    if opType == 'raidStart' then
        if isLimitReached() then
            return false, 'عدد عناصر FBI الفعّال تجاوز الحد المسموح.'
        end

        caseData.status = Config.RaidStages[1]
        caseData.raidStage = 1
        addCaseLog(caseData, 'تم اعتماد بدء بروتوكول المداهمة (المرحلة الأولى).', src)
        return true, 'تم اعتماد بدء المداهمة.'
    end

    return false, 'نوع عملية غير معروف.'
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadCases()
    loadApprovals()
end)

AddEventHandler('playerDropped', function()
    local src = source
    undercoverAgents[src] = nil
end)

QBCore.Functions.CreateCallback('qb-fbi:server:getDashboardData', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.job.name ~= Config.JobName then
        cb({ cases = {}, npcFiles = {}, approvals = {}, denied = true })
        return
    end

    cb({
        cases = serializeCases(),
        npcFiles = Config.NpcFiles,
        approvals = serializeApprovals(),
        undercoverCount = countUndercoverAgents(),
        role = getRoleKey(player),
        rolePermissions = Config.Permissions[getRoleKey(player)]
    })
end)

RegisterNetEvent('qb-fbi:server:setUndercover', function(state)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or player.PlayerData.job.name ~= Config.JobName then
        return
    end

    if state then
        undercoverAgents[src] = {
            fakeJob = Config.CivilianIdentities[math.random(1, #Config.CivilianIdentities)],
            fakeName = Config.Aliases[math.random(1, #Config.Aliases)]
        }
        Player(src).state:set('fbiAliasName', undercoverAgents[src].fakeName, true)
        Player(src).state:set('fbiAliasJob', undercoverAgents[src].fakeJob, true)
    else
        undercoverAgents[src] = nil
        Player(src).state:set('fbiAliasName', nil, true)
        Player(src).state:set('fbiAliasJob', nil, true)
    end

    Player(src).state:set('fbiUndercover', state, true)
    broadcastDashboard()
end)

RegisterNetEvent('qb-fbi:server:createCase', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    if not player or not hasPermission(player, 'canCreateCase') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'ليس لديك صلاحية إنشاء قضايا.', 'error')
        return
    end

    local caseId = ('CASE-%s'):format(math.random(100000, 999999))
    activeCases[caseId] = {
        id = caseId,
        title = data.title or 'قضية بدون عنوان',
        summary = data.summary or '',
        suspects = data.suspects or {},
        plates = data.plates or {},
        weapons = data.weapons or {},
        linkedVehicles = data.linkedVehicles or {},
        notes = data.notes or '',
        media = data.media or {},
        status = 'استخبارات نشطة',
        raidStage = 0,
        createdBy = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        createdAt = os.time(),
        logs = {
            {
                text = 'تم إنشاء القضية وتصنيفها سرية.',
                by = src,
                at = os.time()
            }
        }
    }

    saveCases()
    broadcastDashboard()
    TriggerClientEvent('qb-fbi:client:notify', src, ('تم إنشاء القضية %s بنجاح.'):format(caseId), 'success')
end)

RegisterNetEvent('qb-fbi:server:startOperation', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local opType = data.operation
    local targetCase = data.caseId
    local reason = data.reason
    local caseData = activeCases[targetCase]

    if not caseData then
        TriggerClientEvent('qb-fbi:client:notify', src, 'القضية غير موجودة.', 'error')
        return
    end

    if not hasPermission(player, 'canStartRaid') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'لا تملك صلاحية تنفيذ العمليات.', 'error')
        return
    end

    local now = os.time()
    operationsCooldown[src] = operationsCooldown[src] or {}

    if operationsCooldown[src][opType] and operationsCooldown[src][opType] > now then
        local left = operationsCooldown[src][opType] - now
        TriggerClientEvent('qb-fbi:client:notify', src, ('Cooldown مفعل: متبقي %s ثانية.'):format(left), 'error')
        return
    end

    local needsPermission = Config.RequiredApprovals[opType]
    if needsPermission and not hasPermission(player, needsPermission) then
        createApproval(caseData, src, player, opType, reason)
        operationsCooldown[src][opType] = now + (Config.Cooldowns[opType] or 300)
        saveCases()
        broadcastDashboard()
        TriggerClientEvent('qb-fbi:client:notify', src, 'تم إرسال الطلب وبانتظار موافقة القائد.', 'primary')
        return
    end

    local ok, message = executeOperation(caseData, opType, src)
    operationsCooldown[src][opType] = now + (Config.Cooldowns[opType] or 300)

    if ok then
        saveCases()
        broadcastDashboard()
        TriggerClientEvent('qb-fbi:client:notify', src, message, 'success')
    else
        TriggerClientEvent('qb-fbi:client:notify', src, message, 'error')
    end
end)

RegisterNetEvent('qb-fbi:server:reviewApproval', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPermission(player, 'canApproveTap') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'فقط القيادة يمكنها مراجعة الطلبات.', 'error')
        return
    end

    local approval = pendingApprovals[data.approvalId]
    if not approval or approval.status ~= 'pending' then
        TriggerClientEvent('qb-fbi:client:notify', src, 'طلب الموافقة غير صالح أو تم التعامل معه.', 'error')
        return
    end

    local caseData = activeCases[approval.caseId]
    if not caseData then
        TriggerClientEvent('qb-fbi:client:notify', src, 'القضية غير موجودة.', 'error')
        return
    end

    approval.reviewedBy = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    approval.reviewedAt = os.time()
    approval.decisionNote = data.note or ''

    if data.decision == 'approve' then
        approval.status = 'approved'
        local ok, msg = executeOperation(caseData, approval.operation, src)
        addCaseLog(caseData, ('موافقة %s: %s'):format(approval.id, msg), src)
        TriggerClientEvent('qb-fbi:client:notify', src, ok and 'تمت الموافقة والتنفيذ.' or msg, ok and 'success' or 'error')
    else
        approval.status = 'rejected'
        addCaseLog(caseData, ('تم رفض الطلب %s. ملاحظة: %s'):format(approval.id, approval.decisionNote ~= '' and approval.decisionNote or 'بدون ملاحظة'), src)
        TriggerClientEvent('qb-fbi:client:notify', src, 'تم رفض الطلب.', 'error')
    end

    saveCases()
    saveApprovals()
    broadcastDashboard()
end)

RegisterNetEvent('qb-fbi:server:advanceRaid', function(caseId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local caseData = activeCases[caseId]

    if not player or not caseData then return end
    if not hasPermission(player, 'canApproveRaid') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'فقط القائد الإقليمي يمكنه ترقية مراحل المداهمة.', 'error')
        return
    end

    local nextStage = caseData.raidStage + 1
    if nextStage > #Config.RaidStages then
        caseData.status = 'مكتملة / مؤرشفة'
        addCaseLog(caseData, 'تم إنهاء العملية بالكامل وأرشفتها.', src)
    else
        caseData.raidStage = nextStage
        caseData.status = Config.RaidStages[nextStage]
        addCaseLog(caseData, ('تم الانتقال للمرحلة: %s'):format(Config.RaidStages[nextStage]), src)
    end

    saveCases()
    broadcastDashboard()
    TriggerClientEvent('qb-fbi:client:notify', src, 'تم تحديث مرحلة المداهمة.', 'success')
end)
