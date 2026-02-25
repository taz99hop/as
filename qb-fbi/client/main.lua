local QBCore = exports['qb-core']:GetCoreObject()

local isOpen = false
local k9Dog = nil
local droneCam = nil
local bridgeCamIndex = 1
local spawnedPursuitObjects = {}

local function canOpen()
    local playerData = QBCore.Functions.GetPlayerData()
    return playerData.job and playerData.job.name == Config.JobName
end

local function loadModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(modelHash) then return nil end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(modelHash) then return nil end
    return modelHash
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

local function getClosestNonCopPed(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local bestPed, bestDistance = nil, maxDistance or 60.0

    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= playerPed and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, false) then
            local pedType = GetPedType(ped)
            if pedType ~= 6 and pedType ~= 27 and pedType ~= 29 then
                local dist = #(GetEntityCoords(ped) - playerCoords)
                if dist < bestDistance then
                    bestDistance = dist
                    bestPed = ped
                end
            end
        end
    end

    return bestPed
end

local function ensureK9()
    if k9Dog and DoesEntityExist(k9Dog) then
        return k9Dog
    end

    local model = loadModel(Config.K9.model)
    if not model then
        QBCore.Functions.Notify('فشل تحميل موديل K9.', 'error')
        return nil
    end

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    k9Dog = CreatePed(28, model, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, true)
    SetEntityAsMissionEntity(k9Dog, true, true)
    SetPedAsCop(k9Dog, true)
    SetPedSeeingRange(k9Dog, 80.0)
    SetPedHearingRange(k9Dog, 80.0)
    SetPedCanRagdoll(k9Dog, false)
    SetPedFleeAttributes(k9Dog, 0, false)
    SetPedCombatAbility(k9Dog, 2)
    SetPedCombatRange(k9Dog, 2)

    TaskFollowToOffsetOfEntity(k9Dog, ped, 0.0, 1.0, 0.0, 3.0, -1, 2.0, true)
    SetModelAsNoLongerNeeded(model)
    return k9Dog
end

local function clearPursuitObjects()
    for _, entity in ipairs(spawnedPursuitObjects) do
        if DoesEntityExist(entity) then
            DeleteObject(entity)
        end
    end
    spawnedPursuitObjects = {}
end

local function spawnBackupUnit(offsetX, offsetY)
    local vehModel = loadModel(Config.Dispatch.backupVehicle)
    local pedModel = loadModel(Config.Dispatch.backupPed)
    if not vehModel or not pedModel then
        QBCore.Functions.Notify('تعذر تحميل وحدات الدعم.', 'error')
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, offsetX, offsetY, 0.0)
    local heading = GetEntityHeading(playerPed)

    local vehicle = CreateVehicle(vehModel, coords.x, coords.y, coords.z, heading, true, true)
    local driver = CreatePedInsideVehicle(vehicle, 6, pedModel, -1, true, true)
    local passenger = CreatePedInsideVehicle(vehicle, 6, pedModel, 0, true, true)

    SetVehicleSiren(vehicle, true)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetPedAsCop(driver, true)
    SetPedAsCop(passenger, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetBlockingOfNonTemporaryEvents(passenger, true)

    local target = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 25.0, 0.0)
    TaskVehicleDriveToCoordLongrange(driver, vehicle, target.x, target.y, target.z, 35.0, 447, 15.0)

    SetModelAsNoLongerNeeded(vehModel)
    SetModelAsNoLongerNeeded(pedModel)
end

local function stopDroneCam()
    if droneCam then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(droneCam, false)
        droneCam = nil
    end
end

RegisterCommand(Config.CommandName, function()
    openHub()
end, false)

RegisterCommand('policehub_clear', function()
    stopDroneCam()
    clearPursuitObjects()
    if k9Dog and DoesEntityExist(k9Dog) then
        DeleteEntity(k9Dog)
        k9Dog = nil
    end
    QBCore.Functions.Notify('تم تنظيف أدوات العمليات الميدانية.', 'success')
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

RegisterNetEvent('qb-fbi:client:spawnBackupUnits', function()
    spawnBackupUnit(-12.0, -30.0)
    Wait(350)
    spawnBackupUnit(12.0, -30.0)
end)

RegisterNetEvent('qb-fbi:client:startDroneMode', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if droneCam then
        stopDroneCam()
        QBCore.Functions.Notify('تم إيقاف كاميرا الدرون.', 'primary')
        return
    end

    droneCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(droneCam, coords.x, coords.y, coords.z + 35.0)
    PointCamAtCoord(droneCam, coords.x, coords.y, coords.z)
    SetCamActive(droneCam, true)
    RenderScriptCams(true, true, 550, true, true)

    QBCore.Functions.Notify('كاميرا الدرون مفعلة. استخدم زر التسجيل مرة أخرى للإغلاق.', 'success')

    CreateThread(function()
        while droneCam do
            local current = GetEntityCoords(PlayerPedId())
            SetCamCoord(droneCam, current.x, current.y, current.z + 35.0)
            PointCamAtCoord(droneCam, current.x, current.y, current.z)
            Wait(500)
        end
    end)
end)

RegisterNetEvent('qb-fbi:client:executeK9Command', function(command)
    local dog = ensureK9()
    if not dog then return end

    local officer = PlayerPedId()
    if command == 'تتبع مسار' then
        local targetPed = getClosestNonCopPed(70.0)
        if targetPed then
            TaskGoToEntity(dog, targetPed, -1, 1.5, 4.0, 1073741824, 0)
            QBCore.Functions.Notify('K9 يتتبع أقرب مشتبه ميدانياً.', 'success')
        else
            TaskFollowToOffsetOfEntity(dog, officer, 0.0, 1.2, 0.0, 3.0, -1, 2.0, true)
            QBCore.Functions.Notify('لا يوجد هدف قريب للتتبع.', 'error')
        end
    elseif command == 'كشف مخدرات' then
        TaskStartScenarioInPlace(dog, 'WORLD_DOG_SNIFFING', 0, true)
        QBCore.Functions.Notify('K9 يقوم بفحص ميداني للمنطقة.', 'primary')
        Wait(5000)
        ClearPedTasks(dog)
        TaskFollowToOffsetOfEntity(dog, officer, 0.0, 1.2, 0.0, 3.0, -1, 2.0, true)
    elseif command == 'بحث مفقود' then
        local searchPos = GetOffsetFromEntityInWorldCoords(officer, 0.0, 40.0, 0.0)
        TaskGoStraightToCoord(dog, searchPos.x, searchPos.y, searchPos.z, 4.0, 15000, 0.0, 0.0)
        QBCore.Functions.Notify('K9 بدأ مسار بحث عن مفقود.', 'success')
    else
        TaskFollowToOffsetOfEntity(dog, officer, 0.0, 1.2, 0.0, 3.0, -1, 2.0, true)
    end
end)

RegisterNetEvent('qb-fbi:client:deployPursuitTool', function(tool)
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 6.0, 0.0)
    local heading = GetEntityHeading(ped)

    if tool == 'Spike Strip' then
        local model = loadModel(Config.Pursuit.spikeModel)
        if not model then
            QBCore.Functions.Notify('فشل تحميل سبايك ستريب.', 'error')
            return
        end

        local spike = CreateObject(model, coords.x, coords.y, coords.z - 1.0, true, true, true)
        SetEntityHeading(spike, heading)
        FreezeEntityPosition(spike, true)
        table.insert(spawnedPursuitObjects, spike)
        SetModelAsNoLongerNeeded(model)
        QBCore.Functions.Notify('تم نشر سبايك ستريب بالموقع.', 'success')
    elseif tool == 'Road Block' then
        local vModel = loadModel(Config.Pursuit.roadBlockVehicle)
        local pModel = loadModel(Config.Dispatch.backupPed)
        if not vModel or not pModel then
            QBCore.Functions.Notify('فشل نشر الحاجز المروري.', 'error')
            return
        end

        for i = -1, 1 do
            local vCoords = GetOffsetFromEntityInWorldCoords(ped, i * 4.0, 8.0, 0.0)
            local veh = CreateVehicle(vModel, vCoords.x, vCoords.y, vCoords.z, heading + 90.0, true, true)
            local cop = CreatePedInsideVehicle(veh, 6, pModel, -1, true, true)
            FreezeEntityPosition(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleSiren(veh, true)
            SetBlockingOfNonTemporaryEvents(cop, true)
            table.insert(spawnedPursuitObjects, veh)
        end

        SetModelAsNoLongerNeeded(vModel)
        SetModelAsNoLongerNeeded(pModel)
        QBCore.Functions.Notify('تم إنشاء حاجز مروري كامل.', 'success')
    else
        local model = loadModel(Config.Pursuit.barrierModel)
        if not model then
            QBCore.Functions.Notify('فشل تحميل الحاجز المتحرك.', 'error')
            return
        end

        local barrier = CreateObject(model, coords.x, coords.y, coords.z - 1.0, true, true, true)
        SetEntityHeading(barrier, heading)
        PlaceObjectOnGroundProperly(barrier)
        table.insert(spawnedPursuitObjects, barrier)
        SetModelAsNoLongerNeeded(model)
        QBCore.Functions.Notify('تم إسقاط حاجز متحرك.', 'success')
    end
end)

RegisterNetEvent('qb-fbi:client:viewBridgeCam', function()
    if not Config.DroneBridgeCams[bridgeCamIndex] then
        bridgeCamIndex = 1
    end

    local camData = Config.DroneBridgeCams[bridgeCamIndex]
    bridgeCamIndex = bridgeCamIndex + 1

    stopDroneCam()
    droneCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(droneCam, camData.pos.x, camData.pos.y, camData.pos.z)
    PointCamAtCoord(droneCam, camData.lookAt.x, camData.lookAt.y, camData.lookAt.z)
    SetCamActive(droneCam, true)
    RenderScriptCams(true, true, 500, true, true)
    QBCore.Functions.Notify('تم فتح كاميرا الجسر. استخدم /policehub_clear للإغلاق.', 'primary')
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
                },
                {
                    icon = 'fas fa-video',
                    label = 'فتح كاميرات الجسور',
                    job = Config.JobName,
                    action = function()
                        TriggerEvent('qb-fbi:client:viewBridgeCam')
                    end
                }
            },
            distance = 2.0
        })
    end
end)
