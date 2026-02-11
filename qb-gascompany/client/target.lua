local QBCore = exports['qb-core']:GetCoreObject()

local function addBoxTarget(name, coords, size, options)
    if Config.Target == 'ox_target' then
        exports.ox_target:addBoxZone({
            name = name,
            coords = coords,
            size = size,
            rotation = 0,
            options = options
        })
    else
        exports['qb-target']:AddBoxZone(name, coords, size.x, size.y, {
            heading = 0,
            minZ = coords.z - 1,
            maxZ = coords.z + 2,
            debugPoly = Config.Debug
        }, {
            options = options,
            distance = 2.0
        })
    end
end

RegisterNetEvent('qb-gascompany:client:setupTargets', function()
    addBoxTarget('gas_duty', Config.Duty.hub, vec3(1.4, 1.2, 2.2), {
        {
            icon = 'fa-solid fa-user-clock',
            label = 'بدء / إنهاء الدوام',
            onSelect = function()
                TriggerEvent('qb-gascompany:client:setDuty', not LocalPlayer.state.gasDuty)
                LocalPlayer.state:set('gasDuty', not LocalPlayer.state.gasDuty, true)
            end,
            action = function()
                TriggerEvent('qb-gascompany:client:setDuty', not LocalPlayer.state.gasDuty)
                LocalPlayer.state:set('gasDuty', not LocalPlayer.state.gasDuty, true)
            end,
            canInteract = function()
                local job = QBCore.Functions.GetPlayerData().job
                return job and job.name == Config.JobName
            end
        },
        {
            icon = 'fa-solid fa-chart-line',
            label = 'فتح لوحة شركة الغاز',
            onSelect = function() TriggerEvent('qb-gascompany:client:openPanel') end,
            action = function() TriggerEvent('qb-gascompany:client:openPanel') end,
            canInteract = function()
                local job = QBCore.Functions.GetPlayerData().job
                return job and job.name == Config.JobName
            end
        },
    })

    addBoxTarget('gas_truck_spawn', Config.Duty.truckSpawn.xyz, vec3(2.5, 4.2, 2.2), {
        {
            icon = 'fa-solid fa-truck',
            label = 'استلام شاحنة الغاز',
            onSelect = function() TriggerEvent('qb-gascompany:client:spawnTruck') end,
            action = function() TriggerEvent('qb-gascompany:client:spawnTruck') end,
            canInteract = function()
                local job = QBCore.Functions.GetPlayerData().job
                return job and job.name == Config.JobName and LocalPlayer.state.gasDuty == true
            end
        },
    })

    addBoxTarget('gas_return', Config.Duty.returnPoint, vec3(2.4, 2.4, 2.0), {
        {
            icon = 'fa-solid fa-right-from-bracket',
            label = 'إرجاع الشاحنة',
            onSelect = function() TriggerEvent('qb-gascompany:client:returnTruck') end,
            action = function() TriggerEvent('qb-gascompany:client:returnTruck') end,
            canInteract = function()
                local job = QBCore.Functions.GetPlayerData().job
                return job and job.name == Config.JobName and LocalPlayer.state.gasDuty == true
            end
        }
    })

    addBoxTarget('gas_dispatch', Config.Duty.stash, vec3(1.8, 1.8, 2.0), {
        {
            icon = 'fa-solid fa-list-check',
            label = 'استلام مهمة جديدة',
            onSelect = function()
                TriggerServerEvent('qb-gascompany:server:requestMission')
            end,
            action = function()
                TriggerServerEvent('qb-gascompany:server:requestMission')
            end,
            canInteract = function()
                local job = QBCore.Functions.GetPlayerData().job
                return job and job.name == Config.JobName and LocalPlayer.state.gasDuty == true
            end
        }
    })
end)

RegisterNetEvent('qb-gascompany:client:registerVehicleTarget', function(entity)
    if not entity or not DoesEntityExist(entity) then return end

    exports[Config.Target]:AddTargetEntity(entity, {
        options = {
            {
                icon = 'fa-solid fa-door-open',
                label = 'فتح خزان الشاحنة',
                action = function() TriggerEvent('qb-gascompany:client:openTruckTank') end
            },
            {
                icon = 'fa-solid fa-door-closed',
                label = 'إغلاق خزان الشاحنة',
                action = function() TriggerEvent('qb-gascompany:client:closeTruckTank') end
            }
        },
        distance = 2.5
    })
end)
