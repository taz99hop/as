local QBCore = exports['qb-core']:GetCoreObject()

local activeCases = {}
local operationsCooldown = {}
local undercoverAgents = {}

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

local function saveCases()
    SaveResourceFile(GetCurrentResourceName(), 'server/cases.json', json.encode(activeCases, { indent = true }), -1)
end

local function loadCases()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'server/cases.json')
    if not raw or raw == '' then return end

    local decoded = json.decode(raw)
    if type(decoded) == 'table' then
        activeCases = decoded
    end
end

local function broadcastDashboard()
    local payload = {
        cases = serializeCases(),
        npcFiles = Config.NpcFiles,
        undercoverCount = countUndercoverAgents()
    }

    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        if player.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('qb-fbi:client:syncDashboard', player.PlayerData.source, payload)
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadCases()
end)

QBCore.Functions.CreateCallback('qb-fbi:server:getDashboardData', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.job.name ~= Config.JobName then
        cb({ cases = {}, npcFiles = {}, denied = true })
        return
    end

    cb({
        cases = serializeCases(),
        npcFiles = Config.NpcFiles,
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
            fakeName = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
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
        TriggerClientEvent('qb-fbi:client:notify', src, 'Access denied.', 'error')
        return
    end

    local caseId = ('CASE-%s'):format(math.random(100000, 999999))
    activeCases[caseId] = {
        id = caseId,
        title = data.title or 'Untitled Case',
        summary = data.summary or '',
        suspects = data.suspects or {},
        plates = data.plates or {},
        weapons = data.weapons or {},
        linkedVehicles = data.linkedVehicles or {},
        notes = data.notes or '',
        media = data.media or {},
        status = 'Active Intelligence',
        raidStage = 0,
        createdBy = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        createdAt = os.time(),
        logs = {
            {
                text = 'Case initialized and marked as classified.',
                by = src,
                at = os.time()
            }
        }
    }

    saveCases()
    broadcastDashboard()
    TriggerClientEvent('qb-fbi:client:notify', src, ('Case %s created.'):format(caseId), 'success')
end)

RegisterNetEvent('qb-fbi:server:startOperation', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local opType = data.operation
    local targetCase = data.caseId
    local caseData = activeCases[targetCase]

    if not caseData then
        TriggerClientEvent('qb-fbi:client:notify', src, 'Case not found.', 'error')
        return
    end

    if not hasPermission(player, 'canStartRaid') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'You are not allowed to launch operations.', 'error')
        return
    end

    local now = os.time()
    operationsCooldown[src] = operationsCooldown[src] or {}

    if operationsCooldown[src][opType] and operationsCooldown[src][opType] > now then
        local left = operationsCooldown[src][opType] - now
        TriggerClientEvent('qb-fbi:client:notify', src, ('Cooldown active: %s seconds left.'):format(left), 'error')
        return
    end

    if opType == 'phoneTrace' or opType == 'bugPlant' then
        if not hasPermission(player, 'canRequestTap') then
            TriggerClientEvent('qb-fbi:client:notify', src, 'Insufficient clearance for surveillance tools.', 'error')
            return
        end

        caseData.logs[#caseData.logs + 1] = {
            text = ('%s request submitted; pending lead authorization.'):format(opType),
            by = src,
            at = now
        }

        operationsCooldown[src][opType] = now + (Config.Cooldowns[opType] or 300)
        saveCases()
        broadcastDashboard()
        TriggerClientEvent('qb-fbi:client:notify', src, 'Request submitted. Regional lead approval required.', 'primary')
        return
    end

    if opType == 'raidStart' then
        if isLimitReached() then
            TriggerClientEvent('qb-fbi:client:notify', src, 'FBI active unit cap reached, command review needed.', 'error')
            return
        end

        caseData.status = 'Raid Protocol Active'
        caseData.raidStage = 1
        caseData.logs[#caseData.logs + 1] = {
            text = 'Raid protocol initiated, waiting for judicial authorization.',
            by = src,
            at = now
        }
        operationsCooldown[src][opType] = now + Config.Cooldowns.raidStart
        saveCases()
        broadcastDashboard()
        TriggerClientEvent('qb-fbi:client:notify', src, 'Raid stage 1 started.', 'success')
    end
end)

RegisterNetEvent('qb-fbi:server:advanceRaid', function(caseId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local caseData = activeCases[caseId]

    if not player or not caseData then return end
    if not hasPermission(player, 'canApproveRaid') then
        TriggerClientEvent('qb-fbi:client:notify', src, 'Only regional lead can advance raid stages.', 'error')
        return
    end

    local nextStage = caseData.raidStage + 1
    if nextStage > #Config.RaidStages then
        caseData.status = 'Completed / Archived'
        caseData.logs[#caseData.logs + 1] = {
            text = 'Operation fully completed and archived.',
            by = src,
            at = os.time()
        }
    else
        caseData.raidStage = nextStage
        caseData.status = Config.RaidStages[nextStage]
        caseData.logs[#caseData.logs + 1] = {
            text = ('Raid advanced to stage: %s'):format(Config.RaidStages[nextStage]),
            by = src,
            at = os.time()
        }
    end

    saveCases()
    broadcastDashboard()
    TriggerClientEvent('qb-fbi:client:notify', src, 'Raid stage updated.', 'success')
end)
