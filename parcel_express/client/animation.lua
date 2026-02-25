local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) do
        Wait(20)
        if GetGameTimer() > timeout then
            return false
        end
    end
    return true
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        Wait(20)
        if GetGameTimer() > timeout then
            return false
        end
    end
    return true
end

RegisterNetEvent('parcel_express:client:startCarryBox', function()
    if Parcel.State.carrying then return end

    local ped = PlayerPedId()
    if not loadModel(Config.PackageModel) then
        return TriggerEvent('parcel_express:client:notify', 'تعذر تحميل نموذج الطرد.', 'error')
    end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(Config.PackageModel, coords.x, coords.y, coords.z, true, true, false)

    if not loadAnimDict(Shared.Animations.carry.dict) then
        DeleteEntity(obj)
        return TriggerEvent('parcel_express:client:notify', 'تعذر تحميل حركة الحمل.', 'error')
    end

    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 57005), 0.24, 0.04, -0.06, 265.0, 290.0, 55.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, Shared.Animations.carry.dict, Shared.Animations.carry.clip, 8.0, -8.0, -1, Shared.Animations.carry.flag, 0, false, false, false)

    Parcel.State.carrying = true
    Parcel.State.carriedObject = obj

    SetPedCanRagdoll(ped, false)
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)

    CreateThread(function()
        while Parcel.State.carrying do
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        end
    end)
end)

RegisterNetEvent('parcel_express:client:placeBox', function(doorCoords)
    if not Parcel.State.carrying then return end

    local ped = PlayerPedId()
    if loadAnimDict(Shared.Animations.place.dict) then
        TaskPlayAnim(ped, Shared.Animations.place.dict, Shared.Animations.place.clip, 4.0, -4.0, Shared.Animations.place.duration, Shared.Animations.place.flag, 0, false, false, false)
        Wait(Shared.Animations.place.duration)
    end

    if Parcel.State.carriedObject and DoesEntityExist(Parcel.State.carriedObject) then
        DetachEntity(Parcel.State.carriedObject, true, true)
        DeleteEntity(Parcel.State.carriedObject)
    end

    local placed = CreateObject(Config.PackageModel, doorCoords.x, doorCoords.y, doorCoords.z - 1.0, true, true, false)
    PlaceObjectOnGroundProperly(placed)

    Parcel.State.carrying = false
    Parcel.State.carriedObject = nil

    StopAnimTask(ped, Shared.Animations.carry.dict, Shared.Animations.carry.clip, 1.0)
    SetPedCanRagdoll(ped, true)

    PlaySoundFrontend(-1, 'BASE_JUMP_PASSED', 'HUD_AWARDS', true)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)

    SetTimeout(Config.PackageDeleteDelay, function()
        if DoesEntityExist(placed) then
            DeleteEntity(placed)
        end
    end)
end)

RegisterNetEvent('parcel_express:client:cancelCarry', function()
    local ped = PlayerPedId()
    if Parcel.State.carriedObject and DoesEntityExist(Parcel.State.carriedObject) then
        DetachEntity(Parcel.State.carriedObject, true, true)
        DeleteEntity(Parcel.State.carriedObject)
    end

    Parcel.State.carrying = false
    Parcel.State.carriedObject = nil
    SetPedCanRagdoll(ped, true)
    StopAnimTask(ped, Shared.Animations.carry.dict, Shared.Animations.carry.clip, 1.0)
end)
