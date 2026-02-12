local QBCore = exports['qb-core']:GetCoreObject()

local dutyPlayers = {}
local trucks = {}
local missionLock = {}

local function isGasEmployee(Player)
    return Player and Player.PlayerData.job and Player.PlayerData.job.name == Config.JobName
end

local function isBoss(Player)
    local grade = Player.PlayerData.job.grade.level or 0
    return Config.BossGrades[grade] == true
end

local function getRandomMission(source)
    local pool = Config.Missions.locations
    if #pool == 0 then return nil end

    local pick = pool[math.random(1, #pool)]
    local requested = pick.use or math.random(Config.Truck.missionUse.min, Config.Truck.missionUse.max)

    return {
        id = ('%s-%s'):format(source, os.time()),
        label = pick.label,
        coords = pick.coords,
        use = requested,
        talked = false,
        filled = false,
        startedAt = GetGameTimer(),
    }
end

RegisterNetEvent('qb-gascompany:server:setDuty', function(toggle)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    dutyPlayers[src] = dutyPlayers[src] or { completed = 0, earned = 0 }
    dutyPlayers[src].onDuty = toggle
end)

RegisterNetEvent('qb-gascompany:server:registerTruck', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    trucks[src] = { netId = netId, returned = false }
end)

RegisterNetEvent('qb-gascompany:server:requestMission', function()
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

    missionLock[src] = os.time()
    local mission = getRandomMission(src)
    if not mission then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No mission locations configured.' })
        return
    end

    TriggerClientEvent('qb-gascompany:client:startMission', src, mission)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('Mission assigned: %s'):format(mission.label)
    })
end)

RegisterNetEvent('qb-gascompany:server:finishMission', function(payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not isGasEmployee(Player) then return end

    dutyPlayers[src] = dutyPlayers[src] or { completed = 0, earned = 0 }

    local completed = dutyPlayers[src].completed + 1
    local payout = Config.Payments.base + (Config.Payments.perTaskBonus * completed)

    if Config.Payments.milestone[completed] then
        payout = payout + Config.Payments.milestone[completed]
    end

    Player.Functions.AddMoney('bank', payout, 'gas-company-mission')

    dutyPlayers[src].completed = completed
    dutyPlayers[src].earned = dutyPlayers[src].earned + payout

    TriggerClientEvent('qb-gascompany:client:missionRewarded', src, {
        payout = payout,
        completed = completed,
        earned = dutyPlayers[src].earned
    })
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
    elseif data.action == 'panel' then
        local employees = {}
        for id, info in pairs(dutyPlayers) do
            local p = QBCore.Functions.GetPlayer(id)
            if p and isGasEmployee(p) then
                employees[#employees + 1] = {
                    id = id,
                    name = p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname,
                    onDuty = info.onDuty == true,
                    completed = info.completed,
                    earned = info.earned
                }
            end
        end

        TriggerClientEvent('qb-gascompany:client:panelData', src, {
            employees = employees
        })
    end
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
end)
