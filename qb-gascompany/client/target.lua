local QBCore = exports['qb-core']:GetCoreObject()

local INTERACT_KEY = 38 -- E

local function hasGasJob()
    local player = QBCore.Functions.GetPlayerData()
    return player and player.job and player.job.name == Config.JobName
end

local function showHelp(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, 1)
end

local function isNear(coords, radius)
    local pos = GetEntityCoords(PlayerPedId())
    return #(pos - coords) <= radius
end

local function drawMarkerAt(coords)
    DrawMarker(2, coords.x, coords.y, coords.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 52, 211, 153, 180, false, true, 2, false, nil, nil, false)
end

CreateThread(function()
    while true do
        local waitMs = 1000

        if hasGasJob() then
            local onDuty = LocalPlayer.state.gasDuty == true

            if isNear(Config.Duty.hub, 2.0) then
                waitMs = 0
                drawMarkerAt(Config.Duty.hub)
                showHelp('Press ~INPUT_CONTEXT~ for duty toggle (Shift + E opens panel)')

                if IsControlJustReleased(0, INTERACT_KEY) then
                    if IsControlPressed(0, 21) then
                        TriggerEvent('qb-gascompany:client:openPanel')
                    else
                        TriggerEvent('qb-gascompany:client:setDuty', not onDuty)
                    end
                    Wait(250)
                end
            end

            if onDuty and isNear(Config.Duty.truckSpawn.xyz, 3.5) then
                waitMs = 0
                drawMarkerAt(Config.Duty.truckSpawn.xyz)
                local gasUnits = LocalPlayer.state.gasUnits or 0
                local hasTruck = LocalPlayer.state.gasTruckActive == true
                if hasTruck and gasUnits <= 0 and onDuty then
                    showHelp('Press ~INPUT_CONTEXT~ to refill trailer tank')
                else
                    showHelp('Press ~INPUT_CONTEXT~ to take the gas truck')
                end

                if IsControlJustReleased(0, INTERACT_KEY) then
                    if hasTruck and gasUnits <= 0 and onDuty then
                        TriggerEvent('qb-gascompany:client:refillTrailerTank')
                    else
                        TriggerEvent('qb-gascompany:client:spawnTruck')
                    end
                    Wait(250)
                end
            end

            if onDuty and isNear(Config.Duty.stash, 3.5) then
                waitMs = 0
                drawMarkerAt(Config.Duty.stash)
                showHelp('Press ~INPUT_CONTEXT~ to request a delivery mission')

                if IsControlJustReleased(0, INTERACT_KEY) then
                    TriggerServerEvent('qb-gascompany:server:requestMission')
                    Wait(250)
                end
            end

            if onDuty and isNear(Config.Duty.returnPoint, 3.5) then
                waitMs = 0
                drawMarkerAt(Config.Duty.returnPoint)
                showHelp('Press ~INPUT_CONTEXT~ to return the truck')

                if IsControlJustReleased(0, INTERACT_KEY) then
                    TriggerEvent('qb-gascompany:client:returnTruck')
                    Wait(250)
                end
            end
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 1000
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)

        if veh == 0 then
            local playerPos = GetEntityCoords(PlayerPedId())
            local closestVeh = GetClosestVehicle(playerPos.x, playerPos.y, playerPos.z, 4.0, 0, 71)

            if closestVeh ~= 0 and LocalPlayer.state.gasDuty == true then
                local rearPos = GetOffsetFromEntityInWorldCoords(closestVeh, 0.0, -3.2, 0.0)
                if #(playerPos - rearPos) <= 1.8 then
                    waitMs = 0
                    drawMarkerAt(rearPos)

                    local doorAngle = GetVehicleDoorAngleRatio(closestVeh, 5)
                    local text = doorAngle > 0.01 and 'Press ~INPUT_CONTEXT~ to close truck tank' or 'Press ~INPUT_CONTEXT~ to open truck tank'
                    showHelp(text)

                    if IsControlJustReleased(0, INTERACT_KEY) then
                        if doorAngle > 0.01 then
                            TriggerEvent('qb-gascompany:client:closeTruckTank')
                        else
                            TriggerEvent('qb-gascompany:client:openTruckTank')
                        end
                        Wait(200)
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

RegisterNetEvent('qb-gascompany:client:setupTargets', function()
    -- E-interactions are created by threads in this file.
end)

RegisterNetEvent('qb-gascompany:client:registerVehicleTarget', function()
    -- Kept only for compatibility.
end)

RegisterNetEvent('qb-gascompany:client:addNpcTarget', function()
    -- Kept only for compatibility.
end)
