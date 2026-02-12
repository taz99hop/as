local QBCore = exports['qb-core']:GetCoreObject()

local state = {
    onDuty = false,
    truck = nil,
    truckNetId = nil,
    gasUnits = 0,
    mission = nil,
    missionBlip = nil,
    npc = nil,
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

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
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

local function stopDuty(clearTruck)
    state.onDuty = false
    removeMissionBlip()
    deleteMissionNpc()
    state.mission = nil

    if clearTruck and state.truck and DoesEntityExist(state.truck) then
        DeleteVehicle(state.truck)
    end

    state.truck = nil
    state.truckNetId = nil
    state.gasUnits = 0

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

local function spawnTruck()
    if state.truck and DoesEntityExist(state.truck) then
        notify('لديك شاحنة مسجلة بالفعل.', 'error')
        return
    end

    local model = loadModel(Config.Truck.model)
    if not model then return end

    local coords = Config.Duty.truckSpawn
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, ('GAS%03d'):format(math.random(100, 999)))

    state.truck = veh
    state.truckNetId = VehToNet(veh)
    state.gasUnits = Config.Truck.maxGasUnits

    TriggerEvent('qb-gascompany:client:registerVehicleTarget', veh)

    TriggerServerEvent('qb-gascompany:server:registerTruck', state.truckNetId)
    notify('تم استلام شاحنة الغاز.', 'success')
end

RegisterNetEvent('qb-gascompany:client:spawnTruck', spawnTruck)

local function createMissionPed(mission)
    deleteMissionNpc()

    local hash = loadModel(Config.Peds.model)
    if not hash then return end

    state.npc = CreatePed(4, hash, mission.coords.x, mission.coords.y, mission.coords.z - 1.0, mission.coords.w, false, false)
    SetEntityInvincible(state.npc, true)
    FreezeEntityPosition(state.npc, true)
    SetBlockingOfNonTemporaryEvents(state.npc, true)
    TaskStartScenarioInPlace(state.npc, Config.Peds.scenario, 0, true)

    TriggerEvent('qb-gascompany:client:addNpcTarget', state.npc)

    SetModelAsNoLongerNeeded(hash)
end

local function createMissionBlip(mission)
    removeMissionBlip()
    local blip = AddBlipForCoord(mission.coords.x, mission.coords.y, mission.coords.z)
    SetBlipSprite(blip, 361)
    SetBlipScale(blip, 0.85)
    SetBlipColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('طلب غاز: %s'):format(mission.label))
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    state.missionBlip = blip
end

local function ensureTruckNearby()
    local ped = PlayerPedId()
    if not state.truck or not DoesEntityExist(state.truck) then
        notify('لا يوجد شاحنة فعالة.', 'error')
        return false
    end

    local dist = #(GetEntityCoords(ped) - GetEntityCoords(state.truck))
    if dist > 20.0 then
        notify('اقترب من شاحنة الغاز أولاً.', 'error')
        return false
    end
    return true
end

RegisterNetEvent('qb-gascompany:client:startMission', function(mission)
    if not state.onDuty then return end

    state.mission = mission
    createMissionBlip(mission)
    createMissionPed(mission)

    notify(('مهمة جديدة: %s | الكمية المطلوبة: %s'):format(mission.label, mission.use), 'success')
end)

RegisterNetEvent('qb-gascompany:client:talkToNpc', function()
    if not state.mission or state.mission.talked then return end
    if not ensureTruckNearby() then return end

    local ok = lib.progressBar({
        duration = 4000,
        label = 'التحدث مع المدني',
        canCancel = true,
        disable = { move = true, combat = true }
    })

    if ok then
        state.mission.talked = true
        notify('تم الاتفاق على تعبئة الغاز.', 'success')
    end
end)

RegisterNetEvent('qb-gascompany:client:openTruckTank', function()
    if not state.truck or not DoesEntityExist(state.truck) then return end
    SetVehicleDoorOpen(state.truck, 5, false, false)
    notify('تم فتح خزان الشاحنة.', 'inform')
end)

RegisterNetEvent('qb-gascompany:client:closeTruckTank', function()
    if not state.truck or not DoesEntityExist(state.truck) then return end
    SetVehicleDoorShut(state.truck, 5, false)
    notify('تم إغلاق خزان الشاحنة.', 'inform')
end)

RegisterNetEvent('qb-gascompany:client:startFill', function()
    if not state.mission or state.mission.filled or not state.mission.talked then return end
    if not ensureTruckNearby() then return end
    if state.gasUnits < state.mission.use then
        notify('كمية الغاز في الشاحنة غير كافية.', 'error')
        return
    end

    local ped = PlayerPedId()
    local hoseHash = loadModel(Config.Tools.hoseProp)
    local hose = CreateObject(hoseHash, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(hose, ped, GetPedBoneIndex(ped, 57005), 0.15, 0.02, -0.02, -130.0, 0.0, 0.0, true, true, false, true, 1, true)

    local ok = lib.progressBar({
        duration = math.max(6000, state.mission.use * 550),
        label = 'جاري تعبئة الغاز...',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can' }
    })

    DeleteObject(hose)
    SetModelAsNoLongerNeeded(hoseHash)

    if ok then
        state.mission.filled = true
        state.gasUnits = state.gasUnits - state.mission.use
        state.stats.totalGasUsed = state.stats.totalGasUsed + state.mission.use
        notify('تمت تعبئة الغاز بنجاح.', 'success')
    else
        notify('تم إلغاء التعبئة.', 'error')
    end
end)

RegisterNetEvent('qb-gascompany:client:finishMission', function()
    if not state.mission or not state.mission.filled then return end

    TriggerServerEvent('qb-gascompany:server:finishMission', {
        missionId = state.mission.id,
        truckNetId = state.truckNetId,
        gasUsed = state.mission.use
    })

    state.mission = nil
    removeMissionBlip()
    deleteMissionNpc()
end)

RegisterNetEvent('qb-gascompany:client:missionRewarded', function(data)
    state.stats.completed = data.completed
    state.stats.earned = data.earned

    notify(('استلمت راتب $%s | إجمالي اليوم: $%s'):format(data.payout, data.earned), 'success')
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
        TriggerServerEvent('qb-gascompany:server:setDuty', true)
        notify('تم بدء الدوام في شركة الغاز.', 'success')
    elseif not toggle and state.onDuty then
        stopDuty(false)
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
    state.truck = nil
    state.truckNetId = nil
    state.gasUnits = 0

    notify('تم إرجاع الشاحنة بنجاح.', 'success')
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
            isBoss = Config.BossGrades[(QBCore.Functions.GetPlayerData().job.grade.level or 0)] == true
        }
    })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    cleanupObjects()
    stopDuty(true)
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end

    TriggerEvent('qb-gascompany:client:setupTargets')

    CreateThread(function()
        while true do
            Wait(1000)
            if state.onDuty and state.mission then
                local elapsed = GetGameTimer() - (state.mission.startedAt or GetGameTimer())
                if elapsed > Config.AntiExploit.missionTimeout * 1000 then
                    notify('انتهى وقت المهمة.', 'error')
                    state.mission = nil
                    removeMissionBlip()
                    deleteMissionNpc()
                end
            end
        end
    end)
end)
