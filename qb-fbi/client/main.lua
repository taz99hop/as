local QBCore = exports['qb-core']:GetCoreObject()

local isOpen = false
local dispatchData = {}
local panicActive = false
local currentStatus = 'Available'
local cameraHandle = nil
local cameraRot = 0.0
local cameraFov = 50.0
local lastShotsAt = 0
local lastCrashAt = 0
local lastWantedZoneAt = 0

local function isPoliceOnDuty()
    local data = QBCore.Functions.GetPlayerData()
    return data.job and data.job.name == Config.JobName and data.job.onduty == true
end

local function setNuiState(state)
    isOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'toggle', state = state })
end

local function notify(msg, kind)
    QBCore.Functions.Notify(msg, kind or 'primary')
end

local function openDispatch()
    if not isPoliceOnDuty() then
        notify('غرفة العمليات متاحة فقط لشرطة on-duty.', 'error')
        return
    end

    setNuiState(true)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getDispatchData', function(payload)
        if payload and payload.error then
            notify('غير مصرح بالدخول.', 'error')
            setNuiState(false)
            return
        end
        dispatchData = payload or {}
        SendNUIMessage({ action = 'hydrate', payload = dispatchData })
    end)
end

local function closeCameraView()
    if cameraHandle then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(cameraHandle, false)
        cameraHandle = nil
    end
end

local function openCityCamera(cam)
    closeCameraView()
    cameraHandle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cameraHandle, cam.pos.x, cam.pos.y, cam.pos.z)
    PointCamAtCoord(cameraHandle, cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
    cameraRot = GetCamRot(cameraHandle, 2).z
    cameraFov = 50.0
    SetCamFov(cameraHandle, cameraFov)
    SetCamActive(cameraHandle, true)
    RenderScriptCams(true, true, 500, true, true)

    CreateThread(function()
        while cameraHandle do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            if IsControlPressed(0, 174) then cameraRot = cameraRot + 0.7 end
            if IsControlPressed(0, 175) then cameraRot = cameraRot - 0.7 end
            if IsControlPressed(0, 172) then cameraFov = math.max(10.0, cameraFov - 0.6) end
            if IsControlPressed(0, 173) then cameraFov = math.min(80.0, cameraFov + 0.6) end
            SetCamRot(cameraHandle, -10.0, 0.0, cameraRot, 2)
            SetCamFov(cameraHandle, cameraFov)
            if IsControlJustPressed(0, 177) then
                closeCameraView()
                notify('تم إغلاق الكاميرا.', 'primary')
            end
            Wait(0)
        end
    end)
end

RegisterCommand(Config.CommandName, function()
    openDispatch()
end, false)

RegisterCommand('panic', function()
    if not isPoliceOnDuty() then return end

    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('qb-fbi:server:createIncident', {
        type = 'PANIC BUTTON',
        locationText = ('Emergency Ping %.1f %.1f'):format(coords.x, coords.y),
        description = 'Officer panic button pressed',
        priority = 'Critical',
        isPanic = true,
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })

    panicActive = true
    notify('تم إرسال نداء استغاثة لجميع الوحدات!', 'error')
end, false)
RegisterKeyMapping('panic', 'Police Panic Button', 'keyboard', 'F10')

RegisterNUICallback('close', function(_, cb)
    setNuiState(false)
    cb('ok')
end)

RegisterNUICallback('claimIncident', function(data, cb)
    TriggerServerEvent('qb-fbi:server:claimIncident', data.incidentId)
    cb('ok')
end)

RegisterNUICallback('closeIncident', function(data, cb)
    TriggerServerEvent('qb-fbi:server:closeIncident', data.incidentId)
    cb('ok')
end)

RegisterNUICallback('dispatchIncident', function(data, cb)
    TriggerServerEvent('qb-fbi:server:dispatchIncident', data)
    cb('ok')
end)

RegisterNUICallback('createIncident', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    data.coords = { x = coords.x, y = coords.y, z = coords.z }
    TriggerServerEvent('qb-fbi:server:createIncident', data)
    cb('ok')
end)

RegisterNUICallback('setStatus', function(data, cb)
    currentStatus = data.status or 'Available'
    cb('ok')
end)

RegisterNUICallback('setCityEmergency', function(data, cb)
    TriggerServerEvent('qb-fbi:server:setCityEmergency', data.state == true)
    cb('ok')
end)

RegisterNUICallback('openCamera', function(data, cb)
    for _, cam in ipairs(dispatchData.cameras or {}) do
        if cam.id == data.cameraId then
            openCityCamera(cam)
            break
        end
    end
    cb('ok')
end)

RegisterNUICallback('linkCamera', function(data, cb)
    TriggerServerEvent('qb-fbi:server:linkCamera', data)
    cb('ok')
end)

RegisterNUICallback('getHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-fbi:server:getHistory', function(rows)
        cb(rows)
    end, data)
end)

RegisterNetEvent('qb-fbi:client:notify', function(msg, t)
    notify(msg, t)
end)

RegisterNetEvent('qb-fbi:client:syncDispatchData', function(payload)
    dispatchData = payload
    if isOpen then
        SendNUIMessage({ action = 'hydrate', payload = payload })
    end
end)

RegisterNetEvent('qb-fbi:client:panicAlarm', function(incident)
    if not isPoliceOnDuty() then return end

    SendNUIMessage({ action = 'panicAlarm', payload = incident })
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    notify(('🚨 PANIC: %s'):format(incident and incident.id or 'INC'), 'error')
end)

RegisterNetEvent('qb-fbi:client:dispatchMessage', function(message, coords)
    if not isPoliceOnDuty() then return end

    notify(message, 'primary')
    if coords then
        SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.TelemetryTickMs)
        if isPoliceOnDuty() then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local speed = IsPedInAnyVehicle(ped, false) and (GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 3.6) or 0.0
            local status = currentStatus
            local pursuitPoint = nil

            if speed > 120.0 then
                status = 'Pursuit'
                pursuitPoint = { x = coords.x, y = coords.y, z = coords.z }
            end

            if panicActive then
                status = 'Emergency'
                panicActive = false
            end

            TriggerServerEvent('qb-fbi:server:updateTelemetry', {
                status = status,
                speed = speed,
                coords = { x = coords.x, y = coords.y, z = coords.z },
                panic = status == 'Emergency',
                signalLost = false,
                pursuitPoint = pursuitPoint
            })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(600)
        if isPoliceOnDuty() then
            local ped = PlayerPedId()
            local now = GetGameTimer()

            if IsPedShooting(ped) and now - lastShotsAt > (Config.AutoAlerts.gunshotCooldown * 1000) then
                local c = GetEntityCoords(ped)
                TriggerServerEvent('qb-fbi:server:autoAlert', {
                    type = 'Gunshot Alert',
                    locationText = ('Shots fired @ %.1f %.1f'):format(c.x, c.y),
                    description = 'إطلاق نار مرصود تلقائياً',
                    priority = 'High',
                    coords = { x = c.x, y = c.y, z = c.z }
                })
                lastShotsAt = now
            end

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if HasEntityCollidedWithAnything(veh) and now - lastCrashAt > (Config.AutoAlerts.collisionCooldown * 1000) then
                    local c = GetEntityCoords(veh)
                    local speed = GetEntitySpeed(veh) * 3.6
                    if speed > 60.0 then
                        TriggerServerEvent('qb-fbi:server:autoAlert', {
                            type = 'Major Collision',
                            locationText = ('Vehicle collision @ %.1f %.1f'):format(c.x, c.y),
                            description = 'حادث قوي تلقائي',
                            priority = 'Medium',
                            coords = { x = c.x, y = c.y, z = c.z }
                        })
                        lastCrashAt = now
                    end
                end
            end

            local c = GetEntityCoords(ped)
            local zone = Config.AutoAlerts.wantedZone
            local dist = #(c - zone.center)
            if dist < zone.radius and now - lastWantedZoneAt > (Config.AutoAlerts.wantedZoneCooldown * 1000) then
                TriggerServerEvent('qb-fbi:server:autoAlert', {
                    type = 'Wanted Zone Alert',
                    locationText = ('Sensitive Zone @ %.1f %.1f'):format(c.x, c.y),
                    description = 'دخول منطقة حساسة/مطلوب',
                    priority = 'High',
                    coords = { x = c.x, y = c.y, z = c.z }
                })
                lastWantedZoneAt = now
            end
        end
    end
end)

CreateThread(function()
    local zone = Config.DispatchCenter
    exports['qb-target']:AddBoxZone('smartdispatch_command', zone.coords, zone.size.x, zone.size.y, {
        name = 'smartdispatch_command',
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
                canInteract = function()
                    return isPoliceOnDuty()
                end,
                action = function()
                    openDispatch()
                end
            }
        },
        distance = 2.0
    })
end)
