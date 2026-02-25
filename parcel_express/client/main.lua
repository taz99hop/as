local QBCore = exports['qb-core']:GetCoreObject()

Parcel = Parcel or {}
Parcel.PlayerData = {}
Parcel.State = {
    onDuty = false,
    hasVehicle = false,
    carrying = false,
    activeRoute = nil,
    packagesLoaded = 0,
    delivered = 0,
    earnings = 0,
    rating = 5,
    level = 1,
    dutyVehicle = nil,
    dutyPlate = nil,
    weatherMultiplier = 1.0,
    managerBlips = {}
}

local function isParcelJob()
    return Parcel.PlayerData.job and Parcel.PlayerData.job.name == Config.JobName
end

local function isManager()
    return isParcelJob() and Parcel.PlayerData.job.grade and (Parcel.PlayerData.job.grade.level or 0) >= 1
end

local function notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or 'primary')
end

local function openTablet()
    if not isParcelJob() then
        return notify('هذه الواجهة خاصة بموظفي Parcel Express فقط.', 'error')
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = Shared.NUIActions.OPEN,
        payload = {
            onDuty = Parcel.State.onDuty,
            delivered = Parcel.State.delivered,
            earnings = Parcel.State.earnings,
            rating = Parcel.State.rating,
            level = Parcel.State.level,
            onlineDrivers = 0,
            isManager = isManager(),
            playerName = (Parcel.PlayerData.charinfo and (Parcel.PlayerData.charinfo.firstname .. ' ' .. Parcel.PlayerData.charinfo.lastname)) or 'موظف'
        }
    })

    TriggerServerEvent('parcel_express:server:requestTabletData')
end

local function closeTablet()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = Shared.NUIActions.CLOSE })
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Parcel.PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    Parcel.PlayerData.job = job
    if job.name ~= Config.JobName then
        TriggerEvent('parcel_express:client:forceCleanup', true)
    end
end)

CreateThread(function()
    Parcel.PlayerData = QBCore.Functions.GetPlayerData()

    exports['qb-target']:AddBoxZone('parcel_express_duty', Config.Warehouse.duty, 1.2, 1.2, {
        name = 'parcel_express_duty',
        heading = 0,
        debugPoly = Config.Debug,
        minZ = Config.Warehouse.duty.z - 1.0,
        maxZ = Config.Warehouse.duty.z + 1.4
    }, {
        options = {
            {
                label = 'فتح تابلت العمل',
                icon = Config.Target.iconDuty,
                action = function()
                    openTablet()
                end,
                canInteract = function()
                    return isParcelJob()
                end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('parcel_express_manager', Config.Warehouse.managerDesk, 1.1, 1.1, {
        name = 'parcel_express_manager',
        heading = 0,
        debugPoly = Config.Debug,
        minZ = Config.Warehouse.managerDesk.z - 1.0,
        maxZ = Config.Warehouse.managerDesk.z + 1.3
    }, {
        options = {
            {
                label = 'لوحة المدير',
                icon = Config.Target.iconManager,
                action = function()
                    openTablet()
                end,
                canInteract = function()
                    return isManager()
                end
            }
        },
        distance = 2.0
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('parcel_express:server:toggleDuty')
    cb('ok')
end)

RegisterNUICallback('requestManagerData', function(_, cb)
    if isManager() then
        TriggerServerEvent('parcel_express:server:managerRequestData')
    end
    cb('ok')
end)

RegisterNUICallback('managerAction', function(data, cb)
    if isManager() then
        TriggerServerEvent('parcel_express:server:managerAction', data)
    end
    cb('ok')
end)

RegisterNetEvent('parcel_express:client:updateDutyState', function(state)
    Parcel.State.onDuty = state
    if not state then
        TriggerEvent('parcel_express:client:forceCleanup', false)
    end

    SendNUIMessage({
        action = Shared.NUIActions.UPDATE,
        payload = {
            onDuty = Parcel.State.onDuty,
            delivered = Parcel.State.delivered,
            earnings = Parcel.State.earnings,
            rating = Parcel.State.rating,
            level = Parcel.State.level
        }
    })

    notify(state and 'تم تسجيل الدخول إلى الدوام بنجاح.' or 'تم تسجيل الخروج من الدوام.', state and 'success' or 'primary')
end)

RegisterNetEvent('parcel_express:client:tabletData', function(data)
    Parcel.State.delivered = data.delivered or Parcel.State.delivered
    Parcel.State.earnings = data.earnings or Parcel.State.earnings
    Parcel.State.rating = data.rating or Parcel.State.rating
    Parcel.State.level = data.level or Parcel.State.level

    SendNUIMessage({
        action = Shared.NUIActions.UPDATE,
        payload = {
            onDuty = Parcel.State.onDuty,
            delivered = Parcel.State.delivered,
            earnings = Parcel.State.earnings,
            rating = Parcel.State.rating,
            level = Parcel.State.level,
            onlineDrivers = data.onlineDrivers or 0,
            activeTasks = data.activeTasks or 0,
            dayProfit = data.dayProfit or 0
        }
    })

    if data.manager then
        SendNUIMessage({
            action = Shared.NUIActions.MANAGER,
            payload = data.manager
        })
    end
end)

RegisterNetEvent('parcel_express:client:notify', function(message, messageType)
    notify(message, messageType)
end)

RegisterNetEvent('parcel_express:client:updateStats', function(payload)
    Parcel.State.delivered = payload.delivered
    Parcel.State.earnings = payload.earnings
    Parcel.State.rating = payload.rating
    Parcel.State.level = payload.level

    SendNUIMessage({
        action = Shared.NUIActions.UPDATE,
        payload = {
            delivered = payload.delivered,
            earnings = payload.earnings,
            rating = payload.rating,
            level = payload.level,
            onDuty = Parcel.State.onDuty
        }
    })
end)

RegisterCommand('parcel', function()
    openTablet()
end, false)

RegisterKeyMapping('parcel', 'فتح تابلت Parcel Express', 'keyboard', 'F6')

RegisterNetEvent('parcel_express:client:updateDriverBlips', function(drivers)
    for sourceId, blip in pairs(Parcel.State.managerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        Parcel.State.managerBlips[sourceId] = nil
    end

    if not isManager() then return end

    for _, data in pairs(drivers) do
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 3)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('سائق: %s'):format(data.name))
        EndTextCommandSetBlipName(blip)
        Parcel.State.managerBlips[data.source] = blip
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        if isManager() and Parcel.State.onDuty then
            TriggerServerEvent('parcel_express:server:managerTrackDrivers')
        end
    end
end)
