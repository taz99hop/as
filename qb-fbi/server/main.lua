local QBCore = exports['qb-core']:GetCoreObject()

local liveUnits = {}
local activeIncidents = {}
local incidentCounter = 0
local cityEmergency = false
local heatmap = {}

local function getRole(player)
    local grade = player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
    return Config.Ranks[grade] or 'officer'
end

local function getPerms(player)
    return Config.Permissions[getRole(player)] or Config.Permissions.officer
end

local function isPoliceOnDuty(player)
    if not player then return false end
    local job = player.PlayerData.job
    return job and job.name == Config.JobName and job.onduty == true
end

local function hasPerm(player, key)
    local perms = getPerms(player)
    return perms[key] == true
end

local function unitData(player)
    return {
        source = player.PlayerData.source,
        citizenid = player.PlayerData.citizenid,
        name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
        rank = getRole(player),
        rankLabel = Config.RankLabels[getRole(player)] or getRole(player),
        status = 'Available',
        speed = 0,
        coords = { x = 0.0, y = 0.0, z = 0.0 },
        panic = false,
        signalLost = false,
        updatedAt = os.time(),
        pursuitPath = {}
    }
end

local function nextIncidentId()
    incidentCounter = incidentCounter + 1
    return ('INC-%05d'):format(incidentCounter)
end

local function addHeat(coords)
    local key = ('%d:%d'):format(math.floor(coords.x / 100), math.floor(coords.y / 100))
    heatmap[key] = (heatmap[key] or 0) + 1
end

local function refreshUnitsFromDuty()
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local p = QBCore.Functions.GetPlayer(id)
        if p and isPoliceOnDuty(p) then
            if not liveUnits[id] then
                liveUnits[id] = unitData(p)
            end
        else
            liveUnits[id] = nil
        end
    end
end

local function toList(map)
    local list = {}
    for _, v in pairs(map) do
        list[#list + 1] = v
    end
    table.sort(list, function(a, b)
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)
    return list
end

local function incidentHistoryQuery(filter)
    filter = filter or {}
    local clauses = { '1=1' }
    local params = {}

    if filter.dateFrom and filter.dateFrom ~= '' then
        clauses[#clauses + 1] = 'created_at >= ?'
        params[#params + 1] = filter.dateFrom
    end
    if filter.dateTo and filter.dateTo ~= '' then
        clauses[#clauses + 1] = 'created_at <= ?'
        params[#params + 1] = filter.dateTo
    end
    if filter.officer and filter.officer ~= '' then
        clauses[#clauses + 1] = '(claimed_by_name LIKE ? OR closed_by_name LIKE ?)'
        params[#params + 1] = ('%%%s%%'):format(filter.officer)
        params[#params + 1] = ('%%%s%%'):format(filter.officer)
    end
    if filter.crimeType and filter.crimeType ~= '' then
        clauses[#clauses + 1] = 'type LIKE ?'
        params[#params + 1] = ('%%%s%%'):format(filter.crimeType)
    end

    local sql = ([[
        SELECT incident_id, type, location_text, priority, created_at, closed_at, claimed_by_name, closed_by_name, response_seconds, handle_seconds
        FROM smartdispatch_incident_history
        WHERE %s
        ORDER BY id DESC
        LIMIT 200
    ]]):format(table.concat(clauses, ' AND '))

    return MySQL.query.await(sql, params) or {}
end

local function payloadFor(player)
    refreshUnitsFromDuty()
    local role = getRole(player)

    local cams = {}
    for _, cam in ipairs(Config.Cameras) do
        if role == 'chief' or cam.minRank == 'officer' or (cam.minRank == 'sergeant' and (role == 'sergeant' or role == 'chief')) then
            cams[#cams + 1] = cam
        end
    end

    return {
        projectName = Config.ProjectName,
        rank = role,
        rankLabel = Config.RankLabels[role] or role,
        permissions = getPerms(player),
        unitStatuses = Config.UnitStatuses,
        incidents = toList(activeIncidents),
        units = toList(liveUnits),
        cameras = cams,
        cityEmergency = cityEmergency,
        heatmap = heatmap,
        stats = {
            totalIncidents = #toList(activeIncidents),
            onDutyUnits = #toList(liveUnits)
        }
    }
end

local function broadcastDispatch()
    refreshUnitsFromDuty()
    for src, _ in pairs(liveUnits) do
        local p = QBCore.Functions.GetPlayer(src)
        if p then
            TriggerClientEvent('qb-fbi:client:syncDispatchData', src, payloadFor(p))
        end
    end
end

local function notify(src, msg, t)
    TriggerClientEvent('qb-fbi:client:notify', src, msg, t or 'primary')
end

local function persistCreate(inc)
    MySQL.insert.await([[
        INSERT INTO smartdispatch_incident_history
        (incident_id, type, location_text, location_x, location_y, location_z, priority, created_by_source, created_by_name, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        inc.id,
        inc.type,
        inc.locationText,
        inc.coords.x,
        inc.coords.y,
        inc.coords.z,
        inc.priority,
        inc.createdBySource,
        inc.createdByName
    })
end

local function persistClaim(inc)
    MySQL.update.await([[
        UPDATE smartdispatch_incident_history
        SET claimed_by_source = ?, claimed_by_name = ?, claimed_at = NOW(), response_seconds = TIMESTAMPDIFF(SECOND, created_at, NOW())
        WHERE incident_id = ?
    ]], {
        inc.claimedBySource,
        inc.claimedByName,
        inc.id
    })
end

local function persistClose(inc)
    MySQL.update.await([[
        UPDATE smartdispatch_incident_history
        SET closed_by_source = ?, closed_by_name = ?, closed_at = NOW(), handle_seconds = TIMESTAMPDIFF(SECOND, created_at, NOW())
        WHERE incident_id = ?
    ]], {
        inc.closedBySource,
        inc.closedByName,
        inc.id
    })
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS smartdispatch_incident_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            incident_id VARCHAR(32) UNIQUE,
            type VARCHAR(64),
            location_text VARCHAR(128),
            location_x DOUBLE,
            location_y DOUBLE,
            location_z DOUBLE,
            priority VARCHAR(32),
            created_by_source INT,
            created_by_name VARCHAR(128),
            claimed_by_source INT NULL,
            claimed_by_name VARCHAR(128) NULL,
            closed_by_source INT NULL,
            closed_by_name VARCHAR(128) NULL,
            created_at DATETIME,
            claimed_at DATETIME NULL,
            closed_at DATETIME NULL,
            response_seconds INT DEFAULT 0,
            handle_seconds INT DEFAULT 0
        )
    ]])

    local row = MySQL.single.await('SELECT MAX(id) AS max_id FROM smartdispatch_incident_history')
    incidentCounter = row and row.max_id or 0
end)

QBCore.Functions.CreateCallback('qb-fbi:server:getDispatchData', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not isPoliceOnDuty(player) then
        cb({ error = 'not_allowed' })
        return
    end
    cb(payloadFor(player))
end)

QBCore.Functions.CreateCallback('qb-fbi:server:getHistory', function(source, cb, filter)
    local player = QBCore.Functions.GetPlayer(source)
    if not isPoliceOnDuty(player) then
        cb({})
        return
    end
    cb(incidentHistoryQuery(filter))
end)

RegisterNetEvent('qb-fbi:server:updateTelemetry', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) then return end

    if not liveUnits[src] then
        liveUnits[src] = unitData(player)
    end

    local u = liveUnits[src]
    u.status = data.status or u.status
    u.speed = tonumber(data.speed) or 0
    u.coords = data.coords or u.coords
    u.panic = data.panic == true
    u.signalLost = data.signalLost == true
    u.updatedAt = os.time()

    if data.pursuitPoint then
        u.pursuitPath[#u.pursuitPath + 1] = data.pursuitPoint
        if #u.pursuitPath > 15 then
            table.remove(u.pursuitPath, 1)
        end
    end

    if data.signalLost == true then
        notify(src, 'تحذير: فقدان إشارة الوحدة.', 'error')
    end

    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:createIncident', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) then return end

    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local coords = data.coords or { x = c.x, y = c.y, z = c.z }

    local inc = {
        id = nextIncidentId(),
        type = data.type or 'General',
        locationText = data.locationText or ('X: %.1f | Y: %.1f'):format(coords.x, coords.y),
        coords = coords,
        priority = data.priority or 'Normal',
        description = data.description or '',
        createdAt = os.time(),
        createdBySource = src,
        createdByName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
        status = 'Open',
        assignedUnit = nil,
        closedBySource = nil
    }

    if data.isPanic then
        inc.priority = 'Critical'
        inc.type = 'PANIC BUTTON'
    end

    activeIncidents[inc.id] = inc
    addHeat(coords)
    persistCreate(inc)

    broadcastDispatch()

    if data.isPanic then
        TriggerClientEvent('qb-fbi:client:panicAlarm', -1, inc)
    end
end)

RegisterNetEvent('qb-fbi:server:claimIncident', function(incidentId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) or not hasPerm(player, 'canClaimIncident') then return end

    local inc = activeIncidents[incidentId]
    if not inc then return end

    inc.assignedUnit = src
    inc.claimedBySource = src
    inc.claimedByName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
    inc.status = 'In Progress'
    persistClaim(inc)
    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:closeIncident', function(incidentId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) or not hasPerm(player, 'canCloseIncident') then return end

    local inc = activeIncidents[incidentId]
    if not inc then return end

    inc.status = 'Closed'
    inc.closedBySource = src
    inc.closedByName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
    persistClose(inc)
    activeIncidents[incidentId] = nil
    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:dispatchIncident', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) or not hasPerm(player, 'canDispatch') then return end

    local inc = activeIncidents[data.incidentId]
    if not inc then return end

    if data.mode == 'all' then
        TriggerClientEvent('qb-fbi:client:dispatchMessage', -1, ('Dispatch: %s -> %s'):format(inc.id, inc.type), inc.coords)
    elseif data.mode == 'rank' then
        for unitSrc, u in pairs(liveUnits) do
            if u.rank == data.rank then
                TriggerClientEvent('qb-fbi:client:dispatchMessage', unitSrc, ('Dispatch (%s): %s'):format(data.rank, inc.id), inc.coords)
            end
        end
    elseif data.mode == 'closest' then
        local bestSrc, bestDist = nil, 999999.0
        for unitSrc, u in pairs(liveUnits) do
            local dx = (u.coords.x or 0.0) - inc.coords.x
            local dy = (u.coords.y or 0.0) - inc.coords.y
            local dist = (dx * dx + dy * dy)
            if dist < bestDist then
                bestDist = dist
                bestSrc = unitSrc
            end
        end

        if bestSrc then
            TriggerClientEvent('qb-fbi:client:dispatchMessage', bestSrc, ('Dispatch Closest Unit: %s'):format(inc.id), inc.coords)
            inc.assignedUnit = bestSrc
        end
    elseif data.mode == 'unit' and data.targetSource then
        TriggerClientEvent('qb-fbi:client:dispatchMessage', tonumber(data.targetSource), ('Dispatch Direct: %s'):format(inc.id), inc.coords)
        inc.assignedUnit = tonumber(data.targetSource)
    end

    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:linkCamera', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) or not hasPerm(player, 'canViewCameras') then return end

    local inc = activeIncidents[data.incidentId]
    if not inc then return end

    inc.linkedCamera = data.cameraId
    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:setCityEmergency', function(state)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) or not hasPerm(player, 'canCityEmergency') then return end

    cityEmergency = state == true
    if cityEmergency then
        TriggerClientEvent('qb-fbi:client:dispatchMessage', -1, '⚠ حالة طوارئ المدينة مفعلة', nil)
    else
        TriggerClientEvent('qb-fbi:client:dispatchMessage', -1, '✅ تم إلغاء حالة الطوارئ', nil)
    end

    broadcastDispatch()
end)

RegisterNetEvent('qb-fbi:server:autoAlert', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not isPoliceOnDuty(player) then return end

    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local coords = data.coords or { x = c.x, y = c.y, z = c.z }

    local inc = {
        id = nextIncidentId(),
        type = data.type or 'Auto Alert',
        locationText = data.locationText or ('X: %.1f | Y: %.1f'):format(coords.x, coords.y),
        coords = coords,
        priority = data.priority or 'High',
        description = data.description or 'System generated alert',
        createdAt = os.time(),
        createdBySource = src,
        createdByName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
        status = 'Open',
        assignedUnit = nil,
        closedBySource = nil
    }

    if data.isPanic then
        inc.priority = 'Critical'
        inc.type = 'PANIC BUTTON'
    end

    activeIncidents[inc.id] = inc
    addHeat(coords)
    persistCreate(inc)
    broadcastDispatch()

    if data.isPanic then
        TriggerClientEvent('qb-fbi:client:panicAlarm', -1, inc)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    liveUnits[src] = nil
    broadcastDispatch()
end)

RegisterNetEvent('QBCore:Server:SetDuty', function(onDuty)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or player.PlayerData.job.name ~= Config.JobName then return end

    if onDuty then
        liveUnits[src] = unitData(player)
    else
        liveUnits[src] = nil
    end

    broadcastDispatch()
end)
