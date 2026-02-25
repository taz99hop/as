local QBCore = exports['qb-core']:GetCoreObject()

local DutyPlayers = {}
local ActiveRoutes = {}
local RouteCounter = 0

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function isManager(player)
    return player and player.PlayerData.job and player.PlayerData.job.name == Config.JobName and (player.PlayerData.job.grade.level or 0) >= 1
end

local function ensureDutyState(src)
    DutyPlayers[src] = DutyPlayers[src] or {
        onDuty = false,
        plate = nil,
        vehicleBody = 1000.0,
        weatherMultiplier = 1.0,
        loaded = 0,
        routes = {},
        delivered = 0,
        earnedSession = 0
    }
    return DutyPlayers[src]
end

local function getOnlineDriversCount()
    local count = 0
    for _, data in pairs(DutyPlayers) do
        if data.onDuty then count = count + 1 end
    end
    return count
end

local function makeRoute(src)
    local state = ensureDutyState(src)
    local available = Config.HomeDeliveryPoints
    local point = available[math.random(1, #available)]
    local urgent = math.random(1, 100) <= Config.UrgentChance

    RouteCounter = RouteCounter + 1
    local route = {
        routeId = RouteCounter,
        coords = point,
        urgent = urgent,
        expiresAt = urgent and (os.time() + Config.UrgentDuration) or nil,
        startedAt = os.time(),
        source = src
    }

    state.routes[route.routeId] = route
    ActiveRoutes[route.routeId] = route
    return route
end

local function sendTabletData(src, withManager)
    local player = getPlayer(src)
    if not player then return end

    local stats = ParcelDB.getStats(player.PlayerData.citizenid)
    local state = ensureDutyState(src)

    local payload = {
        delivered = stats.total_delivered,
        earnings = stats.total_earnings,
        rating = stats.rating,
        level = stats.level,
        onlineDrivers = getOnlineDriversCount(),
        activeTasks = 0,
        dayProfit = 0
    }

    if withManager and isManager(player) then
        local tasks = 0
        for _ in pairs(ActiveRoutes) do tasks = tasks + 1 end
        payload.activeTasks = tasks
        payload.dayProfit = ParcelDB.getTodayProfit()

        local drivers = {}
        for targetSrc, data in pairs(DutyPlayers) do
            if data.onDuty then
                local target = getPlayer(targetSrc)
                if target then
                    drivers[#drivers + 1] = {
                        source = targetSrc,
                        name = ('%s %s'):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname),
                        delivered = data.delivered,
                        loaded = data.loaded,
                        plate = data.plate
                    }
                end
            end
        end

        payload.manager = { drivers = drivers }
    end

    TriggerClientEvent('parcel_express:client:tabletData', src, payload)
end

RegisterNetEvent('parcel_express:server:requestTabletData', function()
    sendTabletData(source, true)
end)

RegisterNetEvent('parcel_express:server:toggleDuty', function()
    local src = source
    local player = getPlayer(src)
    if not player or player.PlayerData.job.name ~= Config.JobName then return end

    local state = ensureDutyState(src)
    state.onDuty = not state.onDuty

    if not state.onDuty then
        state.loaded = 0
        state.plate = nil
        for routeId in pairs(state.routes) do
            ActiveRoutes[routeId] = nil
        end
        state.routes = {}
        TriggerClientEvent('parcel_express:client:stopDelivery', src, true)
    end

    TriggerClientEvent('parcel_express:client:updateDutyState', src, state.onDuty)
    sendTabletData(src, false)
end)

RegisterNetEvent('parcel_express:server:setVehiclePlate', function(plate)
    local state = ensureDutyState(source)
    state.plate = plate and plate:gsub('%s+', '') or nil
end)

RegisterNetEvent('parcel_express:server:updateVehicleCondition', function(body, weatherMultiplier)
    local state = ensureDutyState(source)
    state.vehicleBody = tonumber(body) or 1000.0
    state.weatherMultiplier = tonumber(weatherMultiplier) or 1.0
end)

RegisterNetEvent('parcel_express:server:loadPackages', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end

    local state = ensureDutyState(src)
    if not state.onDuty then
        return TriggerClientEvent('parcel_express:client:notify', src, 'سجل دخولك للدوام أولاً.', 'error')
    end

    if not state.plate then
        return TriggerClientEvent('parcel_express:client:notify', src, 'لا يمكنك تحميل الطرود بدون مركبة الشركة.', 'error')
    end

    state.loaded = math.random(Config.MinPackages, Config.MaxPackages)
    TriggerClientEvent('parcel_express:client:packagesLoaded', src, state.loaded)
end)

RegisterNetEvent('parcel_express:server:requestRoute', function()
    local src = source
    local state = ensureDutyState(src)
    if not state.onDuty then
        return TriggerClientEvent('parcel_express:client:notify', src, 'يجب تسجيل الدخول أولاً.', 'error')
    end

    if not state.plate then
        return TriggerClientEvent('parcel_express:client:notify', src, 'المهمة تتطلب مركبة الشركة.', 'error')
    end

    if state.loaded <= 0 then
        return TriggerClientEvent('parcel_express:client:notify', src, 'لا توجد طرود في المركبة، توجه للمستودع.', 'error')
    end

    local route = makeRoute(src)
    TriggerClientEvent('parcel_express:client:setRoute', src, route)
end)

RegisterNetEvent('parcel_express:server:completeRoute', function(routeId)
    local src = source
    local player = getPlayer(src)
    local state = ensureDutyState(src)
    local route = state.routes[routeId]

    if not player or not route then
        return TriggerClientEvent('parcel_express:client:notify', src, 'تعذر اعتماد التسليم: بيانات غير صحيحة.', 'error')
    end

    if ActiveRoutes[routeId] == nil then
        return TriggerClientEvent('parcel_express:client:notify', src, 'هذا الطرد تم تسليمه مسبقاً.', 'error')
    end

    local now = os.time()
    local isFast = (now - route.startedAt) <= math.floor(95 * state.weatherMultiplier)
    local urgentMissed = route.urgent and route.expiresAt and now > route.expiresAt

    local rating = math.random(3, 5)
    if urgentMissed then rating = math.random(1, 2) end

    local pay = ParcelPay.calculate({
        fast = isFast,
        urgent = route.urgent and not urgentMissed,
        rating = rating,
        vehicleBody = state.vehicleBody
    })

    state.loaded = math.max(0, state.loaded - 1)
    state.delivered = state.delivered + 1
    state.earnedSession = state.earnedSession + pay.total
    state.routes[routeId] = nil
    ActiveRoutes[routeId] = nil

    player.Functions.AddMoney('bank', pay.total, 'parcel-express-delivery')

    local updated = ParcelDB.updateStats(player.PlayerData.citizenid, 1, pay.total, rating)
    ParcelDB.logPayout(player.PlayerData.citizenid, routeId, pay.total, {
        fast = isFast,
        urgent = route.urgent,
        urgentMissed = urgentMissed,
        weatherMultiplier = state.weatherMultiplier,
        vehicleBody = state.vehicleBody,
        breakdown = pay
    })

    TriggerClientEvent('parcel_express:client:updateStats', src, updated)
    TriggerClientEvent('parcel_express:client:notify', src, ('تم التسليم! الربح: $%d | التقييم: %d نجوم'):format(pay.total, rating), 'success')
end)

RegisterNetEvent('parcel_express:server:managerRequestData', function()
    sendTabletData(source, true)
end)

RegisterNetEvent('parcel_express:server:managerAction', function(data)
    local src = source
    local manager = getPlayer(src)
    if not isManager(manager) then return end

    if data.action == 'changeBasePay' then
        local amount = tonumber(data.amount)
        if not amount or amount < 20 or amount > 300 then
            return TriggerClientEvent('parcel_express:client:notify', src, 'قيمة راتب غير صالحة.', 'error')
        end

        Config.Payments.basePerPackage = amount
        TriggerClientEvent('parcel_express:client:notify', src, ('تم تحديث الراتب الأساسي إلى $%d'):format(amount), 'success')
    elseif data.action == 'fireDriver' then
        local targetSrc = tonumber(data.target)
        local target = getPlayer(targetSrc)
        if not target then
            return TriggerClientEvent('parcel_express:client:notify', src, 'الموظف غير متصل حالياً.', 'error')
        end

        target.Functions.SetJob('unemployed', 0)
        TriggerClientEvent('parcel_express:client:notify', targetSrc, 'تم فصلك من Parcel Express من قبل الإدارة.', 'error')
        TriggerClientEvent('parcel_express:client:notify', src, 'تم فصل الموظف بنجاح.', 'success')
    elseif data.action == 'resetStats' then
        local citizenid = tostring(data.citizenid or '')
        if citizenid == '' then
            return TriggerClientEvent('parcel_express:client:notify', src, 'أدخل citizenid صحيح.', 'error')
        end

        ParcelDB.resetStats(citizenid)
        TriggerClientEvent('parcel_express:client:notify', src, 'تم إعادة تعيين الإحصائيات بنجاح.', 'success')
    end

    sendTabletData(src, true)
end)

RegisterNetEvent('parcel_express:server:managerTrackDrivers', function()
    local src = source
    local manager = getPlayer(src)
    if not isManager(manager) then return end

    local drivers = {}
    for targetSrc, state in pairs(DutyPlayers) do
        if state.onDuty then
            local ped = GetPlayerPed(targetSrc)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local target = getPlayer(targetSrc)
                if target then
                    drivers[#drivers + 1] = {
                        source = targetSrc,
                        name = ('%s %s'):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname),
                        coords = coords
                    }
                end
            end
        end
    end

    TriggerClientEvent('parcel_express:client:updateDriverBlips', src, drivers)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = DutyPlayers[src]
    if not state then return end

    for routeId in pairs(state.routes) do
        ActiveRoutes[routeId] = nil
    end

    DutyPlayers[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DutyPlayers = {}
    ActiveRoutes = {}
end)
