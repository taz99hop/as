local QBCore = exports['qb-core']:GetCoreObject()

local isOpen = false

local function canOpen()
    local playerData = QBCore.Functions.GetPlayerData()
    return playerData.job and playerData.job.name == Config.JobName
end

local function setNuiState(state)
    isOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'toggle', state = state })
end

local function openHub()
    if not canOpen() then
        QBCore.Functions.Notify('هذا النظام مخصص للشرطة فقط.', 'error')
        return
    end

    setNuiState(true)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getDashboardData', function(payload)
        SendNUIMessage({ action = 'hydrate', payload = payload })
    end)
end

RegisterCommand(Config.CommandName, function()
    openHub()
end, false)

RegisterNUICallback('close', function(_, cb)
    setNuiState(false)
    cb('ok')
end)

RegisterNUICallback('runAction', function(data, cb)
    TriggerServerEvent('qb-fbi:server:runAction', data)
    cb('ok')
end)

RegisterNUICallback('createCase', function(data, cb)
    TriggerServerEvent('qb-fbi:server:createCase', data)
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getDashboardData', function(resp)
        cb(resp)
    end)
end)

RegisterNetEvent('qb-fbi:client:notify', function(msg, notifyType)
    QBCore.Functions.Notify(msg, notifyType or 'primary')
end)

RegisterNetEvent('qb-fbi:client:syncDashboard', function(payload)
    if isOpen then
        SendNUIMessage({ action = 'hydrate', payload = payload })
    end
end)

CreateThread(function()
    for zoneName, zone in pairs(Config.TargetZones) do
        exports['qb-target']:AddBoxZone(('police_hub_%s'):format(zoneName), zone.coords, zone.size.x, zone.size.y, {
            name = ('police_hub_%s'):format(zoneName),
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
                        openHub()
                    end
                }
            },
            distance = 2.0
        })
    end
end)
