local QBCore = exports['qb-core']:GetCoreObject()

local isOpen = false
local undercover = false
local undercoverExpires = 0

local function getRoleKey(playerData)
    local grade = playerData.job and playerData.job.grade and playerData.job.grade.level or 0
    return Config.Grades[grade] or 'analyst'
end

local function hasPermission(permissionKey)
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData.job or playerData.job.name ~= Config.JobName then
        return false
    end

    local roleKey = getRoleKey(playerData)
    local perms = Config.Permissions[roleKey] or {}
    return perms[permissionKey] == true
end

local function setNuiState(state)
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'toggle', state = state })
    isOpen = state
end

local function openTerminal(view)
    if not hasPermission('canViewAllCases') then
        QBCore.Functions.Notify('لا تملك تصريح FBI.', 'error')
        return
    end

    setNuiState(true)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getDashboardData', function(data)
        SendNUIMessage({
            action = 'hydrate',
            payload = data,
            view = view or 'overview'
        })
    end)
end

local function setUndercoverState(state)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = model == GetHashKey('mp_m_freemode_01')

    undercover = state
    if state then
        local outfit = isMale and Config.Outfits.male or Config.Outfits.female
        for k, v in pairs(outfit) do
            TriggerEvent('qb-clothing:client:loadOutfit', { [k] = { item = v, texture = 0 } })
        end
        LocalPlayer.state:set('radioDisabled', true, true)
        TriggerServerEvent('qb-fbi:server:setUndercover', true)
        QBCore.Functions.Notify('تم تفعيل الهوية السرية.', 'success')
    else
        TriggerServerEvent('qb-fbi:server:setUndercover', false)
        LocalPlayer.state:set('radioDisabled', false, true)
        QBCore.Functions.Notify('تمت استعادة الهوية الرسمية.', 'primary')
    end
end

RegisterNetEvent('qb-fbi:client:openCaseBoard', function()
    openTerminal('cases')
end)

RegisterNetEvent('qb-fbi:client:openIntel', function()
    openTerminal('overview')
end)

RegisterCommand('fbi', function(_, args)
    local subCommand = args[1]
    if subCommand == 'undercover' then
        if not hasPermission('canViewAllCases') then
            QBCore.Functions.Notify('أنت غير تابع لـ FBI.', 'error')
            return
        end

        local currentTime = GetGameTimer()
        if currentTime < undercoverExpires then
            local sec = math.ceil((undercoverExpires - currentTime) / 1000)
            QBCore.Functions.Notify(('انتظر %s ثانية قبل تغيير الهوية.'):format(sec), 'error')
            return
        end

        setUndercoverState(not undercover)
        undercoverExpires = currentTime + (Config.UndercoverCooldown * 1000)
    else
        openTerminal('overview')
    end
end, false)

RegisterNUICallback('close', function(_, cb)
    setNuiState(false)
    cb('ok')
end)

RegisterNUICallback('createCase', function(data, cb)
    TriggerServerEvent('qb-fbi:server:createCase', data)
    cb('ok')
end)

RegisterNUICallback('startOperation', function(data, cb)
    TriggerServerEvent('qb-fbi:server:startOperation', data)
    cb('ok')
end)

RegisterNUICallback('reviewApproval', function(data, cb)
    TriggerServerEvent('qb-fbi:server:reviewApproval', data)
    cb('ok')
end)

RegisterNUICallback('advanceRaid', function(data, cb)
    TriggerServerEvent('qb-fbi:server:advanceRaid', data.caseId)
    cb('ok')
end)

RegisterNUICallback('requestDataRefresh', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getDashboardData', function(resp)
        cb(resp)
    end)
end)

RegisterNetEvent('qb-fbi:client:notify', function(msg, notifyType)
    QBCore.Functions.Notify(msg, notifyType or 'primary')
end)

RegisterNetEvent('qb-fbi:client:syncDashboard', function(payload)
    SendNUIMessage({
        action = 'hydrate',
        payload = payload,
        view = isOpen and nil or 'cases'
    })
end)

CreateThread(function()
    for zoneName, zone in pairs(Config.TargetZones) do
        exports['qb-target']:AddBoxZone(('fbi_%s'):format(zoneName), zone.coords, zone.size.x, zone.size.y, {
            name = ('fbi_%s'):format(zoneName),
            heading = zone.heading,
            debugPoly = false,
            minZ = zone.coords.z - 1.0,
            maxZ = zone.coords.z + 1.0
        }, {
            options = {
                {
                    icon = zone.icon,
                    label = zone.label,
                    job = Config.JobName,
                    action = function()
                        if zoneName == 'command_terminal' then
                            TriggerEvent('qb-fbi:client:openIntel')
                        else
                            TriggerEvent('qb-fbi:client:openCaseBoard')
                        end
                    end
                }
            },
            distance = 2.0
        })
    end
end)
