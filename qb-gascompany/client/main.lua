local QBCore = exports['qb-core']:GetCoreObject()

local state = {
    onDuty = false,
    truck = nil,
    trailer = nil,
    truckNetId = nil,
    trailerNetId = nil,
    gasUnits = 0,
    mission = nil,
    missionQueue = {},
    missionBlip = nil,
    npc = nil,
    hasNozzle = false,
    nozzleProp = nil,
    stationObjects = {},
    stats = {
        completed = 0,
        earned = 0,
        totalGasUsed = 0,
    }
}

local function notify(msg, type)
    lib.notify({ description = msg, type = type or 'inform' })
end

local function syncGasState()
    LocalPlayer.state:set('gasUnits', state.gasUnits, true)
    SendNUIMessage({ action = 'tankHud', data = { liters = state.gasUnits, max = Config.Truck.maxGasUnits } })
end

local function syncTruckState()
    LocalPlayer.state:set('gasTruckActive', state.truck and DoesEntityExist(state.truck) or false, true)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

local function showHelp(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, 1)
end

local function removeMissionBlip()
    if state.missionBlip and DoesBlipExist(state.missionBlip) then
        RemoveBlip(state.missionBlip)
    end
    state.missionBlip = nil
end

local function deleteMissionNpc()
    if state.npc and DoesEntityExist(state.npc) then
        DeletePed(state.npc)
    end
    state.npc = nil
end

local function cleanupObjects()
    for _, obj in pairs(state.stationObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    state.stationObjects = {}
end

local function detachNozzle()
    if state.nozzleProp and DoesEntityExist(state.nozzleProp) then
        DeleteObject(state.nozzleProp)
    end
    state.nozzleProp = nil
    state.hasNozzle = false
end

local function stopDuty(clearTruck)
    state.onDuty = false
    removeMissionBlip()
    deleteMissionNpc()
    detachNozzle()
    state.mission = nil
    state.missionQueue = {}

    if clearTruck then
        if state.truck and DoesEntityExist(state.truck) then DeleteVehicle(state.truck) end
        if state.trailer and DoesEntityExist(state.trailer) then DeleteVehicle(state.trailer) end
    end

    state.truck = nil
    state.trailer = nil
    state.truckNetId = nil
    state.trailerNetId = nil
    state.gasUnits = 0

    syncTruckState()
    SendNUIMessage({ action = 'tankHudHide' })
    syncGasState()
    LocalPlayer.state:set('gasDuty', false, true)
    TriggerServerEvent('qb-gascompany:server:setDuty', false)
end

local function setUniform(enable)
    local gender = QBCore.Functions.GetPlayerData().charinfo.gender
    local skin = gender == 0 and Config.Uniform.male or Config.Uniform.female

    if enable then
        TriggerEvent('qb-clothing:client:loadOutfit', skin)
    else
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    end
end

local function drawHubObjects()
    cleanupObjects()
    local tankHash = loadModel(Config.Objects.stationTank)
    local standHash = loadModel(Config.Objects.hoseStand)
    local coneHash = loadModel(Config.Objects.cone)

    if tankHash then
        local tank = CreateObjectNoOffset(tankHash, Config.Duty.hub.x + 1.9, Config.Duty.hub.y + 2.3, Config.Duty.hub.z - 1.0, false, false, false)
        FreezeEntityPosition(tank, true)
        table.insert(state.stationObjects, tank)
    end

    if standHash then
        local stand = CreateObjectNoOffset(standHash, Config.Duty.hub.x - 1.4, Config.Duty.hub.y + 0.8, Config.Duty.hub.z - 1.0, false, false, false)
        FreezeEntityPosition(stand, true)
        table.insert(state.stationObjects, stand)
    end

    if coneHash then
        for i = 1, 2 do
            local cone = CreateObjectNoOffset(coneHash, Config.Duty.hub.x + i, Config.Duty.hub.y - 3.0, Config.Duty.hub.z - 1.0, false, false, false)
            FreezeEntityPosition(cone, true)
            table.insert(state.stationObjects, cone)
        end
    end

    SetModelAsNoLongerNeeded(tankHash)
    SetModelAsNoLongerNeeded(standHash)
    SetModelAsNoLongerNeeded(coneHash)
end

local function ensureTruckNearby()
    local ped = PlayerPedId()
    if not state.truck or not DoesEntityExist(state.truck) then
        notify('No active gas truck found.', 'error')
        return false
    end

    local dist = #(GetEntityCoords(ped) - GetEntityCoords(state.truck))
    if dist > 35.0 then
        notify('Get closer to your truck/trailer first.', 'error')
        return false
    end
    return true
end

local function createMissionPed(mission)
    deleteMissionNpc()
    local hash = loadModel(Config.Peds.model)
    if not hash then return end

    state.npc = CreatePed(4, hash, mission.coords.x, mission.coords.y, mission.coords.z - 1.0, mission.coords.w, false, false)
    SetEntityInvincible(state.npc, true)
    FreezeEntityPosition(state.npc, true)
    SetBlockingOfNonTemporaryEvents(state.npc, true)
    TaskStartScenarioInPlace(state.npc, Config.Peds.scenario, 0, true)
    SetModelAsNoLongerNeeded(hash)
end

local function createMissionBlip(mission)
    removeMissionBlip()
    local blip = AddBlipForCoord(mission.coords.x, mission.coords.y, mission.coords.z)
    SetBlipSprite(blip, 361)
    SetBlipScale(blip, 0.85)
    SetBlipColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Gas delivery: %s (%s/%s)'):format(mission.label, mission.index or 1, mission.total or 1))
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    state.missionBlip = blip
    SetNewWaypoint(mission.coords.x, mission.coords.y)
end

local function beginMission(mission)
    if not mission then return end
    mission.startedAt = GetGameTimer()
    state.mission = mission
    detachNozzle()
    createMissionPed(mission)
    createMissionBlip(mission)
    notify(('Go to %s (%s/%s).'):format(mission.label, mission.index or 1, mission.total or 1), 'success')
end

local function proceedNextMission()
    if #state.missionQueue > 0 then
        local nextMission = table.remove(state.missionQueue, 1)
        beginMission(nextMission)
    else
        state.mission = nil
        removeMissionBlip()
        deleteMissionNpc()
        notify('All selected delivery locations are complete.', 'success')
    end
end

local function applyVehicleKeyOwnership(veh, plate)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)

    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    TriggerEvent('qb-vehiclekeys:client:SetOwner', plate)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
end

local function spawnTruck()
    if state.truck and DoesEntityExist(state.truck) then
        notify('لديك شاحنة مسجلة بالفعل.', 'error')
        return
    end

    local truckModel = loadModel(Config.Truck.model)
    local trailerModel = loadModel(Config.Truck.trailerModel)
    if not truckModel or not trailerModel then return end

    local tCoords = Config.Duty.truckSpawn
    local trCoords = Config.Duty.trailerSpawn

    local truck = CreateVehicle(truckModel, tCoords.x, tCoords.y, tCoords.z, tCoords.w, true, true)
    local trailer = CreateVehicle(trailerModel, trCoords.x, trCoords.y, trCoords.z, trCoords.w, true, true)

    SetVehicleDirtLevel(truck, 0.0)
    SetVehicleDirtLevel(trailer, 0.0)

    local plate = ('GAS%03d'):format(math.random(100, 999))
    applyVehicleKeyOwnership(truck, plate)
    SetVehicleNumberPlateText(trailer, plate)
    AttachVehicleToTrailer(truck, trailer, 1.1)

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, truck, -1)
    SetVehicleEngineOn(truck, true, true, false)

    state.truck = truck
    state.trailer = trailer
    state.truckNetId = VehToNet(truck)
    state.trailerNetId = VehToNet(trailer)
    state.gasUnits = Config.Truck.maxGasUnits
    syncTruckState()
    syncGasState()

    TriggerServerEvent('qb-gascompany:server:registerTruck', state.truckNetId, state.trailerNetId)
    notify('تم استلام رأس شاحنة مع مقطورة غاز.', 'success')
end

local function refillTrailerTank()
    if not state.trailer or not DoesEntityExist(state.trailer) then
        notify('Spawn truck and trailer first.', 'error')
        return
    end

    if state.gasUnits >= Config.Truck.maxGasUnits then
        notify('Trailer tank already full.', 'inform')
        return
    end

    local done = lib.progressBar({
        duration = 4500,
        label = 'Refilling trailer tank...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true }
    })

    if done then
        state.gasUnits = Config.Truck.maxGasUnits
        syncGasState()
        notify('Trailer tank filled successfully.', 'success')
    end
end

RegisterNetEvent('qb-gascompany:client:spawnTruck', spawnTruck)
RegisterNetEvent('qb-gascompany:client:refillTrailerTank', refillTrailerTank)

RegisterNetEvent('qb-gascompany:client:startMissionBatch', function(missions)
    if not missions or #missions == 0 then
        notify('Mission data is invalid, ask admin to check config.', 'error')
        return
    end

    if not state.onDuty then
        notify('Start duty first.', 'error')
        return
    end

    if state.mission then
        notify('Finish your current mission first.', 'error')
        return
    end

    state.missionQueue = missions
    local first = table.remove(state.missionQueue, 1)
    beginMission(first)
end)

RegisterNetEvent('qb-gascompany:client:talkToNpc', function()
    if not state.mission or state.mission.talked then return end
    if not ensureTruckNearby() then return end

    TaskTurnPedToFaceEntity(state.npc, PlayerPedId(), 2000)
    Wait(650)
    state.mission.talked = true
    notify('Customer is waiting. Grab nozzle from trailer, then press E to fill.', 'inform')
end)

RegisterNetEvent('qb-gascompany:client:pickupNozzle', function()
    if not state.mission or not state.mission.talked then
        notify('Talk to customer first.', 'error')
        return
    end

    if state.hasNozzle then
        notify('You already hold the nozzle.', 'error')
        return
    end

    local ped = PlayerPedId()
    local hash = loadModel(Config.Tools.hoseProp)
    if not hash then return end

    state.nozzleProp = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(state.nozzleProp, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, 290.0, 70.0, 20.0, true, true, false, true, 1, true)
    state.hasNozzle = true
    SetModelAsNoLongerNeeded(hash)

    notify('Nozzle picked up. Return to customer and start filling.', 'success')
end)

RegisterNetEvent('qb-gascompany:client:startFill', function()
    if not state.mission or not state.mission.talked then return end
    if state.mission.filled then
        notify('Tank already filled. Confirm with customer.', 'inform')
        return
    end

    if not ensureTruckNearby() then return end
    if not state.hasNozzle then
        notify('Pick up nozzle from trailer first.', 'error')
        return
    end

    if not state.gasUnits or state.gasUnits < state.mission.use then
        notify('Trailer tank empty. Refill at company station.', 'error')
        return
    end

    local duration = 5500
    SendNUIMessage({ action = 'fillStart', data = { duration = duration, label = 'تعبئة الغاز للعميل' } })

    local done = lib.progressBar({
        duration = duration,
        label = 'Filling gas... ',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true }
    })

    SendNUIMessage({ action = 'fillEnd' })

    if done then
        state.mission.filled = true
        state.gasUnits = state.gasUnits - state.mission.use
        state.stats.totalGasUsed = state.stats.totalGasUsed + state.mission.use
        syncGasState()
        notify('تمت التعبئة. ارجع للمدني لاستلام الدفع.', 'success')
    else
        notify('تم إلغاء التعبئة.', 'error')
    end
end)

RegisterNetEvent('qb-gascompany:client:finishMission', function()
    if not state.mission or not state.mission.filled then
        notify('Finish filling first.', 'error')
        return
    end

    TriggerServerEvent('qb-gascompany:server:finishMission', {
        missionId = state.mission.id,
        truckNetId = state.truckNetId,
        trailerNetId = state.trailerNetId,
        gasUsed = state.mission.use
    })

    detachNozzle()
    deleteMissionNpc()
    proceedNextMission()
end)

RegisterNetEvent('qb-gascompany:client:missionRewarded', function(data)
    state.stats.completed = data.completed
    state.stats.earned = data.earned
    notify(('Customer paid $%s | Total shift: $%s'):format(data.payout, data.earned), 'success')
end)

RegisterNetEvent('qb-gascompany:client:setDuty', function(toggle)
    local playerJob = QBCore.Functions.GetPlayerData().job
    if not playerJob or playerJob.name ~= Config.JobName then
        notify('هذه النقطة خاصة بموظفي شركة الغاز.', 'error')
        return
    end

    if toggle and not state.onDuty then
        state.onDuty = true
        drawHubObjects()
        setUniform(true)
        LocalPlayer.state:set('gasDuty', true, true)
        TriggerServerEvent('qb-gascompany:server:setDuty', true)
        notify('تم بدء الدوام في شركة الغاز.', 'success')
    elseif not toggle and state.onDuty then
        stopDuty(false)
        LocalPlayer.state:set('gasDuty', false, true)
        setUniform(false)
        notify('تم إنهاء الدوام.', 'inform')
    end
end)

RegisterNetEvent('qb-gascompany:client:returnTruck', function()
    if not state.truck or not DoesEntityExist(state.truck) then
        notify('لا يوجد شاحنة لإرجاعها.', 'error')
        return
    end

    local playerPos = GetEntityCoords(PlayerPedId())
    if #(playerPos - Config.Duty.returnPoint) > 15.0 then
        notify('اذهب إلى نقطة إرجاع الشاحنة.', 'error')
        return
    end

    TriggerServerEvent('qb-gascompany:server:returnTruck', state.truckNetId)

    DeleteVehicle(state.truck)
    if state.trailer and DoesEntityExist(state.trailer) then DeleteVehicle(state.trailer) end

    state.truck = nil
    state.trailer = nil
    state.truckNetId = nil
    state.trailerNetId = nil
    state.gasUnits = 0
    syncTruckState()
    SendNUIMessage({ action = 'tankHudHide' })
    syncGasState()

    notify('تم إرجاع الشاحنة والمقطورة بنجاح.', 'success')
end)

RegisterNetEvent('qb-gascompany:client:openTruckTank', function()
    if state.trailer and DoesEntityExist(state.trailer) then
        SetVehicleDoorOpen(state.trailer, 5, false, false)
    end
end)

RegisterNetEvent('qb-gascompany:client:closeTruckTank', function()
    if state.trailer and DoesEntityExist(state.trailer) then
        SetVehicleDoorShut(state.trailer, 5, false)
    end
end)

RegisterNetEvent('qb-gascompany:client:missionRequested', function()
    notify('Mission request sent. Please wait...', 'inform')
end)

RegisterNetEvent('qb-gascompany:client:openPanel', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            onDuty = state.onDuty,
            stats = state.stats,
            gasUnits = state.gasUnits,
            mission = state.mission,
            queueCount = #state.missionQueue,
            minBatch = Config.Missions.minBatch or 1,
            maxBatch = Config.Missions.maxBatch or 5,
            isBoss = Config.BossGrades[(QBCore.Functions.GetPlayerData().job.grade.level or 0)] == true
        }
    })
end)

CreateThread(function()
    while true do
        local waitMs = 1000

        if state.onDuty and state.mission and state.npc and DoesEntityExist(state.npc) then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local npcPos = GetEntityCoords(state.npc)
            local dist = #(pos - npcPos)

            if dist <= 2.5 then
                waitMs = 0
                showHelp('Press ~INPUT_CONTEXT~ to interact with customer')
                if IsControlJustReleased(0, 38) then
                    if not state.mission.talked then
                        TriggerEvent('qb-gascompany:client:talkToNpc')
                    elseif not state.mission.filled then
                        TriggerEvent('qb-gascompany:client:startFill')
                    else
                        TriggerEvent('qb-gascompany:client:finishMission')
                    end
                    Wait(250)
                end
            end
        end

        if state.onDuty and state.mission and state.trailer and DoesEntityExist(state.trailer) and not state.hasNozzle then
            local pos = GetEntityCoords(PlayerPedId())
            local rearPos = GetOffsetFromEntityInWorldCoords(state.trailer, 0.0, -4.3, 0.1)
            local dist = #(pos - rearPos)
            if dist <= 2.1 then
                waitMs = 0
                DrawMarker(2, rearPos.x, rearPos.y, rearPos.z + 0.08, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 52, 211, 153, 180, false, true, 2, false, nil, nil, false)
                showHelp('Press ~INPUT_CONTEXT~ to grab nozzle from trailer')
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('qb-gascompany:client:pickupNozzle')
                    Wait(250)
                end
            end
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        if state.truck and DoesEntityExist(state.truck) and GetVehiclePedIsIn(ped, false) == state.truck then
            SendNUIMessage({ action = 'tankHudShow' })
            SendNUIMessage({ action = 'tankHud', data = { liters = state.gasUnits, max = Config.Truck.maxGasUnits } })
        else
            SendNUIMessage({ action = 'tankHudHide' })
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    cleanupObjects()
    stopDuty(true)
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end

    TriggerEvent('qb-gascompany:client:setupTargets')
    syncGasState()
    syncTruckState()

    CreateThread(function()
        while true do
            Wait(1000)
            if state.onDuty and state.mission then
                local elapsed = GetGameTimer() - (state.mission.startedAt or GetGameTimer())
                if elapsed > Config.AntiExploit.missionTimeout * 1000 then
                    notify('انتهى وقت المهمة.', 'error')
                    detachNozzle()
                    state.mission = nil
                    state.missionQueue = {}
                    removeMissionBlip()
                    deleteMissionNpc()
                    SendNUIMessage({ action = 'fillEnd' })
                end
            end
        end
    end)
end)
