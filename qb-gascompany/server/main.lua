local QBCore = exports['qb-core']:GetCoreObject()

local dutyPlayers = {}
local trucks = {}
local missionLock = {}
local activeMissions = {}

local companyState = {
    funds = 0,
    stock = Config.Company.initialStock or 0,
}

local function isGasEmployee(Player)
    return Player and Player.PlayerData.job and Player.PlayerData.job.name == Config.JobName
end

local function isBoss(Player)
    local grade = Player.PlayerData.job.grade.level or 0
    return Config.BossGrades[grade] == true
end

local function copyAndShuffle(items)
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

local function buildMissionBatch(source, count)
    local pool = Config.Missions.locations
    if #pool == 0 then return nil end

    local picked = {}
    local shuffled = copyAndShuffle(pool)
    local cap = math.min(count, #shuffled)

    for i = 1, cap do
        local place = shuffled[i]
        local requested = place.use or math.random(Config.Truck.missionUse.min, Config.Truck.missionUse.max)
        picked[#picked + 1] = {
            id = ('%s-%s-%s'):format(source, os.time(), i),
            label = place.label,
            coords = place.coords,
            use = requested,
            region = place.region or 'city',
            payoutMult = place.payoutMult or 1.0,
            talked = false,
            filled = false,
            startedAt = GetGameTimer(),
            index = i,
            total = cap,
        }
    end

    return picked
end

local function getMaxJobGrade(jobDef)
    if not jobDef or not jobDef.grades then return 0 end
    local max = 0
    for gradeKey, _ in pairs(jobDef.grades) do
        local g = tonumber(gradeKey) or 0
        if g > max then max = g end
    end
    return max
end

local function sendManagerPanel(src)
    local employees = {}
    local players = QBCore.Functions.GetQBPlayers()

    for id, p in pairs(players) do
        if p and isGasEmployee(p) then
            local info = dutyPlayers[id] or { completed = 0, earned = 0, onDuty = false }
            employees[#employees + 1] = {
                id = id,
                name = p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname,
                onDuty = info.onDuty == true,
                completed = info.completed or 0,
                earned = info.earned or 0,
                grade = p.PlayerData.job.grade.level or 0,
            }
        end
    end

    TriggerClientEvent('qb-gascompany:client:panelData', src, {
        employees = employees,
        company = {
            funds = companyState.funds,
            stock = companyState.stock,
            importCost = Config.Company.import.cost,
            importLiters = Config.Company.import.liters,
            cutPercent = Config.Payments.companyCutPercent,
        }
    })
end

RegisterNetEvent('qb-gascompany:server:setDuty', function(toggle)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    dutyPlayers[src] = dutyPlayers[src] or { completed = 0, earned = 0 }
    dutyPlayers[src].onDuty = toggle
end)

RegisterNetEvent('qb-gascompany:server:registerTruck', function(netId, trailerNetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    trucks[src] = { netId = netId, trailerNetId = trailerNetId, returned = false }
end)

RegisterNetEvent('qb-gascompany:server:requestMission', function(missionCount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not a gas company employee.' })
        return
    end

    if not dutyPlayers[src] or dutyPlayers[src].onDuty ~= true then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Start duty first, then request mission.' })
        return
    end

    TriggerClientEvent('qb-gascompany:client:missionRequested', src)

    if missionLock[src] and os.time() - missionLock[src] < Config.Missions.cooldownSec then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Please wait before requesting another mission.' })
        return
    end

    local count = tonumber(missionCount) or 1
    count = math.floor(count)
    count = math.max(Config.Missions.minBatch or 1, math.min(Config.Missions.maxBatch or 5, count))

    missionLock[src] = os.time()
    local missions = buildMissionBatch(src, count)
    if not missions or #missions == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No mission locations configured.' })
        return
    end

    activeMissions[src] = {}
    for _, mission in ipairs(missions) do
        activeMissions[src][mission.id] = mission
    end

    TriggerClientEvent('qb-gascompany:client:startMissionBatch', src, missions)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('%s mission(s) assigned.'):format(#missions)
    })
end)

RegisterNetEvent('qb-gascompany:server:finishMission', function(payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    if not payload or not payload.missionId then return end
    local serverMission = activeMissions[src] and activeMissions[src][payload.missionId]
    if not serverMission then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Mission validation failed.' })
        return
    end

    dutyPlayers[src] = dutyPlayers[src] or { completed = 0, earned = 0 }

    local completed = dutyPlayers[src].completed + 1
    local basePayout = Config.Payments.base + (Config.Payments.perTaskBonus * completed)
    basePayout = math.floor(basePayout * (serverMission.payoutMult or 1.0))

    if Config.Payments.milestone[completed] then
        basePayout = basePayout + Config.Payments.milestone[completed]
    end

    local companyCut = math.floor(basePayout * ((Config.Payments.companyCutPercent or 0) / 100))
    local playerPayout = math.max(0, basePayout - companyCut)

    Player.Functions.AddMoney('bank', playerPayout, 'gas-company-mission')

    companyState.funds = companyState.funds + companyCut

    dutyPlayers[src].completed = completed
    dutyPlayers[src].earned = dutyPlayers[src].earned + playerPayout

    activeMissions[src][payload.missionId] = nil

    TriggerClientEvent('qb-gascompany:client:missionRewarded', src, {
        payout = playerPayout,
        completed = completed,
        earned = dutyPlayers[src].earned,
        companyCut = companyCut,
        region = serverMission.region,
        multiplier = serverMission.payoutMult or 1.0,
    })
end)

RegisterNetEvent('qb-gascompany:server:requestRefill', function(requiredUnits)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    local amount = math.max(1, math.floor(tonumber(requiredUnits) or 0))
    if amount <= 0 then return end

    if companyState.stock < amount then
        TriggerClientEvent('qb-gascompany:client:refillResult', src, false, companyState.stock)
        return
    end

    companyState.stock = companyState.stock - amount
    TriggerClientEvent('qb-gascompany:client:refillResult', src, true, companyState.stock)
end)

RegisterNetEvent('qb-gascompany:server:returnTruck', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    if trucks[src] and trucks[src].netId == netId then
        trucks[src].returned = true
    end
end)

RegisterNetEvent('qb-gascompany:server:managerAction', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) or not isBoss(Player) then return end

    if data.action == 'kick' and data.target then
        local target = QBCore.Functions.GetPlayer(tonumber(data.target))
        if target and isGasEmployee(target) then
            target.Functions.SetJob('unemployed', 0)
        end
    elseif data.action == 'promote' and data.target then
        local target = QBCore.Functions.GetPlayer(tonumber(data.target))
        if target and isGasEmployee(target) then
            local grade = target.PlayerData.job.grade.level or 0
            local jobDef = QBCore.Shared.Jobs[Config.JobName]
            local maxGrade = getMaxJobGrade(jobDef)
            if grade < maxGrade then
                target.Functions.SetJob(Config.JobName, grade + 1)
                TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Employee promoted successfully.' })
                TriggerClientEvent('ox_lib:notify', target.PlayerData.source, { type = 'success', description = 'You have been promoted in Gas Company.' })
            else
                TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Employee is already at max grade.' })
            end
        end
    elseif data.action == 'companyWithdraw' then
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount <= 0 then return end
        if companyState.funds < amount then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Company balance is not enough.' })
            return
        end

        companyState.funds = companyState.funds - amount
        Player.Functions.AddMoney('bank', amount, 'gas-company-manager-withdraw')
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('You withdrew $%s from company funds.'):format(amount) })
    elseif data.action == 'companyImport' then
        local cost = Config.Company.import.cost
        local liters = Config.Company.import.liters

        if companyState.funds < cost then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Not enough company funds for gas import.' })
            return
        end

        companyState.funds = companyState.funds - cost
        companyState.stock = companyState.stock + liters
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Imported %sL gas for $%s.'):format(liters, cost) })
    elseif data.action == 'panel' then
        sendManagerPanel(src)
        return
    end

    sendManagerPanel(src)
end)

AddEventHandler('playerDropped', function()
    local src = source

    if trucks[src] and not trucks[src].returned then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.RemoveMoney('bank', Config.Truck.penaltyForNoReturn, 'gas-company-truck-penalty')
        end
    end

    dutyPlayers[src] = nil
    trucks[src] = nil
    missionLock[src] = nil
    activeMissions[src] = nil
end)
