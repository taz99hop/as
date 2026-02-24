local QBCore = exports['qb-core']:GetCoreObject()

local ArmyState = {
    domeEnabled = true,
    domeAuto = true,
    activeMissions = {},
    alerts = {}
}

local function getGrade(player)
    return player.PlayerData.job.grade.level or player.PlayerData.job.grade or 0
end

local function isArmy(player)
    return player and player.PlayerData.job.name == Config.JobName
end

local function hasPerm(player, perm)
    if not isArmy(player) then return false end
    local grade = getGrade(player)
    if grade >= Config.CommanderGrade then return true end
    local rank = Config.Ranks[grade]
    return rank and rank.permissions and (rank.permissions.all or rank.permissions[perm] == true)
end

local function pushAlert(text)
    ArmyState.alerts[#ArmyState.alerts + 1] = { text = text, at = os.date('%H:%M:%S') }
    if #ArmyState.alerts > 30 then table.remove(ArmyState.alerts, 1) end
end

local function sendWebhook(key, title, description)
    local url = Config.Webhooks[key]
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'Army Control',
        embeds = {{ title = title, description = description, color = 16711680 }}
    }), { ['Content-Type'] = 'application/json' })
end

QBCore.Functions.CreateCallback('qb-army:server:getDashboardData', function(source, cb)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not isArmy(player) then cb({}) return end

    local online = {}
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local p = QBCore.Functions.GetPlayer(id)
        if p and isArmy(p) then
            local grade = getGrade(p)
            online[#online + 1] = {
                id = id,
                name = p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname,
                rank = (Config.Ranks[grade] and Config.Ranks[grade].label) or tostring(grade),
                onduty = p.PlayerData.job.onduty == true
            }
        end
    end

    cb({
        overview = {
            domeEnabled = ArmyState.domeEnabled,
            domeAuto = ArmyState.domeAuto,
            missions = #ArmyState.activeMissions
        },
        personnel = online,
        activeMissions = ArmyState.activeMissions,
        alerts = ArmyState.alerts
    })
end)

RegisterNetEvent('qb-army:server:requestLoadout', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'gear') then return end
    for _, weapon in ipairs(Config.Weapons) do
        player.Functions.AddItem(weapon, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[weapon], 'add')
    end
    pushAlert(('الجندي %s استلم العتاد.'):format(src))
end)

RegisterNetEvent('qb-army:server:applyUniform', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'uniform') then return end
    TriggerClientEvent('qb-clothing:client:openOutfitMenu', src)
end)

RegisterNetEvent('qb-army:server:startMission', function(missionId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'mission') then return end
    ArmyState.activeMissions[#ArmyState.activeMissions + 1] = {
        id = missionId,
        by = src,
        startedAt = os.time()
    }
    pushAlert(('بدء المهمة %s بواسطة %s.'):format(missionId, src))
end)

RegisterNetEvent('qb-army:server:completeMission', function(missionId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not isArmy(player) then return end

    local reward = Config.MissionReward
    for _, m in ipairs(Config.Missions) do
        if m.id == missionId then reward = m.reward break end
    end

    player.Functions.AddMoney('bank', reward, 'army-mission-success')
    pushAlert(('اكتمال المهمة %s من %s مع مكافأة %s$'):format(missionId, src, reward))
    TriggerClientEvent('qb-army:client:notify', src, ('تم تسليم مكافأة المهمة: $%s'):format(reward), 'success')
end)

RegisterNetEvent('qb-army:server:setDomeState', function(enabled, auto)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'dome') then return end

    ArmyState.domeEnabled = enabled == true
    ArmyState.domeAuto = auto == true
    pushAlert(('تعديل القبة الحديدية: enabled=%s auto=%s بواسطة %s'):format(tostring(enabled), tostring(auto), src))
end)

RegisterNetEvent('qb-army:server:launchMissile', function(target)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'missile') then return end

    TriggerClientEvent('qb-army:client:missileIncoming', -1, target)
    sendWebhook('launch', 'Missile Launch', ('Launcher: %s\nTarget: %.2f, %.2f, %.2f'):format(src, target.x, target.y, target.z))
    pushAlert(('إطلاق صاروخ بواسطة %s باتجاه %.1f, %.1f'):format(src, target.x, target.y))

    SetTimeout(5000, function()
        local intercepted = false
        local targetVec = vector3(target.x, target.y, target.z)
        local distToBase = #(targetVec - Config.Base.center)
        if ArmyState.domeEnabled and distToBase <= Config.Base.radius then
            local chance = ArmyState.domeAuto and math.random(55, 95) or math.random(35, 75)
            intercepted = math.random(1, 100) <= chance
            if intercepted then
                pushAlert('تم اعتراض صاروخ معادٍ بواسطة القبة الحديدية.')
                sendWebhook('intercept', 'Iron Dome Intercept', ('Success by defense net. Chance %s%%'):format(chance))
            end
        end
        TriggerClientEvent('qb-army:client:executeMissile', -1, target, intercepted)
    end)
end)

RegisterNetEvent('qb-army:server:setJamming', function(state)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not hasPerm(player, 'jam') then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pcoords = GetEntityCoords(ped)

    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local tgtPed = GetPlayerPed(id)
        if tgtPed ~= 0 then
            local dist = #(GetEntityCoords(tgtPed) - pcoords)
            if dist <= Config.JammingRange then
                TriggerClientEvent('qb-army:client:setJammed', id, state == true, GetPlayerName(src))
            end
        end
    end
end)

RegisterNetEvent('qb-army:server:requestTroopTracking', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not isArmy(player) then return end

    local units = {}
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local p = QBCore.Functions.GetPlayer(id)
        if p and isArmy(p) then
            local ped = GetPlayerPed(id)
            local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
            units[#units + 1] = {
                id = id,
                name = p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname,
                hp = GetEntityHealth(ped),
                armor = GetPedArmour(ped),
                coords = { x = coords.x, y = coords.y, z = coords.z }
            }
        end
    end

    TriggerClientEvent('qb-army:client:troopTracking', src, units)
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player and isArmy(player) then
        pushAlert(('دخول للخدمة: %s'):format(src))
        sendWebhook('duty', 'Army Duty', ('Player %s joined service'):format(src))
    end
end)
