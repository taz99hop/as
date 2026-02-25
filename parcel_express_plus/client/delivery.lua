local QBCore = exports['qb-core']:GetCoreObject()

local currentDoorZone = nil
local currentBlip = nil

local function hasDutyVehicleLocal()
    if Parcel.State.hasVehicle then
        return true
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return false end

    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local isCompanyPlate = plate ~= '' and plate:sub(1, #Config.VehiclePlatePrefix) == Config.VehiclePlatePrefix
    local isCompanyModel = GetEntityModel(veh) == GetHashKey(Config.CompanyVehicle)

    if isCompanyPlate or isCompanyModel then
        Parcel.State.hasVehicle = true
        Parcel.State.dutyVehicle = veh
        Parcel.State.dutyPlate = plate ~= '' and plate or Parcel.State.dutyPlate
        return true
    end

    return false
end

local function clearDoorTarget()
    if currentDoorZone then
        exports['qb-target']:RemoveZone(currentDoorZone)
        currentDoorZone = nil
    end
end

local function clearDeliveryBlip()
    if currentBlip and DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        currentBlip = nil
    end
end

local function setRouteBlip(coords, urgent)
    clearDeliveryBlip()
    currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, urgent and 161 or 280)
    SetBlipColour(currentBlip, urgent and 1 or 5)
    SetBlipScale(currentBlip, urgent and 0.9 or 0.75)
    SetBlipRoute(currentBlip, true)
    SetBlipRouteColour(currentBlip, urgent and 1 or 3)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(urgent and 'توصيل مستعجل' or 'عنوان توصيل')
    EndTextCommandSetBlipName(currentBlip)
end

local function addDoorTarget(route)
    clearDoorTarget()
    local zoneName = ('parcel_express_door_%d'):format(route.routeId)
    currentDoorZone = zoneName

    exports['qb-target']:AddCircleZone(zoneName, route.coords.xyz, 1.0, {
        name = zoneName,
        useZ = true,
        debugPoly = Config.Debug
    }, {
        options = {
            {
                icon = Config.Target.iconDoor,
                label = 'تسليم الطرد',
                action = function()
                    TriggerEvent('parcel_express:client:deliverPackage')
                end,
                canInteract = function()
                    return Parcel.State.carrying and Parcel.State.activeRoute and Parcel.State.activeRoute.routeId == route.routeId
                end
            }
        },
        distance = 2.0
    })
end

local function playNPCAck(route)
    local model = `a_f_y_business_04`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local npc = CreatePed(4, model, route.coords.x + 0.7, route.coords.y, route.coords.z - 1.0, route.coords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    TaskTurnPedToFaceCoord(npc, GetEntityCoords(PlayerPedId()), 1200)

    SetTimeout(2500, function()
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end)

    local line = Config.NPCLines[math.random(1, #Config.NPCLines)]
    QBCore.Functions.Notify(('العميل: %s'):format(line), 'success', 3000)
end

local function requestNextRoute()
    if not Parcel.State.onDuty then
        return QBCore.Functions.Notify('يجب تسجيل الدخول إلى الدوام أولاً.', 'error')
    end

    if not hasDutyVehicleLocal() then
        return QBCore.Functions.Notify('لا يمكنك البدء بدون مركبة الشركة.', 'error')
    end

    TriggerServerEvent('parcel_express:server:requestRoute')
end

CreateThread(function()
    exports['qb-target']:AddBoxZone('parcel_express_package_load', Config.Warehouse.packageLoad, 1.5, 1.5, {
        name = 'parcel_express_package_load',
        heading = 0,
        debugPoly = Config.Debug,
        minZ = Config.Warehouse.packageLoad.z - 1.0,
        maxZ = Config.Warehouse.packageLoad.z + 1.2
    }, {
        options = {
            {
                label = 'تحميل الطرود للشحنة الحالية',
                icon = Config.Target.iconPackage,
                action = function()
                    if not Parcel.State.onDuty then
                        return QBCore.Functions.Notify('يجب تسجيل الدخول أولاً.', 'error')
                    end
                    if not hasDutyVehicleLocal() then
                        return QBCore.Functions.Notify('يجب استلام مركبة العمل أولاً.', 'error')
                    end

                    local now = GetGameTimer()
                    if Parcel.State.lastLoadAt and (now - Parcel.State.lastLoadAt) < 3500 then
                        return QBCore.Functions.Notify('انتظر قليلاً قبل إعادة التحميل.', 'error')
                    end
                    Parcel.State.lastLoadAt = now

                    if Parcel.State.dutyPlate then
                        TriggerServerEvent('parcel_express:server:setVehiclePlate', Parcel.State.dutyPlate)
                    end

                    QBCore.Functions.Progressbar('parcel_load', 'جاري تحميل الطرود من المستودع...', 6000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableCombat = true,
                        disableMouse = false
                    }, {
                        animDict = 'amb@prop_human_bum_bin@base',
                        anim = 'base',
                        flags = 49
                    }, {}, {}, function()
                        TriggerServerEvent('parcel_express:server:loadPackages')
                    end, function()
                        QBCore.Functions.Notify('تم إلغاء التحميل.', 'error')
                    end)
                end,
                canInteract = function()
                    return Parcel.PlayerData.job and Parcel.PlayerData.job.name == Config.JobName
                end
            },
            {
                label = 'بدء أول عملية توصيل',
                icon = 'fas fa-map-marked-alt',
                action = function()
                    requestNextRoute()
                end,
                canInteract = function()
                    return Parcel.State.packagesLoaded > 0 and not Parcel.State.activeRoute
                end
            }
        },
        distance = 2.0
    })
end)

RegisterNetEvent('parcel_express:client:packagesLoaded', function(amount)
    Parcel.State.packagesLoaded = amount
    QBCore.Functions.Notify(('تم تجهيز %d طرداً للتوزيع.'):format(amount), 'success')
end)

RegisterNetEvent('parcel_express:client:setRoute', function(route)
    Parcel.State.activeRoute = route
    setRouteBlip(route.coords, route.urgent)
    addDoorTarget(route)

    QBCore.Functions.Notify(route.urgent and 'طلب مستعجل! لديك وقت محدود.' or 'تم تحديد عنوان التسليم التالي.', route.urgent and 'error' or 'primary')

    TriggerEvent('parcel_express:client:startCarryBox')
end)

RegisterNetEvent('parcel_express:client:deliverPackage', function()
    if not Parcel.State.activeRoute then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local dest = Parcel.State.activeRoute.coords.xyz
    if #(coords - dest) > Config.RequiredDeliveryDistance then
        return QBCore.Functions.Notify('اقترب أكثر من الباب لتسليم الطرد.', 'error')
    end

    QBCore.Functions.Progressbar('parcel_deliver', 'جاري تسليم الطرد...', 2600, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
        disableMouse = false
    }, {}, {}, {}, function()
        TriggerEvent('parcel_express:client:placeBox', Parcel.State.activeRoute.coords)
        playNPCAck(Parcel.State.activeRoute)
        TriggerServerEvent('parcel_express:server:completeRoute', Parcel.State.activeRoute.routeId)

        Parcel.State.packagesLoaded = math.max(0, Parcel.State.packagesLoaded - 1)
        Parcel.State.activeRoute = nil
        clearDoorTarget()
        clearDeliveryBlip()

        if Parcel.State.packagesLoaded > 0 then
            SetTimeout(750, function()
                requestNextRoute()
            end)
        else
            QBCore.Functions.Notify('انتهت كل الطرود، عد للمستودع لإعادة التحميل.', 'success')
        end
    end, function()
        QBCore.Functions.Notify('تم إلغاء التسليم.', 'error')
    end)
end)

RegisterNetEvent('parcel_express:client:stopDelivery', function(force)
    clearDoorTarget()
    clearDeliveryBlip()
    Parcel.State.activeRoute = nil
    if force then
        Parcel.State.packagesLoaded = 0
    end
    TriggerEvent('parcel_express:client:cancelCarry')
end)
