local QBCore = exports['qb-core']:GetCoreObject()

local function hasGasJob()
    local player = QBCore.Functions.GetPlayerData()
    return player and player.job and player.job.name == Config.JobName
end

local function mapOptions(options)
    local mapped = {}

    for i = 1, #options do
        local option = options[i]

        if Config.Target == 'ox_target' then
            mapped[#mapped + 1] = {
                name = option.name or ('gas_option_%s'):format(i),
                icon = option.icon,
                label = option.label,
                canInteract = option.canInteract,
                onSelect = option.cb
            }
        else
            mapped[#mapped + 1] = {
                icon = option.icon,
                label = option.label,
                canInteract = option.canInteract,
                action = option.cb
            }
        end
    end

    return mapped
end

local function addBoxTarget(name, coords, size, options)
    local mapped = mapOptions(options)

    if Config.Target == 'ox_target' then
        exports.ox_target:addBoxZone({
            name = name,
            coords = coords,
            size = size,
            rotation = 0,
            debug = Config.Debug,
            options = mapped
        })
    else
        exports['qb-target']:AddBoxZone(name, coords, size.x, size.y, {
            heading = 0,
            minZ = coords.z - 1,
            maxZ = coords.z + 2,
            debugPoly = Config.Debug
        }, {
            options = mapped,
            distance = 2.0
        })
    end
end

local function addEntityTarget(entity, options, distance)
    if not entity or not DoesEntityExist(entity) then return end

    local mapped = mapOptions(options)

    if Config.Target == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, mapped)
    else
        exports['qb-target']:AddTargetEntity(entity, {
            options = mapped,
            distance = distance or 2.5
        })
    end
end

RegisterNetEvent('qb-gascompany:client:setupTargets', function()
    addBoxTarget('gas_duty', Config.Duty.hub, vec3(1.4, 1.2, 2.2), {
        {
            name = 'gas_toggle_duty',
            icon = 'fa-solid fa-user-clock',
            label = 'بدء / إنهاء الدوام',
            cb = function()
                TriggerEvent('qb-gascompany:client:setDuty', not LocalPlayer.state.gasDuty)
                LocalPlayer.state:set('gasDuty', not LocalPlayer.state.gasDuty, true)
            end,
            canInteract = function()
                return hasGasJob()
            end
        },
        {
            name = 'gas_open_panel',
            icon = 'fa-solid fa-chart-line',
            label = 'فتح لوحة شركة الغاز',
            cb = function()
                TriggerEvent('qb-gascompany:client:openPanel')
            end,
            canInteract = function()
                return hasGasJob()
            end
        },
    })

    addBoxTarget('gas_truck_spawn', Config.Duty.truckSpawn.xyz, vec3(2.5, 4.2, 2.2), {
        {
            name = 'gas_spawn_truck',
            icon = 'fa-solid fa-truck',
            label = 'استلام شاحنة الغاز',
            cb = function()
                TriggerEvent('qb-gascompany:client:spawnTruck')
            end,
            canInteract = function()
                return hasGasJob() and LocalPlayer.state.gasDuty == true
            end
        },
    })

    addBoxTarget('gas_return', Config.Duty.returnPoint, vec3(2.4, 2.4, 2.0), {
        {
            name = 'gas_return_truck',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'إرجاع الشاحنة',
            cb = function()
                TriggerEvent('qb-gascompany:client:returnTruck')
            end,
            canInteract = function()
                return hasGasJob() and LocalPlayer.state.gasDuty == true
            end
        }
    })

    addBoxTarget('gas_dispatch', Config.Duty.stash, vec3(1.8, 1.8, 2.0), {
        {
            name = 'gas_request_mission',
            icon = 'fa-solid fa-list-check',
            label = 'استلام مهمة جديدة',
            cb = function()
                TriggerServerEvent('qb-gascompany:server:requestMission')
            end,
            canInteract = function()
                return hasGasJob() and LocalPlayer.state.gasDuty == true
            end
        }
    })
end)

RegisterNetEvent('qb-gascompany:client:registerVehicleTarget', function(entity)
    addEntityTarget(entity, {
        {
            name = 'gas_truck_open_tank',
            icon = 'fa-solid fa-door-open',
            label = 'فتح خزان الشاحنة',
            cb = function()
                TriggerEvent('qb-gascompany:client:openTruckTank')
            end
        },
        {
            name = 'gas_truck_close_tank',
            icon = 'fa-solid fa-door-closed',
            label = 'إغلاق خزان الشاحنة',
            cb = function()
                TriggerEvent('qb-gascompany:client:closeTruckTank')
            end
        }
    }, 2.5)
end)

RegisterNetEvent('qb-gascompany:client:addNpcTarget', function(entity)
    addEntityTarget(entity, {
        {
            name = 'gas_talk_npc',
            icon = 'fa-solid fa-comments',
            label = 'التحدث مع المدني',
            cb = function()
                TriggerEvent('qb-gascompany:client:talkToNpc')
            end,
            canInteract = function(_, distance)
                return distance <= Config.AntiExploit.maxDistanceToInteract
            end
        },
        {
            name = 'gas_fill_npc',
            icon = 'fa-solid fa-gas-pump',
            label = 'بدء تعبئة الغاز',
            cb = function()
                TriggerEvent('qb-gascompany:client:startFill')
            end,
            canInteract = function(_, distance)
                return distance <= Config.AntiExploit.maxDistanceToInteract
            end
        },
        {
            name = 'gas_finish_npc',
            icon = 'fa-solid fa-check',
            label = 'إنهاء المهمة',
            cb = function()
                TriggerEvent('qb-gascompany:client:finishMission')
            end,
            canInteract = function(_, distance)
                return distance <= Config.AntiExploit.maxDistanceToInteract
            end
        }
    }, 2.0)
end)
