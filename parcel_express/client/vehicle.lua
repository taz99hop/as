local QBCore = exports['qb-core']:GetCoreObject()

local function hasCompanyVehicleNearby()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return false end

    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    if Parcel.State.dutyPlate and plate == Parcel.State.dutyPlate then
        return true
    end

    return false
end

local function spawnVehicle()
    if Parcel.State.hasVehicle and Parcel.State.dutyVehicle and DoesEntityExist(Parcel.State.dutyVehicle) then
        return QBCore.Functions.Notify('لديك مركبة عمل بالفعل.', 'error')
    end

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        if not netId then
            return QBCore.Functions.Notify('تعذر إخراج المركبة حالياً.', 'error')
        end

        local veh = NetToVeh(netId)
        while not DoesEntityExist(veh) do Wait(10) end

        local plate = ('%s%d'):format(Config.VehiclePlatePrefix, math.random(100, 999))
        SetVehicleNumberPlateText(veh, plate)
        SetVehicleEngineOn(veh, true, true)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleFuelLevel(veh, 100.0)
        exports['qb-vehiclekeys']:SetVehicleKey(plate, true)

        Parcel.State.hasVehicle = true
        Parcel.State.dutyVehicle = veh
        Parcel.State.dutyPlate = plate

        TriggerServerEvent('parcel_express:server:setVehiclePlate', plate)
        QBCore.Functions.Notify('تم استلام مركبة Parcel Express.', 'success')
    end, Config.CompanyVehicle, Config.Warehouse.vehicleSpawn, true)
end

local function returnVehicle()
    if Parcel.State.dutyVehicle and DoesEntityExist(Parcel.State.dutyVehicle) then
        DeleteVehicle(Parcel.State.dutyVehicle)
    end

    Parcel.State.hasVehicle = false
    Parcel.State.dutyVehicle = nil
    Parcel.State.dutyPlate = nil
    TriggerServerEvent('parcel_express:server:setVehiclePlate', nil)
    QBCore.Functions.Notify('تم إنهاء مركبة الدوام.', 'primary')
end

RegisterNetEvent('parcel_express:client:forceCleanup', function(fromJobChange)
    TriggerEvent('parcel_express:client:stopDelivery', true)
    returnVehicle()
    if fromJobChange then
        QBCore.Functions.Notify('تم تنظيف حالة الوظيفة لتغيير المسمى الوظيفي.', 'error')
    end
end)

CreateThread(function()
    exports['qb-target']:AddBoxZone('parcel_express_vehicle_spawn', Config.Warehouse.vehicleSpawn.xyz, 2.2, 4.6, {
        name = 'parcel_express_vehicle_spawn',
        heading = Config.Warehouse.vehicleSpawn.w,
        debugPoly = Config.Debug,
        minZ = Config.Warehouse.vehicleSpawn.z - 1.0,
        maxZ = Config.Warehouse.vehicleSpawn.z + 2.0
    }, {
        options = {
            {
                label = 'استلام مركبة الشركة',
                icon = Config.Target.iconVehicle,
                action = function()
                    if not Parcel.State.onDuty then
                        return QBCore.Functions.Notify('يجب تسجيل الدخول أولاً.', 'error')
                    end
                    spawnVehicle()
                end,
                canInteract = function()
                    return Parcel.PlayerData.job and Parcel.PlayerData.job.name == Config.JobName
                end
            }
        },
        distance = 3.0
    })

    exports['qb-target']:AddBoxZone('parcel_express_vehicle_return', Config.Warehouse.vehicleReturn, 3.2, 3.2, {
        name = 'parcel_express_vehicle_return',
        heading = 0,
        debugPoly = Config.Debug,
        minZ = Config.Warehouse.vehicleReturn.z - 1.0,
        maxZ = Config.Warehouse.vehicleReturn.z + 2.0
    }, {
        options = {
            {
                label = 'إرجاع مركبة الشركة',
                icon = 'fas fa-warehouse',
                action = function()
                    returnVehicle()
                end,
                canInteract = function()
                    return Parcel.State.hasVehicle
                end
            }
        },
        distance = 3.0
    })
end)

CreateThread(function()
    local weatherHashes = {}
    for weatherType, _ in pairs(Shared.WeatherImpact) do
        weatherHashes[GetHashKey(weatherType)] = weatherType
    end

    while true do
        Wait(2000)
        if Parcel.State.onDuty and Parcel.State.hasVehicle and Parcel.State.dutyVehicle and DoesEntityExist(Parcel.State.dutyVehicle) then
            local currentHash = GetPrevWeatherTypeHashName()
            local weatherType = weatherHashes[currentHash] or 'CLEAR'
            local multiplier = Shared.WeatherImpact[weatherType] or 1.0

            Parcel.State.weatherMultiplier = multiplier
            SetVehicleMaxSpeed(Parcel.State.dutyVehicle, (30.0 * multiplier))

            local body = GetVehicleBodyHealth(Parcel.State.dutyVehicle)
            TriggerServerEvent('parcel_express:server:updateVehicleCondition', body, multiplier)
        end
    end
end)

RegisterNetEvent('parcel_express:client:checkCompanyVehicle', function(cbEvent)
    TriggerServerEvent(cbEvent, hasCompanyVehicleNearby())
end)
