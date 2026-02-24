local QBCore = exports['qb-core']:GetCoreObject()

local nuiOpen = false
local jammerActive = false
local domeEnabled = true
local domeAuto = true
local currentMission = nil

local function isArmy(playerData)
    return playerData and playerData.job and playerData.job.name == Config.JobName
end

local function getGrade(playerData)
    return playerData.job and playerData.job.grade and (playerData.job.grade.level or playerData.job.grade) or 0
end

local function hasPerm(key)
    local pd = QBCore.Functions.GetPlayerData()
    if not isArmy(pd) then return false end
    local grade = getGrade(pd)
    if grade >= Config.CommanderGrade then return true end
    local rank = Config.Ranks[grade]
    if not rank or not rank.permissions then return false end
    return rank.permissions.all or rank.permissions[key] == true
end

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function setNui(open)
    nuiOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = 'toggle', state = open })
end

local function buildMissionList()
    local list = {}
    for _, m in ipairs(Config.Missions) do
        list[#list + 1] = m
    end
    return list
end

local function openPanel()
    if not hasPerm('command') and not hasPerm('mission') then
        notify('ليست لديك صلاحية فتح لوحة القيادة.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('qb-army:server:getDashboardData', function(data)
        data.missions = buildMissionList()
        SendNUIMessage({ action = 'hydrate', payload = data })
        setNui(true)
    end)
end

local function spawnExplosionFx(coords)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 2.0, false, false, false)
    AddExplosion(coords.x, coords.y, coords.z, 29, 30.0, true, false, 1.0)
end

RegisterNetEvent('qb-army:client:missileIncoming', function(target)
    local myPos = GetEntityCoords(PlayerPedId())
    local dist = #(myPos - vector3(target.x, target.y, target.z))
    if dist <= Config.AlertRange then
        notify('تحذير: ضربة صاروخية خلال 5 ثوانٍ! ابتعد عن المنطقة.', 'error')
        PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', false)
    end
end)

RegisterNetEvent('qb-army:client:executeMissile', function(target, intercepted)
    if intercepted then
        spawnExplosionFx(vector3(target.x, target.y, target.z + 25.0))
        notify('تم اعتراض التهديد جواً بواسطة القبة الحديدية.', 'success')
        return
    end
    spawnExplosionFx(vector3(target.x, target.y, target.z))
end)

RegisterNetEvent('qb-army:client:setJammed', function(state, byName)
    SendNUIMessage({ action = 'jammed', state = state, by = byName })
    if state then
        notify('تم التشويش على الاتصالات القريبة.', 'error')
    else
        notify('تم إنهاء التشويش.', 'success')
    end
end)

CreateThread(function()
    exports['qb-target']:AddBoxZone('army_duty', Config.Base.zones.duty, 1.0, 1.2, {
        name = 'army_duty', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.duty.z - 1.0, maxZ = Config.Base.zones.duty.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-user-shield',
                label = 'تسجيل دخول/خروج الخدمة',
                action = function() TriggerServerEvent('QBCore:ToggleDuty') end,
                canInteract = function() return isArmy(QBCore.Functions.GetPlayerData()) end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('army_armory', Config.Base.zones.armory, 1.2, 1.2, {
        name = 'army_armory', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.armory.z - 1.0, maxZ = Config.Base.zones.armory.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-gun',
                label = 'استلام العتاد العسكري',
                action = function() TriggerServerEvent('qb-army:server:requestLoadout') end,
                canInteract = function() return hasPerm('gear') end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('army_locker', Config.Base.zones.locker, 1.2, 1.2, {
        name = 'army_locker', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.locker.z - 1.0, maxZ = Config.Base.zones.locker.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-shirt', label = 'تغيير الزي العسكري',
                action = function() TriggerServerEvent('qb-army:server:applyUniform') end,
                canInteract = function() return hasPerm('uniform') end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('army_command', Config.Base.zones.command, 1.2, 1.2, {
        name = 'army_command', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.command.z - 1.0, maxZ = Config.Base.zones.command.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-display', label = 'لوحة القيادة العسكرية',
                action = openPanel,
                canInteract = function() return hasPerm('mission') or hasPerm('command') end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('army_missile', Config.Base.zones.missile, 1.2, 1.2, {
        name = 'army_missile', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.missile.z - 1.0, maxZ = Config.Base.zones.missile.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-crosshairs', label = 'وحدة إطلاق الصواريخ',
                action = function() SendNUIMessage({ action = 'showMissileModal' }); openPanel() end,
                canInteract = function() return hasPerm('missile') end
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone('army_dome', Config.Base.zones.dome, 1.2, 1.2, {
        name = 'army_dome', heading = 0.0, debugPoly = false, minZ = Config.Base.zones.dome.z - 1.0, maxZ = Config.Base.zones.dome.z + 1.0
    }, {
        options = {
            {
                icon = 'fas fa-shield-halved', label = 'إعدادات القبة الحديدية',
                action = function()
                    if not hasPerm('dome') then return end
                    domeEnabled = not domeEnabled
                    TriggerServerEvent('qb-army:server:setDomeState', domeEnabled, domeAuto)
                    notify(domeEnabled and 'تم تفعيل القبة الحديدية.' or 'تم تعطيل القبة الحديدية.', domeEnabled and 'success' or 'error')
                end,
                canInteract = function() return hasPerm('dome') end
            }
        },
        distance = 2.0
    })
end)

RegisterNUICallback('close', function(_, cb)
    setNui(false)
    cb('ok')
end)

RegisterNUICallback('startMission', function(data, cb)
    if not hasPerm('mission') then cb(false) return end
    currentMission = data.id
    TriggerServerEvent('qb-army:server:startMission', data.id)
    cb(true)
end)

RegisterNUICallback('completeMission', function(data, cb)
    TriggerServerEvent('qb-army:server:completeMission', data.id)
    currentMission = nil
    cb(true)
end)

RegisterNUICallback('launchMissile', function(data, cb)
    if not hasPerm('missile') then cb(false) return end
    local target = {
        x = tonumber(data.x),
        y = tonumber(data.y),
        z = tonumber(data.z)
    }
    if not target.x or not target.y or not target.z then cb(false) return end
    TriggerServerEvent('qb-army:server:launchMissile', target)
    cb(true)
end)

RegisterNUICallback('toggleDomeMode', function(data, cb)
    if not hasPerm('dome') then cb(false) return end
    domeAuto = data.auto == true
    TriggerServerEvent('qb-army:server:setDomeState', domeEnabled, domeAuto)
    cb(true)
end)

RegisterNUICallback('refreshDashboard', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-army:server:getDashboardData', function(payload)
        payload.missions = buildMissionList()
        cb(payload)
    end)
end)

RegisterCommand('nightvision', function()
    if not hasPerm('gear') then return end
    SetNightvision(not GetUsingnightvision())
    notify('تم تبديل الرؤية الليلية.')
end)

RegisterCommand('thermal', function()
    if not hasPerm('gear') then return end
    SetSeethrough(not IsSeethroughActive())
    notify('تم تبديل الرؤية الحرارية.')
end)

RegisterCommand('laser', function()
    if not hasPerm('gear') then return end
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    SetFlashLightFadeDistance(50.0)
    DrawSpotLight(GetEntityCoords(ped), GetGameplayCamRot(2), 255, 0, 0, 10.0, 30.0, 30.0, 10.0, 1.0)
    notify(('تم تفعيل المؤشر الليزري على السلاح: %s'):format(weapon))
end)

RegisterCommand('jamming', function()
    if not hasPerm('jam') then return end
    jammerActive = not jammerActive
    TriggerServerEvent('qb-army:server:setJamming', jammerActive)
    notify(jammerActive and 'تم تفعيل التشويش الإلكتروني.' or 'تم إيقاف التشويش الإلكتروني.')
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not nuiOpen or not hasPerm('radar') then goto continue end

        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local entities = {}
        for _, playerId in ipairs(GetActivePlayers()) do
            local targetPed = GetPlayerPed(playerId)
            local coords = GetEntityCoords(targetPed)
            local dist = #(coords - pcoords)
            if dist <= Config.RadarRange and targetPed ~= ped then
                local serverId = GetPlayerServerId(playerId)
                entities[#entities + 1] = {
                    id = serverId,
                    x = coords.x - pcoords.x,
                    y = coords.y - pcoords.y,
                    ally = true
                }
            end
        end

        local veh = GetClosestVehicle(pcoords.x, pcoords.y, pcoords.z, Config.RadarRange, 0, 70)
        if veh ~= 0 then
            local vcoords = GetEntityCoords(veh)
            entities[#entities + 1] = { id = 'veh', x = vcoords.x - pcoords.x, y = vcoords.y - pcoords.y, ally = false }
        end

        SendNUIMessage({ action = 'radar', entities = entities, range = Config.RadarRange })
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        if not nuiOpen then goto continue end
        TriggerServerEvent('qb-army:server:requestTroopTracking')
        ::continue::
    end
end)

RegisterNetEvent('qb-army:client:troopTracking', function(units)
    SendNUIMessage({ action = 'troops', units = units })
end)

RegisterNetEvent('qb-army:client:notify', function(msg, typ)
    notify(msg, typ)
end)
